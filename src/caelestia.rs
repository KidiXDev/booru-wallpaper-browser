// Everything that touches caelestia shell. Paths mirror the shell's utils/Paths.qml
use std::{env, fs, path::PathBuf, process::Command};

fn home() -> String {
    env::var("HOME").unwrap_or_default()
}

fn xdg(var: &str, fallback: &str) -> PathBuf {
    env::var(var)
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from(home()).join(fallback))
}

// CAELESTIA_WALLPAPERS_DIR, then paths.wallpaperDir in shell.json, then the shell default
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
        .unwrap_or_else(|| PathBuf::from(home()).join("Pictures/Wallpapers"))
}

// Raw scheme.json, the UI reads `colours` from it
pub fn scheme() -> String {
    fs::read_to_string(xdg("XDG_STATE_HOME", ".local/state").join("caelestia/scheme.json"))
        .unwrap_or_else(|_| "{}".into())
}

// Goes through the shell's `wallpaper` IpcHandler so it handles smart scheme and videos
pub fn set_wallpaper(path: &str) -> Result<(), String> {
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

// The shell bundles Google Sans Flex instead of installing it, so load it from the shell config
pub fn font_path() -> Option<PathBuf> {
    [
        xdg("XDG_CONFIG_HOME", ".config").join("quickshell/caelestia"),
        PathBuf::from("/etc/xdg/quickshell/caelestia"),
    ]
    .iter()
    .filter_map(|shell| fs::read_dir(shell.join("assets/google-sans-flex")).ok())
    .flatten()
    .flatten()
    .map(|entry| entry.path())
    .find(|p| p.extension().is_some_and(|e| e == "ttf"))
}
