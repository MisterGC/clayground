#ifndef CLAYIOSBRIDGEWRAPPER_H
#define CLAYIOSBRIDGEWRAPPER_H

#include <QObject>

class ClayIosBridgeWrapper : public QObject
{
    Q_OBJECT
public:
    explicit ClayIosBridgeWrapper(QObject *parent = nullptr);
    virtual ~ClayIosBridgeWrapper();

    Q_INVOKABLE void requestReview();

signals:
};

#endif // CLAYIOSBRIDGEWRAPPER_H
