//
//  LaunchAtLoginController.h
//
//  Updated to use SMAppService (macOS 13+)
//

#import <Cocoa/Cocoa.h>
#import <ServiceManagement/ServiceManagement.h>

@interface LaunchAtLoginController : NSObject

@property(assign) BOOL launchAtLogin;

@end