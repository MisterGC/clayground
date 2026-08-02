// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "clayannotations.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonParseError>
#include <QSaveFile>

namespace ClayScene {
namespace Annotations {

QString dir(const QString& crewDir)
{
    return crewDir + QStringLiteral("/annotations");
}

QString indexPath(const QString& crewDir)
{
    return dir(crewDir) + QStringLiteral("/index.json");
}

QString cropRelativePath(const QString& id)
{
    return QStringLiteral("annotations/") + id + QStringLiteral(".png");
}

QString cropAbsolutePath(const QString& crewDir, const QString& relative)
{
    if (relative.isEmpty())
        return {};
    const QFileInfo info(relative);
    if (info.isAbsolute())
        return info.absoluteFilePath();
    return QDir(crewDir).absoluteFilePath(relative);
}

namespace {

// The whole document, so a patch can put back everything it did not touch.
QJsonObject readDocument(const QString& crewDir, bool* existed, QString* error)
{
    if (existed) *existed = false;
    QFile file(indexPath(crewDir));
    if (!file.exists())
        return {};
    if (!file.open(QIODevice::ReadOnly)) {
        if (error) *error = QStringLiteral("cannot read %1").arg(file.fileName());
        return {};
    }
    const QByteArray data = file.readAll();
    file.close();
    if (existed) *existed = true;

    // An empty file is the moment between create and first write on the other
    // side, not a corrupt store.
    if (data.trimmed().isEmpty())
        return {};

    QJsonParseError parseError;
    const auto doc = QJsonDocument::fromJson(data, &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        if (error)
            *error = QStringLiteral("%1 is not valid JSON: %2")
                         .arg(file.fileName(), parseError.errorString());
        return {};
    }
    return doc.object();
}

bool writeDocument(const QString& crewDir, const QJsonObject& doc, QString* error)
{
    QDir parent(dir(crewDir));
    if (!parent.exists() && !parent.mkpath(".")) {
        if (error) *error = QStringLiteral("cannot create %1").arg(parent.path());
        return false;
    }
    QSaveFile file(indexPath(crewDir));
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        if (error) *error = QStringLiteral("cannot open %1").arg(file.fileName());
        return false;
    }
    file.write(QJsonDocument(doc).toJson(QJsonDocument::Indented));
    if (!file.commit()) {
        if (error) *error = QStringLiteral("cannot commit %1").arg(indexPath(crewDir));
        return false;
    }
    return true;
}

} // namespace

QJsonArray load(const QString& crewDir, QString* error)
{
    if (crewDir.isEmpty()) {
        if (error) *error = QStringLiteral("no sandbox dir");
        return {};
    }
    bool existed = false;
    const QJsonObject doc = readDocument(crewDir, &existed, error);
    if (!existed)
        return {};
    return doc.value(QStringLiteral("annotations")).toArray();
}

QJsonArray list(const QString& crewDir, const QString& status,
                int sinceGeneration, int limit, QString* error)
{
    return filter(load(crewDir, error), status, sinceGeneration, limit);
}

QJsonArray filter(const QJsonArray& all, const QString& status,
                  int sinceGeneration, int limit)
{
    QJsonArray out;
    for (const auto& value : all) {
        const QJsonObject entry = value.toObject();
        if (!status.isEmpty() && status.compare(QLatin1String("any"),
                                                Qt::CaseInsensitive) != 0) {
            // An entry the overlay wrote without a status is open: "not yet
            // dealt with" is the only honest default.
            const QString entryStatus =
                entry.value(QStringLiteral("status")).toString(QStringLiteral("open"));
            if (entryStatus.compare(status, Qt::CaseInsensitive) != 0)
                continue;
        }
        if (sinceGeneration >= 0
            && entry.value(QStringLiteral("generation")).toInt(0) < sinceGeneration)
            continue;
        out.append(entry);
        if (limit > 0 && out.size() >= limit)
            break;
    }
    return out;
}

bool patchEntry(const QString& crewDir, const QString& id,
                const QJsonObject& patch, QString* error)
{
    if (crewDir.isEmpty()) {
        if (error) *error = QStringLiteral("no sandbox dir");
        return false;
    }
    if (id.isEmpty()) {
        if (error) *error = QStringLiteral("no annotation id");
        return false;
    }

    bool existed = false;
    QString readError;
    QJsonObject doc = readDocument(crewDir, &existed, &readError);
    if (!readError.isEmpty()) {
        if (error) *error = readError;
        return false;
    }
    if (!existed) {
        if (error)
            *error = QStringLiteral("no annotations yet (%1 does not exist)")
                         .arg(indexPath(crewDir));
        return false;
    }

    QJsonArray annotations = doc.value(QStringLiteral("annotations")).toArray();
    int index = -1;
    for (int i = 0; i < annotations.size(); ++i) {
        if (annotations.at(i).toObject().value(QStringLiteral("id")).toString() == id) {
            index = i;
            break;
        }
    }
    if (index < 0) {
        if (error) *error = QStringLiteral("no annotation '%1'").arg(id);
        return false;
    }

    // Patch, never replace: the overlay may have moved the rect or edited the
    // note between the read that produced this patch and this write.
    QJsonObject entry = annotations.at(index).toObject();
    for (auto it = patch.begin(); it != patch.end(); ++it)
        entry[it.key()] = it.value();
    annotations.replace(index, entry);

    doc[QStringLiteral("annotations")] = annotations;
    if (!doc.contains(QStringLiteral("version")))
        doc[QStringLiteral("version")] = VERSION;
    return writeDocument(crewDir, doc, error);
}

} // namespace Annotations
} // namespace ClayScene
