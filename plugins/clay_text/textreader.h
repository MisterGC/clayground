// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <QString>
#include <qqmlregistration.h>

/*!
    \qmltype TextReader
    \inqmlmodule Clayground.Text
    \brief Reads a whole text file in one call, and says whether it worked.

    The counterpart of \l TextWriter: what one process wrote - a lab snapshot,
    a manifest - another reads back. QML can only read a local file through
    XMLHttpRequest, which Qt refuses unless \c QML_XHR_ALLOW_FILE_READ is set
    in the environment, so a lab could write a file it could not load again.

    \c read() returns the text, or an empty string with \l error filled on
    failure - an empty file and a missing one are told apart by \l error.

    \qml
    import Clayground.Text

    TextReader { id: r }
    // const text = r.read("run.snap.json"); if (r.error) console.warn(r.error)
    \endqml
*/
class TextReader : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString error READ error NOTIFY errorChanged)

public:
    using QObject::QObject;

    const QString& error() const { return m_error; }

public slots:
    /*!
        \qmlmethod string TextReader::read(string source)
        \brief Returns the content of \a source, read as UTF-8. Returns an
        empty string and sets \l error on failure; a \c file:// URL is
        accepted as well as a path.
    */
    QString read(const QString& source);

signals:
    void errorChanged();

private:
    QString m_error;
};
