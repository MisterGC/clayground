// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "benchcsvwriter.h"
#include <QUrl>
#include <QDir>
#include <QFileInfo>

BenchCsvWriter::BenchCsvWriter(QObject *parent)
    : QObject(parent)
{
}

BenchCsvWriter::~BenchCsvWriter()
{
    close();
}

bool BenchCsvWriter::open(const QString &path)
{
    close();

    // Accept both file:// URLs and plain paths.
    QString localPath = path;
    if (localPath.startsWith("file:"))
        localPath = QUrl(localPath).toLocalFile();

    QDir dir = QFileInfo(localPath).absoluteDir();
    if (!dir.exists())
        dir.mkpath(".");

    m_file.setFileName(localPath);
    if (!m_file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text))
        return false;

    m_stream.setDevice(&m_file);
    return true;
}

void BenchCsvWriter::writeLine(const QString &line)
{
    if (!m_file.isOpen())
        return;
    m_stream << line << '\n';
}

void BenchCsvWriter::flush()
{
    if (!m_file.isOpen())
        return;
    m_stream.flush();
    m_file.flush();
}

void BenchCsvWriter::close()
{
    if (!m_file.isOpen())
        return;
    m_stream.flush();
    m_stream.setDevice(nullptr);
    m_file.close();
}

bool BenchCsvWriter::isOpen() const
{
    return m_file.isOpen();
}
