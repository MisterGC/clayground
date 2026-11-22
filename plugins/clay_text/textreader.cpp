// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "textreader.h"

#include <QFile>
#include <QFileInfo>
#include <QUrl>

QString TextReader::read(const QString& source)
{
    auto setError = [this](const QString& message) {
        m_error = message;
        emit errorChanged();
        return QString();
    };

    if (source.isEmpty())
        return setError(QStringLiteral("no source"));

    const QString path = source.startsWith(QStringLiteral("file:"))
        ? QUrl(source).toLocalFile() : source;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return setError(QStringLiteral("cannot read %1: %2")
                            .arg(QFileInfo(path).absoluteFilePath(), file.errorString()));
    const QString text = QString::fromUtf8(file.readAll());
    file.close();

    if (!m_error.isEmpty()) {
        m_error.clear();
        emit errorChanged();
    }
    return text;
}
