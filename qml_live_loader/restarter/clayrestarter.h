#ifndef CLAY_RESTARTER_H
#define CLAY_RESTARTER_H 
#include <QObject>

class ClayRestarter: public QObject 
{
    Q_OBJECT
    Q_PROPERTY(int nrRestarts READ nrRestarts NOTIFY nrRestartsChanged)

public:
    ClayRestarter(QObject* parent = nullptr);
    int nrRestarts() const;

public slots:
    void run();

signals:
    void finished();
    void nrRestartsChanged();

private:
   int nrRestarts_ = 0;
};
#endif
