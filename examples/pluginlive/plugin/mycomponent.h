// (c) Clayground Contributors - zlib license, see "LICENSE" file
#pragma once

#include <QObject>
#include <qqmlregistration.h>

class MyComponent: public QObject
{
    Q_OBJECT
    QML_ELEMENT

public slots:
    QString sayHello();
    QString sayBye();
};
