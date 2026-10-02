// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// libdatachannel reports a close on its own thread, also once the object the
// callback was set up for is gone: a ClayNetwork whose peer connection closes
// (#357), a LocalSignalingClient whose socket closes (#359). Each test holds
// that close callback in the test hook while it destroys the object, so the
// race that is otherwise a few microseconds wide is hit every run. The object
// lives in memory the test owns and zeroes after the destructor, as a reused
// allocation would be: a callback that still reaches it crashes at once.

#include "claynetwork_native.h"
#include "signaling_local.h"
#include "testhooks.h"

#include <QSignalSpy>
#include <QTest>
#include <QDeadlineTimer>

#include <atomic>
#include <chrono>
#include <cstring>
#include <thread>

namespace {

constexpr int kHoldMs = 300;

std::atomic<const void *> heldOwner{nullptr};
std::atomic<int> held{0};
std::thread::id testThread;

// Holds the close callback meant for heldOwner when libdatachannel reports it
// on its own thread; lets every other one pass
void holdClose(const void *owner)
{
    if (owner != heldOwner.load() || std::this_thread::get_id() == testThread)
        return;
    held.fetch_add(1);
    std::this_thread::sleep_for(std::chrono::milliseconds(kHoldMs));
}

// Without running the event loop: nothing queued to the object can reach it
// before it is destroyed, the close has to come from libdatachannel
bool waitUntilHeld()
{
    QDeadlineTimer deadline(5000);
    while (held.load() == 0 && !deadline.hasExpired())
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    return held.load() == 1;
}

struct HoldCloseOf
{
    explicit HoldCloseOf(const void *owner)
    {
        held = 0;
        testThread = std::this_thread::get_id();
        heldOwner = owner;
        clay::network::testhooks::closeCallback = &holdClose;
    }
    ~HoldCloseOf()
    {
        clay::network::testhooks::closeCallback = nullptr;
        heldOwner = nullptr;
    }
};

// A T whose memory is zeroed once it is destroyed
template <typename T>
class Scribbled
{
public:
    Scribbled() { obj_ = new (storage_) T(); }
    ~Scribbled() { destroy(); }
    T *operator->() { return obj_; }
    T *get() { return obj_; }
    void destroy()
    {
        if (!obj_)
            return;
        obj_->~T();
        obj_ = nullptr;
        std::memset(storage_, 0, sizeof(storage_));
    }

private:
    alignas(T) unsigned char storage_[sizeof(T)];
    T *obj_ = nullptr;
};

} // namespace

class TestLateClose : public QObject
{
    Q_OBJECT

private slots:
    // The server closes the socket; the client is destroyed while its Closed
    // callback is running on libdatachannel's thread. resetCallbacks() in
    // disconnect() waits for that callback (#359). Without it, dropping the
    // client's rtc::WebSocket does the same - unless something else still
    // holds that socket
    void signalingClientDestroyedWhileItsCloseIsReported()
    {
        LocalSignalingServer server;
        QVERIFY(server.start(0));
        auto client = std::make_unique<Scribbled<LocalSignalingClient>>();
        (*client)->connect("127.0.0.1", server.port());
        QTRY_VERIFY_WITH_TIMEOUT((*client)->isConnected(), 5000);

        HoldCloseOf hold(client->get());
        server.stop();
        QVERIFY(waitUntilHeld());
        client->destroy();
        // The held callback goes on without the client
        QTest::qWait(2 * kHoldMs);
        QCOMPARE(held.load(), 1);
    }

    // The host leaves, which closes the joiner's peer connection from the
    // far side; the joiner is destroyed while that connection's Closed
    // callback is running (#357)
    void networkDestroyedWhileAPeerCloseIsReported()
    {
        ClayNetwork host;
        host.setSignalingMode(ClayNetwork::Local);
        QSignalSpy created(&host, &ClayNetwork::roomCreated);
        host.createRoom();
        QVERIFY(created.wait(10000));

        auto joiner = std::make_unique<Scribbled<ClayNetwork>>();
        (*joiner)->joinRoom(host.networkId());
        QTRY_VERIFY_WITH_TIMEOUT((*joiner)->connected() && host.nodes().size() == 1, 20000);

        HoldCloseOf hold(joiner->get());
        host.leave();
        QVERIFY(waitUntilHeld());
        joiner->destroy();
        QTest::qWait(2 * kHoldMs);
        QCOMPARE(held.load(), 1);
    }
};

QTEST_GUILESS_MAIN(TestLateClose)
#include "tst_late_close.moc"
