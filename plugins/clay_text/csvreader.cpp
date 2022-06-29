// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "csvreader.h"
#include <csv.hpp>
#include <QDebug>

const QString &CsvReader::source() const
{
    return source_;
}

void CsvReader::setSource(const QString &newSource)
{
    if (source_ == newSource)
        return;
    source_ = newSource;
    emit sourceChanged();
}

void CsvReader::load()
{
    csv::CSVFormat format;
    format.delimiter(delimiter().front().toLatin1());
    format.quote(quote().front().toLatin1());
    csv::CSVReader reader(source_.toStdString(),format);

    auto colNames = reader.get_col_names();
    QStringList vals;

    for (auto const& n: colNames) vals << QString::fromStdString(n);
    emit columnNames(vals);

    for (auto const& r: reader) {
        vals.clear();
        for (auto & field: r) { vals << QString::fromStdString(field.get<>()); }
        emit row(vals);
    }
}

const QString &CsvReader::delimiter() const
{
    return delimiter_;
}

void CsvReader::setDelimiter(const QString &newDelimiter)
{
    if (delimiter_ == newDelimiter || newDelimiter.isEmpty())
        return;
    delimiter_ = newDelimiter;
    emit delimiterChanged();
}

const QString &CsvReader::quote() const
{
    return quote_;
}

void CsvReader::setQuote(const QString &newQuote)
{
    if (quote_ == newQuote || newQuote.isEmpty())
        return;
    quote_ = newQuote;
    emit quoteChanged();
}
