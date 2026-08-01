// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QImage>
#include <QString>

class QQmlEngine;
class QQuickItem;
class QQuickWindow;

namespace ClayScene {

// What the scene layer needs from whoever hosts a loaded sandbox. The dojo
// hosts it in a QQuickWidget, clayrender in a render-control window, the web
// runtime in a QQuickWindow - none of that is visible from here.
//
// Deliberately Core/Gui/Qml/Quick only: no QtWidgets, so this library also
// builds for WASM and the web runtime can adopt it instead of growing a
// third implementation of the same queries.
class Host
{
public:
    virtual ~Host();

    // The sandbox's root item, or nullptr while nothing is loaded.
    virtual QQuickItem* rootObject() const = 0;

    // Increments on every *successful* load, so a caller can tell whether the
    // scene it is measuring is the one it edited.
    virtual int generation() const = 0;

    // Defaults derive from the root item; override when the host knows better
    // (a render-control host has a window before it has a root, for example).
    virtual QQuickWindow* window() const;
    virtual QQmlEngine* engine() const;

    // Renders the current scene. The default implementation drives
    // QQuickItem::grabToImage and spins a local event loop until it is ready,
    // which is what a live GUI host needs; an offscreen host that renders
    // synchronously should override this. Returns a null image on failure and
    // fills 'error' when given.
    virtual QImage grabImage(int timeoutMs = 3000, QString* error = nullptr) const;
};

} // namespace ClayScene
