#import "ObjcExceptionCatcher.h"

BOOL ObjcTryCatch(void (^tryBlock)(void), NSError * _Nullable * _Nullable errorOut) {
    @try {
        tryBlock();
        return YES;
    }
    @catch (NSException *exception) {
        if (errorOut) {
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: exception.reason ?: @"Unknown Objective-C exception",
                @"NSExceptionName": exception.name ?: @"Unknown",
            };
            *errorOut = [NSError errorWithDomain:@"ObjcExceptionDomain"
                                           code:-1
                                       userInfo:userInfo];
        }
        return NO;
    }
}
