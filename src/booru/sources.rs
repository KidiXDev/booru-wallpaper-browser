// One static per site. Adding a site on an existing engine is one entry here plus one in SOURCES.
// The id is the download folder name (shown as a category in caelestia) and the JSON `source`,
// so don't rename existing ones. Only SFW sites for now; more in hoshi's sources/
use super::{Source, danbooru::Danbooru, gelbooru::Gelbooru, moebooru::Moebooru};

pub static KONACHAN_NET: Moebooru = Moebooru {
    id: "konachan.net",
    name: "Konachan",
    base: "https://konachan.net",
    safe_only: true,
};

pub static DANBOORU_SAFE: Danbooru = Danbooru {
    id: "danbooru-safe",
    name: "Danbooru (Safe)",
    base: "https://safebooru.donmai.us",
};

pub static SAFEBOORU: Gelbooru = Gelbooru {
    id: "safebooru",
    name: "Safebooru",
    base: "https://safebooru.org",
};

// Order is the order of the source picker, first is the default
pub static SOURCES: &[&dyn Source] = &[&KONACHAN_NET, &DANBOORU_SAFE, &SAFEBOORU];
