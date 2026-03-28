//
//  ConfigEditorWindowController.h
//  Shuttle
//

#import <Cocoa/Cocoa.h>

@interface ConfigEditorWindowController : NSWindowController
    <NSOutlineViewDataSource, NSOutlineViewDelegate, NSTextFieldDelegate>

- (instancetype)initWithConfigPath:(NSString *)configPath;

@end
