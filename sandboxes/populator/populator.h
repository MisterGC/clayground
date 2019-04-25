#ifndef POPULATOR_H
#define POPULATOR_H
#include <QObject>

class Populator: public QObject
{
    Q_OBJECT

public slots:
    void loadSvgPopulationModel(const QString& pathToSvg);
signals:
    void createItemAt(const QString& componentName, int x, int y);
};
#endif
