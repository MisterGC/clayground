// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QObject>
#include <QRectF>
#include <QSet>
#include <QSize>
#include <QString>
#include <QVariantList>

// The annotation store behind the dojo's annotation surface (issue #182).
//
// Owns <sandboxDir>/.clay/crew/annotations/index.json - the *authoring* half
// of the file. An agent reads the same file and writes back status /
// addressedNote / addressedAt / anchor / crop; those fields are never
// rewritten here. Every save re-reads the file, patches only the fields this
// class owns and commits through QSaveFile, so a concurrent "addressed" mark
// survives a note edit that happens at the same moment.
//
// The path matters: the dojo watches the whole sandbox tree and skips only
// .clay/, so everything written here has to stay under .clay/ or every
// keystroke would trigger a hot reload.
class ClayAnnotationStore : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList annotations READ annotations NOTIFY annotationsChanged)
    Q_PROPERTY(int openCount READ openCount NOTIFY annotationsChanged)
    Q_PROPERTY(int generation READ generation NOTIFY generationChanged)
    Q_PROPERTY(bool pauseOnOpen READ pauseOnOpen WRITE setPauseOnOpen NOTIFY pauseOnOpenChanged)

public:
    explicit ClayAnnotationStore(QObject* parent = nullptr);

    void setSandboxDir(const QString& dir);
    QString sandboxDir() const { return m_sandboxDir; }

    // The viewport the surface is drawn over. Part of every annotation's view
    // fingerprint, so a resized window detaches what it can no longer place.
    void setViewSize(const QSize& size);
    QSize viewSize() const { return m_viewSize; }

    // Counts *successful* loads, mirroring ClayInspector's generation (both
    // are driven from HotReloadContainer::loadSucceeded).
    int generation() const { return m_generation; }
    void bumpGeneration();

    QVariantList annotations() const;
    int openCount() const;

    bool pauseOnOpen() const { return m_pauseOnOpen; }
    void setPauseOnOpen(bool on);

    // Re-read the file. Called when the sandbox dir is set and whenever the
    // surface opens, so an agent's "addressed" marks show up.
    Q_INVOKABLE void reload();

    // Returns the new annotation's id. scope is "scene" or "region";
    // for "scene" the rect is ignored and stored as null.
    Q_INVOKABLE QString addAnnotation(const QString& scope, const QRectF& rect,
                                      const QString& note, bool paused);
    Q_INVOKABLE void setNote(const QString& id, const QString& note);
    Q_INVOKABLE void setRect(const QString& id, const QRectF& rect);
    Q_INVOKABLE void removeAnnotation(const QString& id);
    Q_INVOKABLE void clearAddressed();
    Q_INVOKABLE void wipeAll();

    // The scene-level note, or an empty string when there is none yet. There
    // is at most one open scene annotation; a new one is only started when the
    // previous one has been addressed.
    Q_INVOKABLE QString sceneNoteId() const;

signals:
    void annotationsChanged();
    void generationChanged();
    void pauseOnOpenChanged();

private:
    QString indexPath() const;
    QJsonArray readFromDisk() const;
    void save();
    int indexOf(const QString& id) const;
    QString nextId() const;
    // An annotation is drawn over the scene only while its view fingerprint
    // still describes what is on screen. Everything else lives in the margin
    // list as "detached" - a marker is never drawn over pixels that no longer
    // correspond to it.
    bool isAttached(const QJsonObject& a) const;

    QString m_sandboxDir;
    QJsonArray m_annotations;
    // Ids created by this process. A note from an earlier run cannot claim to
    // match the current view no matter what its fingerprint says - the scene
    // was built from scratch since.
    QSet<QString> m_sessionIds;
    // Ids this process deleted, so a merge-on-write never resurrects them.
    QSet<QString> m_deleted;
    QSize m_viewSize;
    int m_generation = 0;
    bool m_pauseOnOpen = true;
};
