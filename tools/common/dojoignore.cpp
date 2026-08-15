// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "dojoignore.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTextStream>

const QStringList &DojoIgnore::defaultPatterns()
{
    // Editor, OS and tool noise only. Nothing here may collide with a name
    // that can legitimately be source or an asset (.qml, .js, .svg, images,
    // shaders, audio, .json) — those must keep triggering a reload.
    static const QStringList kPatterns = {
        QStringLiteral("*~"),          // emacs/gedit/kate backup
        QStringLiteral(".#*"),         // emacs lock file
        QStringLiteral("#*#"),         // emacs auto-save
        QStringLiteral("*.swp"),       // vim swap
        QStringLiteral("*.swo"),
        QStringLiteral("*.swx"),
        QStringLiteral("4913"),        // vim's writability probe file
        QStringLiteral(".DS_Store"),   // macOS finder metadata
        QStringLiteral("Thumbs.db"),   // windows explorer metadata
        QStringLiteral("*.tmp"),
        QStringLiteral("*.temp"),
        QStringLiteral("*.bak"),
        QStringLiteral("*.orig"),      // merge leftovers
        QStringLiteral("*.rej"),       // rejected patch hunks
        QStringLiteral("__pycache__/"),
        QStringLiteral("*.pyc"),
        QStringLiteral(".git/")
    };
    return kPatterns;
}

DojoIgnore::DojoIgnore()
{
    for (const auto &p : defaultPatterns())
        defaultRules_.append(compileRule(p));
}

bool DojoIgnore::load(const QString &ignoreFile, const QString &rootDir)
{
    userRules_.clear();
    rootDir_ = QFileInfo(rootDir).absoluteFilePath();

    QFile f(ignoreFile);
    if (!f.exists() || !f.open(QIODevice::ReadOnly | QIODevice::Text))
        return false;

    QTextStream in(&f);
    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        if (line.isEmpty() || line.startsWith('#'))
            continue;
        userRules_.append(compileRule(line));
    }
    return true;
}

void DojoIgnore::clear()
{
    rootDir_.clear();
    userRules_.clear();
}

DojoIgnore::Decision DojoIgnore::decide(const QString &absPath) const
{
    const QString abs = QFileInfo(absPath).absoluteFilePath();

    // Without a root the user rules (which are root-anchored) cannot be
    // evaluated, but the defaults still apply — they are basename rules,
    // so the absolute path is a fine subject for them.
    QString rel = abs;
    const bool haveRoot = !rootDir_.isEmpty();
    if (haveRoot) {
        rel = QDir(rootDir_).relativeFilePath(abs);
        // Paths outside the root never match.
        if (rel.startsWith(QLatin1String("..")))
            return Decision::NotIgnored;
    }

    // Last matching rule wins (gitignore semantics), defaults first so a
    // user rule - including a negation - can always override them.
    auto decision = Decision::NotIgnored;
    for (const auto &rule : defaultRules_) {
        if (rule.re.match(rel).hasMatch())
            decision = rule.negate ? Decision::NotIgnored : Decision::IgnoredByDefault;
    }
    if (haveRoot) {
        for (const auto &rule : userRules_) {
            if (rule.re.match(rel).hasMatch())
                decision = rule.negate ? Decision::NotIgnored : Decision::IgnoredByUserRule;
        }
    }
    return decision;
}

DojoIgnore::Rule DojoIgnore::compileRule(const QString &rawLine)
{
    QString p = rawLine;
    bool negate = false;
    if (p.startsWith('!')) {
        negate = true;
        p = p.mid(1);
    } else if (p.startsWith(QLatin1String("\\!"))) {
        // Escaped literal '!' at the start of a name.
        p = p.mid(1);
    }
    return { compile(p), negate };
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
