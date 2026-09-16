// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "audio_devices.h"

// Q_OS_WASM comes from here - the guards below need it before anything else.
#include <QtGlobal>

#ifdef Q_OS_WASM
#include <QCoreApplication>
#include <QMediaDevices>
#endif

namespace clay::sound {

void primeAudioDevices()
{
#ifdef Q_OS_WASM
    static bool primed = false;
    if (primed) return;
    // QMediaDevices needs an application object; without one the probe
    // would be pointless (and the deadlock unreachable anyway).
    if (!QCoreApplication::instance()) return;
    primed = true;

    // Leaked on purpose: the probe must outlive every Sound/Music in the
    // page, and Qt's device singleton lives for the whole process anyway.
    auto *probe = new QMediaDevices;
    // The connection itself is the point - the empty slot never matters.
    // connectNotify() on the platform object is what constructs
    // QWasmMediaDevices, and that populates inputs and outputs alike.
    QObject::connect(probe, &QMediaDevices::audioOutputsChanged, probe, [] {});
#endif
}

} // namespace clay::sound
