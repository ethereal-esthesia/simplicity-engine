use std::ffi::OsString;
use std::fs::{self, OpenOptions};
use std::io::{self, BufRead, Write};
use std::path::PathBuf;
use std::sync::Mutex;

const GUIDANCE: &str = include_str!("../../web/assets/diagram-guide.mmd");

pub struct DiagramFile {
    path: PathBuf,
    pub source: String,
    saved_source: Mutex<String>,
}

impl DiagramFile {
    pub fn from_process() -> Result<Self, String> {
        Self::open(
            std::env::args_os().skip(1),
            &mut io::stdin().lock(),
            &mut io::stderr().lock(),
        )
    }

    fn open(
        mut args: impl Iterator<Item = OsString>,
        input: &mut impl BufRead,
        output: &mut impl Write,
    ) -> Result<Self, String> {
        let path = args
            .next()
            .map(PathBuf::from)
            .ok_or_else(|| "Usage: simplicity-app <diagram.mmd>".to_owned())?;
        if args.next().is_some() {
            return Err("Usage: simplicity-app <diagram.mmd>".to_owned());
        }

        let saved_source = match fs::read_to_string(&path) {
            Ok(source) => source,
            Err(error) if error.kind() == io::ErrorKind::NotFound => {
                loop {
                    write!(output, "Create {}? [y/n] ", path.display())
                        .and_then(|_| output.flush())
                        .map_err(|error| format!("Cannot display confirmation: {error}"))?;
                    let mut answer = String::new();
                    if input
                        .read_line(&mut answer)
                        .map_err(|error| error.to_string())?
                        == 0
                    {
                        return Err("Cannot confirm file creation: no input available".to_owned());
                    }
                    match answer.trim().to_ascii_lowercase().as_str() {
                        "y" | "yes" => break,
                        "n" | "no" => return Err("File creation cancelled".to_owned()),
                        _ => writeln!(output, "Please answer y or n.")
                            .map_err(|error| error.to_string())?,
                    }
                }
                let mut file = OpenOptions::new()
                    .write(true)
                    .create_new(true)
                    .open(&path)
                    .map_err(|error| format!("Cannot create {}: {error}", path.display()))?;
                file.write_all(GUIDANCE.as_bytes())
                    .map_err(|error| format!("Cannot write {}: {error}", path.display()))?;
                GUIDANCE.to_owned()
            }
            Err(error) => return Err(format!("Cannot read {}: {error}", path.display())),
        };
        let path = fs::canonicalize(&path)
            .map_err(|error| format!("Cannot resolve {}: {error}", path.display()))?;
        let source = if saved_source.trim().is_empty() {
            GUIDANCE.to_owned()
        } else {
            saved_source.clone()
        };
        Ok(Self {
            path,
            source,
            saved_source: Mutex::new(saved_source),
        })
    }

    pub fn save(&self, source: &str) -> Result<(), String> {
        let mut saved = self
            .saved_source
            .lock()
            .map_err(|error| error.to_string())?;
        let current = fs::read_to_string(&self.path)
            .map_err(|error| format!("Cannot read {}: {error}", self.path.display()))?;
        if current != *saved {
            return Err(format!(
                "{} changed on disk; reload it before saving",
                self.path.display()
            ));
        }
        let original = OpenOptions::new()
            .write(true)
            .open(&self.path)
            .map_err(|error| format!("Cannot open {} for writing: {error}", self.path.display()))?;
        let parent = self
            .path
            .parent()
            .ok_or_else(|| format!("Cannot find the directory for {}", self.path.display()))?;
        let mut temporary = tempfile::NamedTempFile::new_in(parent).map_err(|error| {
            format!("Cannot prepare a save for {}: {error}", self.path.display())
        })?;
        temporary
            .write_all(source.as_bytes())
            .and_then(|_| {
                temporary
                    .as_file()
                    .set_permissions(original.metadata()?.permissions())
            })
            .and_then(|_| temporary.as_file().sync_all())
            .map_err(|error| format!("Cannot write {}: {error}", self.path.display()))?;
        temporary
            .persist(&self.path)
            .map_err(|error| format!("Cannot save {}: {}", self.path.display(), error.error))?;
        *saved = source.to_owned();
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;
    use std::sync::atomic::{AtomicUsize, Ordering};

    fn path() -> PathBuf {
        static NEXT: AtomicUsize = AtomicUsize::new(0);
        std::env::temp_dir().join(format!(
            "simplicity-diagram-{}-{}.mmd",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ))
    }

    fn open(path: &std::path::Path, answer: &str) -> Result<DiagramFile, String> {
        DiagramFile::open(
            [path.as_os_str().to_owned()].into_iter(),
            &mut Cursor::new(answer),
            &mut Vec::new(),
        )
    }

    #[test]
    fn missing_file_requires_confirmation_and_creates_guidance() {
        let path = path();
        assert!(open(&path, "n\n").is_err());
        assert!(!path.exists());
        let file = open(&path, "y\n").unwrap();
        assert_eq!(fs::read_to_string(&path).unwrap(), GUIDANCE);
        file.save("flowchart TD\n  A --> B\n").unwrap();
        assert_eq!(
            fs::read_to_string(&path).unwrap(),
            "flowchart TD\n  A --> B\n"
        );
        fs::remove_file(path).unwrap();
    }

    #[test]
    fn empty_file_gets_guidance_without_changing_it_until_save() {
        let path = path();
        fs::write(&path, "").unwrap();
        let file = open(&path, "").unwrap();
        assert_eq!(file.source, GUIDANCE);
        assert_eq!(fs::read_to_string(&path).unwrap(), "");
        fs::remove_file(path).unwrap();
        assert!(file.save("flowchart TD\n  A --> B").is_err());
    }

    #[test]
    fn requires_exactly_one_path_and_reports_unreadable_files() {
        assert!(DiagramFile::open([].into_iter(), &mut Cursor::new(""), &mut Vec::new()).is_err());
        assert!(DiagramFile::open(
            [OsString::from("a"), OsString::from("b")].into_iter(),
            &mut Cursor::new(""),
            &mut Vec::new(),
        )
        .is_err());
        assert!(open(std::env::temp_dir().as_path(), "").is_err());
    }

    #[test]
    fn refuses_to_overwrite_an_external_change() {
        let path = path();
        fs::write(&path, "original").unwrap();
        let file = open(&path, "").unwrap();
        fs::write(&path, "external change").unwrap();
        assert!(file.save("edited").is_err());
        assert_eq!(fs::read_to_string(&path).unwrap(), "external change");
        fs::remove_file(path).unwrap();
    }
}
