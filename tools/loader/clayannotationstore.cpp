// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "clayannotationstore.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonValue>
#include <QSaveFile>
#include <QSettings>
#include <QVariantMap>

namespace {

constexpr int STORE_VERSION = 1;

// Fields the agent side owns. They are read from disk on every save and put
// back untouched - a note edit must never undo a mark made a moment ago.
const char* const AGENT_FIELDS[] = {
    "status", "addressedNote", "addressedAt", "anchor", "crop"
};

QJsonArray rectToJson(const QRectF& r)
{
    QJsonArray a;
    a.append(qRound(r.x()));
    a.append(qRound(r.y()));
    a.append(qRound(r.width()));
    a.append(qRound(r.height()));
    return a;
}

} // namespace

ClayAnnotationStore::ClayAnnotationStore(QObject* parent)
    : QObject(parent)
{
    QSettings settings("Clayground", "LiveLoader");
    m_pauseOnOpen = settings.value("annotations/pauseOnOpen", true).toBool();
}

void ClayAnnotationStore::setSandboxDir(const QString& dir)
{
    if (dir == m_sandboxDir)
        return;
    m_sandboxDir = dir;
    m_sessionIds.clear();
    m_deleted.clear();
    reload();
}

void ClayAnnotationStore::setViewSize(const QSize& size)
{
    if (size == m_viewSize)
        return;
    m_viewSize = size;
    emit annotationsChanged();
}

void ClayAnnotationStore::bumpGeneration()
{
    ++m_generation;
    emit generationChanged();
    // Attachment is generation-scoped, so the list changes meaning even though
    // no annotation did.
    emit annotationsChanged();
}

void ClayAnnotationStore::setPauseOnOpen(bool on)
{
    if (on == m_pauseOnOpen)
        return;
    m_pauseOnOpen = on;
    QSettings settings("Clayground", "LiveLoader");
    settings.setValue("annotations/pauseOnOpen", on);
    emit pauseOnOpenChanged();
}

QString ClayAnnotationStore::indexPath() const
{
    if (m_sandboxDir.isEmpty())
        return {};
    return m_sandboxDir + "/.clay/crew/annotations/index.json";
}

QJsonArray ClayAnnotationStore::readFromDisk() const
{
    const QString path = indexPath();
    if (path.isEmpty())
        return {};
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    QJsonParseError err;
    const auto doc = QJsonDocument::fromJson(file.readAll(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning() << "ClayAnnotationStore: cannot parse" << path
                   << err.errorString();
        return {};
    }
    return doc.object().value("annotations").toArray();
}

void ClayAnnotationStore::reload()
{
    m_annotations = readFromDisk();
    emit annotationsChanged();
}

int ClayAnnotationStore::indexOf(const QString& id) const
{
    for (int i = 0; i < m_annotations.size(); ++i) {
        if (m_annotations.at(i).toObject().value("id").toString() == id)
            return i;
    }
    return -1;
}

QString ClayAnnotationStore::nextId() const
{
    // Monotonic per sandbox and stable across restarts: the highest number
    // ever used on disk wins, so a cleared-then-reused id can never make an
    // agent's older reference point at a different note.
    int highest = 0;
    const QJsonArray disk = readFromDisk();
    auto scan = [&highest](const QJsonArray& arr) {
        for (const QJsonValue& v : arr) {
            const QString id = v.toObject().value("id").toString();
            if (id.size() > 1 && id.at(0) == QLatin1Char('a')) {
                bool ok = false;
                const int n = QStringView(id).mid(1).toInt(&ok);
                if (ok)
                    highest = qMax(highest, n);
            }
        }
    };
    scan(disk);
    scan(m_annotations);
    return QStringLiteral("a%1").arg(highest + 1);
}

bool ClayAnnotationStore::isAttached(const QJsonObject& a) const
{
    if (a.value("scope").toString() != QLatin1String("region"))
        return false;

    // --- RE-PROJECTION SEAM (issue #182, agent side) -----------------------
    // Once anchors land, a non-null anchor means the annotation follows its
    // object: resolve the anchor to viewport pixels here and return true, and
    // have the caller use that rect instead of the stored one. Until then a
    // filled anchor is treated like none, which only ever detaches - it never
    // draws a marker over pixels that may have moved.
    // -----------------------------------------------------------------------

    // No anchor: the fingerprint has to still describe what is on screen.
    if (!m_sessionIds.contains(a.value("id").toString()))
        return false;
    if (a.value("generation").toInt() != m_generation)
        return false;
    const QJsonArray size = a.value("view").toObject().value("size").toArray();
    if (size.size() != 2)
        return false;
    return size.at(0).toInt() == m_viewSize.width()
        && size.at(1).toInt() == m_viewSize.height();
}

QVariantList ClayAnnotationStore::annotations() const
{
    QVariantList out;
    for (const QJsonValue& v : m_annotations) {
        const QJsonObject a = v.toObject();
        QVariantMap m;
        m["id"] = a.value("id").toString();
        m["scope"] = a.value("scope").toString();
        m["note"] = a.value("note").toString();
        m["created"] = a.value("created").toString();
        m["generation"] = a.value("generation").toInt();
        m["status"] = a.value("status").toString(QStringLiteral("open"));
        m["addressedNote"] = a.value("addressedNote").toString();
        m["addressedAt"] = a.value("addressedAt").toString();
        m["hasAnchor"] = !a.value("anchor").isNull()
                      && !a.value("anchor").isUndefined();
        const QJsonArray r = a.value("rect").toArray();
        const bool hasRect = r.size() == 4;
        m["hasRect"] = hasRect;
        m["rectX"] = hasRect ? r.at(0).toDouble() : 0.0;
        m["rectY"] = hasRect ? r.at(1).toDouble() : 0.0;
        m["rectW"] = hasRect ? r.at(2).toDouble() : 0.0;
        m["rectH"] = hasRect ? r.at(3).toDouble() : 0.0;
        m["attached"] = isAttached(a);
        out.append(m);
    }
    return out;
}

int ClayAnnotationStore::openCount() const
{
    int n = 0;
    for (const QJsonValue& v : m_annotations) {
        if (v.toObject().value("status").toString(QStringLiteral("open"))
            == QLatin1String("open"))
            ++n;
    }
    return n;
}

QString ClayAnnotationStore::sceneNoteId() const
{
    for (const QJsonValue& v : m_annotations) {
        const QJsonObject a = v.toObject();
        if (a.value("scope").toString() == QLatin1String("scene")
            && a.value("status").toString(QStringLiteral("open"))
               == QLatin1String("open"))
            return a.value("id").toString();
    }
    return {};
}

QString ClayAnnotationStore::addAnnotation(const QString& scope,
                                           const QRectF& rect,
                                           const QString& note, bool paused)
{
    if (m_sandboxDir.isEmpty()) {
        qWarning() << "ClayAnnotationStore: no sandbox dir, annotation dropped";
        return {};
    }
    const QString id = nextId();

    QJsonObject view;
    QJsonArray size;
    size.append(m_viewSize.width());
    size.append(m_viewSize.height());
    view["size"] = size;
    // Camera state is the agent side's to fill - it is the half of the
    // fingerprint only a scene query can produce.
    view["camera"] = QJsonValue::Null;
    view["paused"] = paused;

    QJsonObject a;
    a["id"] = id;
    a["created"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    a["generation"] = m_generation;
    a["scope"] = scope;
    a["rect"] = scope == QLatin1String("scene") ? QJsonValue(QJsonValue::Null)
                                                : QJsonValue(rectToJson(rect));
    a["note"] = note;
    a["status"] = QStringLiteral("open");
    a["addressedNote"] = QJsonValue::Null;
    a["addressedAt"] = QJsonValue::Null;
    a["crop"] = QJsonValue::Null;
    a["view"] = view;
    a["anchor"] = QJsonValue::Null;

    m_annotations.append(a);
    m_sessionIds.insert(id);
    m_deleted.remove(id);
    save();
    emit annotationsChanged();
    return id;
}

void ClayAnnotationStore::setNote(const QString& id, const QString& note)
{
    const int i = indexOf(id);
    if (i < 0)
        return;
    QJsonObject a = m_annotations.at(i).toObject();
    if (a.value("note").toString() == note)
        return;
    a["note"] = note;
    m_annotations.replace(i, a);
    save();
    emit annotationsChanged();
}

void ClayAnnotationStore::setRect(const QString& id, const QRectF& rect)
{
    const int i = indexOf(id);
    if (i < 0)
        return;
    QJsonObject a = m_annotations.at(i).toObject();
    if (a.value("scope").toString() == QLatin1String("scene"))
        return;
    const QJsonArray next = rectToJson(rect);
    if (a.value("rect").toArray() == next)
        return;
    a["rect"] = next;
    // Moving or resizing re-frames the annotation against what is on screen
    // right now, so the fingerprint is re-taken with it.
    QJsonObject view = a.value("view").toObject();
    QJsonArray size;
    size.append(m_viewSize.width());
    size.append(m_viewSize.height());
    view["size"] = size;
    a["view"] = view;
    a["generation"] = m_generation;
    m_annotations.replace(i, a);
    m_sessionIds.insert(id);
    save();
    emit annotationsChanged();
}

void ClayAnnotationStore::removeAnnotation(const QString& id)
{
    const int i = indexOf(id);
    if (i < 0)
        return;
    m_annotations.removeAt(i);
    m_deleted.insert(id);
    m_sessionIds.remove(id);
    save();
    emit annotationsChanged();
}

void ClayAnnotationStore::clearAddressed()
{
    QJsonArray kept;
    for (const QJsonValue& v : m_annotations) {
        const QJsonObject a = v.toObject();
        if (a.value("status").toString(QStringLiteral("open"))
            == QLatin1String("open"))
            kept.append(a);
        else
            m_deleted.insert(a.value("id").toString());
    }
    if (kept.size() == m_annotations.size())
        return;
    m_annotations = kept;
    save();
    emit annotationsChanged();
}

void ClayAnnotationStore::wipeAll()
{
    for (const QJsonValue& v : m_annotations)
        m_deleted.insert(v.toObject().value("id").toString());
    // Anything an agent added between our last read and now goes too - "wipe
    // all" that leaves something behind is worse than one that overreaches.
    for (const QJsonValue& v : readFromDisk())
        m_deleted.insert(v.toObject().value("id").toString());
    m_annotations = QJsonArray();
    save();
    emit annotationsChanged();
}

void ClayAnnotationStore::save()
{
    const QString path = indexPath();
    if (path.isEmpty())
        return;

    QDir().mkpath(QFileInfo(path).absolutePath());

    // Merge: the file on disk is the base, this process patches only what it
    // owns. An agent that marked something addressed a millisecond ago keeps
    // that mark.
    QJsonArray disk = readFromDisk();
    QJsonArray merged;
    QSet<QString> written;

    for (const QJsonValue& mineVal : m_annotations) {
        const QJsonObject mine = mineVal.toObject();
        const QString id = mine.value("id").toString();
        QJsonObject out = mine;
        for (const QJsonValue& diskVal : disk) {
            const QJsonObject onDisk = diskVal.toObject();
            if (onDisk.value("id").toString() != id)
                continue;
            for (const char* field : AGENT_FIELDS) {
                if (onDisk.contains(QLatin1String(field)))
                    out[QLatin1String(field)] = onDisk.value(field);
            }
            break;
        }
        merged.append(out);
        written.insert(id);
    }

    // Entries that appeared on disk since the last read and were never
    // deleted here survive - dropping them would lose an agent's work.
    for (const QJsonValue& diskVal : disk) {
        const QJsonObject onDisk = diskVal.toObject();
        const QString id = onDisk.value("id").toString();
        if (written.contains(id) || m_deleted.contains(id))
            continue;
        merged.append(onDisk);
    }

    QJsonObject root;
    root["version"] = STORE_VERSION;
    root["annotations"] = merged;

    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        qWarning() << "ClayAnnotationStore: cannot open" << path << "for write";
        return;
    }
    file.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    if (!file.commit())
        qWarning() << "ClayAnnotationStore: failed to commit" << path;

    m_annotations = merged;
}
