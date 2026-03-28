//
//  LaunchAtLoginController.m
//
//  Updated to use SMAppService (macOS 13+)
//

#import "LaunchAtLoginController.h"

static NSString *const StartAtLoginKey = @"launchAtLogin";

@implementation LaunchAtLoginController

- (void) setLaunchAtLogin: (BOOL) enabled
{
    [self willChangeValueForKey:StartAtLoginKey];
    SMAppService *service = [SMAppService mainAppService];
    NSError *error = nil;
    if (enabled) {
        [service registerAndReturnError:&error];
    } else {
        [service unregisterAndReturnError:&error];
    }
    if (error) {
        NSLog(@"LaunchAtLogin error: %@", error);
    }
    [self didChangeValueForKey:StartAtLoginKey];
}

- (BOOL) launchAtLogin
{
    return [SMAppService mainAppService].status == SMAppServiceStatusEnabled;
}

@end