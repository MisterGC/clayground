// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <qqmlregistration.h>
#include <QStringList>

class CsvReader : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(QString delimiter READ delimiter WRITE setDelimiter NOTIFY delimiterChanged)
    Q_PROPERTY(QString quote READ quote WRITE setQuote NOTIFY quoteChanged)

public:
    const QString &source() const;
    void setSource(const QString &newSource);

    const QString &delimiter() const;
    void setDelimiter(const QString &newDelimiter);

    const QString &quote() const;
    void setQuote(const QString &newQuote);

public slots:
    void load();

signals:
    void sourceChanged();
    void columnNames(QStringList names);
    void row(QStringList values);
    void theEnd();

    void delimiterChanged();

    void quoteChanged();

private:
    QString source_;
    QString delimiter_ = ",";
    QString quote_ = "\"";
};
