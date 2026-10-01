# wallpaper-browser

Browse and download wallpapers from boorus: Konachan, Danbooru (Safe) and Safebooru. Qt Quick UI, Rust backend via cxx-qt.

An additional plugin for [kdz-caelestia](https://github.com/KidiXDev/kdz-caelestia), my fork of the caelestia shell. It runs as a standalone app styled like the shell, and its CLI is meant to back the wallpaper section of the fork's nexus settings.

```sh
cargo build --release
./target/release/wallpaper-browser          # GUI
```

## Caelestia integration

- Downloads go to `<wallpaper dir>/<source>/`, so they show up as a category in the shell's wallpaper picker. The dir is resolved like `utils/Paths.qml`: `$CAELESTIA_WALLPAPERS_DIR`, then `paths.wallpaperDir` in `~/.config/caelestia/shell.json`, then `~/Pictures/Wallpapers`.
- "Set wallpaper" runs `qs -c caelestia ipc call wallpaper set <path>` (the `Wallpapers` service IpcHandler).
- Colours come from `~/.local/state/caelestia/scheme.json`, polled every second, so the app recolours (animated) with the shell.
- Wayland app id is `wallpaper-browser`.

## Look and feel

`qml/` ports caelestia's design system with the same names and API: `Tokens` (rounding, spacing, padding, fonts, anim durations and bezier curves), `Colours.palette.m3*`, `Anim`/`CAnim` types, `StateLayer` (ripple), `ButtonBase`/`IconButton`/`IconTextButton` (radius morph), `SearchBar`, `LoadingIndicator`, `StyledScrollBar`, `Elevation`. Code written against them moves into the shell by swapping `import WallpaperBrowser` for the shell's imports.

Needs `qt6-m3shapes` (the shell's loading indicator) and Material Symbols Rounded, both already required by caelestia. Google Sans Flex is loaded from the shell's `assets/`.

## CLI (for nexus)

The binary has a headless mode that prints the same JSON the GUI gets, so nexus can use a `Process` instead of linking Rust:

```sh
wallpaper-browser search [-s SOURCE] [--sort latest|score|random] [-p PAGE] [-l LIMIT] [TAGS...]
wallpaper-browser download [-s SOURCE] [--set] ID   # prints the saved path
wallpaper-browser sources                           # [{"id": "konachan.net", "name": "Konachan"}, {"id": "gelbooru", ..., "account": {...}}, ...]
```

`SOURCE` defaults to the first source (`konachan.net`). `search` prints `{"posts": [Post], "more": bool}`. A Post is:

```json
{"source": "konachan.net", "id": 409110, "width": 3188, "height": 2000, "score": 12,
 "rating": "s", "tags": "sky clouds ...", "ext": "png", "size": 13971142,
 "preview": "https://…", "sample": "https://…", "file": "https://…", "url": "https://konachan.net/post/show/409110"}
```

`size` is 0 when the site doesn't report it (Safebooru), and `rating` is the site's raw value. Errors go to stderr with a non-zero exit code, including API messages such as Danbooru's 2-tag limit for anonymous users and missing credentials.

The CLI reads the GUI's settings (`~/.config/wallpaper-browser/settings.json`, mode 0600): `spicy` (show every rating; off keeps general/sensitive, or safe on Moebooru) and per-source `credentials`. A source that takes credentials has an `account` in `sources` (`fields`, `required`, `url`, `note`).

```qml
Process {
    command: ["wallpaper-browser", "search", "-p", page.toString(), ...tags.split(" ")]
    stdout: StdioCollector {
        onStreamFinished: root.posts = JSON.parse(text).posts
    }
}
```

## Sources

`src/booru/` has one engine per API family (`moebooru.rs`, `danbooru.rs`, `gelbooru.rs`) behind the `Source` trait, and `sources.rs` lists the sites as statics of those engines:

| id | engine | site |
| --- | --- | --- |
| `konachan.net` | Moebooru | konachan.net, safe-rated only |
| `danbooru-safe` | Danbooru | safebooru.donmai.us |
| `safebooru` | Gelbooru (0.2) | safebooru.org |
| `danbooru` | Danbooru | danbooru.donmai.us, optional login + API key |
| `gelbooru` | Gelbooru | gelbooru.com, user id + API key required |
| `yande.re` | Moebooru | yande.re |
| `konachan.com` | Moebooru | konachan.com, API behind Cloudflare: needs the browser's `cf_clearance` cookie and User-Agent |

A site on an existing engine is one static plus one entry in `SOURCES`. A new API family is a new engine module implementing `Source`. `hoshi/src-tauri/src/booru/` has more engines and sites to port.

Some boorus' CDNs behind Cloudflare (cdn.donmai.us) reject Qt's default User-Agent, so `cpp/network.h` gives the QML engine's network requests the app's own.
