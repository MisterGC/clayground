// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QWidget>
#include <QQuickWidget>
#include <QQmlEngine>
#include <QPropertyAnimation>
#include <QGraphicsOpacityEffect>
#include <QGraphicsEffect>
#include <QLabel>
#include <QUrl>
#include <memory>

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
    
    void hotReload();
    
signals:
    void sourceChanged();
    void engineAboutToBeDestroyed();
    void engineCreated();
    void loadingStarted();
    void loadingFinished();
    
protected:
    void resizeEvent(QResizeEvent *event) override;
    
private slots:
    void onFadeOutFinished();
    void onFadeInFinished();
    void onQuickWidgetStatusChanged(QQuickWidget::Status status);
    
private:
    void startFadeOut();
    void showLoadingScreen();
    void hideLoadingScreen();
    void startFadeIn();
    void createNewEngine();
    void destroyCurrentEngine();
    void setupQuickWidget(QQuickWidget* widget);
    
private:
    QUrl m_source;
    std::unique_ptr<QQuickWidget> m_currentWidget;
    std::unique_ptr<QQuickWidget> m_nextWidget;
    std::unique_ptr<QQmlEngine> m_engine;
    
    QLabel* m_loadingLabel;
    QGraphicsEffect* m_currentEffect;
    QGraphicsEffect* m_nextEffect;
    QGraphicsOpacityEffect* m_loadingEffect;
    
    bool m_isReloading;
};