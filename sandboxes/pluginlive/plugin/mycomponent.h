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
};
#endif
