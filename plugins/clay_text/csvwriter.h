// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <qqmlregistration.h>
#include <QStringList>
#include <csv.hpp>
#include <iostream>

class CsvWriter : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString destination READ destination WRITE setDestination NOTIFY destinationChanged)
    Q_PROPERTY(QString delimiter READ delimiter WRITE setDelimiter NOTIFY delimiterChanged)

public:
    const QString &destination() const;
    void setDestination(const QString &newDestination);

    const QString &delimiter() const;
    void setDelimiter(const QString &newDelimiter);

public slots:
    void begin(const QStringList& header);
    void appendRow(const QStringList& row);
    void finish();

signals:
    void destinationChanged();

    void delimiterChanged();

private:
    QString destination_;
    QString content_;
    QString delimiter_ = ",";
};
