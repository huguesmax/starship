//
//  ShuttleConfigItem.m
//  Shuttle
//

#import "ShuttleConfigItem.h"

@implementation ShuttleConfigItem

+ (NSMutableArray<ShuttleConfigItem *> *)itemsFromJSONArray:(NSArray *)jsonArray {
    NSMutableArray *result = [NSMutableArray array];
    for (id entry in jsonArray) {
        if (![entry isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *dict = (NSDictionary *)entry;

        if (dict[@"cmd"] && dict[@"name"]) {
            // Leaf host
            ShuttleConfigItem *item = [[ShuttleConfigItem alloc] init];
            item.itemType = ShuttleConfigItemTypeHost;
            item.name = dict[@"name"];
            item.cmd = dict[@"cmd"];
            item.theme = dict[@"theme"];
            item.title = dict[@"title"];
            item.inTerminal = dict[@"inTerminal"];
            [result addObject:item];
        } else {
            // Folder(s) - each key is a folder name, value is an array
            for (NSString *key in dict) {
                id value = dict[key];
                if (![value isKindOfClass:[NSArray class]]) continue;

                ShuttleConfigItem *folder = [[ShuttleConfigItem alloc] init];
                folder.itemType = ShuttleConfigItemTypeFolder;
                folder.name = key;
                folder.children = [self itemsFromJSONArray:value];
                for (ShuttleConfigItem *child in folder.children) {
                    child.parent = folder;
                }
                [result addObject:folder];
            }
        }
    }
    return result;
}

- (id)toJSON {
    if (self.itemType == ShuttleConfigItemTypeHost) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        dict[@"name"] = self.name ?: @"";
        dict[@"cmd"] = self.cmd ?: @"";
        if (self.theme.length > 0)      dict[@"theme"] = self.theme;
        if (self.title.length > 0)      dict[@"title"] = self.title;
        if (self.inTerminal.length > 0) dict[@"inTerminal"] = self.inTerminal;
        return dict;
    } else {
        NSMutableArray *childJSON = [NSMutableArray array];
        for (ShuttleConfigItem *child in self.children) {
            [childJSON addObject:[child toJSON]];
        }
        return @{ self.name ?: @"" : childJSON };
    }
}

- (instancetype)deepCopy {
    ShuttleConfigItem *copy = [[ShuttleConfigItem alloc] init];
    copy.itemType = self.itemType;
    copy.name = [self.name copy];
    copy.cmd = [self.cmd copy];
    copy.theme = [self.theme copy];
    copy.title = [self.title copy];
    copy.inTerminal = [self.inTerminal copy];
    if (self.children) {
        copy.children = [NSMutableArray arrayWithCapacity:self.children.count];
        for (ShuttleConfigItem *child in self.children) {
            ShuttleConfigItem *childCopy = [child deepCopy];
            childCopy.parent = copy;
            [copy.children addObject:childCopy];
        }
    }
    return copy;
}

@end
