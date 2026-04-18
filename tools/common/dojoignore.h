// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// DojoIgnore — gitignore-style filter for the dojo file watcher.
//
// Syntax (one pattern per line, blank lines and lines starting with '#'
// are ignored):
//   name          matches any file/dir named "name" anywhere under the root
//   name/         matches any directory "name" and everything beneath it
//   *.ext         basename wildcard (matches in any sub-directory)
//   sub/file.txt  path-anchored to the root
//   /file.txt     path-anchored to the root (leading slash is optional)
//   **            matches any number of path segments
//
// Glob specials: '*' matches anything except '/', '?' matches one non-'/'
// character, '**' matches anything including '/'.

#pragma once

#include <QRegularExpression>
#include <QString>
#include <QVector>

class DojoIgnore
{
public:
    // Load patterns from `ignoreFile`. `rootDir` is the directory the
    // patterns are evaluated against (absolute paths are converted to
    // relative before matching). Missing ignore file -> no patterns
    // loaded; returns false. An empty/comment-only file returns true
    // with no rules.
    bool load(const QString &ignoreFile, const QString &rootDir);

    // Clear all rules and the root dir.
    void clear();

    // True if `absPath` matches any rule.
    bool matches(const QString &absPath) const;

    int ruleCount() const { return rules_.size(); }
    const QString &rootDir() const { return rootDir_; }

private:
    struct Rule
    {
        QRegularExpression re;
    };

    static QRegularExpression compile(const QString &rawPattern);

    QString rootDir_;
    QVector<Rule> rules_;
};
