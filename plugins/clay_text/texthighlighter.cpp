// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "texthighlighter.h"

#include <QTextCharFormat>
#include <QRegularExpression>
#include <QRegularExpressionMatchIterator>

TextHighlighter::TextHighlighter(QObject *parent):
    QSyntaxHighlighter(parent)
{}

void TextHighlighter::highlightBlock(const QString &text)
{
    QTextCharFormat fmt;
    fmt.setBackground(Qt::yellow);
    fmt.setForeground(Qt::black);

    QRegularExpression expression(search_);
    auto i = expression.globalMatch(text);
    while (i.hasNext())
    {
        auto match = i.next();
        setFormat(match.capturedStart(), match.capturedLength(), fmt);
    }
}

const QString &TextHighlighter::search() const
{
    return search_;
}

void TextHighlighter::setSearch(const QString &newSearch)
{
    if (search_ == newSearch)
        return;
    search_ = newSearch;
    emit searchChanged();
}

QQuickTextDocument* TextHighlighter::quickDocument() const
{
    return document_;
}

void TextHighlighter::setQuickDocument(QQuickTextDocument *newDocument)
{
    if (document_ == newDocument)
        return;
    document_ = newDocument;
    if (document_) {
        setDocument(document_->textDocument());
    }
    emit quickDocumentChanged();
}
