#ifndef POPULATOR_H
#define POPULATOR_H
#include <QObject>
#include <QFileSystemWatcher>
#include <QXmlStreamReader>

class SvgInspector: public QObject
{
    Q_OBJECT

public slots:
    void setPathToFile(const QString& pathToSvg);

signals:
    void begin(float widthWu, float heightWu, int widthPx, int heightPx);
    void beginGroup(const QString& grpName);
    void rectangle(const QString& componentName, float xWu, float yWu, float widthWu, float heightWu, const QString& description);
    void circle(const QString& componentName, float xWu, float yWu, float radiusWu, const QString& description);
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

private:
    QFileSystemWatcher fileObserver_;
};
#endif
