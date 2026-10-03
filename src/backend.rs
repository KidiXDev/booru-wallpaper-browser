#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    unsafe extern "C++" {
        include!("cxx-qt-lib/qqmlapplicationengine.h");
        include!("wallpaper-browser/cpp/network.h");
        type QQmlApplicationEngine = cxx_qt_lib::QQmlApplicationEngine;

        // Also sets up the image disk cache
        #[namespace = "wallpaper"]
        #[rust_name = "install_network"]
        fn installNetwork(engine: Pin<&mut QQmlApplicationEngine>, ua: &QString, cache_bytes: i64);

        #[namespace = "wallpaper"]
        #[rust_name = "set_cache_limit"]
        fn setCacheLimit(bytes: i64);

        #[namespace = "wallpaper"]
        #[rust_name = "clear_image_cache"]
        fn clearCache();

        #[namespace = "wallpaper"]
        #[rust_name = "image_cache_size"]
        fn cacheSize() -> i64;
    }

    unsafe extern "C++" {
        include!("wallpaper-browser/cpp/crash.h");

        #[namespace = "wallpaper"]
        #[rust_name = "install_crash_handler"]
        fn installCrashHandler(log_dir: &QString, version: &QString);

        #[namespace = "wallpaper"]
        #[rust_name = "report_fatal"]
        fn reportFatal(message: &QString);
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qml_singleton]
        #[qproperty(bool, busy)]
        type Booru = super::BooruRust;
    }

    impl cxx_qt::Threading for Booru {}

    #[auto_cxx_name]
    extern "RustQt" {
        #[qinvokable]
        fn search(self: Pin<&mut Booru>, source: &QString, tags: &QString, sort: &QString, page: i32);

        // apply = also set it as the desktop wallpaper
        #[qinvokable]
        fn download(self: Pin<&mut Booru>, source: &QString, id: i64, apply: bool);

        #[qinvokable]
        fn sources(self: &Booru) -> QString;

        #[qinvokable]
        fn settings(self: &Booru) -> QString;

        #[qinvokable]
        fn save_settings(self: &Booru, json: &QString) -> QString;

        // Bytes on disk
        #[qinvokable]
        fn cache_size(self: &Booru) -> i64;

        #[qinvokable]
        fn clear_cache(self: &Booru);

        #[qinvokable]
        fn scheme(self: &Booru) -> QString;

        #[qinvokable]
        fn walls_dir(self: &Booru) -> QString;

        // UI-owned state files ("window", "favorites")
        #[qinvokable]
        fn load_state(self: &Booru, name: &QString) -> QString;

        #[qinvokable]
        fn save_state(self: &Booru, name: &QString, json: &QString) -> QString;

        #[qsignal]
        fn results(self: Pin<&mut Booru>, json: &QString, error: &QString);

        #[qsignal]
        fn downloaded(self: Pin<&mut Booru>, source: &QString, id: i64, path: &QString, error: &QString);
    }
}

use crate::{
    booru::{self, Query, Sort},
    platform, settings,
};
use cxx_qt::{CxxQtType, Threading};
use cxx_qt_lib::QString;
use std::pin::Pin;

const PAGE_SIZE: u32 = 40;

#[derive(Default)]
pub struct BooruRust {
    busy: bool,
    // Drops results of a search that a newer one replaced
    seq: u64,
}

fn split<T>(res: Result<T, String>) -> (T, String)
where
    T: Default,
{
    match res {
        Ok(v) => (v, String::new()),
        Err(e) => (T::default(), e),
    }
}

impl qobject::Booru {
    fn search(mut self: Pin<&mut Self>, source: &QString, tags: &QString, sort: &QString, page: i32) {
        self.as_mut().rust_mut().seq += 1;
        let seq = self.rust().seq;
        self.as_mut().set_busy(true);
        let (source, tags, sort) = (source.to_string(), tags.to_string(), sort.to_string());
        let thread = self.qt_thread();
        std::thread::spawn(move || {
            let (json, err) = split(
                Sort::parse(&sort)
                    .and_then(|sort| {
                        let settings = settings::load();
                        let auth = settings.auth(&source);
                        let page = page.max(1) as u32;
                        let query = Query { tags: &tags, sort, page, limit: PAGE_SIZE, spicy: settings.spicy, auth: &auth };
                        booru::source(&source)?.search(&query)
                    })
                    .and_then(|p| serde_json::to_string(&p).map_err(|e| e.to_string())),
            );
            let _ = thread.queue(move |mut o| {
                if o.rust().seq == seq {
                    o.as_mut().set_busy(false);
                    o.results(&QString::from(&json), &QString::from(&err));
                }
            });
        });
    }

    fn download(self: Pin<&mut Self>, source: &QString, id: i64, apply: bool) {
        let source = source.to_string();
        let thread = self.qt_thread();
        std::thread::spawn(move || {
            let (path, mut err) = split(
                booru::source(&source)
                    .and_then(|s| booru::download(s, id as u64, &platform::walls_dir(), &settings::load().auth(&source)))
                    .map(|p| p.to_string_lossy().into_owned()),
            );
            if apply && err.is_empty() {
                err = platform::set_wallpaper(&path).err().unwrap_or_default();
            }
            let _ = thread.queue(move |o| {
                o.downloaded(&QString::from(&source), id, &QString::from(&path), &QString::from(&err));
            });
        });
    }

    fn sources(&self) -> QString {
        QString::from(&serde_json::to_string(&booru::sources()).unwrap_or_default())
    }

    fn settings(&self) -> QString {
        QString::from(&serde_json::to_string(&settings::load()).unwrap_or_default())
    }

    fn save_settings(&self, json: &QString) -> QString {
        match settings::save(&json.to_string()) {
            Ok(s) => {
                qobject::set_cache_limit(s.cache_bytes());
                QString::default()
            }
            Err(e) => QString::from(&e),
        }
    }

    fn cache_size(&self) -> i64 {
        qobject::image_cache_size()
    }

    fn clear_cache(&self) {
        qobject::clear_image_cache();
    }

    fn scheme(&self) -> QString {
        QString::from(&platform::scheme())
    }

    fn walls_dir(&self) -> QString {
        QString::from(&*platform::walls_dir().to_string_lossy())
    }

    fn load_state(&self, name: &QString) -> QString {
        QString::from(&settings::load_state(&name.to_string()))
    }

    fn save_state(&self, name: &QString, json: &QString) -> QString {
        QString::from(&settings::save_state(&name.to_string(), &json.to_string()).err().unwrap_or_default())
    }

}
