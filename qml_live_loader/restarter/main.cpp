#include "clayrestarter.h"
#include <QTimer>
#include <QCoreApplication>

int main(int argc, char *argv[])
{
    QCoreApplication a(argc, argv);
    QCoreApplication::setApplicationName("ClayRestarter");
    QCoreApplication::setApplicationVersion("0.1");

    ClayRestarter restarter;
    QObject::connect(&restarter, SIGNAL(finished()), &a, SLOT(quit()));
    QTimer::singleShot(0, &restarter, SLOT(run()));
    return a.exec();
}
