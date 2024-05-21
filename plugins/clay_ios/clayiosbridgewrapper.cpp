#include "clayiosbridgewrapper.h"
#include <QDebug>

ClayIosBridgeWrapper::ClayIosBridgeWrapper(QObject *parent) : QObject(parent) {
}

ClayIosBridgeWrapper::~ClayIosBridgeWrapper() {
}

void ClayIosBridgeWrapper::requestReview() {
    qWarning() << "Requesting reviews is not supported on this platform.";
}
