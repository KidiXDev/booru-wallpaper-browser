#pragma once

#include <QString>

namespace wallpaper {

void installCrashHandler(const QString &logDir, const QString &version);

void reportFatal(const QString &message);

} // namespace wallpaper
