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

        #[namespace = "wallpaper"]
        #[rust_name = "set_user_agent"]
        fn setUserAgent(engine: Pin<&mut QQmlApplicationEngine>, ua: &QString);
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

        #[qinvokable]
        fn scheme(self: &Booru) -> QString;

        #[qinvokable]
        fn walls_dir(self: &Booru) -> QString;

        #[qinvokable]
        fn window_state(self: &Booru) -> QString;

        #[qinvokable]
        fn save_window_state(self: &Booru, json: &QString) -> QString;

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
        QString::from(&settings::save(&json.to_string()).err().unwrap_or_default())
    }

    fn scheme(&self) -> QString {
        QString::from(&platform::scheme())
    }

    fn walls_dir(&self) -> QString {
        QString::from(&*platform::walls_dir().to_string_lossy())
    }

    fn window_state(&self) -> QString {
        QString::from(&settings::load_window())
    }

    fn save_window_state(&self, json: &QString) -> QString {
        QString::from(&settings::save_window(&json.to_string()).err().unwrap_or_default())
    }

}
