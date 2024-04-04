#import "clayiosbridge.h"
#import <StoreKit/StoreKit.h>

#include <QThread>
#include <QCoreApplication>

@interface ClayIosBridge ()
@end

@implementation ClayIosBridge

+ (instancetype)sharedInstance {
    static ClayIosBridge *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ClayIosBridge alloc] init];
    });
    return sharedInstance;
}

- (void)requestReview {
    dispatch_async(dispatch_get_main_queue(), ^{
        [SKStoreReviewController requestReview];
    });
}


@end
