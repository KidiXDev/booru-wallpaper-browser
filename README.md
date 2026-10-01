# wallpaper-browser

Browse, download and set wallpapers from Konachan, Danbooru, Safebooru, Gelbooru and yande.re. Runs on Linux and Windows, and fits right in with the [caelestia](https://github.com/KidiXDev/kdz-caelestia) shell if you use it.

## Install

Grab the latest build from the [Releases](../../releases) page:

- **Windows:** download the `.zip`, extract it and run `wallpaper-browser.exe`. Run it as `wallpaper-browser.exe --debug` to get a console window with the app's logs.
- **Linux:** download the `.tar.gz` and run `wallpaper-browser`. You need Qt 6 with QtQuick installed (`qt6-declarative` on Arch, `qml6-module-*` packages on Debian/Ubuntu).

Or build it yourself (Rust and Qt 6 required):

```sh
cargo build --release
./target/release/wallpaper-browser
```

## Using it

Pick a site, search by tags, and click a wallpaper to preview it. From there you can download it or set it as your wallpaper in one click.

- **Where files go:** `~/Pictures/Wallpapers/<site>/` (`%USERPROFILE%\Pictures\Wallpapers\<site>\` on Windows). With caelestia installed it uses the shell's wallpaper folder instead, so downloads show up as a category in its picker.
- **Settings:** the settings page has a switch for questionable/explicit posts (off by default) and logins for sites that need them. Gelbooru requires a user id and API key; you can paste the `&api_key=…&user_id=…` string from its account page and it fills both fields.
- **Colours:** with caelestia the app follows the shell's colour scheme, otherwise it uses a dark default. It looks the same on every platform.
- **Window:** F11 toggles fullscreen (Esc also leaves it). On Windows the app reopens where you left it: same position and size, maximized or fullscreen.

| Site | Notes |
| --- | --- |
| Konachan (`konachan.net`) | Safe-rated only |
| Danbooru (Safe) | Safe posts only |
| Safebooru | |
| Danbooru | Optional login + API key; anonymous users are limited to 2 tags |
| Gelbooru | User id + API key required |
| yande.re | |
| Konachan (`konachan.com`) | Needs your browser's `cf_clearance` cookie and User-Agent |

## Command line

Without arguments it opens the window. With arguments it prints JSON, which scripts (and caelestia's settings) can use:

```sh
wallpaper-browser search [-s SOURCE] [--sort latest|score|random] [-p PAGE] [-l LIMIT] [TAGS...]
wallpaper-browser download [-s SOURCE] [--set] ID   # prints the saved path
wallpaper-browser sources                           # list the source ids
```

`SOURCE` defaults to `konachan.net`. `search` prints `{"posts": [...], "more": bool}`; each post looks like:

```json
{"source": "konachan.net", "id": 409110, "width": 3188, "height": 2000, "score": 12,
 "rating": "s", "tags": "sky clouds ...", "ext": "png", "size": 13971142,
 "preview": "https://…", "sample": "https://…", "file": "https://…", "url": "https://konachan.net/post/show/409110"}
```

Errors go to stderr with a non-zero exit code. The CLI uses the same settings as the app (`~/.config/wallpaper-browser/settings.json`, `%APPDATA%\wallpaper-browser\settings.json` on Windows).

From QML:

```qml
Process {
    command: ["wallpaper-browser", "search", "-p", page.toString(), ...tags.split(" ")]
    stdout: StdioCollector {
        onStreamFinished: root.posts = JSON.parse(text).posts
    }
}
```

## Contributing

`src/booru/` has one engine per API family (Moebooru, Danbooru, Gelbooru) and `sources.rs` lists the sites. Adding a site on an existing engine is one static plus one entry in `SOURCES`. The UI in `qml/` is a port of caelestia's design system. The bundled fonts are cut down from the full ones in `assets/fonts/src/` to the icons the QML uses: after using a new icon, run `python3 scripts/subset_fonts.py` (needs `pip install fonttools uharfbuzz`), or it shows up as its name. Pushing a `v*` tag builds the Windows and Linux releases.
