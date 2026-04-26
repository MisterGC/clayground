// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "dojoignore.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTextStream>

bool DojoIgnore::load(const QString &ignoreFile, const QString &rootDir)
{
    clear();
    rootDir_ = QFileInfo(rootDir).absoluteFilePath();

    QFile f(ignoreFile);
    if (!f.exists() || !f.open(QIODevice::ReadOnly | QIODevice::Text))
        return false;

    QTextStream in(&f);
    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        if (line.isEmpty() || line.startsWith('#'))
            continue;
        rules_.append({ compile(line) });
    }
    return true;
}

void DojoIgnore::clear()
{
    rootDir_.clear();
    rules_.clear();
}

bool DojoIgnore::matches(const QString &absPath) const
{
    if (rules_.isEmpty() || rootDir_.isEmpty())
        return false;

    const QString abs = QFileInfo(absPath).absoluteFilePath();
    const QString rel = QDir(rootDir_).relativeFilePath(abs);

    // Paths outside the root never match.
    if (rel.startsWith(QLatin1String("..")))
        return false;

    for (const auto &rule : rules_) {
        if (rule.re.match(rel).hasMatch())
            return true;
    }
    return false;
}

QRegularExpression DojoIgnore::compile(const QString &rawPattern)
{
    QString p = rawPattern;
    const bool dirOnly = p.endsWith('/');
    if (dirOnly) p.chop(1);

    bool rooted = false;
    if (p.startsWith('/')) {
        rooted = true;
        p = p.mid(1);
    } else if (p.contains('/')) {
        // Any pattern containing a slash is treated as root-anchored
        // (like gitignore).
        rooted = true;
    }

    QString regex;
    regex.reserve(p.size() * 2 + 8);
    for (int i = 0; i < p.size(); ++i) {
        const QChar c = p[i];
        if (c == '*') {
            if (i + 1 < p.size() && p[i + 1] == '*') {
                regex += QStringLiteral(".*");
                ++i;
            } else {
                regex += QStringLiteral("[^/]*");
            }
        } else if (c == '?') {
            regex += QStringLiteral("[^/]");
        } else {
            const QString esc = QRegularExpression::escape(QString(c));
            regex += esc;
        }
    }

    QString anchored;
    if (rooted)
        anchored = QStringLiteral("^") + regex;
    else
        anchored = QStringLiteral("(?:^|.*/)") + regex;

    // For directory-only rules, match the directory entry itself or
    // anything beneath it.
    if (dirOnly)
        anchored += QStringLiteral("(?:/.*)?$");
    else
        anchored += QStringLiteral("(?:/.*)?$");

    return QRegularExpression(anchored);
}
