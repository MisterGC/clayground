#ifndef POPULATOR_H
#define POPULATOR_H
#include <QObject>
#include <QFileSystemWatcher>
#include <QXmlStreamReader>

class SvgInspector: public QObject
{
    Q_OBJECT

public:
    SvgInspector();

public slots:
    void setSource(const QString& pathToSvg);
    QString source() const;

signals:
    void sourceChanged();
    void begin(float widthWu, float heightWu, int widthPx, int heightPx);
    void beginGroup(const QString& grpName);
    void rectangle(const QString& componentName, float x, float y, float width, float height, const QString& description);
    void circle(const QString& componentName, float x, float y, float radius, const QString& description);
    void endGroup();
    void end();

private slots:
    void onFileChanged(const QString &path);

private:
    void introspect();
    void processShape(QXmlStreamReader &reader,
                       QXmlStreamReader::TokenType &token,
                       bool &currentTokenProcessed,
                       const float &heightWu);
    void resetFileObservation();

private:
    QFileSystemWatcher fileObserver_;
    QString source_;
};
#endif
