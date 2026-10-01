#pragma once

#include <QString>

namespace wallpaper {

// Logs every Qt message to <logDir>/latest.log, and on a fatal error (access violation, abort,
// qFatal, unhandled C++ exception, Rust panic) writes crash-<time>.log with a stack trace and the
// last messages (plus a minidump on Windows), tells the user in a native dialog and exits.
// Call once, before the QGuiApplication
void installCrashHandler(const QString& logDir, const QString& version);

// For fatal errors found outside the handlers above (Rust panics). Doesn't return
void reportFatal(const QString& message);

} // namespace wallpaper
