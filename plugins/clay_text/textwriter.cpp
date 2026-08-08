// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "textwriter.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>

bool TextWriter::write(const QString& destination, const QString& text)
{
    auto setError = [this](const QString& message) {
        m_error = message;
        emit errorChanged();
        return false;
    };

    if (destination.isEmpty())
        return setError(QStringLiteral("no destination"));

    // A records directory that does not exist yet is the normal case for the
    // first run of a new lab, not an error worth reporting to the author.
    const QFileInfo info(destination);
    const QDir dir = info.absoluteDir();
    if (!dir.exists() && !dir.mkpath(QStringLiteral(".")))
        return setError(QStringLiteral("cannot create %1").arg(dir.absolutePath()));

    QFile file(destination);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return setError(QStringLiteral("cannot write %1: %2")
                            .arg(info.absoluteFilePath(), file.errorString()));

    const QByteArray bytes = text.toUtf8();
    if (file.write(bytes) != bytes.size())
        return setError(QStringLiteral("short write to %1: %2")
                            .arg(info.absoluteFilePath(), file.errorString()));
    file.close();

    if (!m_error.isEmpty()) {
        m_error.clear();
        emit errorChanged();
    }
    return true;
}
