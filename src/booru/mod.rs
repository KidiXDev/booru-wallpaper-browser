// Booru backends. Engines (one per API family) live in their own modules; a site
// is a static of an engine in `sources.rs`. Same split as hoshi's src-tauri/src/booru/
mod danbooru;
mod gelbooru;
mod moebooru;
mod sources;

use serde::Serialize;
use serde_json::Value;
use std::{
    collections::HashMap,
    fs, io,
    path::{Path, PathBuf},
    sync::LazyLock,
};

pub use sources::SOURCES;

pub const UA: &str = concat!("wallpaper-browser/", env!("CARGO_PKG_VERSION"));

// Wallpapers only: no gifs, videos or archives
const IMAGE_EXTENSIONS: &[&str] = &["jpg", "jpeg", "png", "webp"];

// What's shown without spicy mode: danbooru/gelbooru general + sensitive, moebooru safe ("s" is
// sensitive on danbooru and safe on moebooru, both are allowed)
const MILD_RATINGS: &[&str] = &["g", "s", "general", "sensitive", "safe"];

// Field key -> value for one site, as saved by the settings page
pub type Credentials = HashMap<String, String>;

// A credential the settings page asks for
#[derive(Serialize)]
pub struct Field {
    pub key: &'static str,
    pub label: &'static str,
    pub secret: bool,
}

#[derive(Serialize)]
pub struct Account {
    pub fields: &'static [Field],
    // The site refuses (or returns nothing) without them
    pub required: bool,
    // Where the user finds them, and how
    pub url: &'static str,
    pub note: &'static str,
}

pub trait Source: Sync {
    fn id(&self) -> &'static str;
    fn name(&self) -> &'static str;
    // Origin of the site, also sent as Referer for downloads
    fn base(&self) -> &'static str;
    fn account(&self) -> Option<&Account> {
        None
    }
    fn search(&self, query: &Query) -> Result<Page, String>;
    fn post(&self, id: u64, auth: &Credentials) -> Result<Post, String>;
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Sort {
    Latest,
    Score,
    Random,
}

impl Sort {
    pub fn parse(sort: &str) -> Result<Self, String> {
        match sort {
            "" | "latest" => Ok(Self::Latest),
            "score" => Ok(Self::Score),
            "random" => Ok(Self::Random),
            _ => Err(format!("unknown sort: {sort} (latest, score, random)")),
        }
    }
}

pub struct Query<'a> {
    pub tags: &'a str,
    pub sort: Sort,
    pub page: u32, // 1-based
    pub limit: u32,
    // Show every rating, not just general and sensitive
    pub spicy: bool,
    pub auth: &'a Credentials,
}

impl Query<'_> {
    // Engines also filter server-side; this catches what the site's rating tag lets through
    pub fn allows(&self, rating: &str) -> bool {
        self.spicy || MILD_RATINGS.contains(&rating)
    }
}

// The JSON contract shared by the CLI and the GUI, keep it stable
#[derive(Serialize)]
pub struct Post {
    pub source: &'static str,
    pub id: u64,
    pub width: u64,
    pub height: u64,
    pub score: i64,
    pub rating: String,
    pub tags: String,
    pub ext: String,
    pub size: u64, // 0 when the site doesn't report it
    pub preview: String,
    pub sample: String,
    pub file: String,
    pub url: String,
}

#[derive(Serialize)]
pub struct Page {
    pub posts: Vec<Post>,
    pub more: bool,
}

#[derive(Serialize)]
pub struct SourceInfo {
    pub id: &'static str,
    pub name: &'static str,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub account: Option<&'static Account>,
}

pub fn source(id: &str) -> Result<&'static dyn Source, String> {
    SOURCES
        .iter()
        .copied()
        .find(|s| s.id() == id)
        .ok_or_else(|| format!("unsupported source: {id}"))
}

pub fn sources() -> Vec<SourceInfo> {
    SOURCES.iter().map(|s| SourceInfo { id: s.id(), name: s.name(), account: s.account() }).collect()
}

static AGENT: LazyLock<ureq::Agent> = LazyLock::new(|| {
    ureq::Agent::new_with_config(
        ureq::Agent::config_builder()
            .user_agent(UA)
            // Error bodies carry the useful message (e.g. danbooru's tag limit)
            .http_status_as_error(false)
            .build(),
    )
});

pub(crate) fn get(url: &str) -> ureq::RequestBuilder<ureq::typestate::WithoutBody> {
    AGENT.get(url)
}

// Sends and parses JSON. An empty body is an empty list (gelbooru 0.2 with no results)
pub(crate) fn send_json(
    source: &str,
    request: ureq::RequestBuilder<ureq::typestate::WithoutBody>,
) -> Result<Value, String> {
    let mut response = request.call().map_err(|e| format!("{source}: {e}"))?;
    let status = response.status();
    let body = response
        .body_mut()
        .read_to_string()
        .map_err(|e| format!("{source}: {e}"))?;
    if !status.is_success() {
        let message = serde_json::from_str::<Value>(&body)
            .ok()
            .and_then(|v| ["message", "reason", "error"].iter().find_map(|k| v.get(k)?.as_str().map(str::to_owned)));
        return Err(format!("{source}: {}", message.unwrap_or_else(|| format!("HTTP {status}"))));
    }
    if body.trim().is_empty() {
        return Ok(Value::Array(Vec::new()));
    }
    serde_json::from_str(&body).map_err(|e| format!("{source}: invalid response: {e}"))
}

pub(crate) fn str_of(v: &Value, key: &str) -> String {
    v.get(key).and_then(Value::as_str).unwrap_or_default().into()
}

pub(crate) fn u64_of(v: &Value, key: &str) -> u64 {
    v.get(key).and_then(Value::as_u64).unwrap_or_default()
}

pub(crate) fn i64_of(v: &Value, key: &str) -> i64 {
    v.get(key).and_then(Value::as_i64).unwrap_or_default()
}

pub(crate) fn is_image(ext: &str) -> bool {
    IMAGE_EXTENSIONS.contains(&ext.to_lowercase().as_str())
}

pub(crate) fn ext_of(url: &str) -> String {
    let path = url.split(['?', '#']).next().unwrap_or_default();
    path.rsplit_once('.').map(|(_, e)| e.to_lowercase()).unwrap_or_default()
}

// Joins the user's tags with the engine's sort and rating tags
pub(crate) fn join_tags(parts: &[&str]) -> String {
    parts.iter().map(|p| p.trim()).filter(|p| !p.is_empty()).collect::<Vec<_>>().join(" ")
}

// A non-empty credential
pub(crate) fn cred<'a>(auth: &'a Credentials, key: &str) -> Option<&'a str> {
    auth.get(key).map(|v| v.trim()).filter(|v| !v.is_empty())
}

// gelbooru.com answers an empty list instead of an error without credentials, so check first
pub(crate) fn require(name: &str, account: Option<&Account>, auth: &Credentials) -> Result<(), String> {
    let Some(account) = account.filter(|a| a.required) else {
        return Ok(());
    };
    let missing: Vec<_> = account.fields.iter().filter(|f| cred(auth, f.key).is_none()).map(|f| f.label).collect();
    if missing.is_empty() {
        Ok(())
    } else {
        Err(format!("{name} needs your {} (open Settings)", missing.join(" and ")))
    }
}

// Downloads into <dir>/<source>/, which caelestia's picker shows as a category.
// Skips the request if the file is already there.
pub fn download(source: &dyn Source, id: u64, dir: &Path, auth: &Credentials) -> Result<PathBuf, String> {
    let post = source.post(id, auth)?;
    let dir = dir.join(source.id());
    let prefix = source.id().split('.').next().unwrap_or_default();
    let dest = dir.join(format!("{prefix}-{id}.{}", post.ext));
    if dest.exists() {
        return Ok(dest);
    }
    fs::create_dir_all(&dir).map_err(|e| format!("{}: {e}", dir.display()))?;
    // .part keeps half-written files out of caelestia's image-only FileSystemModel
    let part = dest.with_extension("part");
    let result = get(&post.file)
        .header("Referer", format!("{}/", source.base()))
        .call()
        .map_err(|e| e.to_string())
        .and_then(|mut r| {
            if !r.status().is_success() {
                return Err(format!("HTTP {}", r.status()));
            }
            let mut out = fs::File::create(&part).map_err(|e| e.to_string())?;
            io::copy(&mut r.body_mut().as_reader(), &mut out).map_err(|e| e.to_string())?;
            fs::rename(&part, &dest).map_err(|e| e.to_string())
        });
    if let Err(e) = result {
        let _ = fs::remove_file(&part);
        return Err(format!("{} download {id}: {e}", source.id()));
    }
    Ok(dest)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn helpers() {
        assert_eq!(Sort::parse("").unwrap(), Sort::Latest);
        assert!(Sort::parse("nope").is_err());
        assert_eq!(ext_of("https://x/a/b.PNG?x=1"), "png");
        assert_eq!(join_tags(&[" sky ", "order:score", ""]), "sky order:score");
        assert_eq!(join_tags(&["", ""]), "");
        let auth = Credentials::from([("api_key".into(), "k".into()), ("user_id".into(), " ".into())]);
        let q = Query { tags: "", sort: Sort::Latest, page: 1, limit: 1, spicy: false, auth: &auth };
        assert!(q.allows("s") && q.allows("general") && !q.allows("q") && !q.allows("explicit"));
        assert!(Query { spicy: true, ..q }.allows("e"));
        let gelbooru = source("gelbooru").unwrap();
        assert_eq!(require("Gelbooru", gelbooru.account(), &auth).unwrap_err(), "Gelbooru needs your User ID (open Settings)");
        assert!(require("Danbooru", source("danbooru").unwrap().account(), &Credentials::new()).is_ok());
        assert!(is_image("JPG") && !is_image("gif"));
        assert!(source("konachan.net").is_ok() && source("nope").is_err());
        // Ids are directory names and JSON keys, so they must be unique
        let ids: Vec<_> = sources().iter().map(|s| s.id).collect();
        assert!(ids.iter().enumerate().all(|(i, id)| !ids[..i].contains(id)));
    }
}
