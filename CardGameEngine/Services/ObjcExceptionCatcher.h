#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Wraps a block that may throw an Objective-C exception and converts it into an NSError.
/// Returns YES on success, NO if an exception was caught (errorOut will be populated).
BOOL ObjcTryCatch(void (^tryBlock)(void), NSError * _Nullable * _Nullable errorOut);

NS_ASSUME_NONNULL_END
