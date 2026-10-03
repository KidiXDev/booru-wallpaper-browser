#pragma once

#include <QDirIterator>
#include <QNetworkAccessManager>
#include <QNetworkDiskCache>
#include <QNetworkRequest>
#include <QQmlApplicationEngine>
#include <QQmlNetworkAccessManagerFactory>
#include <QStandardPaths>
#include <atomic>
#include <cstdint>

namespace wallpaper {

// Bytes, set from the settings page on the GUI thread
inline std::atomic<std::int64_t> cacheLimit{0};

// ~/.cache/wallpaper-browser, %LOCALAPPDATA%\wallpaper-browser\cache
inline QString cacheDir() {
  return QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
}

// One per loader thread, all on the same directory. Each takes a new limit
// itself before storing, since a QNetworkDiskCache belongs to its thread. In
// prepare(), not insert(): prepare() already refuses anything over 3/4 of the
// old limit, so after a limit of 0 insert() would never run again
class DiskCache : public QNetworkDiskCache {
public:
  using QNetworkDiskCache::QNetworkDiskCache;

  QIODevice *prepare(const QNetworkCacheMetaData &metaData) override {
    if (maximumCacheSize() != cacheLimit)
      setMaximumCacheSize(cacheLimit);
    return QNetworkDiskCache::prepare(metaData);
  }
};

// Cloudflare on some boorus (cdn.donmai.us) answers 403 to Qt's default
// "Mozilla/5.0" user agent,
class UserAgentManager : public QNetworkAccessManager {
public:
  UserAgentManager(const QByteArray &ua, QObject *parent)
      : QNetworkAccessManager(parent), m_ua(ua) {}

protected:
  QNetworkReply *createRequest(Operation op, const QNetworkRequest &request,
                               QIODevice *data) override {
    QNetworkRequest r(request);
    r.setHeader(QNetworkRequest::UserAgentHeader, m_ua);
    if (!r.hasRawHeader("Referer"))
      r.setRawHeader(
          "Referer",
          r.url().adjusted(QUrl::RemovePath | QUrl::RemoveQuery).toEncoded() +
              '/');
    // Booru media is named by its hash and never changes, so a cached copy
    // is used as is, without revalidating
    r.setAttribute(QNetworkRequest::CacheLoadControlAttribute,
                   QNetworkRequest::PreferCache);
    return QNetworkAccessManager::createRequest(op, r, data);
  }

private:
  QByteArray m_ua;
};

// Called from the engine's loader threads, so it only reads its members
class UserAgentFactory : public QQmlNetworkAccessManagerFactory {
public:
  UserAgentFactory(const QByteArray &ua, const QString &cache)
      : m_ua(ua), m_cache(cache) {}

  QNetworkAccessManager *create(QObject *parent) override {
    auto *manager = new UserAgentManager(m_ua, parent);
    auto *cache = new DiskCache(manager);
    cache->setCacheDirectory(m_cache);
    cache->setMaximumCacheSize(cacheLimit);
    manager->setCache(cache);
    return manager;
  }

private:
  QByteArray m_ua;
  QString m_cache;
};

inline void installNetwork(QQmlApplicationEngine &engine, const QString &ua,
                           std::int64_t cacheBytes) {
  cacheLimit = cacheBytes;
  engine.setNetworkAccessManagerFactory(
      new UserAgentFactory(ua.toUtf8(), cacheDir()));
}

// Trims to the new limit right away (oldest first, to 90% of it), so the size
// the settings page shows is right; the threads' caches follow on their next
// insert
inline void setCacheLimit(std::int64_t bytes) {
  cacheLimit = bytes;
  QNetworkDiskCache cache;
  cache.setCacheDirectory(cacheDir());
  cache.setMaximumCacheSize(bytes);
  cache.cacheSize(); // Scans the directory, expiring what's over
}

inline void clearCache() {
  QNetworkDiskCache cache;
  cache.setCacheDirectory(cacheDir());
  cache.clear();
}

// What the caches count: their ".d" entries
inline std::int64_t cacheSize() {
  std::int64_t total = 0;
  QDirIterator it(cacheDir(), {"*.d"}, QDir::Files,
                  QDirIterator::Subdirectories);
  while (it.hasNext())
    total += it.nextFileInfo().size();
  return total;
}

} // namespace wallpaper
