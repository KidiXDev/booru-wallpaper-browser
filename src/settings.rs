use crate::{booru::Credentials, platform::xdg};
use flate2::{Compression, read::ZlibDecoder, write::ZlibEncoder};
use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    fs,
    io::{Read, Write},
    path::PathBuf,
    sync::atomic::{AtomicU64, Ordering},
};

const MAGIC: &[u8] = b"WOOF1";

#[derive(Serialize, Deserialize)]
#[serde(default)]
pub struct Settings {
    pub spicy: bool,
    pub credentials: HashMap<String, Credentials>,
    pub cache_mb: u32,
}

impl Default for Settings {
    fn default() -> Self {
        Self { spicy: false, credentials: HashMap::new(), cache_mb: 1024 }
    }
}

impl Settings {
    pub fn auth(&self, source: &str) -> Credentials {
        self.credentials.get(source).cloned().unwrap_or_default()
    }

    pub fn cache_bytes(&self) -> i64 {
        i64::from(self.cache_mb) << 20
    }
}

fn dir() -> PathBuf {
    xdg("XDG_CONFIG_HOME", ".config").join("wallpaper-browser")
}

pub fn log_dir() -> PathBuf {
    dir().join("logs")
}

fn file(name: &str, ext: &str) -> PathBuf {
    dir().join(format!("{name}.{ext}"))
}

fn encode(text: &str) -> Vec<u8> {
    let mut z = ZlibEncoder::new(MAGIC.to_vec(), Compression::default());
    z.write_all(text.as_bytes()).and_then(|_| z.finish()).unwrap_or_default()
}

fn decode(bytes: &[u8]) -> Option<String> {
    let mut text = String::new();
    ZlibDecoder::new(bytes.strip_prefix(MAGIC)?).read_to_string(&mut text).ok()?;
    Some(text)
}

pub fn load_state(name: &str) -> String {
    let path = file(name, "woof");
    let Ok(bytes) = fs::read(&path) else {
        let old = file(name, "json");
        let Ok(text) = fs::read_to_string(&old) else {
            return String::new();
        };
        match save_state(name, &text) {
            Ok(()) => drop(fs::remove_file(old)),
            Err(e) => eprintln!("{e}"),
        }
        return text;
    };
    decode(&bytes).unwrap_or_else(|| {
        eprintln!("{}: unreadable", path.display());
        String::new()
    })
}

pub fn save_state(name: &str, text: &str) -> Result<(), String> {
    static WRITES: AtomicU64 = AtomicU64::new(0);
    let path = file(name, "woof");
    let tmp = file(name, &format!("woof.{}-{}.tmp", std::process::id(), WRITES.fetch_add(1, Ordering::Relaxed)));
    fs::create_dir_all(dir()).map_err(|e| format!("{}: {e}", dir().display()))?;
    let mut options = fs::OpenOptions::new();
    options.write(true).create(true).truncate(true);
    #[cfg(unix)]
    std::os::unix::fs::OpenOptionsExt::mode(&mut options, 0o600);
    options
        .open(&tmp)
        .and_then(|mut f| f.write_all(&encode(text)))
        .and_then(|_| fs::rename(&tmp, &path))
        .map_err(|e| {
            let _ = fs::remove_file(&tmp);
            format!("{}: {e}", path.display())
        })
}

pub fn load() -> Settings {
    let text = load_state("settings");
    if text.is_empty() {
        return Settings::default();
    }
    serde_json::from_str(&text).unwrap_or_else(|e| {
        eprintln!("{}: {e}", file("settings", "woof").display());
        Settings::default()
    })
}

pub fn save(json: &str) -> Result<Settings, String> {
    let mut settings: Settings = serde_json::from_str(json).map_err(|e| e.to_string())?;
    settings.credentials.values_mut().for_each(split_pasted);
    save_state("settings", &serde_json::to_string(&settings).map_err(|e| e.to_string())?)?;
    Ok(settings)
}

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
        let mut auth = Credentials::from([("cookie".into(), "cf_clearance=x; a=b".into())]);
        split_pasted(&mut auth);
        assert_eq!(auth["cookie"], "cf_clearance=x; a=b");
    }

    #[test]
    fn encodes() {
        let json = r#"{"spicy":true,"credentials":{}}"#;
        let bytes = encode(json);
        assert!(bytes.starts_with(MAGIC) && !bytes.windows(5).any(|w| w == b"spicy"));
        assert_eq!(decode(&bytes).as_deref(), Some(json));
        assert_eq!(decode(json.as_bytes()), None);
        assert_eq!(decode(&bytes[..bytes.len() - 1]), None);
    }

    #[test]
    fn defaults_missing_fields() {
        let s: Settings = serde_json::from_str(r#"{"spicy":true}"#).unwrap();
        assert!(s.spicy && s.cache_mb == 1024 && s.cache_bytes() == 1 << 30);
    }
}
