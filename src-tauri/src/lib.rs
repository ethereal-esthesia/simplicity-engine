use std::{ffi::OsString, path::PathBuf};
use tauri::Manager;

struct VideoPath(Result<String, String>);

fn video_path(mut args: impl Iterator<Item = OsString>) -> Result<String, String> {
    let path = args.next().ok_or("Usage: simplicity-app <video-path>")?;
    if args.next().is_some() {
        return Err("Usage: simplicity-app <video-path>".into());
    }
    let path = PathBuf::from(path)
        .canonicalize()
        .map_err(|error| format!("Cannot open video: {error}"))?;
    if !path.is_file() {
        return Err("Video path must be a file".into());
    }
    path.into_os_string()
        .into_string()
        .map_err(|_| "Video path must be valid Unicode".into())
}

#[tauri::command]
fn get_video_path(path: tauri::State<'_, VideoPath>) -> Result<String, String> {
    path.0.clone()
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .setup(|app| {
            let path = video_path(std::env::args_os().skip(1)).and_then(|path| {
                app.asset_protocol_scope()
                    .allow_file(&path)
                    .map_err(|error| format!("Cannot allow video access: {error}"))?;
                Ok(path)
            });
            app.manage(VideoPath(path));
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![get_video_path])
        .run(tauri::generate_context!())
        .expect("could not run Simplicity Engine");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validates_command_line_video_path() {
        assert!(video_path(std::iter::empty())
            .unwrap_err()
            .starts_with("Usage:"));
        assert!(
            video_path([OsString::from("a"), OsString::from("b")].into_iter())
                .unwrap_err()
                .starts_with("Usage:")
        );
        assert!(video_path([OsString::from(".")].into_iter()).is_err());
        assert!(video_path([OsString::from("missing-video-file")].into_iter()).is_err());

        let file = std::env::current_exe().unwrap();
        assert_eq!(
            video_path([file.clone().into_os_string()].into_iter()).unwrap(),
            file.canonicalize().unwrap().to_str().unwrap()
        );
    }
}
