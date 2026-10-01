#pragma once

#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QQmlApplicationEngine>
#include <QQmlNetworkAccessManagerFactory>

namespace wallpaper {

// Cloudflare on some boorus (cdn.donmai.us) answers 403 to Qt's default "Mozilla/5.0" user agent,
// so every request the QML engine makes (thumbnails, samples) gets ours instead
class UserAgentManager : public QNetworkAccessManager {
public:
    UserAgentManager(const QByteArray& ua, QObject* parent)
        : QNetworkAccessManager(parent)
        , m_ua(ua) {}

protected:
    QNetworkReply* createRequest(Operation op, const QNetworkRequest& request, QIODevice* data) override {
        QNetworkRequest r(request);
        r.setHeader(QNetworkRequest::UserAgentHeader, m_ua);
        return QNetworkAccessManager::createRequest(op, r, data);
    }

private:
    QByteArray m_ua;
};

// Called from the engine's loader threads, so it only reads m_ua
class UserAgentFactory : public QQmlNetworkAccessManagerFactory {
public:
    explicit UserAgentFactory(const QByteArray& ua)
        : m_ua(ua) {}

    QNetworkAccessManager* create(QObject* parent) override { return new UserAgentManager(m_ua, parent); }

private:
    QByteArray m_ua;
};

// Must run before anything is loaded. The engine doesn't own the factory; it lives for the whole app
inline void setUserAgent(QQmlApplicationEngine& engine, const QString& ua) {
    engine.setNetworkAccessManagerFactory(new UserAgentFactory(ua.toUtf8()));
}

} // namespace wallpaper
