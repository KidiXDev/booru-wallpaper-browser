// The settings page's state, also read by the CLI: $XDG_CONFIG_HOME/wallpaper-browser/settings.json.
// It holds API keys and cookies, so the file is created 0600
use crate::{booru::Credentials, caelestia::xdg};
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, fs, io::Write, os::unix::fs::OpenOptionsExt, path::PathBuf};

#[derive(Default, Serialize, Deserialize)]
#[serde(default)]
pub struct Settings {
    // Show questionable and explicit posts too
    pub spicy: bool,
    // Source id -> its credentials
    pub credentials: HashMap<String, Credentials>,
}

impl Settings {
    pub fn auth(&self, source: &str) -> Credentials {
        self.credentials.get(source).cloned().unwrap_or_default()
    }
}

fn path() -> PathBuf {
    xdg("XDG_CONFIG_HOME", ".config").join("wallpaper-browser/settings.json")
}

pub fn load() -> Settings {
    let Ok(text) = fs::read_to_string(path()) else {
        return Settings::default();
    };
    serde_json::from_str(&text).unwrap_or_else(|e| {
        eprintln!("{}: {e}", path().display());
        Settings::default()
    })
}

// json is a Settings object from the settings page
pub fn save(json: &str) -> Result<(), String> {
    let mut settings: Settings = serde_json::from_str(json).map_err(|e| e.to_string())?;
    settings.credentials.values_mut().for_each(split_pasted);
    let path = path();
    if let Some(dir) = path.parent() {
        fs::create_dir_all(dir).map_err(|e| format!("{}: {e}", dir.display()))?;
    }
    let json = serde_json::to_string_pretty(&settings).map_err(|e| e.to_string())?;
    fs::OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .mode(0o600)
        .open(&path)
        .and_then(|mut f| f.write_all(json.as_bytes()))
        .map_err(|e| format!("{}: {e}", path.display()))
}

// gelbooru shows its credentials as "&api_key=…&user_id=…": a paste of that into any field fills
// the fields it names
fn split_pasted(auth: &mut Credentials) {
    let pairs: Vec<(String, String)> = auth
        .values()
        .flat_map(|v| v.split('&').filter_map(|p| p.split_once('=')))
        .filter(|(k, _)| auth.contains_key(k.trim()))
        .map(|(k, v)| (k.trim().into(), v.trim().into()))
        .collect();
    auth.extend(pairs);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn splits_pasted_credentials() {
        let mut auth = Credentials::from([
            ("user_id".into(), "".into()),
            ("api_key".into(), "&api_key=abc&user_id=42".into()),
        ]);
        split_pasted(&mut auth);
        assert_eq!((auth["user_id"].as_str(), auth["api_key"].as_str()), ("42", "abc"));
        // Cookies have "=" too, but their names aren't field keys
        let mut auth = Credentials::from([("cookie".into(), "cf_clearance=x; a=b".into())]);
        split_pasted(&mut auth);
        assert_eq!(auth["cookie"], "cf_clearance=x; a=b");
    }
}
