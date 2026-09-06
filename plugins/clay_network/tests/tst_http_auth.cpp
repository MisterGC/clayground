// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include <QtTest/QtTest>
#include <QTcpServer>
#include <QTcpSocket>
#include <QQmlEngine>
#include <QQmlComponent>
#include <QJSValue>
#include <QSharedPointer>

#include "claywebaccess.h"

namespace {

/**
 * @brief Records the head of every HTTP request it receives and answers 200.
 *
 * Enough of a server to assert what a client actually put on the wire; it
 * never looks at a body, so the suite drives GET endpoints only.
 */
class EchoServer : public QTcpServer
{
    Q_OBJECT

public:
    explicit EchoServer(QObject* parent = nullptr) : QTcpServer(parent)
    {
        connect(this, &QTcpServer::newConnection, this, &EchoServer::onConnection);
    }

    QList<QByteArray> requestHeads;

    /** Value of \a name in request \a index, or a null QByteArray if absent. */
    QByteArray header(int index, const QByteArray& name) const
    {
        if (index < 0 || index >= requestHeads.size()) return {};
        const auto lines = requestHeads[index].split('\n');
        for (const auto& line : lines) {
            const auto colon = line.indexOf(':');
            if (colon < 0) continue;
            if (line.left(colon).trimmed().toLower() == name.toLower())
                return line.mid(colon + 1).trimmed();
        }
        return {};
    }

private slots:
    void onConnection()
    {
        auto* socket = nextPendingConnection();
        auto buffer = QSharedPointer<QByteArray>::create();
        connect(socket, &QTcpSocket::readyRead, this, [this, socket, buffer]() {
            buffer->append(socket->readAll());
            const auto end = buffer->indexOf("\r\n\r\n");
            if (end < 0) return;
            requestHeads.append(buffer->left(end));
            socket->write("HTTP/1.1 200 OK\r\n"
                          "Content-Type: application/json\r\n"
                          "Content-Length: 2\r\n"
                          "Connection: close\r\n"
                          "\r\n"
                          "{}");
            socket->flush();
            socket->disconnectFromHost();
        });
        connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
    }
};

} // namespace

/**
 * @brief Asserts the headers ClayHttpClient sends for each auth scheme.
 *
 * ClayHttpClient.qml is loaded straight from the source tree and ClayWebAccess
 * is registered by hand, so the suite needs neither the built plugin nor a QML
 * import path.
 */
class TestHttpAuth : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void bearerTokenUnchanged();
    void basicAuthHeader();
    void basicAuthPasswordFromEnv();
    void apiKeyHeaderVerbatim();
    void apiKeyHeaderRenamed();
    void apiKeyAlongsideBearerToken();
    void noCredentialsNoAuthHeader();
    void cleanup();

private:
    /** Creates a client with one "GET ping" endpoint and the given properties. */
    QObject* createClient(const QVariantMap& props);
    /** Calls api.ping() and waits until the server has seen the request. */
    void callPing(QObject* client);

    QQmlEngine engine_;
    EchoServer server_;
    QString baseUrl_;
    std::vector<std::unique_ptr<QObject>> clients_;
};

void TestHttpAuth::initTestCase()
{
    qmlRegisterType<ClayWebAccess>("Clayground.Network", 1, 0, "ClayWebAccess");
    QVERIFY2(server_.listen(QHostAddress::LocalHost),
             qPrintable(server_.errorString()));
    baseUrl_ = QString("http://127.0.0.1:%1").arg(server_.serverPort());
}

void TestHttpAuth::cleanup()
{
    server_.requestHeads.clear();
    clients_.clear();
}

QObject* TestHttpAuth::createClient(const QVariantMap& props)
{
    QQmlComponent comp(&engine_, QUrl::fromLocalFile(CLAY_HTTP_CLIENT_QML));
    auto* client = comp.create();
    if (!client) {
        qWarning() << comp.errorString();
        return nullptr;
    }
    clients_.emplace_back(client);

    client->setProperty("baseUrl", baseUrl_);
    for (auto it = props.cbegin(); it != props.cend(); ++it)
        client->setProperty(qPrintable(it.key()), it.value());
    // Last, so the generated api object sees the finished configuration.
    client->setProperty("endpoints", QVariantMap{{"ping", "GET ping"}});
    return client;
}

void TestHttpAuth::callPing(QObject* client)
{
    QVERIFY(client);
    auto api = client->property("api").value<QJSValue>();
    auto ping = api.property("ping");
    QVERIFY2(ping.isCallable(), "api.ping was not generated");
    const auto result = ping.callWithInstance(api);
    QVERIFY2(!result.isError(), qPrintable(result.toString()));
    QTRY_VERIFY(!server_.requestHeads.isEmpty());
}

void TestHttpAuth::bearerTokenUnchanged()
{
    auto* client = createClient({{"bearerToken", "tok-123"}});
    callPing(client);
    QCOMPARE(server_.header(0, "Authorization"), QByteArray("Bearer tok-123"));
}

void TestHttpAuth::basicAuthHeader()
{
    auto* client = createClient({{"basicAuthUser", "alice"},
                                 {"basicAuthPassword", "s3cret"}});
    callPing(client);
    // base64("alice:s3cret")
    QCOMPARE(server_.header(0, "Authorization"),
             QByteArray("Basic YWxpY2U6czNjcmV0"));
    QCOMPARE(QByteArray::fromBase64(server_.header(0, "Authorization").mid(6)),
             QByteArray("alice:s3cret"));
}

void TestHttpAuth::basicAuthPasswordFromEnv()
{
    qputenv("CLAY_TEST_BASIC_PASSWORD", "s3cret");
    auto* client = createClient({{"basicAuthUser", "alice"},
                                 {"basicAuthPassword", "env.CLAY_TEST_BASIC_PASSWORD"}});
    callPing(client);
    QCOMPARE(server_.header(0, "Authorization"),
             QByteArray("Basic YWxpY2U6czNjcmV0"));
    qunsetenv("CLAY_TEST_BASIC_PASSWORD");
}

void TestHttpAuth::apiKeyHeaderVerbatim()
{
    auto* client = createClient({{"apiKey", "abc123"}});
    callPing(client);
    QCOMPARE(server_.header(0, "X-API-Key"), QByteArray("abc123"));
    QVERIFY(server_.header(0, "Authorization").isNull());
}

void TestHttpAuth::apiKeyHeaderRenamed()
{
    auto* client = createClient({{"apiKey", "abc123"},
                                 {"apiKeyHeader", "X-Custom-Key"}});
    callPing(client);
    QCOMPARE(server_.header(0, "X-Custom-Key"), QByteArray("abc123"));
    QVERIFY(server_.header(0, "X-API-Key").isNull());
}

void TestHttpAuth::apiKeyAlongsideBearerToken()
{
    auto* client = createClient({{"bearerToken", "tok-123"},
                                 {"apiKey", "abc123"}});
    callPing(client);
    QCOMPARE(server_.header(0, "Authorization"), QByteArray("Bearer tok-123"));
    QCOMPARE(server_.header(0, "X-API-Key"), QByteArray("abc123"));
}

void TestHttpAuth::noCredentialsNoAuthHeader()
{
    auto* client = createClient({});
    callPing(client);
    QVERIFY(server_.header(0, "Authorization").isNull());
    QVERIFY(server_.header(0, "X-API-Key").isNull());
}

QTEST_MAIN(TestHttpAuth)
#include "tst_http_auth.moc"
