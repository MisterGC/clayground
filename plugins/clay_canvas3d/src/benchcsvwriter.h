// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <QString>
#include <QFile>
#include <QTextStream>
#include <QtQml/qqmlregistration.h>

// Minimal file sink for BenchLogger: QML cannot write files, so this dumb
// helper just opens/appends/closes a QFile via a QTextStream. No formatting
// logic lives here — BenchLogger.qml builds the CSV rows.
class BenchCsvWriter : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(BenchCsvWriter)

public:
    explicit BenchCsvWriter(QObject *parent = nullptr);
    ~BenchCsvWriter() override;

    // Open path for writing (truncates). Returns true on success.
    Q_INVOKABLE bool open(const QString &path);
    // Append one raw line (a trailing newline is added).
    Q_INVOKABLE void writeLine(const QString &line);
    // Flush pending bytes to disk without closing.
    Q_INVOKABLE void flush();
    // Flush and close the underlying file.
    Q_INVOKABLE void close();
    // True while a file is open for writing.
    Q_INVOKABLE bool isOpen() const;

private:
    QFile m_file;
    QTextStream m_stream;
};
