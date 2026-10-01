use cxx_qt_build::{CxxQtBuilder, QmlFile, QmlModule};

const SINGLETONS: &[&str] = &["Colours.qml", "Tokens.qml"];

fn main() {
    // Built as "qml/<name>" rather than read_dir's paths, which use `\` on Windows. cxx-qt writes
    // those verbatim into qmldir and the qrc aliases, so each type got loaded twice (once from the
    // qmlcachegen unit, once interpreted) and the copies didn't match as signal arguments
    let mut files: Vec<String> = std::fs::read_dir("qml")
        .unwrap()
        .map(|e| e.unwrap().file_name().into_string().unwrap())
        .filter(|name| name.ends_with(".qml"))
        .collect();
    files.sort();
    let mut module = QmlModule::new("WallpaperBrowser");
    for name in files {
        let singleton = SINGLETONS.contains(&name.as_str());
        module = module.qml_file(QmlFile::from(format!("qml/{name}")).singleton(singleton));
    }
    println!("cargo::rerun-if-changed=qml");
    println!("cargo::rerun-if-changed=assets");
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("windows") {
        // Crash handler: stack walk and minidump, the dialog, revealing the report in Explorer
        for lib in ["dbghelp", "user32", "shell32"] {
            println!("cargo::rustc-link-lib={lib}");
        }
    }
    println!("cargo::rerun-if-changed=cpp");
    CxxQtBuilder::new_qml_module(module)
        .qrc("assets/fonts.qrc")
        .cpp_file("cpp/crash.cpp")
        .files(["src/backend.rs"])
        .qt_module("Network")
        .build();
}
