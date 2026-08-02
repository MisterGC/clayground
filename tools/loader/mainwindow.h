// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QMainWindow>
#include <QUrl>

class HotReloadContainer;
class ClayLiveLoader;
class ClayInspector;
class ClayAnnotationStore;
class ClayTimeControl;
class ClayInputControl;
class QQmlEngine;
class QQuickWidget;
class QLabel;
class QShortcut;

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
    // Installs everything a sandbox needs at load time (context properties,
    // import paths). Runs for the initial engine and for every reload
    // candidate, before it parses any QML.
    void configureEngine(QQmlEngine* engine);
    void onSandboxUrlChanged();
    void onRestarted();
    void toggleLogOverlay();
    void toggleGuideOverlay();
    // The annotation surface (issue #182). Ctrl+F used to flag a moment on the
    // spot; that instant note is now the surface's scene-level slot, and the
    // shortcut toggles the whole surface in and out.
    void toggleAnnotationOverlay();
    void showAnnotationOverlay();
    void hideAnnotationOverlay();
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
    ClayAnnotationStore* m_annotations = nullptr;
    ClayTimeControl* m_timeCtrl = nullptr;
    ClayInputControl* m_inputCtrl = nullptr;
    QQuickWidget* m_logOverlay = nullptr;
    QQuickWidget* m_guideOverlay = nullptr;
    QQuickWidget* m_flagOverlay = nullptr;
    QQuickWidget* m_annotationOverlay = nullptr;

    QLabel* m_traceIndicator = nullptr;
    // Tab, live only while the surface is up - a sandbox that uses Tab keeps
    // it the rest of the time.
    QShortcut* m_panelShortcut = nullptr;

    bool m_logVisible = false;
    bool m_guideVisible = false;
    bool m_flagActive = false;
    bool m_annotationVisible = false;
    // True while the pause under the surface is ours to undo. A scene the user
    // paused before opening the surface stays paused when it closes.
    bool m_annotationPaused = false;
};