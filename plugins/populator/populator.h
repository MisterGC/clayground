#ifndef POPULATOR_H
#define POPULATOR_H
#include <QObject>
#include <QFileSystemWatcher>
#include <QXmlStreamReader>

class Populator: public QObject
{
    Q_OBJECT

public slots:
    void setPopulationModel(const QString& pathToSvg);

signals:
    void aboutToPopulate(float widthWu, float heightWu, int widthPx, int heightPx);
    void createItemAt(const QString& componentName, float xWu, float yWu, float widthWu, float heightWu, const QString& customInfo);
    void createPoIAt(const QString& componentName, float xWu, float yWu, float radiusWu, const QString& customInfo);
    void populationFinished();

private slots:
    void onSvgChanged(const QString &path);

private:
    void syncWithSvg();
    void processEntity(QXmlStreamReader &reader,
                       QXmlStreamReader::TokenType &token,
                       bool &currentTokenProcessed,
                       const float &heightWu);

private:
    QFileSystemWatcher svgObserver_;
};
#endif
