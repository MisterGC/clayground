// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "clayplatform.h"

#ifdef Q_OS_WASM
#include <emscripten.h>
#endif

ClayPlatform::ClayPlatform(QObject *parent)
    : QObject(parent)
{
    detectPlatform();
}

void ClayPlatform::detectPlatform()
{
    // Detect operating system using Qt's compile-time macros
#if defined(Q_OS_WIN)
    os_ = OS_Windows;
#elif defined(Q_OS_MACOS)
    os_ = OS_MacOS;
#elif defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
    os_ = OS_Linux;
#elif defined(Q_OS_ANDROID)
    os_ = OS_Android;
#elif defined(Q_OS_IOS)
    os_ = OS_iOS;
#elif defined(Q_OS_TVOS)
    os_ = OS_tvOS;
#elif defined(Q_OS_VISIONOS)
    os_ = OS_visionOS;
#elif defined(Q_OS_QNX)
    os_ = OS_QNX;
#elif defined(Q_OS_WASM)
    os_ = OS_WebAssembly;
#elif defined(Q_OS_UNIX)
    os_ = OS_Unix;
#else
    os_ = OS_Unknown;
#endif

    // Detect browser (only relevant for WebAssembly)
#ifdef Q_OS_WASM
    // Get browser from navigator.userAgent via JavaScript
    int browserCode = EM_ASM_INT({
        var ua = navigator.userAgent || '';
        // Order matters: Edge contains "Chrome", Safari contains "Safari"
        if (ua.indexOf('Edg/') !== -1) return 4;      // Edge
        if (ua.indexOf('OPR/') !== -1) return 5;      // Opera
        if (ua.indexOf('Firefox/') !== -1) return 2;  // Firefox
        if (ua.indexOf('Chrome/') !== -1) return 1;   // Chrome
        if (ua.indexOf('Safari/') !== -1) return 3;   // Safari
        return 6;                                      // Other
    });

    switch (browserCode) {
        case 1: browser_ = Browser_Chrome; break;
        case 2: browser_ = Browser_Firefox; break;
        case 3: browser_ = Browser_Safari; break;
        case 4: browser_ = Browser_Edge; break;
        case 5: browser_ = Browser_Opera; break;
        case 6: browser_ = Browser_Other; break;
        default: browser_ = Browser_Other; break;
    }
#else
    browser_ = Browser_None;
#endif
}

QString ClayPlatform::gpuStatus() const
{
#ifdef Q_OS_WASM
    bool hasWebGPU = EM_ASM_INT({
        return typeof navigator !== 'undefined' && navigator.gpu ? 1 : 0;
    }) == 1;
    return hasWebGPU ? QStringLiteral("full") : QStringLiteral("unavailable");
#else
    return QStringLiteral("unknown");
#endif
}

QString ClayPlatform::gpuHint() const
{
#ifdef Q_OS_WASM
    if (gpuStatus() == QStringLiteral("unavailable"))
        return tr("WebGPU not available. AI inference will be slower.");
    return QString();
#else
    return tr("GPU detection not yet implemented for this platform.");
#endif
}
