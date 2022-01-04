// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file
#pragma once

#include <QObject>
#include <qqmlregistration.h>
//#include <QtQuick>

class MyComponent: public QObject
{
    Q_OBJECT
    QML_ELEMENT

public slots:
    QString sayHello();
    QString sayBye();
};
