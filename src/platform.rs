use std::{env, fs, path::PathBuf, process::Command};

fn home() -> String {
    env::var(if cfg!(windows) { "USERPROFILE" } else { "HOME" }).unwrap_or_default()
}

// Linux: $XDG_<var> or ~/<fallback>; Windows: %APPDATA% (var and fallback are Linux-only)
pub(crate) fn xdg(var: &str, fallback: &str) -> PathBuf {
    if cfg!(windows) {
        return env::var("APPDATA").map(PathBuf::from).unwrap_or_else(|_| PathBuf::from(home()));
    }
    env::var(var).map(PathBuf::from).unwrap_or_else(|_| PathBuf::from(home()).join(fallback))
}

fn caelestia() -> bool {
    cfg!(unix)
        && (xdg("XDG_CONFIG_HOME", ".config").join("caelestia/shell.json").exists()
            || scheme_path().exists())
}

fn scheme_path() -> PathBuf {
    xdg("XDG_STATE_HOME", ".local/state").join("caelestia/scheme.json")
}

pub fn walls_dir() -> PathBuf {
    if let Ok(dir) = env::var("CAELESTIA_WALLPAPERS_DIR") {
        return dir.into();
    }
    fs::read_to_string(xdg("XDG_CONFIG_HOME", ".config").join("caelestia/shell.json"))
        .ok()
        .and_then(|s| serde_json::from_str::<serde_json::Value>(&s).ok())
        .and_then(|v| v.pointer("/paths/wallpaperDir")?.as_str().map(str::to_owned))
        .filter(|d| !d.is_empty())
        .map(|d| d.replacen('~', &home(), 1).replace("$HOME", &home()).into())
        .unwrap_or_else(|| PathBuf::from(home()).join("Pictures").join("Wallpapers"))
}

pub fn scheme() -> String {
    fs::read_to_string(scheme_path()).unwrap_or_else(|_| "{}".into())
}

pub fn set_wallpaper(path: &str) -> Result<(), String> {
    if !caelestia() {
        return wallpaper::set_from_path(path).map_err(|e| e.to_string());
    }
    let out = Command::new("qs")
        .args(["-c", "caelestia", "ipc", "call", "wallpaper", "set", path])
        .output()
        .map_err(|e| format!("qs: {e}"))?;
    if out.status.success() {
        Ok(())
    } else {
        Err(format!("qs ipc: {}", String::from_utf8_lossy(&out.stderr).trim()))
    }
}

#[cfg(windows)]
pub fn reveal(path: &str) -> Result<(), String> {
    use std::os::windows::process::CommandExt;
    Command::new("explorer")
        .raw_arg(format!("/select,\"{path}\""))
        .spawn()
        .map(drop)
        .map_err(|e| format!("explorer: {e}"))
}

#[cfg(not(windows))]
pub fn reveal(_path: &str) -> Result<(), String> {
    Err("only on Windows".into())
}

#[cfg(windows)]
pub fn attach_console(alloc: bool) {
    use std::ffi::c_void;
    const ATTACH_PARENT_PROCESS: u32 = u32::MAX;
    const STD_OUTPUT_HANDLE: u32 = -11i32 as u32;
    const FILE_TYPE_DISK: u32 = 1;
    const FILE_TYPE_PIPE: u32 = 3;
    #[link(name = "kernel32")]
    unsafe extern "system" {
        fn AttachConsole(pid: u32) -> i32;
        fn AllocConsole() -> i32;
        fn GetStdHandle(id: u32) -> *mut c_void;
        fn GetFileType(handle: *mut c_void) -> u32;
    }
    unsafe {
        if matches!(GetFileType(GetStdHandle(STD_OUTPUT_HANDLE)), FILE_TYPE_DISK | FILE_TYPE_PIPE) {
            return;
        }
        if AttachConsole(ATTACH_PARENT_PROCESS) == 0 && alloc {
            AllocConsole();
        }
    }
}

#[cfg(not(windows))]
pub fn attach_console(_alloc: bool) {}
