// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "csvwriter.h"
#include <QFile>
#include <QTextStream>

const QString &CsvWriter::destination() const
{
    return destination_;
}

void CsvWriter::setDestination(const QString &newDestination)
{
    if (destination_ == newDestination)
        return;
    destination_ = newDestination;
    emit destinationChanged();
}

void CsvWriter::begin(const QStringList &header)
{
    content_ = header.join(delimiter_);
}

void CsvWriter::appendRow(const QStringList &row)
{
    content_ += ("\n" + row.join(delimiter_));
}

void CsvWriter::finish()
{
    QFile file(destination_);
    if(!file.open(QIODevice::WriteOnly|QIODevice::Text)) return;
    QTextStream out(&file);
    out << content_;
}

const QString &CsvWriter::delimiter() const
{
    return delimiter_;
}

void CsvWriter::setDelimiter(const QString &newDelimiter)
{
    if (delimiter_ == newDelimiter || newDelimiter.isEmpty())
        return;
    delimiter_ = newDelimiter;
    emit delimiterChanged();
}
