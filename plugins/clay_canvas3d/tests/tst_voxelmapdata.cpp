// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// What a fill() paints, checked by reading the voxels back.
//
// #178: prepareColorDistribution() read every colour with toString(), so it
// only ever worked for the shapes QVariant happens to know how to stringify.
// A colour that has been through JS - spread into a new object, or deep-copied
// through JSON - arrives as a plain {r,g,b,a} map, stringifies to nothing, and
// became QColor(""): the whole filled body came out one dead colour while the
// hand-placed voxels next to it stayed right, because setVoxel() takes a
// QColor and never went through this path.
//
// The cases below feed each fill entry point the variant shapes QML actually
// produces and assert the colour that comes back out of voxel().

#include <QtTest>
#include <QColor>
#include <QVariantMap>

#include "voxelmapdata.h"

namespace {

QVariantList dist(const QVariant &color, const QVariant &weight = QVariant(1.0))
{
    QVariantMap entry;
    entry["color"] = color;
    if (weight.isValid()) entry["weight"] = weight;
    return QVariantList{entry};
}

} // namespace

class TstVoxelMapData : public QObject
{
    Q_OBJECT

private slots:
    void init()
    {
        m_map.reset(new VoxelMapData);
        m_map->setVoxelCountX(4);
        m_map->setVoxelCountY(4);
        m_map->setVoxelCountZ(4);
    }

    // THE REGRESSION. Every colour spelling QML can hand over must survive.
    void fillPaintsTheColorItWasGiven_data()
    {
        QTest::addColumn<QVariant>("color");

        const QColor cyan("#00d9ff");
        QVariantMap channels;
        channels["r"] = cyan.redF();
        channels["g"] = cyan.greenF();
        channels["b"] = cyan.blueF();
        channels["a"] = 1.0;

        QTest::newRow("QColor variant") << QVariant::fromValue(cyan);
        QTest::newRow("string") << QVariant(QStringLiteral("#00d9ff"));
        QTest::newRow("named string") << QVariant(QStringLiteral("cyan"));
        QTest::newRow("rgb channel map") << QVariant(channels);
    }

    void fillPaintsTheColorItWasGiven()
    {
        QFETCH(QVariant, color);
        const QColor wanted = color.metaType().id() == QMetaType::QString
                ? QColor(color.toString()) : QColor("#00d9ff");

        m_map->fillBox(0, 0, 0, 4, 4, 4, dist(color), 0.0f);
        QCOMPARE(m_map->voxel(1, 1, 1), wanted);
    }

    // fillSphere / fillCylinder share prepareColorDistribution, so they share
    // the bug and the fix - assert that rather than assume it.
    void everyFillEntryPointReadsAColorVariant()
    {
        const QColor cyan("#00d9ff");
        const QVariantList d = dist(QVariant::fromValue(cyan));

        m_map->fillSphere(2, 2, 2, 3, d, 0.0f);
        QCOMPARE(m_map->voxel(2, 2, 2), cyan);

        init();
        m_map->fillCylinder(2, 0, 2, 3, 4, d, 0.0f);
        QCOMPARE(m_map->voxel(2, 1, 2), cyan);

        init();
        m_map->fillBox(0, 0, 0, 4, 4, 4, d, 0.0f);
        QCOMPARE(m_map->voxel(2, 2, 2), cyan);
    }

    // A missing weight means "this colour, all of it" rather than a silently
    // dropped entry - the single-colour case is the common one.
    void aMissingWeightMeansAllOfIt()
    {
        const QColor cyan("#00d9ff");
        m_map->fillBox(0, 0, 0, 4, 4, 4, dist(QVariant::fromValue(cyan), QVariant()), 0.0f);
        QCOMPARE(m_map->voxel(1, 1, 1), cyan);
    }

    // Two colours, both placed, and nothing else.
    void aWeightedDistributionUsesOnlyItsOwnColors()
    {
        const QColor pink("#ff3366"), gold("#ffd93d");
        QVariantMap a, b;
        a["color"] = QVariant::fromValue(pink); a["weight"] = 0.5;
        b["color"] = QVariant::fromValue(gold); b["weight"] = 0.5;

        m_map->fillBox(0, 0, 0, 4, 4, 4, QVariantList{a, b}, 0.0f);

        bool seenPink = false, seenGold = false;
        for (int x = 0; x < 4; ++x) {
            for (int y = 0; y < 4; ++y) {
                for (int z = 0; z < 4; ++z) {
                    const QColor got = m_map->voxel(x, y, z);
                    QVERIFY2(got == pink || got == gold,
                             qPrintable(QStringLiteral("stray color %1 at %2,%3,%4")
                                        .arg(got.name()).arg(x).arg(y).arg(z)));
                    seenPink = seenPink || got == pink;
                    seenGold = seenGold || got == gold;
                }
            }
        }
        QVERIFY(seenPink && seenGold);
    }

    // A useless entry is skipped AND said out loud - the silence is what made
    // the original bug so expensive to find.
    void unusableEntriesWarnInsteadOfPaintingWhite_data()
    {
        QTest::addColumn<QVariantList>("distribution");

        QVariantMap noColor; noColor["weight"] = 1.0;
        QVariantMap emptyName; emptyName["color"] = QString(); emptyName["weight"] = 1.0;
        QVariantMap nonsense; nonsense["color"] = QStringLiteral("not-a-color"); nonsense["weight"] = 1.0;
        QVariantMap zeroWeight; zeroWeight["color"] = QStringLiteral("#00d9ff"); zeroWeight["weight"] = 0.0;
        QVariantMap badWeight; badWeight["color"] = QStringLiteral("#00d9ff"); badWeight["weight"] = QStringLiteral("heavy");

        QTest::newRow("no color key") << QVariantList{noColor};
        QTest::newRow("empty color string") << QVariantList{emptyName};
        QTest::newRow("unparseable color") << QVariantList{nonsense};
        QTest::newRow("zero weight") << QVariantList{zeroWeight};
        QTest::newRow("non-numeric weight") << QVariantList{badWeight};
    }

    void unusableEntriesWarnInsteadOfPaintingWhite()
    {
        QFETCH(QVariantList, distribution);

        // Two warnings: the entry, then the distribution left with nothing.
        QTest::ignoreMessage(QtWarningMsg, QRegularExpression("voxel fill:"));
        QTest::ignoreMessage(QtWarningMsg, QRegularExpression("no usable color"));

        m_map->fillBox(0, 0, 0, 4, 4, 4, distribution, 0.0f);
        QCOMPARE(m_map->voxel(1, 1, 1), QColor(Qt::transparent));
        QCOMPARE(m_map->solidCount(), 0);
    }

    // One bad entry must not take the good ones down with it.
    void aBadEntryDoesNotPoisonTheGoodOnes()
    {
        const QColor cyan("#00d9ff");
        QVariantMap bad; bad["color"] = QStringLiteral("not-a-color"); bad["weight"] = 1.0;
        QVariantMap good; good["color"] = QVariant::fromValue(cyan); good["weight"] = 1.0;

        QTest::ignoreMessage(QtWarningMsg, QRegularExpression("voxel fill:"));
        m_map->fillBox(0, 0, 0, 4, 4, 4, QVariantList{bad, good}, 0.0f);
        QCOMPARE(m_map->voxel(1, 1, 1), cyan);
    }

private:
    QScopedPointer<VoxelMapData> m_map;
};

QTEST_GUILESS_MAIN(TstVoxelMapData)
#include "tst_voxelmapdata.moc"
