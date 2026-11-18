use std::collections::BTreeSet;
use std::os::raw::c_char;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(u32)]
pub enum MenuKind {
    Action = 0,
    Toggle = 1,
    Radio = 2,
    Separator = 3,
    Submenu = 4,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct MenuItem {
    pub id: String,
    pub label: String,
    pub kind: MenuKind,
    pub enabled: bool,
    pub checked: bool,
    pub group: String,
    pub parent: Option<usize>,
}

#[derive(Debug, Eq, PartialEq)]
pub enum MenuError {
    InvalidItem,
    InvalidParent,
    DuplicateId,
    InvalidRadioGroup,
}

#[derive(Debug, Default)]
pub struct Menu {
    items: Vec<MenuItem>,
}

impl Menu {
    pub fn new(items: Vec<MenuItem>) -> Result<Self, MenuError> {
        let mut ids = BTreeSet::new();
        let mut selected_groups = BTreeSet::new();

        for (index, item) in items.iter().enumerate() {
            if item.kind != MenuKind::Separator {
                if item.id.is_empty() {
                    return Err(MenuError::InvalidItem);
                }
                if !ids.insert(item.id.as_str()) {
                    return Err(MenuError::DuplicateId);
                }
            }

            if let Some(parent) = item.parent {
                if parent >= index || items[parent].kind != MenuKind::Submenu {
                    return Err(MenuError::InvalidParent);
                }
            }

            if item.kind == MenuKind::Radio {
                if item.group.is_empty() {
                    return Err(MenuError::InvalidRadioGroup);
                }
                if item.checked && !selected_groups.insert((item.parent, item.group.as_str())) {
                    return Err(MenuError::InvalidRadioGroup);
                }
            }
        }

        Ok(Self { items })
    }

    pub fn items(&self) -> &[MenuItem] {
        &self.items
    }

    pub fn find(&self, id: &str) -> Option<&MenuItem> {
        self.items
            .iter()
            .find(|item| item.kind != MenuKind::Separator && item.id == id)
    }

    pub fn set_enabled(&mut self, id: &str, enabled: bool) -> bool {
        self.find_mut(id, true).is_some_and(|item| {
            item.enabled = enabled;
            true
        })
    }

    pub fn set_label(&mut self, id: &str, label: String) -> bool {
        self.find_mut(id, true).is_some_and(|item| {
            item.label = label;
            true
        })
    }

    pub fn activate(&mut self, id: &str) -> bool {
        let Some(index) = self
            .items
            .iter()
            .position(|item| item.kind != MenuKind::Separator && item.id == id)
        else {
            return false;
        };

        if !self.is_enabled(index)
            || matches!(
                self.items[index].kind,
                MenuKind::Submenu | MenuKind::Separator
            )
        {
            return false;
        }

        match self.items[index].kind {
            MenuKind::Toggle => self.items[index].checked = !self.items[index].checked,
            MenuKind::Radio => {
                let parent = self.items[index].parent;
                let group = self.items[index].group.clone();
                for sibling in &mut self.items {
                    if sibling.parent == parent
                        && sibling.kind == MenuKind::Radio
                        && sibling.group == group
                    {
                        sibling.checked = false;
                    }
                }
                self.items[index].checked = true;
            }
            MenuKind::Action | MenuKind::Separator | MenuKind::Submenu => {}
        }
        true
    }

    fn find_mut(&mut self, id: &str, include_separators: bool) -> Option<&mut MenuItem> {
        self.items
            .iter_mut()
            .find(|item| (include_separators || item.kind != MenuKind::Separator) && item.id == id)
    }

    fn is_enabled(&self, mut index: usize) -> bool {
        loop {
            let item = &self.items[index];
            if !item.enabled {
                return false;
            }
            match item.parent {
                Some(parent) => index = parent,
                None => return true,
            }
        }
    }
}

#[repr(C)]
pub struct RawMenuItem {
    id: *const c_char,
    id_len: usize,
    label: *const c_char,
    label_len: usize,
    kind: u32,
    enabled: u8,
    checked: u8,
    group: *const c_char,
    group_len: usize,
    parent_index: i32,
}

fn read_string(value: *const c_char, len: usize) -> Option<String> {
    if value.is_null() && len != 0 {
        return None;
    }
    let bytes = if len == 0 {
        &[]
    } else {
        unsafe { std::slice::from_raw_parts(value.cast::<u8>(), len) }
    };
    std::str::from_utf8(bytes).ok().map(str::to_owned)
}

fn set_error(error: *mut i32, value: i32) {
    if !error.is_null() {
        unsafe { *error = value };
    }
}

#[no_mangle]
pub unsafe extern "C" fn simplicity_menu_create(
    raw_items: *const RawMenuItem,
    len: usize,
    error: *mut i32,
) -> *mut Menu {
    set_error(error, 0);
    if raw_items.is_null() && len != 0 {
        set_error(error, 1);
        return std::ptr::null_mut();
    }

    let raw_items = if len == 0 {
        &[]
    } else {
        std::slice::from_raw_parts(raw_items, len)
    };
    let mut items = Vec::with_capacity(len);
    for raw in raw_items {
        let Some(id) = read_string(raw.id, raw.id_len) else {
            set_error(error, 1);
            return std::ptr::null_mut();
        };
        let Some(label) = read_string(raw.label, raw.label_len) else {
            set_error(error, 1);
            return std::ptr::null_mut();
        };
        let Some(group) = read_string(raw.group, raw.group_len) else {
            set_error(error, 1);
            return std::ptr::null_mut();
        };
        let Some(kind) = (match raw.kind {
            0 => Some(MenuKind::Action),
            1 => Some(MenuKind::Toggle),
            2 => Some(MenuKind::Radio),
            3 => Some(MenuKind::Separator),
            4 => Some(MenuKind::Submenu),
            _ => None,
        }) else {
            set_error(error, 1);
            return std::ptr::null_mut();
        };
        let parent = match raw.parent_index {
            -1 => None,
            parent if parent >= 0 => Some(parent as usize),
            _ => {
                set_error(error, 1);
                return std::ptr::null_mut();
            }
        };
        items.push(MenuItem {
            id,
            label,
            kind,
            enabled: raw.enabled != 0,
            checked: raw.checked != 0,
            group,
            parent,
        });
    }

    match Menu::new(items) {
        Ok(menu) => Box::into_raw(Box::new(menu)),
        Err(error_kind) => {
            set_error(
                error,
                match error_kind {
                    MenuError::InvalidItem
                    | MenuError::InvalidParent
                    | MenuError::DuplicateId
                    | MenuError::InvalidRadioGroup => 2,
                },
            );
            std::ptr::null_mut()
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn simplicity_menu_destroy(menu: *mut Menu) {
    if !menu.is_null() {
        drop(Box::from_raw(menu));
    }
}

#[no_mangle]
pub unsafe extern "C" fn simplicity_menu_activate(
    menu: *mut Menu,
    id: *const c_char,
    id_len: usize,
) -> bool {
    let (Some(menu), Some(id)) = (menu.as_mut(), read_string(id, id_len)) else {
        return false;
    };
    menu.activate(&id)
}

#[no_mangle]
pub unsafe extern "C" fn simplicity_menu_set_enabled(
    menu: *mut Menu,
    id: *const c_char,
    id_len: usize,
    enabled: bool,
) -> bool {
    let (Some(menu), Some(id)) = (menu.as_mut(), read_string(id, id_len)) else {
        return false;
    };
    menu.set_enabled(&id, enabled)
}

#[no_mangle]
pub unsafe extern "C" fn simplicity_menu_set_label(
    menu: *mut Menu,
    id: *const c_char,
    id_len: usize,
    label: *const c_char,
    label_len: usize,
) -> bool {
    let (Some(menu), Some(id), Some(label)) = (
        menu.as_mut(),
        read_string(id, id_len),
        read_string(label, label_len),
    ) else {
        return false;
    };
    menu.set_label(&id, label)
}

#[no_mangle]
pub unsafe extern "C" fn simplicity_menu_get_state(
    menu: *const Menu,
    id: *const c_char,
    id_len: usize,
    enabled: *mut bool,
    checked: *mut bool,
) -> bool {
    let (Some(menu), Some(id)) = (menu.as_ref(), read_string(id, id_len)) else {
        return false;
    };
    let Some(item) = menu.find(&id) else {
        return false;
    };
    if enabled.is_null() || checked.is_null() {
        return false;
    }
    *enabled = item.enabled;
    *checked = item.checked;
    true
}

#[cfg(test)]
mod tests {
    use super::{Menu, MenuError, MenuItem, MenuKind};

    fn item(
        id: &str,
        kind: MenuKind,
        parent: Option<usize>,
        group: &str,
        checked: bool,
    ) -> MenuItem {
        MenuItem {
            id: id.into(),
            label: id.into(),
            kind,
            enabled: true,
            checked,
            group: group.into(),
            parent,
        }
    }

    fn fixture() -> Menu {
        Menu::new(vec![
            item("run", MenuKind::Action, None, "", false),
            item("flag", MenuKind::Toggle, None, "", false),
            item("blocked", MenuKind::Action, None, "", false),
            item("group", MenuKind::Submenu, None, "", false),
            item("a", MenuKind::Radio, Some(3), "choice", true),
            item("b", MenuKind::Radio, Some(3), "choice", false),
            item("", MenuKind::Separator, None, "", false),
            item("root_choice", MenuKind::Radio, None, "choice", true),
        ])
        .unwrap()
    }

    #[test]
    fn actions_toggles_and_radio_groups_activate() {
        let mut menu = fixture();
        assert!(menu.activate("run"));
        assert!(menu.activate("flag"));
        assert!(menu.find("flag").unwrap().checked);
        assert!(menu.activate("flag"));
        assert!(!menu.find("flag").unwrap().checked);
        assert!(menu.activate("b"));
        assert!(menu.find("b").unwrap().checked);
        assert!(!menu.find("a").unwrap().checked);
        assert!(menu.find("root_choice").unwrap().checked);
    }

    #[test]
    fn disabled_ancestors_and_non_action_items_cannot_activate() {
        let mut menu = fixture();
        assert!(!menu.activate("missing"));
        assert!(!menu.activate("group"));
        assert!(!menu.activate(""));
        menu.set_enabled("group", false);
        assert!(!menu.activate("a"));
        menu.set_enabled("group", true);
        assert!(menu.activate("a"));
        menu.set_enabled("blocked", false);
        assert!(!menu.activate("blocked"));
    }

    #[test]
    fn mutations_report_missing_ids_and_update_state() {
        let mut menu = fixture();
        assert!(menu.set_label("run", "Execute".into()));
        assert_eq!(menu.find("run").unwrap().label, "Execute");
        assert!(menu.set_enabled("run", false));
        assert!(!menu.find("run").unwrap().enabled);
        assert!(!menu.set_label("missing", "Nope".into()));
        assert!(!menu.set_enabled("missing", false));
    }

    #[test]
    fn validates_ids_parents_and_radio_groups() {
        let duplicate = vec![
            item("same", MenuKind::Action, None, "", false),
            item("same", MenuKind::Action, None, "", false),
        ];
        assert_eq!(Menu::new(duplicate).unwrap_err(), MenuError::DuplicateId);

        let invalid_parent = vec![
            item("parent", MenuKind::Action, None, "", false),
            item("child", MenuKind::Action, Some(0), "", false),
        ];
        assert_eq!(
            Menu::new(invalid_parent).unwrap_err(),
            MenuError::InvalidParent
        );

        let invalid_group = vec![
            item("a", MenuKind::Radio, None, "choice", true),
            item("b", MenuKind::Radio, None, "choice", true),
        ];
        assert_eq!(
            Menu::new(invalid_group).unwrap_err(),
            MenuError::InvalidRadioGroup
        );

        let empty_group = vec![item("a", MenuKind::Radio, None, "", false)];
        assert_eq!(
            Menu::new(empty_group).unwrap_err(),
            MenuError::InvalidRadioGroup
        );

        let empty_id = vec![item("", MenuKind::Action, None, "", false)];
        assert_eq!(Menu::new(empty_id).unwrap_err(), MenuError::InvalidItem);
    }
}
