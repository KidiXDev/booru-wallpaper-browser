# wallpaper-browser

Browse, download and set wallpapers from Konachan, Danbooru, Safebooru, Gelbooru and yande.re. Runs on Linux and Windows.

## Install

Grab the latest build from the [Releases](../../releases) page:

- **Windows:** download the `.zip`, extract it and run `wallpaper-browser.exe`.
- **Linux:** download the `.tar.gz` and run `wallpaper-browser`. You need Qt 6 with QtQuick installed (`qt6-declarative` on Arch, `qml6-module-*` packages on Debian/Ubuntu).

Or build it yourself (Rust and Qt 6 required):

```sh
cargo build --release
./target/release/wallpaper-browser
```

## Using it

Pick a site, search by tags, and click a wallpaper to preview it. From there you can download it or set it as your wallpaper in one click.

| Site                      | Notes                                                     |
| ------------------------- | --------------------------------------------------------- |
| Konachan (`konachan.net`) | Safe-rated only                                           |
| Danbooru (Safe)           | Safe posts only                                           |
| Safebooru                 |                                                           |
| Danbooru                  | Optional login + API key                                  |
| Gelbooru                  | User id + API key required                                |
| yande.re                  |                                                           |
| Konachan (`konachan.com`) | Needs your browser's `cf_clearance` cookie and User-Agent |

## Contributing

### Architecture & Adding Sites

- **Engines:** `src/booru/` implements an engine for each API family (Moebooru, Danbooru, Gelbooru).
- **Adding a site:** If the site uses an existing engine, define a static config and add an entry to `SOURCES` in `src/sources.rs`.
- **UI:** Located in `qml/`, ported from caelestia's design system.

### Asset Pipelines

- **Fonts & Icons:** Bundled fonts are subsetted from `assets/fonts/src/` to only include glyphs used in QML. When adding new icons, re-generate subsets (requires `fonttools` and `uharfbuzz`) or they will render as text:
  ```sh
  pip install fonttools uharfbuzz
  python3 scripts/subset_fonts.py
  ```
- **Shaders:** Shaders in `assets/shaders/` are committed precompiled. After modifying them, recompile with Qt's `qsb`:
  ```sh
  ./scripts/compile_shaders.sh
  ```
