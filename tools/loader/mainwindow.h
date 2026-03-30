// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QMainWindow>
#include <QUrl>

class HotReloadContainer;
class ClayLiveLoader;
class ClayInspector;
class QQuickWidget;
class QLabel;

class MainWindow : public QMainWindow
{
    Q_OBJECT
    
public:
    explicit MainWindow(ClayLiveLoader* loader, QWidget *parent = nullptr);
    ~MainWindow();

    ClayInspector* inspector() const { return m_inspector; }
    
protected:
    void keyPressEvent(QKeyEvent *event) override;
    void closeEvent(QCloseEvent *event) override;
    void moveEvent(QMoveEvent *event) override;
    void resizeEvent(QResizeEvent *event) override;
    
private slots:
    void onSandboxUrlChanged();
    void onRestarted();
    void toggleLogOverlay();
    void toggleGuideOverlay();
    void startFlag();
    void onFlagReady(const QString& screenshotPath);
    void onFlagConfirmed(const QString& annotation);
    void onFlagCancelled();
    void restartSandbox(int index);
    void saveWindowGeometry();
    void restoreWindowGeometry();

private:
    void setupShortcuts();
    void createOverlays();
    void showSandboxName();
    void showAltMessage();

private:
    ClayLiveLoader* m_liveLoader = nullptr;
    HotReloadContainer* m_container = nullptr;
    ClayInspector* m_inspector = nullptr;
    QQuickWidget* m_logOverlay = nullptr;
    QQuickWidget* m_guideOverlay = nullptr;
    QQuickWidget* m_flagOverlay = nullptr;

    QLabel* m_traceIndicator = nullptr;

    bool m_logVisible = false;
    bool m_guideVisible = false;
    bool m_flagActive = false;
};