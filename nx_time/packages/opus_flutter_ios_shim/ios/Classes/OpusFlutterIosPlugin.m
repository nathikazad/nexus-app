#import "OpusFlutterIosPlugin.h"
#if __has_include(<opus_flutter_ios/opus_flutter_ios-Swift.h>)
#import <opus_flutter_ios/opus_flutter_ios-Swift.h>
#else
#import "opus_flutter_ios-Swift.h"
#endif

@implementation OpusFlutterIosPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftOpusFlutterIosPlugin registerWithRegistrar:registrar];
}
@end
