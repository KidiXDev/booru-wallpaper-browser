mod backend;
mod booru;
mod caelestia;

use booru::{Query, Sort};
use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QString, QUrl};
use std::process::ExitCode;

const USAGE: &str = "\
usage:
  wallpaper-browser                                     open the browser
  wallpaper-browser search [-s SRC] [--sort SORT] [-p N] [-l N] [TAGS...]   print a page as JSON
  wallpaper-browser download [-s SRC] [--set] ID        print the saved path
  wallpaper-browser sources                             print sources as JSON
SRC defaults to the first source (konachan.net), SORT is latest, score or random.
Files go to <caelestia wallpaper dir>/<SRC>/";

// Headless mode for scripts and caelestia (Process + JSON.parse)
fn cli(args: &[String]) -> Result<String, String> {
    let mut source = booru::SOURCES[0].id().to_string();
    let (mut sort, mut page, mut limit, mut set) = (Sort::Latest, 1, 40, false);
    let mut rest = Vec::new();
    let mut it = args[1..].iter();
    while let Some(arg) = it.next() {
        let mut value = || it.next().ok_or(format!("{arg} needs a value"));
        let number = |v: &String| v.parse::<u32>().map_err(|_| format!("bad number: {v}"));
        match arg.as_str() {
            "-s" | "--source" => source = value()?.clone(),
            "--sort" => sort = Sort::parse(value()?)?,
            "-p" | "--page" => page = number(value()?)?,
            "-l" | "--limit" => limit = number(value()?)?,
            "--set" => set = true,
            _ => rest.push(arg.as_str()),
        }
    }
    match args[0].as_str() {
        "search" => {
            let tags = rest.join(" ");
            json(&booru::source(&source)?.search(&Query { tags: &tags, sort, page, limit })?)
        }
        "download" => {
            let id = rest.first().and_then(|id| id.parse().ok()).ok_or(USAGE)?;
            let path = booru::download(booru::source(&source)?, id, &caelestia::walls_dir())?;
            let path = path.to_string_lossy().into_owned();
            if set {
                caelestia::set_wallpaper(&path)?;
            }
            Ok(path)
        }
        "sources" => json(&booru::sources()),
        _ => Err(USAGE.into()),
    }
}

fn json(value: &impl serde::Serialize) -> Result<String, String> {
    serde_json::to_string(value).map_err(|e| e.to_string())
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if !args.is_empty() {
        return match cli(&args) {
            Ok(out) => {
                println!("{out}");
                ExitCode::SUCCESS
            }
            Err(e) => {
                eprintln!("{e}");
                ExitCode::FAILURE
            }
        };
    }

    let mut app = QGuiApplication::new();
    // Wayland app id, for Hyprland window rules
    QGuiApplication::set_desktop_file_name(&QString::from("wallpaper-browser"));
    let mut engine = QQmlApplicationEngine::new();
    if let Some(mut engine) = engine.as_mut() {
        backend::qobject::set_user_agent(engine.as_mut(), &QString::from(booru::UA));
        engine.load(&QUrl::from("qrc:/qt/qml/WallpaperBrowser/qml/Main.qml"));
    }
    match app.as_mut().map(|app| app.exec()) {
        Some(0) => ExitCode::SUCCESS,
        _ => ExitCode::FAILURE,
    }
}
