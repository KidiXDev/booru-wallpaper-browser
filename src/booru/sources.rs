// The id is the download folder name and the JSON `source`, so don't rename existing ones
use super::{
    Account, Source,
    danbooru::{self, Danbooru},
    gelbooru::{self, Gelbooru},
    moebooru::{self, Moebooru},
};

pub static KONACHAN_NET: Moebooru = Moebooru {
    id: "konachan.net",
    name: "Konachan",
    base: "https://konachan.net",
    safe_only: true,
    account: None,
};

pub static DANBOORU_SAFE: Danbooru = Danbooru {
    id: "danbooru-safe",
    name: "Danbooru (Safe)",
    base: "https://safebooru.donmai.us",
    account: None,
};

pub static SAFEBOORU: Gelbooru = Gelbooru {
    id: "safebooru",
    name: "Safebooru",
    base: "https://safebooru.org",
    account: None,
};

pub static DANBOORU: Danbooru = Danbooru {
    id: "danbooru",
    name: "Danbooru",
    base: "https://danbooru.donmai.us",
    account: Some(Account {
        fields: danbooru::FIELDS,
        required: false,
        url: "https://danbooru.donmai.us/profile",
        note: "Optional. The API key is on your profile page",
    }),
};

pub static GELBOORU: Gelbooru = Gelbooru {
    id: "gelbooru",
    name: "Gelbooru",
    base: "https://gelbooru.com",
    account: Some(Account {
        fields: gelbooru::FIELDS,
        required: true,
        url: "https://gelbooru.com/index.php?page=account&s=options",
        note: "Required to search. Copy them from Options → API Access Credentials",
    }),
};

pub static YANDERE: Moebooru = Moebooru {
    id: "yande.re",
    name: "yande.re",
    base: "https://yande.re",
    safe_only: false,
    account: None,
};

pub static KONACHAN_COM: Moebooru = Moebooru {
    id: "konachan.com",
    name: "Konachan.com",
    base: "https://konachan.com",
    safe_only: false,
    account: Some(Account {
        fields: moebooru::COOKIE_FIELDS,
        required: true,
        url: "https://konachan.com",
        note: "Required, the API is behind Cloudflare. Open the site in a browser, then copy its cf_clearance cookie and the browser's User-Agent",
    }),
};

pub static SOURCES: &[&dyn Source] = &[
    &KONACHAN_NET,
    &DANBOORU_SAFE,
    &SAFEBOORU,
    &DANBOORU,
    &GELBOORU,
    &YANDERE,
    &KONACHAN_COM,
];
