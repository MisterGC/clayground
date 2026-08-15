// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "dojoignore.h"

#include <QtTest/QtTest>
#include <QDir>
#include <QFile>
#include <QTemporaryDir>

class TestDojoIgnore : public QObject
{
    Q_OBJECT

private slots:
    void noFileGivesNoRules();
    void emptyAndCommentLinesAreSkipped();
    void basenameMatchesAnywhere();
    void extensionGlobMatchesAnywhere();
    void trailingSlashMatchesDirAndContents();
    void relativePathIsRootAnchored();
    void pathsOutsideRootDoNotMatch();
    void doubleStarMatchesAnyDepth();
    void leadingSlashIsRootAnchored();
    void defaultsMatchWithoutIgnoreFile();
    void defaultsApplyWithoutRootDir();
    void defaultsApplyAlongsideUserRules();
    void negationUnIgnoresADefault();
    void negationUnIgnoresAUserRule();
    void sourcesAndAssetsAreNeverIgnored();
    void defaultNoiseOutsideRootDoesNotMatch();

private:
    QString write(QTemporaryDir &dir, const QString &relPath, const QByteArray &content);
};

QString TestDojoIgnore::write(QTemporaryDir &dir, const QString &relPath, const QByteArray &content)
{
    const QString abs = dir.filePath(relPath);
    QFileInfo fi(abs);
    QDir().mkpath(fi.absolutePath());
    QFile f(abs);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return {};
    f.write(content);
    f.close();
    return abs;
}

void TestDojoIgnore::noFileGivesNoRules()
{
    QTemporaryDir dir;
    DojoIgnore ig;
    QVERIFY(!ig.load(dir.filePath(".dojoignore"), dir.path()));
    QCOMPARE(ig.ruleCount(), 0);
    QVERIFY(!ig.matches(dir.filePath("Sandbox.qml")));
}

void TestDojoIgnore::emptyAndCommentLinesAreSkipped()
{
    QTemporaryDir dir;
    const QString ignoreFile = write(dir, ".dojoignore",
        "\n# a comment\n   \n# another\n");
    DojoIgnore ig;
    QVERIFY(ig.load(ignoreFile, dir.path()));
    QCOMPARE(ig.ruleCount(), 0);
}

void TestDojoIgnore::basenameMatchesAnywhere()
{
    QTemporaryDir dir;
    const QString ignoreFile = write(dir, ".dojoignore", "notes.txt\n");
    DojoIgnore ig;
    QVERIFY(ig.load(ignoreFile, dir.path()));
    QVERIFY(ig.matches(dir.filePath("notes.txt")));
    QVERIFY(ig.matches(dir.filePath("sub/notes.txt")));
    QVERIFY(ig.matches(dir.filePath("a/b/notes.txt")));
    QVERIFY(!ig.matches(dir.filePath("other.txt")));
}

void TestDojoIgnore::extensionGlobMatchesAnywhere()
{
    QTemporaryDir dir;
    const QString ignoreFile = write(dir, ".dojoignore", "*.song.json\n");
    DojoIgnore ig;
    QVERIFY(ig.load(ignoreFile, dir.path()));
    QVERIFY(ig.matches(dir.filePath("demo.song.json")));
    QVERIFY(ig.matches(dir.filePath("songs/demo.song.json")));
    QVERIFY(ig.matches(dir.filePath("a/b/c.song.json")));
    QVERIFY(!ig.matches(dir.filePath("demo.json")));
    QVERIFY(!ig.matches(dir.filePath("demo.song")));
}

void TestDojoIgnore::trailingSlashMatchesDirAndContents()
{
    QTemporaryDir dir;
    const QString ignoreFile = write(dir, ".dojoignore", "songs/\n");
    DojoIgnore ig;
    QVERIFY(ig.load(ignoreFile, dir.path()));
    QVERIFY(ig.matches(dir.filePath("songs")));
    QVERIFY(ig.matches(dir.filePath("songs/demo.json")));
    QVERIFY(ig.matches(dir.filePath("songs/sub/deep.json")));
    QVERIFY(!ig.matches(dir.filePath("other/demo.json")));
}

void TestDojoIgnore::relativePathIsRootAnchored()
{
    QTemporaryDir dir;
    const QString ignoreFile = write(dir, ".dojoignore", "songs/demo.song.json\n");
    DojoIgnore ig;
    QVERIFY(ig.load(ignoreFile, dir.path()));
    QVERIFY(ig.matches(dir.filePath("songs/demo.song.json")));
    QVERIFY(!ig.matches(dir.filePath("nested/songs/demo.song.json")));
}

void TestDojoIgnore::pathsOutsideRootDoNotMatch()
{
    QTemporaryDir root;
    QTemporaryDir elsewhere;
    const QString ignoreFile = write(root, ".dojoignore", "*.json\n");
    DojoIgnore ig;
    QVERIFY(ig.load(ignoreFile, root.path()));
    QVERIFY(!ig.matches(elsewhere.filePath("foo.json")));
}

void TestDojoIgnore::doubleStarMatchesAnyDepth()
{
    QTemporaryDir dir;
    const QString ignoreFile = write(dir, ".dojoignore", "data/**/*.bin\n");
    DojoIgnore ig;
    QVERIFY(ig.load(ignoreFile, dir.path()));
    QVERIFY(ig.matches(dir.filePath("data/a.bin")) ||
            ig.matches(dir.filePath("data/x/a.bin")));
    QVERIFY(ig.matches(dir.filePath("data/x/y/a.bin")));
    QVERIFY(!ig.matches(dir.filePath("other/a.bin")));
}

void TestDojoIgnore::leadingSlashIsRootAnchored()
{
    QTemporaryDir dir;
    const QString ignoreFile = write(dir, ".dojoignore", "/demo.txt\n");
    DojoIgnore ig;
    QVERIFY(ig.load(ignoreFile, dir.path()));
    QVERIFY(ig.matches(dir.filePath("demo.txt")));
    QVERIFY(!ig.matches(dir.filePath("sub/demo.txt")));
}

void TestDojoIgnore::defaultsMatchWithoutIgnoreFile()
{
    QTemporaryDir dir;
    DojoIgnore ig;
    // No .dojoignore at all - the built-in rules must still be armed.
    QVERIFY(!ig.load(dir.filePath(".dojoignore"), dir.path()));
    QCOMPARE(ig.ruleCount(), 0);
    QVERIFY(ig.defaultRuleCount() > 0);

    const QStringList noise = {
        "Sandbox.qml~", "sub/Sandbox.qml~",
        ".#Sandbox.qml", "#Sandbox.qml#",
        ".Sandbox.qml.swp", ".Sandbox.qml.swo", ".Sandbox.qml.swx",
        "4913", ".DS_Store", "sub/.DS_Store", "Thumbs.db",
        "capture.tmp", "capture.temp", "Sandbox.qml.bak",
        "Sandbox.qml.orig", "Sandbox.qml.rej",
        "__pycache__", "__pycache__/tool.pyc", "tools/helper.pyc",
        ".git", ".git/index", ".git/refs/heads/main"
    };
    for (const auto &n : noise) {
        QVERIFY2(ig.matches(dir.filePath(n)), qPrintable(n));
        QCOMPARE(ig.decide(dir.filePath(n)), DojoIgnore::Decision::IgnoredByDefault);
    }
}

void TestDojoIgnore::defaultsApplyWithoutRootDir()
{
    // A DojoIgnore whose root was never set (or was cleared) still filters
    // noise - matches() must not fall into an "empty rules" shortcut.
    DojoIgnore fresh;
    QVERIFY(fresh.rootDir().isEmpty());
    QVERIFY(fresh.matches("/somewhere/sandbox/.DS_Store"));
    QVERIFY(fresh.matches("/somewhere/sandbox/Sandbox.qml~"));
    QVERIFY(!fresh.matches("/somewhere/sandbox/Sandbox.qml"));

    QTemporaryDir dir;
    DojoIgnore ig;
    write(dir, ".dojoignore", "notes.txt\n");
    QVERIFY(ig.load(dir.filePath(".dojoignore"), dir.path()));
    ig.clear();
    QCOMPARE(ig.ruleCount(), 0);
    QVERIFY(ig.rootDir().isEmpty());
    QVERIFY(ig.matches(dir.filePath("Sandbox.qml.swp")));
    QVERIFY(!ig.matches(dir.filePath("notes.txt")));
}

void TestDojoIgnore::defaultsApplyAlongsideUserRules()
{
    QTemporaryDir dir;
    const QString ignoreFile = write(dir, ".dojoignore", "notes.txt\nsongs/\n");
    DojoIgnore ig;
    QVERIFY(ig.load(ignoreFile, dir.path()));
    QCOMPARE(ig.ruleCount(), 2);

    // User rules work ...
    QCOMPARE(ig.decide(dir.filePath("notes.txt")), DojoIgnore::Decision::IgnoredByUserRule);
    QCOMPARE(ig.decide(dir.filePath("songs/demo.json")), DojoIgnore::Decision::IgnoredByUserRule);
    // ... and the defaults are not replaced by them.
    QCOMPARE(ig.decide(dir.filePath(".DS_Store")), DojoIgnore::Decision::IgnoredByDefault);
    QCOMPARE(ig.decide(dir.filePath("Sandbox.qml~")), DojoIgnore::Decision::IgnoredByDefault);
    QCOMPARE(ig.decide(dir.filePath("Sandbox.qml")), DojoIgnore::Decision::NotIgnored);
}

void TestDojoIgnore::negationUnIgnoresADefault()
{
    QTemporaryDir dir;
    const QString ignoreFile = write(dir, ".dojoignore", "!*.bak\n");
    DojoIgnore ig;
    QVERIFY(ig.load(ignoreFile, dir.path()));
    QCOMPARE(ig.ruleCount(), 1);
    // Opted back in ...
    QCOMPARE(ig.decide(dir.filePath("level.bak")), DojoIgnore::Decision::NotIgnored);
    QCOMPARE(ig.decide(dir.filePath("sub/level.bak")), DojoIgnore::Decision::NotIgnored);
    // ... while the remaining defaults stay in force.
    QCOMPARE(ig.decide(dir.filePath("level.tmp")), DojoIgnore::Decision::IgnoredByDefault);
    QCOMPARE(ig.decide(dir.filePath(".DS_Store")), DojoIgnore::Decision::IgnoredByDefault);
}

void TestDojoIgnore::negationUnIgnoresAUserRule()
{
    QTemporaryDir dir;
    // Last match wins: *.json is ignored, except keep.json.
    const QString ignoreFile = write(dir, ".dojoignore", "*.json\n!keep.json\n");
    DojoIgnore ig;
    QVERIFY(ig.load(ignoreFile, dir.path()));
    QCOMPARE(ig.decide(dir.filePath("data.json")), DojoIgnore::Decision::IgnoredByUserRule);
    QCOMPARE(ig.decide(dir.filePath("sub/data.json")), DojoIgnore::Decision::IgnoredByUserRule);
    QCOMPARE(ig.decide(dir.filePath("keep.json")), DojoIgnore::Decision::NotIgnored);
    QCOMPARE(ig.decide(dir.filePath("sub/keep.json")), DojoIgnore::Decision::NotIgnored);
}

void TestDojoIgnore::sourcesAndAssetsAreNeverIgnored()
{
    const QStringList assets = {
        "Sandbox.qml", "sub/Main.qml", "logic.js", "map.svg",
        "sprite.png", "photo.jpg", "level.json", "toon.frag",
        "toon.vert", "shader.glsl", "jump.wav", "theme.mp3", "theme.ogg"
    };

    QTemporaryDir noFile;
    DojoIgnore bare;
    QVERIFY(!bare.load(noFile.filePath(".dojoignore"), noFile.path()));
    for (const auto &a : assets)
        QVERIFY2(!bare.matches(noFile.filePath(a)), qPrintable(a));

    QTemporaryDir dir;
    const QString ignoreFile = write(dir, ".dojoignore", "notes.txt\n");
    DojoIgnore ig;
    QVERIFY(ig.load(ignoreFile, dir.path()));
    for (const auto &a : assets)
        QVERIFY2(!ig.matches(dir.filePath(a)), qPrintable(a));
}

void TestDojoIgnore::defaultNoiseOutsideRootDoesNotMatch()
{
    QTemporaryDir root;
    QTemporaryDir elsewhere;
    DojoIgnore ig;
    QVERIFY(!ig.load(root.filePath(".dojoignore"), root.path()));
    QVERIFY(ig.matches(root.filePath(".DS_Store")));
    QVERIFY(!ig.matches(elsewhere.filePath(".DS_Store")));
    QVERIFY(!ig.matches(elsewhere.filePath("Sandbox.qml~")));

    // Same with user rules loaded.
    const QString ignoreFile = write(root, ".dojoignore", "*.json\n");
    QVERIFY(ig.load(ignoreFile, root.path()));
    QVERIFY(!ig.matches(elsewhere.filePath("foo.json")));
    QVERIFY(!ig.matches(elsewhere.filePath(".DS_Store")));
}

QTEST_MAIN(TestDojoIgnore)
#include "tst_dojoignore.moc"
