// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// DojoIgnore — gitignore-style filter for the dojo file watcher.
//
// A built-in set of default rules (see defaultPatterns()) is ALWAYS active,
// even when the sandbox has no .dojoignore at all. It covers editor, OS and
// tool noise (swap files, backups, .DS_Store, __pycache__, ...) so that such
// writes never restart a running scene. Source and asset extensions are
// deliberately not part of it — changing those should reload.
//
// Syntax (one pattern per line, blank lines and lines starting with '#'
// are ignored):
//   name          matches any file/dir named "name" anywhere under the root
//   name/         matches any directory "name" and everything beneath it
//   *.ext         basename wildcard (matches in any sub-directory)
//   sub/file.txt  path-anchored to the root
//   /file.txt     path-anchored to the root (leading slash is optional)
//   **            matches any number of path segments
//   !name         negation — un-ignores what an earlier rule ignored
//
// Glob specials: '*' matches anything except '/', '?' matches one non-'/'
// character, '**' matches anything including '/'.
//
// Rules are evaluated in order — the built-in defaults first, then the
// patterns from .dojoignore — and the LAST matching rule decides (gitignore
// semantics). So "!*.bak" in a .dojoignore brings back a default-ignored
// name, while a later plain rule can ignore it again. A leading '!' can be
// escaped as "\!" to match a file whose name really starts with '!'.

#pragma once

#include <QRegularExpression>
#include <QString>
#include <QStringList>
#include <QVector>

class DojoIgnore
{
public:
    // Why a path is ignored — lets callers name the responsible rule set.
    enum class Decision
    {
        NotIgnored,
        IgnoredByDefault,
        IgnoredByUserRule
    };

    DojoIgnore();

    // Load patterns from `ignoreFile`. `rootDir` is the directory the
    // patterns are evaluated against (absolute paths are converted to
    // relative before matching). Missing ignore file -> no user patterns
    // loaded; returns false. An empty/comment-only file returns true
    // with no user rules. The built-in defaults are (re-)installed either
    // way, and `rootDir` is remembered either way.
    bool load(const QString &ignoreFile, const QString &rootDir);

    // Drop the user rules and the root dir. The built-in defaults stay
    // active — they still match, using the path as given.
    void clear();

    // True if `absPath` is ignored.
    bool matches(const QString &absPath) const { return decide(absPath) != Decision::NotIgnored; }

    // Ignore decision including which rule set had the last word.
    Decision decide(const QString &absPath) const;

    // Number of user rules loaded from .dojoignore (defaults excluded).
    int ruleCount() const { return userRules_.size(); }
    // Number of always-on built-in rules.
    int defaultRuleCount() const { return defaultRules_.size(); }
    const QString &rootDir() const { return rootDir_; }

    // The built-in default patterns, in evaluation order.
    static const QStringList &defaultPatterns();

private:
    struct Rule
    {
        QRegularExpression re;
        bool negate = false;
    };

    static Rule compileRule(const QString &rawLine);
    static QRegularExpression compile(const QString &rawPattern);

    QString rootDir_;
    QVector<Rule> defaultRules_;
    QVector<Rule> userRules_;
};
