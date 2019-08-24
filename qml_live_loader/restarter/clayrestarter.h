#ifndef CLAY_RESTARTER_H
#define CLAY_RESTARTER_H 
#include <QObject>

class ClayRestarter: public QObject 
{
    Q_OBJECT

public:
    ClayRestarter(QObject* parent = nullptr);

public slots:
    void run();

signals:
    void finished();
    void restarted();
};
#endif
