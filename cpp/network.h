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

inline std::atomic<std::int64_t> cacheLimit{0};

inline QString cacheDir() {
  return QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
}

class DiskCache : public QNetworkDiskCache {
public:
  using QNetworkDiskCache::QNetworkDiskCache;

  QIODevice *prepare(const QNetworkCacheMetaData &metaData) override {
    if (maximumCacheSize() != cacheLimit)
      setMaximumCacheSize(cacheLimit);
    return QNetworkDiskCache::prepare(metaData);
  }
};

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
    r.setAttribute(QNetworkRequest::CacheLoadControlAttribute,
                   QNetworkRequest::PreferCache);
    return QNetworkAccessManager::createRequest(op, r, data);
  }

private:
  QByteArray m_ua;
};

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

inline std::int64_t cacheSize() {
  std::int64_t total = 0;
  QDirIterator it(cacheDir(), {"*.d"}, QDir::Files,
                  QDirIterator::Subdirectories);
  while (it.hasNext())
    total += it.nextFileInfo().size();
  return total;
}

} // namespace wallpaper
