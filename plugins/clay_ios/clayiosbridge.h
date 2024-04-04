#ifndef CLAYIOSBRIDGE_H
#define CLAYIOSBRIDGE_H

#import <Foundation/Foundation.h>
#include <QtQuick/QQuickItem>

// Define a protocol or interface if needed
@protocol ClayIosBridgeProtocol <NSObject>

@end

// Bridge class declaration
@interface ClayIosBridge : NSObject <ClayIosBridgeProtocol>
+ (instancetype)sharedInstance;
- (void)requestReview;
@end

#endif // CLAYIOSBRIDGE_H
