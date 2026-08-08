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

class ClayAnchorResolver;

// The annotation store behind the dojo's annotation surface (issue #182).
//
// Owns <sandboxDir>/.clay/crew/annotations/index.json - the *authoring* half
// of the file. An agent reads the same file and writes back status /
// addressedNote / addressedAt / anchor / crop; those fields are never
// rewritten here. Every save re-reads the file, patches only the fields this
// class owns and commits through QSaveFile, so a concurrent "addressed" mark
// survives a note edit that happens at the same moment.
//
// `anchorRef` is the one field that straddles the line: the anchor belongs to
// the resolver, but where it pointed at the moment the rect was drawn belongs
// to the rect, so it is written and owned here.
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
    // Whether the margin panel is folded away. Lives here rather than in the
    // surface because the surface is rebuilt with every engine, and a panel
    // that unfolds itself on each hot reload is a panel you fight.
    Q_PROPERTY(bool panelCollapsed READ panelCollapsed WRITE setPanelCollapsed NOTIFY panelCollapsedChanged)

public:
    explicit ClayAnnotationStore(QObject* parent = nullptr);

    void setSandboxDir(const QString& dir);
    QString sandboxDir() const { return m_sandboxDir; }

    // What answers "what is this rect about" and "where is that now". Optional:
    // without one the store still records rects and notes, they just cannot
    // follow the scene.
    void setAnchorResolver(ClayAnchorResolver* resolver);

    // The SCENE viewport - the sandbox's own widget, not the dojo window and
    // never the surface's layout. Rects are stored in this space and the
    // fingerprint is taken against it, so a rect framed with the margin panel
    // showing describes the same pixels once the panel is gone.
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

    bool panelCollapsed() const { return m_panelCollapsed; }
    void setPanelCollapsed(bool on);

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

    // Drop every open annotation that carries no note. A click makes a rect on
    // purpose, but a rect nobody wrote on is a stray click, not feedback -
    // persisting it only buries the remarks that mean something. Called when
    // the surface opens (leftovers from a run that ended without one) and when
    // it closes.
    Q_INVOKABLE void dropEmptyNotes();

    // The scene-level note, or an empty string when there is none yet. There
    // is at most one open scene annotation; a new one is only started when the
    // previous one has been addressed.
    Q_INVOKABLE QString sceneNoteId() const;

signals:
    void annotationsChanged();
    void generationChanged();
    void pauseOnOpenChanged();
    void panelCollapsedChanged();

private:
    // Where an annotation is drawn, and whether it may be drawn at all.
    struct Placement
    {
        bool attached = false;
        // True when `rect` came from the anchor rather than from the store -
        // the note followed its object instead of trusting the fingerprint.
        bool reprojected = false;
        QRectF rect;
    };

    QString indexPath() const;
    QJsonArray readFromDisk() const;
    void save();
    // Ask the resolver what this rect is about and let it write anchor + crop,
    // then re-read so the store sees them. No-op without a resolver.
    void attachToScene(const QString& id, const QRectF& rect);
    int indexOf(const QString& id) const;
    QString nextId() const;
    // Where this annotation belongs on screen right now. An anchored one is
    // re-projected and follows its object across a reload, a camera move or a
    // restart; an unanchored one is drawn only while its view fingerprint
    // still describes what is on screen. Everything else lives in the margin
    // list as "detached" - a marker is never drawn over pixels that no longer
    // correspond to it.
    Placement placement(const QJsonObject& a) const;

    ClayAnchorResolver* m_resolver = nullptr;
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
    bool m_panelCollapsed = false;
};
