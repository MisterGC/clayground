// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QSyntaxHighlighter>
#include <qqmlregistration.h>
#include <QQuickTextDocument>

class TextHighlighter : public QSyntaxHighlighter
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString search READ search WRITE setSearch NOTIFY searchChanged)
    Q_PROPERTY(QQuickTextDocument* document READ quickDocument WRITE setQuickDocument NOTIFY quickDocumentChanged)

public:
    TextHighlighter(QObject* parent=nullptr);
    const QString &search() const;
    void setSearch(const QString &newSearch);

    QQuickTextDocument* quickDocument() const;
    void setQuickDocument(QQuickTextDocument *newDocument);

signals:
    void searchChanged();
    void quickDocumentChanged();

protected:
    void highlightBlock(const QString &text);
private:
    QString search_;
    QQuickTextDocument* document_ = nullptr;
};
