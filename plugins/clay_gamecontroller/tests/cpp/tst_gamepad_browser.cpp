// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "gamepadbackend_browser.h"

#include <QTest>

// What navigator.getGamepads() returns, set by the test
class FakeBrowser : public BrowserGamepadBackend
{
public:
    QList<BrowserPadState> pads;
    QString ua;

protected:
    QList<BrowserPadState> sample() override { return pads; }
    QString userAgent() const override { return ua; }
};

static const char *kFirefox =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:158.0) Gecko/20100101 Firefox/158.0";
static const char *kChrome =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36";

// A Switch Pro Controller as Firefox 158 on macOS reported it untouched:
// buttons 1-8 and 15-17 read pressed in a share of the samples and axis 0
// swung from -1 to 0.99. Frame n of that noise.
static BrowserPadState noisyProController(const QString &id, int n)
{
    BrowserPadState s;
    s.present = true;
    s.id = id;
    s.mapping = QStringLiteral("standard");
    s.axes = {n % 2 ? .99 : -1.0, 0, 0, 0};
    s.buttonValues.fill(0, 18);
    s.buttonPressed.fill(false, 18);
    for (int b : {1, 2, 3, 4, 5, 6, 7, 8, 15, 16, 17}) {
        const bool on = (n + b) % 2;
        s.buttonPressed[b] = on;
        s.buttonValues[b] = on ? 1 : 0;
    }
    return s;
}

// A pad the browser maps to its standard gamepad: 17 buttons, 4 axes
static BrowserPadState standardPad(const QString &id)
{
    BrowserPadState s;
    s.present = true;
    s.id = id;
    s.mapping = QStringLiteral("standard");
    s.axes.fill(0, 4);
    s.buttonValues.fill(0, 17);
    s.buttonPressed.fill(false, 17);
    return s;
}

class TestGamepadBrowser : public QObject
{
    Q_OBJECT

    struct Change { int deviceId; QString input; double value; };

    FakeBrowser *backend_ = nullptr;
    QList<GamepadInfo> added_;
    QList<int> removed_;
    QList<Change> changes_;

    void pollOnce()
    {
        added_.clear();
        removed_.clear();
        changes_.clear();
        backend_->poll();
    }

    // The value each input changed to in the last poll
    QHash<QString, double> changed() const
    {
        QHash<QString, double> map;
        for (const Change &c : changes_) map.insert(c.input, c.value);
        return map;
    }

private slots:
    void init()
    {
        backend_ = new FakeBrowser;
        connect(backend_, &GamepadBackend::padAdded, this,
                [this](const GamepadInfo &i) { added_.append(i); });
        connect(backend_, &GamepadBackend::padRemoved, this,
                [this](int id) { removed_.append(id); });
        connect(backend_, &GamepadBackend::inputChanged, this,
                [this](int id, const QString &input, double v) { changes_.append({id, input, v}); });
    }

    void cleanup()
    {
        delete backend_;
        backend_ = nullptr;
    }

    void name_drops_what_the_browser_adds_data()
    {
        QTest::addColumn<QString>("id");
        QTest::addColumn<QString>("name");
        QTest::newRow("chrome") << "DualSense Wireless Controller (STANDARD GAMEPAD Vendor: 054c Product: 0ce6)"
                                << "DualSense Wireless Controller";
        QTest::newRow("chrome xinput") << "Xbox 360 Controller (XInput STANDARD GAMEPAD)"
                                       << "Xbox 360 Controller";
        QTest::newRow("chrome unmapped") << "8BitDo Zero 2 (Vendor: 2dc8 Product: 9018)"
                                         << "8BitDo Zero 2";
        // What emscripten delivers of those: 63 bytes and its terminator
        QTest::newRow("chrome cut") << "DualSense Wireless Controller (STANDARD GAMEPAD Vendor: 054c Pr"
                                    << "DualSense Wireless Controller";
        QTest::newRow("chrome cut xbox") << "Xbox Wireless Controller (STANDARD GAMEPAD Vendor: 045e Product"
                                         << "Xbox Wireless Controller";
        QTest::newRow("chrome cut ps4") << "Wireless Controller (STANDARD GAMEPAD Vendor: 054c Product: 09c"
                                        << "Wireless Controller";
        QTest::newRow("firefox") << "054c-0ce6-DualSense Wireless Controller"
                                 << "DualSense Wireless Controller";
        QTest::newRow("plain") << "Steam Deck (Rev 2)" << "Steam Deck (Rev 2)";
        QTest::newRow("empty") << "" << "Gamepad";
    }

    void name_drops_what_the_browser_adds()
    {
        QFETCH(QString, id);
        QFETCH(QString, name);
        QCOMPARE(BrowserGamepadBackend::padName(id), name);
    }

    void no_gamepad_api_means_no_pads()
    {
        pollOnce();
        QVERIFY(added_.isEmpty());
        QVERIFY(changes_.isEmpty());
    }

    void a_standard_pad_reports_every_input_it_has()
    {
        backend_->pads = {standardPad("054c-0ce6-DualSense Wireless Controller")};
        pollOnce();
        QCOMPARE(added_.size(), 1);
        const GamepadInfo &info = added_.first();
        QVERIFY(info.deviceId > 0);
        QCOMPARE(info.name, QStringLiteral("DualSense Wireless Controller"));
        QCOMPARE(info.type, QStringLiteral("standard"));
        QCOMPARE(info.buttons, QStringList({"south", "east", "west", "north", "back", "guide",
                                            "start", "leftStick", "rightStick", "leftShoulder",
                                            "rightShoulder", "dpadUp", "dpadDown", "dpadLeft",
                                            "dpadRight"}));
        QCOMPARE(info.axes, QStringList({"leftX", "leftY", "rightX", "rightY",
                                         "leftTrigger", "rightTrigger"}));
        QVERIFY(info.labels.isEmpty());
        // Everything is neutral, so nothing changed
        QVERIFY(changes_.isEmpty());
    }

    void each_standard_button_drives_its_name()
    {
        const QStringList names{"south", "east", "west", "north", "leftShoulder", "rightShoulder",
                                "", "", "back", "start", "leftStick", "rightStick",
                                "dpadUp", "dpadDown", "dpadLeft", "dpadRight", "guide"};
        backend_->pads = {standardPad("Pad")};
        pollOnce();
        const int id = added_.first().deviceId;
        for (int b = 0; b < names.size(); ++b) {
            if (names[b].isEmpty()) continue;
            backend_->pads[0].buttonPressed[b] = true;
            backend_->pads[0].buttonValues[b] = 1;
            pollOnce();
            QCOMPARE(changes_.size(), 1);
            QCOMPARE(changes_.first().deviceId, id);
            QCOMPARE(changes_.first().input, names[b]);
            QCOMPARE(changes_.first().value, 1.0);
            backend_->pads[0].buttonPressed[b] = false;
            backend_->pads[0].buttonValues[b] = 0;
            pollOnce();
            QCOMPARE(changed().value(names[b], -1), 0.0);
        }
    }

    void triggers_are_axes_from_button_values()
    {
        backend_->pads = {standardPad("Pad")};
        pollOnce();
        backend_->pads[0].buttonValues[6] = .25;
        backend_->pads[0].buttonValues[7] = 1.5;
        backend_->pads[0].buttonPressed[7] = true;
        pollOnce();
        QCOMPARE(changed().value("leftTrigger"), .25);
        QCOMPARE(changed().value("rightTrigger"), 1.0);

        // A trigger that is only a switch
        backend_->pads[0].buttonValues[6] = 0;
        backend_->pads[0].buttonPressed[6] = true;
        pollOnce();
        QCOMPARE(changed().value("leftTrigger"), 1.0);
    }

    void sticks_keep_y_down_and_clamp()
    {
        backend_->pads = {standardPad("Pad")};
        pollOnce();
        backend_->pads[0].axes = {.5, 1.0, -1.2, -.75};
        pollOnce();
        QCOMPARE(changed().value("leftX"), .5);
        QCOMPARE(changed().value("leftY"), 1.0);
        QCOMPARE(changed().value("rightX"), -1.0);
        QCOMPARE(changed().value("rightY"), -.75);
        pollOnce();
        QVERIFY2(changes_.isEmpty(), "an unchanged pad reports nothing");
    }

    void an_unmapped_pad_is_read_by_the_standard_indices()
    {
        BrowserPadState s = standardPad("2dc8-9018-8BitDo Zero 2");
        s.mapping.clear();
        s.axes.fill(0, 2);
        s.buttonValues.fill(0, 4);
        s.buttonPressed.fill(false, 4);
        backend_->pads = {s};
        pollOnce();
        QCOMPARE(added_.first().type, QStringLiteral("unmapped"));
        QCOMPARE(added_.first().buttons, QStringList({"south", "east", "west", "north"}));
        QCOMPARE(added_.first().axes, QStringList({"leftX", "leftY"}));
        backend_->pads[0].buttonPressed[2] = true;
        backend_->pads[0].axes[0] = -1;
        pollOnce();
        QCOMPARE(changed().value("west"), 1.0);
        QCOMPARE(changed().value("leftX"), -1.0);
    }

    void a_pad_that_goes_frees_its_slot()
    {
        backend_->pads = {standardPad("Pad A"), standardPad("Pad B")};
        pollOnce();
        QCOMPARE(added_.size(), 2);
        const int a = added_[0].deviceId;
        const int b = added_[1].deviceId;
        QVERIFY(a != b);

        // The browser keeps the index of the second pad
        backend_->pads[0] = BrowserPadState();
        pollOnce();
        QCOMPARE(removed_, QList<int>({a}));
        QVERIFY(added_.isEmpty());

        // Plugged in again it is a pad of its own
        backend_->pads[0] = standardPad("Pad A");
        pollOnce();
        QCOMPARE(added_.size(), 1);
        QVERIFY(added_.first().deviceId != a && added_.first().deviceId != b);

        // Another pad in a slot replaces the one there
        const int again = added_.first().deviceId;
        backend_->pads[0] = standardPad("Pad C");
        pollOnce();
        QCOMPARE(removed_, QList<int>({again}));
        QCOMPARE(added_.size(), 1);
        QCOMPARE(added_.first().name, QStringLiteral("Pad C"));

        backend_->pads.clear();
        pollOnce();
        QCOMPARE(removed_.size(), 2);
        QVERIFY(removed_.contains(b));
    }

    void firefox_lists_a_pad_and_reads_nothing_of_it()
    {
        backend_->ua = kFirefox;
        backend_->pads = {noisyProController("057e-2009-Pro Controller", 0)};
        pollOnce();
        QCOMPARE(added_.size(), 1);
        QCOMPARE(added_.first().name, QStringLiteral("Pro Controller"));
        QCOMPARE(added_.first().type, QStringLiteral("unsupported"));
        QVERIFY(added_.first().buttons.isEmpty());
        QVERIFY(added_.first().axes.isEmpty());
        QVERIFY(changes_.isEmpty());

        for (int n = 1; n < 20; ++n) {
            backend_->pads = {noisyProController("057e-2009-Pro Controller", n)};
            pollOnce();
            QVERIFY2(changes_.isEmpty(), "Firefox's noise drives no input");
            QVERIFY(added_.isEmpty());
        }

        // Unplugging still counts
        backend_->pads.clear();
        pollOnce();
        QCOMPARE(removed_.size(), 1);
    }

    void chrome_reads_the_same_pad()
    {
        backend_->ua = kChrome;
        const QString id = "Pro Controller (STANDARD GAMEPAD Vendor: 057e Product: 2009)";
        backend_->pads = {noisyProController(id, 0)};
        pollOnce();
        QCOMPARE(added_.first().name, QStringLiteral("Pro Controller"));
        QCOMPARE(added_.first().type, QStringLiteral("standard"));
        QCOMPARE(added_.first().axes.size(), 6);
        backend_->pads = {noisyProController(id, 1)};
        pollOnce();
        QVERIFY2(!changes_.isEmpty(), "outside Firefox every reading counts");
        QCOMPARE(changed().value("leftX"), .99);
    }

    void virtual_pads_stand_in_for_the_browser()
    {
        backend_->pads = {standardPad("Browser Pad")};
        const int id = backend_->attachVirtual("Clay Test Pad");
        QVERIFY(id > 0);
        pollOnce();
        QCOMPARE(added_.size(), 2);
        QCOMPARE(added_[1].deviceId, id);
        QCOMPARE(added_[1].name, QStringLiteral("Clay Test Pad"));

        QVERIFY(backend_->setVirtualInput(id, "north", 1));
        QVERIFY(backend_->setVirtualInput(id, "rightTrigger", .5));
        QVERIFY(backend_->setVirtualInput(id, "leftY", -2));
        QVERIFY(!backend_->setVirtualInput(id, "misc1", 1));
        QVERIFY(!backend_->setVirtualInput(id + 100, "north", 1));
        pollOnce();
        QCOMPARE(changes_.size(), 3);
        for (const Change &c : changes_) QCOMPARE(c.deviceId, id);
        QCOMPARE(changed().value("north"), 1.0);
        QCOMPARE(changed().value("rightTrigger"), .5);
        QCOMPARE(changed().value("leftY"), -1.0);

        QVERIFY(backend_->detachVirtual(id));
        QVERIFY(!backend_->detachVirtual(id));
        pollOnce();
        QCOMPARE(removed_, QList<int>({id}));
    }
};

QTEST_GUILESS_MAIN(TestGamepadBrowser)
#include "tst_gamepad_browser.moc"
