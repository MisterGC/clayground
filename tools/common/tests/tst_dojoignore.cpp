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

QTEST_MAIN(TestDojoIgnore)
#include "tst_dojoignore.moc"
