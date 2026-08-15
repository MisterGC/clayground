// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <QString>
#include <qqmlregistration.h>

/*!
    \qmltype TextWriter
    \inqmlmodule Clayground.Text
    \brief Writes a whole text file in one call, and says whether it worked.

    The counterpart of \l CsvWriter for content that is not a table - a run
    record, a manifest, an exported scene. QML has no way to write a file, and
    borrowing CsvWriter for it (one column, no quoting) works only until
    CsvWriter learns to quote.

    \c write() returns false and fills \l error on failure. That is the whole
    reason this exists as its own type rather than as another CsvWriter slot:
    a recorder that silently produces no file is worse than one that stops.

    \qml
    import Clayground.Text

    TextWriter { id: w }
    // if (!w.write("run.labrec", text)) console.warn(w.error)
    \endqml
*/
class TextWriter : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString error READ error NOTIFY errorChanged)

public:
    using QObject::QObject;

    const QString& error() const { return m_error; }

public slots:
    /*!
        \qmlmethod bool TextWriter::write(string destination, string text)
        \brief Writes \a text to \a destination as UTF-8, creating parent
        directories. Returns false and sets \l error on failure.
    */
    bool write(const QString& destination, const QString& text);

signals:
    void errorChanged();

private:
    QString m_error;
};
