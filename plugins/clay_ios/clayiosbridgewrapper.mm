#include "clayiosbridgewrapper.h"
#import "clayiosbridge.h"

ClayIosBridgeWrapper::ClayIosBridgeWrapper(QObject *parent) : QObject(parent) {
}

ClayIosBridgeWrapper::~ClayIosBridgeWrapper() {
}

void ClayIosBridgeWrapper::requestReview() {
    [[ClayIosBridge sharedInstance] requestReview]; // Call the Objective-C++ method
}
