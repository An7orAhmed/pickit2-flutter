#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^Pk2ProgressHandler)(NSString *phase, NSInteger percent, NSString *message);

@interface Pk2NativeBridge : NSObject

- (nullable instancetype)initWithDeviceFilePath:(NSString *)path error:(NSError **)error;
- (nullable NSDictionary<NSString *, id> *)connect:(NSError **)error;
- (void)disconnect;
- (nullable NSDictionary<NSString *, id> *)selectPart:(NSString *)partName error:(NSError **)error;
- (nullable NSDictionary<NSString *, id> *)autoDetect:(NSError **)error;
- (BOOL)erase:(NSError **)error;
- (nullable NSDictionary<NSString *, id> *)blankCheck:(NSError **)error;
- (nullable NSDictionary<NSString *, id> *)read:(NSError **)error;
- (BOOL)exportHexAtPath:(NSString *)path error:(NSError **)error;
- (nullable NSDictionary<NSString *, id> *)writeHexAtPath:(NSString *)path
                                                  progress:(nullable Pk2ProgressHandler)progress
                                                     error:(NSError **)error;
- (nullable NSDictionary<NSString *, id> *)verifyHexAtPath:(NSString *)path
                                                   progress:(nullable Pk2ProgressHandler)progress
                                                      error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
