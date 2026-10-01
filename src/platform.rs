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

// Empty without caelestia, so the UI falls back to its default scheme
pub fn scheme() -> String {
    fs::read_to_string(scheme_path()).unwrap_or_else(|_| "{}".into())
}

// With the shell it goes through its `wallpaper` IpcHandler so it handles smart scheme and videos
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
