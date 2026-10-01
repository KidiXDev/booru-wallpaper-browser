use cxx_qt_build::{CxxQtBuilder, QmlFile, QmlModule};

const SINGLETONS: &[&str] = &["Colours.qml", "Tokens.qml"];

fn main() {
    let mut files: Vec<_> = std::fs::read_dir("qml")
        .unwrap()
        .map(|e| e.unwrap().path())
        .filter(|p| p.extension().is_some_and(|e| e == "qml"))
        .collect();
    files.sort();
    let mut module = QmlModule::new("WallpaperBrowser");
    for path in files {
        let singleton = SINGLETONS.iter().any(|s| path.ends_with(s));
        module = module.qml_file(QmlFile::from(path).singleton(singleton));
    }
    println!("cargo::rerun-if-changed=qml");
    CxxQtBuilder::new_qml_module(module)
        .files(["src/backend.rs"])
        .qt_module("Network")
        .build();
}
