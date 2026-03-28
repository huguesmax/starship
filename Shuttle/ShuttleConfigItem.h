//
//  ShuttleConfigItem.h
//  Shuttle
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, ShuttleConfigItemType) {
    ShuttleConfigItemTypeFolder,
    ShuttleConfigItemTypeHost
};

@interface ShuttleConfigItem : NSObject

@property (nonatomic, assign) ShuttleConfigItemType itemType;

// Common
@property (nonatomic, copy) NSString *name;

// Host-only properties
@property (nonatomic, copy) NSString *cmd;
@property (nonatomic, copy) NSString *theme;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *inTerminal;

// Folder-only: children
@property (nonatomic, strong) NSMutableArray<ShuttleConfigItem *> *children;

// Parent reference (weak to avoid retain cycles)
@property (nonatomic, weak) ShuttleConfigItem *parent;

// Conversion JSON <-> model
+ (NSMutableArray<ShuttleConfigItem *> *)itemsFromJSONArray:(NSArray *)jsonArray;
- (id)toJSON;

// Deep copy (for duplication)
- (instancetype)deepCopy;

@end
