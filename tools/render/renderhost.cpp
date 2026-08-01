// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "renderhost.h"

#include <clayscenequery.h>

#include <QCoreApplication>
#include <QDir>
#include <QEventLoop>
#include <QFileInfo>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickRenderControl>
#include <QQuickWindow>
#include <QQuickRenderTarget>
#include <QRegularExpression>
#include <rhi/qrhi.h>
#include <QTimer>
#include <QUrl>

RenderHost::RenderHost() = default;
RenderHost::~RenderHost()
{
    // The root item must go before the window it lives in, and the render
    // control before the RHI it owns.
    delete m_rootObject;
    m_rootObject = nullptr;
    m_rootItem = nullptr;
    m_component.reset();
    m_renderTarget.reset();
    m_renderPass.reset();
    m_depthStencil.reset();
    m_texture.reset();
    if (m_renderControl)
        m_renderControl->invalidate();
    m_window.reset();
    m_renderControl.reset();
    m_engine.reset();
}

QQuickWindow* RenderHost::window() const
{
    return m_window.get();
}

QQmlEngine* RenderHost::engine() const
{
    return m_engine.get();
}

bool RenderHost::load(const QString& sandboxFile, const QSize& size)
{
    QFileInfo fi(sandboxFile);
    if (!fi.exists()) {
        m_errors << QStringLiteral("no such sandbox: %1").arg(sandboxFile);
        return false;
    }

    m_renderControl = std::make_unique<QQuickRenderControl>();
    m_window = std::make_unique<QQuickWindow>(m_renderControl.get());
    m_window->setGeometry(0, 0, size.width(), size.height());
    // Transparent would hide anything the sandbox does not paint; a picture
    // that silently drops the background is exactly the kind of half-truth
    // this tool exists to remove.
    m_window->setColor(Qt::black);

    m_engine = std::make_unique<QQmlEngine>();
    // Resolve plugins relative to the binary, not the current directory -
    // clayrender is meant to be run from anywhere.
    m_engine->addImportPath(QCoreApplication::applicationDirPath() + "/qml");
    m_engine->addImportPath(fi.absolutePath());
    m_engine->setOfflineStoragePath(QDir::homePath() + "/.clayground");

    m_loaderContext = std::make_unique<RenderLoaderContext>(
        fi.absolutePath(), fi.absoluteFilePath());
    m_engine->rootContext()->setContextProperty("ClayLiveLoader",
                                                m_loaderContext.get());

    if (!m_renderControl->initialize()) {
        m_errors << QStringLiteral(
            "cannot initialize the render control - clayrender needs a real "
            "graphics session (it does not work under QT_QPA_PLATFORM=offscreen "
            "or over a bare ssh connection)");
        return false;
    }

    m_size = size;
    if (!createRenderTarget(size))
        return false;

    m_component = std::make_unique<QQmlComponent>(m_engine.get(),
                                                  QUrl::fromLocalFile(fi.absoluteFilePath()));
    if (m_component->isLoading()) {
        QEventLoop loop;
        QObject::connect(m_component.get(), &QQmlComponent::statusChanged,
                         &loop, &QEventLoop::quit);
        loop.exec();
    }
    if (m_component->isError()) {
        for (const auto& e : m_component->errors())
            m_errors << e.toString();
        return false;
    }

    m_rootObject = m_component->create();
    if (!m_rootObject) {
        m_errors << QStringLiteral("sandbox produced no root object");
        for (const auto& e : m_component->errors())
            m_errors << e.toString();
        return false;
    }

    m_rootItem = qobject_cast<QQuickItem*>(m_rootObject);
    if (!m_rootItem) {
        m_errors << QStringLiteral(
            "sandbox root is a %1, not a visual item - clayrender renders "
            "sandboxes, not Window or QtObject roots")
            .arg(QString::fromUtf8(m_rootObject->metaObject()->className()));
        return false;
    }

    m_rootItem->setParentItem(m_window->contentItem());
    // Mirror the dojo's SizeRootObjectToView so a sandbox sees the same
    // geometry it would in the loader.
    m_rootItem->setWidth(size.width());
    m_rootItem->setHeight(size.height());

    m_initialized = true;
    ++m_generation;

    // A first pass so Component.onCompleted work, bindings and the initial
    // scene graph exist before anyone asks a question about them.
    renderFrames(2);
    return true;
}

bool RenderHost::createRenderTarget(const QSize& size)
{
    QRhi* rhi = m_renderControl->rhi();
    if (!rhi) {
        m_errors << QStringLiteral("render control came up without an RHI");
        return false;
    }

    m_texture.reset(rhi->newTexture(QRhiTexture::RGBA8, size, 1,
                                    QRhiTexture::RenderTarget
                                    | QRhiTexture::UsedAsTransferSource));
    if (!m_texture->create()) {
        m_errors << QStringLiteral("cannot create the %1x%2 render texture")
                    .arg(size.width()).arg(size.height());
        return false;
    }

    // Quick3D needs a depth buffer; without one a 3D scene renders as a
    // painter-order mess that looks plausible and is wrong.
    m_depthStencil.reset(rhi->newRenderBuffer(QRhiRenderBuffer::DepthStencil,
                                              size, 1));
    if (!m_depthStencil->create()) {
        m_errors << QStringLiteral("cannot create the depth-stencil buffer");
        return false;
    }

    QRhiTextureRenderTargetDescription desc;
    desc.setColorAttachments({QRhiColorAttachment(m_texture.get())});
    desc.setDepthStencilBuffer(m_depthStencil.get());
    m_renderTarget.reset(rhi->newTextureRenderTarget(desc));
    m_renderPass.reset(m_renderTarget->newCompatibleRenderPassDescriptor());
    m_renderTarget->setRenderPassDescriptor(m_renderPass.get());
    if (!m_renderTarget->create()) {
        m_errors << QStringLiteral("cannot create the texture render target");
        return false;
    }

    m_window->setRenderTarget(
        QQuickRenderTarget::fromRhiRenderTarget(m_renderTarget.get()));
    return true;
}

bool RenderHost::applyAssignment(const QString& assignment, QString* error)
{
    if (!m_rootItem) {
        if (error) *error = QStringLiteral("nothing loaded");
        return false;
    }

    int eq = assignment.indexOf('=');
    if (eq <= 0) {
        if (error) *error = QStringLiteral("expected <path>=<value>, got '%1'")
                            .arg(assignment);
        return false;
    }

    const QString path = assignment.left(eq).trimmed();
    const QString rawValue = assignment.mid(eq + 1).trimmed();

    // A bare word is meant as a string ("--set title=hello"); anything that is
    // valid JSON keeps its type. This is the only place clayrender guesses,
    // and quoting explicitly always wins.
    static const QRegularExpression jsonish(
        R"(^(true|false|null|-?\d+(\.\d+)?([eE][-+]?\d+)?|".*"|'.*'|\[.*\]|\{.*\})$)");
    const QString value = jsonish.match(rawValue).hasMatch()
                          ? rawValue : ClayScene::jsStringLiteral(rawValue);

    const QString expression = QString("%1 = %2").arg(path, value);
    if (!ClayScene::callVoid(m_rootItem, expression)) {
        if (error) *error = QStringLiteral("assignment failed: %1").arg(expression);
        return false;
    }
    return true;
}

void RenderHost::renderFrames(int count)
{
    if (!m_initialized)
        return;

    for (int i = 0; i < count; ++i) {
        // Let timers, animations and QML events run between frames, otherwise
        // every frame renders the same instant.
        QEventLoop loop;
        QTimer::singleShot(16, &loop, &QEventLoop::quit);
        loop.exec();

        m_renderControl->polishItems();
        m_renderControl->beginFrame();
        m_renderControl->sync();
        m_renderControl->render();
        m_renderControl->endFrame();
    }
}

QImage RenderHost::grabImage(int timeoutMs, QString* error) const
{
    Q_UNUSED(timeoutMs)

    if (!m_initialized || !m_renderControl) {
        if (error) *error = QStringLiteral("nothing loaded");
        return {};
    }

    // Render one frame and read the texture back. Synchronous: no event loop,
    // no waiting for a compositor, which is the whole point of being stateless.
    QRhi* rhi = m_renderControl->rhi();
    auto* self = const_cast<RenderHost*>(this);

    self->m_renderControl->polishItems();
    self->m_renderControl->beginFrame();
    self->m_renderControl->sync();
    self->m_renderControl->render();

    QRhiReadbackResult readback;
    QRhiResourceUpdateBatch* batch = rhi->nextResourceUpdateBatch();
    batch->readBackTexture(QRhiReadbackDescription(m_texture.get()), &readback);
    self->m_renderControl->commandBuffer()->resourceUpdate(batch);
    self->m_renderControl->endFrame();
    rhi->finish();

    if (readback.data.isEmpty()) {
        if (error) *error = QStringLiteral("render produced no image");
        return {};
    }

    QImage image(reinterpret_cast<const uchar*>(readback.data.constData()),
                 readback.pixelSize.width(), readback.pixelSize.height(),
                 QImage::Format_RGBA8888_Premultiplied);
    // The readback aliases a temporary buffer, and the backends disagree on
    // which way up a framebuffer is.
    image = rhi->isYUpInFramebuffer() ? image.mirrored() : image.copy();
    return image.convertToFormat(QImage::Format_ARGB32);
}
