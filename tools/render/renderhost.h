// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <clayscenehost.h>

#include <QObject>
#include <QSize>
#include <QString>
#include <QStringList>
#include <memory>

class QQmlComponent;
class QQmlEngine;
class QQuickItem;
class QQuickRenderControl;
class QQuickWindow;
class QRhiRenderBuffer;
class QRhiRenderPassDescriptor;
class QRhiTexture;
class QRhiTextureRenderTarget;

// The context object a sandbox expects to find under the name ClayLiveLoader.
// Clayground.runsInSandbox is literally "typeof ClayLiveLoader != 'undefined'"
// and ClayWorldBase resolves its scene through ClayLiveLoader.sandboxDir, so a
// renderer that omits this loads worlds and labs differently from the dojo -
// which would make every picture it produces a lie.
class RenderLoaderContext : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString sandboxDir READ sandboxDir CONSTANT)
    Q_PROPERTY(QString sandboxFile READ sandboxFile CONSTANT)
    Q_PROPERTY(int numRestarts READ numRestarts CONSTANT)

public:
    RenderLoaderContext(const QString& sandboxDir, const QString& sandboxFile,
                        QObject* parent = nullptr)
        : QObject(parent), m_sandboxDir(sandboxDir), m_sandboxFile(sandboxFile) {}

    QString sandboxDir() const { return m_sandboxDir; }
    QString sandboxFile() const { return m_sandboxFile; }
    int numRestarts() const { return 0; }

private:
    QString m_sandboxDir;
    QString m_sandboxFile;
};

// Loads one sandbox into an offscreen QQuickWindow driven by
// QQuickRenderControl, so rendering goes through the real RHI (Metal/Vulkan/
// D3D) without a visible window. The QT_QPA_PLATFORM=offscreen route is NOT
// equivalent - it produces blank View3D content because there is no GPU
// surface - so this needs a graphics session, and says so in --help.
class RenderHost : public ClayScene::Host
{
public:
    RenderHost();
    ~RenderHost() override;

    // Loads the sandbox and renders the first frames. Returns false and fills
    // errors() when the QML fails to load or the render stack cannot start.
    bool load(const QString& sandboxFile, const QSize& size);

    // Applies "<expression>=<value>" assignments in the root's own context, so
    // ids, dotted paths and JS values all work. Returns false on the first
    // failure - a picture of a state you did not reach is worse than an error.
    bool applyAssignment(const QString& assignment, QString* error);

    // Renders n additional frames, giving animations and lazily-built scene
    // graph nodes a chance to appear.
    void renderFrames(int count);

    QQuickItem* rootObject() const override { return m_rootItem; }
    int generation() const override { return m_generation; }
    QQuickWindow* window() const override;
    QQmlEngine* engine() const override;
    QImage grabImage(int timeoutMs = 3000, QString* error = nullptr) const override;

    QStringList errors() const { return m_errors; }

private:
    // A render control has no swapchain, so it needs an explicit target: we
    // render into an RHI texture and read it back. This is the only route
    // that gives real GPU rendering without a visible window.
    bool createRenderTarget(const QSize& size);

    std::unique_ptr<QQuickRenderControl> m_renderControl;
    std::unique_ptr<QQuickWindow> m_window;
    std::unique_ptr<QRhiTexture> m_texture;
    std::unique_ptr<QRhiRenderBuffer> m_depthStencil;
    std::unique_ptr<QRhiTextureRenderTarget> m_renderTarget;
    std::unique_ptr<QRhiRenderPassDescriptor> m_renderPass;
    QSize m_size;
    std::unique_ptr<QQmlEngine> m_engine;
    std::unique_ptr<QQmlComponent> m_component;
    std::unique_ptr<RenderLoaderContext> m_loaderContext;
    QObject* m_rootObject = nullptr;
    QQuickItem* m_rootItem = nullptr;
    int m_generation = 0;
    QStringList m_errors;
    bool m_initialized = false;
};
