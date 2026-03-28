// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Minimal stub for HotReloadContainer used in unit tests.
// Only provides rootObject() which returns nullptr.

#include "hotreloadcontainer.h"
#include <QResizeEvent>

HotReloadContainer::HotReloadContainer(QWidget* parent)
    : QWidget(parent)
    , m_loadingLabel(nullptr)
    , m_currentEffect(nullptr)
    , m_nextEffect(nullptr)
    , m_loadingEffect(nullptr)
    , m_isReloading(false)
{}
HotReloadContainer::~HotReloadContainer() {}
QQuickItem* HotReloadContainer::rootObject() const { return nullptr; }
QQmlEngine* HotReloadContainer::engine() const { return nullptr; }
QQmlContext* HotReloadContainer::rootContext() const { return nullptr; }
void HotReloadContainer::setSource(const QUrl&) {}
void HotReloadContainer::hotReload() {}
void HotReloadContainer::resizeEvent(QResizeEvent*) {}
void HotReloadContainer::onFadeOutFinished() {}
void HotReloadContainer::onFadeInFinished() {}
void HotReloadContainer::onQuickWidgetStatusChanged(QQuickWidget::Status) {}
void HotReloadContainer::startFadeOut() {}
void HotReloadContainer::showLoadingScreen() {}
void HotReloadContainer::hideLoadingScreen() {}
void HotReloadContainer::startFadeIn() {}
void HotReloadContainer::createNewEngine() {}
void HotReloadContainer::destroyCurrentEngine() {}
void HotReloadContainer::setupQuickWidget(QQuickWidget*) {}

#include "moc_hotreloadcontainer.cpp"
