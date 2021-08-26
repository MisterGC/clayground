// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#ifndef MYCOMPONENT_H
#define MYCOMPONENT_H
#include <QObject>
#include <QString>

class MyComponent: public QObject
{
    Q_OBJECT

public:
    MyComponent();

public slots:
    QString sayHello() const;
    QString sayBye() const;
};
#endif
