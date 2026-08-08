// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QWidget>
#include <QQuickWidget>
#include <QQmlEngine>
#include <QPropertyAnimation>
#include <QGraphicsOpacityEffect>
#include <QGraphicsEffect>
#include <QLabel>
#include <QStringList>
#include <QUrl>
#include <memory>

// Hosts the live sandbox and swaps it on every hot reload.
//
// A reload never touches the running scene until the replacement has proven
// itself: the new QML is loaded into a *candidate* engine and widget that is
// off the layout and invisible. Only a candidate that reaches
// QQuickWidget::Ready is promoted; a candidate that fails is dropped and the
// previous scene keeps running and rendering (issue #170). The price is two
// engines alive for the duration of a load.
class HotReloadContainer : public QWidget
{
    Q_OBJECT

public:
    explicit HotReloadContainer(QWidget *parent = nullptr);
    ~HotReloadContainer();

    void setSource(const QUrl& url);
    QUrl source() const { return m_source; }

    QQmlEngine* engine() const;
    QQmlContext* rootContext() const;
    QQuickItem* rootObject() const;

    void hotReload();

signals:
    void sourceChanged();
    // A candidate engine exists and is about to parse the sandbox. Everything
    // the QML needs at load time (context properties, import paths) has to be
    // installed here — the engine may never become current.
    void engineAboutToLoad(QQmlEngine* engine);
    // The current engine is being torn down; anything attached to it (the
    // overlays) must go first. Never emitted for a discarded candidate.
    void engineAboutToBeDestroyed();
    // A new engine has become the current one.
    void engineCreated();
    void loadingStarted();
    void loadingFinished();
    void loadSucceeded();
    void loadFailed(const QStringList& errorLines);

protected:
    void resizeEvent(QResizeEvent *event) override;

private slots:
    void finishLoad();
    void onFadeInFinished();
    void onQuickWidgetStatusChanged(QQuickWidget::Status status);

private:
    void showLoadingScreen();
    void hideLoadingScreen();
    void startFadeIn();
    void createCandidate();
    void promoteCandidate();
    void discardCandidate();
    void scheduleLoadCompletion();
    void setupQuickWidget(QQuickWidget* widget);

private:
    QUrl m_source;
    std::unique_ptr<QQuickWidget> m_currentWidget;
    std::unique_ptr<QQuickWidget> m_nextWidget;
    std::unique_ptr<QQmlEngine> m_engine;
    std::unique_ptr<QQmlEngine> m_nextEngine;

    QLabel* m_loadingLabel;
    QGraphicsEffect* m_currentEffect;
    QGraphicsEffect* m_nextEffect;
    QGraphicsOpacityEffect* m_loadingEffect;

    bool m_isReloading;
    bool m_candidateOk = false;
    bool m_completionScheduled = false;
    QStringList m_pendingErrors;
};
