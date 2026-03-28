//
//  ConfigEditorWindowController.m
//  Shuttle
//

#import "ConfigEditorWindowController.h"
#import "ShuttleConfigItem.h"
#import "LaunchAtLoginController.h"

@interface ConfigEditorWindowController ()

// Global settings
@property (strong) NSPopUpButton *terminalPopup;
@property (strong) NSPopUpButton *iTermVersionPopup;
@property (strong) NSPopUpButton *openInPopup;
@property (strong) NSTextField   *defaultThemeField;
@property (strong) NSButton      *launchAtLoginCheckbox;

// Hosts outline
@property (strong) NSOutlineView *outlineView;
@property (strong) NSScrollView  *scrollView;

// Detail panel
@property (strong) NSTextField   *detailNameField;
@property (strong) NSTextField   *detailCmdField;
@property (strong) NSTextField   *detailThemeField;
@property (strong) NSTextField   *detailTitleField;
@property (strong) NSPopUpButton *detailInTerminalPopup;

// Detail labels (to hide for folders)
@property (strong) NSTextField   *detailNameLabel;
@property (strong) NSTextField   *detailCmdLabel;
@property (strong) NSTextField   *detailThemeLabel;
@property (strong) NSTextField   *detailTitleLabel;
@property (strong) NSTextField   *detailInTerminalLabel;

// Buttons
@property (strong) NSButton *addHostButton;
@property (strong) NSButton *addFolderButton;
@property (strong) NSButton *removeButton;
@property (strong) NSButton *saveButton;
@property (strong) NSButton *cancelButton;

// Data
@property (copy)   NSString *configPath;
@property (strong) NSMutableDictionary *configDict;
@property (strong) NSMutableArray<ShuttleConfigItem *> *rootItems;
@property (weak)   ShuttleConfigItem *selectedItem;

@end

@implementation ConfigEditorWindowController

#pragma mark - Initialization

- (instancetype)initWithConfigPath:(NSString *)configPath {
    NSRect frame = NSMakeRect(0, 0, 720, 560);
    NSWindowStyleMask styleMask = NSWindowStyleMaskTitled
                                | NSWindowStyleMaskClosable
                                | NSWindowStyleMaskMiniaturizable
                                | NSWindowStyleMaskResizable;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:styleMask
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"Shuttle Configuration";
    window.minSize = NSMakeSize(650, 480);
    [window center];

    self = [super initWithWindow:window];
    if (self) {
        _configPath = [configPath copy];
        [self buildUI];
        [self loadConfig];
        [self populateGlobalSettings];
        [self.outlineView reloadData];
        [self.outlineView expandItem:nil expandChildren:YES];
        [self.outlineView sizeLastColumnToFit];
        [self updateDetailPanel];
    }
    return self;
}

#pragma mark - Build UI

- (void)buildUI {
    NSView *cv = self.window.contentView;

    // Use anchor-based layout exclusively — no VFL, no NSBox

    // ── Section label: Global Settings ──
    NSTextField *globalLabel = [NSTextField labelWithString:@"Global Settings"];
    globalLabel.font = [NSFont boldSystemFontOfSize:13];
    globalLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cv addSubview:globalLabel];

    // ── Row 1: Terminal / iTerm / Open In ──
    NSTextField *termLabel = [self makeLabel:@"Terminal:"];
    self.terminalPopup = [self makePopup:@[@"Terminal.app", @"iTerm"]];

    NSTextField *iTermLabel = [self makeLabel:@"iTerm:"];
    self.iTermVersionPopup = [self makePopup:@[@"stable", @"nightly"]];

    NSTextField *openInLabel = [self makeLabel:@"Open In:"];
    self.openInPopup = [self makePopup:@[@"tab", @"new", @"current"]];

    // ── Row 2: Theme / Launch at Login ──
    NSTextField *themeLabel = [self makeLabel:@"Theme:"];
    self.defaultThemeField = [[NSTextField alloc] initWithFrame:NSZeroRect];
    self.defaultThemeField.translatesAutoresizingMaskIntoConstraints = NO;
    self.defaultThemeField.placeholderString = @"Default theme";

    self.launchAtLoginCheckbox = [NSButton checkboxWithTitle:@"Launch at Login" target:nil action:nil];
    self.launchAtLoginCheckbox.translatesAutoresizingMaskIntoConstraints = NO;

    for (NSView *v in @[termLabel, self.terminalPopup,
                        iTermLabel, self.iTermVersionPopup,
                        openInLabel, self.openInPopup,
                        themeLabel, self.defaultThemeField,
                        self.launchAtLoginCheckbox]) {
        [cv addSubview:v];
    }

    // ── Separator ──
    NSBox *separator = [[NSBox alloc] initWithFrame:NSZeroRect];
    separator.boxType = NSBoxSeparator;
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    [cv addSubview:separator];

    // ── Section label: Hosts ──
    NSTextField *hostsLabel = [NSTextField labelWithString:@"Hosts"];
    hostsLabel.font = [NSFont boldSystemFontOfSize:13];
    hostsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cv addSubview:hostsLabel];

    // ── Outline View ──
    self.outlineView = [[NSOutlineView alloc] initWithFrame:NSMakeRect(0, 0, 300, 200)];
    self.outlineView.headerView = nil;
    self.outlineView.dataSource = self;
    self.outlineView.delegate = self;
    self.outlineView.allowsEmptySelection = YES;
    self.outlineView.usesAlternatingRowBackgroundColors = YES;
    self.outlineView.rowHeight = 20;

    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"Name"];
    column.width = 280;
    column.minWidth = 200;
    column.resizingMask = NSTableColumnAutoresizingMask;
    [column setEditable:NO];
    [self.outlineView addTableColumn:column];
    [self.outlineView setOutlineTableColumn:column];
    self.outlineView.columnAutoresizingStyle = NSTableViewLastColumnOnlyAutoresizingStyle;

    self.scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 300, 200)];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.documentView = self.outlineView;
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.hasHorizontalScroller = NO;
    self.scrollView.autohidesScrollers = YES;
    self.scrollView.borderType = NSLineBorder;
    [cv addSubview:self.scrollView];

    // ── Buttons under outline ──
    self.addHostButton = [self makeSmallButton:@"+ Host" action:@selector(addHost:)];
    self.addFolderButton = [self makeSmallButton:@"+ Folder" action:@selector(addFolder:)];
    self.removeButton = [self makeSmallButton:@"- Remove" action:@selector(removeItem:)];
    self.removeButton.enabled = NO;
    [cv addSubview:self.addHostButton];
    [cv addSubview:self.addFolderButton];
    [cv addSubview:self.removeButton];

    // ── Detail fields (right side) ──
    self.detailNameLabel = [self makeLabel:@"Name:"];
    self.detailNameField = [self makeTextField];
    self.detailNameField.delegate = self;

    self.detailCmdLabel = [self makeLabel:@"Cmd:"];
    self.detailCmdField = [self makeTextField];
    self.detailCmdField.delegate = self;

    self.detailThemeLabel = [self makeLabel:@"Theme:"];
    self.detailThemeField = [self makeTextField];
    self.detailThemeField.delegate = self;

    self.detailTitleLabel = [self makeLabel:@"Title:"];
    self.detailTitleField = [self makeTextField];
    self.detailTitleField.delegate = self;

    self.detailInTerminalLabel = [self makeLabel:@"Open:"];
    self.detailInTerminalPopup = [self makePopup:@[@"(default)", @"tab", @"new", @"current"]];

    for (NSView *v in @[self.detailNameLabel, self.detailNameField,
                        self.detailCmdLabel, self.detailCmdField,
                        self.detailThemeLabel, self.detailThemeField,
                        self.detailTitleLabel, self.detailTitleField,
                        self.detailInTerminalLabel, self.detailInTerminalPopup]) {
        [cv addSubview:v];
    }

    // ── Cancel / Save ──
    self.cancelButton = [NSButton buttonWithTitle:@"Cancel" target:self action:@selector(cancel:)];
    self.cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.cancelButton.keyEquivalent = @"\033";
    [cv addSubview:self.cancelButton];

    self.saveButton = [NSButton buttonWithTitle:@"Save" target:self action:@selector(save:)];
    self.saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.saveButton.keyEquivalent = @"\r";
    [cv addSubview:self.saveButton];

    // ═══════════════════════════════════════════
    // CONSTRAINTS — all anchor-based
    // ═══════════════════════════════════════════
    CGFloat m = 16; // margin
    CGFloat rowH = 26;

    [NSLayoutConstraint activateConstraints:@[

        // ── Global Settings label ──
        [globalLabel.topAnchor constraintEqualToAnchor:cv.topAnchor constant:m],
        [globalLabel.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:m],

        // ── Row 1: Terminal / iTerm / Open In ──
        [termLabel.topAnchor constraintEqualToAnchor:globalLabel.bottomAnchor constant:8],
        [termLabel.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:m],
        [self.terminalPopup.centerYAnchor constraintEqualToAnchor:termLabel.centerYAnchor],
        [self.terminalPopup.leadingAnchor constraintEqualToAnchor:termLabel.trailingAnchor constant:4],
        [self.terminalPopup.widthAnchor constraintGreaterThanOrEqualToConstant:110],

        [iTermLabel.centerYAnchor constraintEqualToAnchor:termLabel.centerYAnchor],
        [iTermLabel.leadingAnchor constraintEqualToAnchor:self.terminalPopup.trailingAnchor constant:16],
        [self.iTermVersionPopup.centerYAnchor constraintEqualToAnchor:termLabel.centerYAnchor],
        [self.iTermVersionPopup.leadingAnchor constraintEqualToAnchor:iTermLabel.trailingAnchor constant:4],
        [self.iTermVersionPopup.widthAnchor constraintGreaterThanOrEqualToConstant:80],

        [openInLabel.centerYAnchor constraintEqualToAnchor:termLabel.centerYAnchor],
        [openInLabel.leadingAnchor constraintEqualToAnchor:self.iTermVersionPopup.trailingAnchor constant:16],
        [self.openInPopup.centerYAnchor constraintEqualToAnchor:termLabel.centerYAnchor],
        [self.openInPopup.leadingAnchor constraintEqualToAnchor:openInLabel.trailingAnchor constant:4],
        [self.openInPopup.widthAnchor constraintGreaterThanOrEqualToConstant:80],

        // ── Row 2: Theme / Launch at Login ──
        [themeLabel.topAnchor constraintEqualToAnchor:termLabel.bottomAnchor constant:8],
        [themeLabel.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:m],
        [self.defaultThemeField.centerYAnchor constraintEqualToAnchor:themeLabel.centerYAnchor],
        [self.defaultThemeField.leadingAnchor constraintEqualToAnchor:themeLabel.trailingAnchor constant:4],
        [self.defaultThemeField.widthAnchor constraintEqualToConstant:150],
        [self.defaultThemeField.heightAnchor constraintEqualToConstant:rowH],

        [self.launchAtLoginCheckbox.centerYAnchor constraintEqualToAnchor:themeLabel.centerYAnchor],
        [self.launchAtLoginCheckbox.leadingAnchor constraintEqualToAnchor:self.defaultThemeField.trailingAnchor constant:20],

        // ── Separator ──
        [separator.topAnchor constraintEqualToAnchor:themeLabel.bottomAnchor constant:12],
        [separator.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:m],
        [separator.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-m],
        [separator.heightAnchor constraintEqualToConstant:1],

        // ── Hosts label ──
        [hostsLabel.topAnchor constraintEqualToAnchor:separator.bottomAnchor constant:8],
        [hostsLabel.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:m],

        // ── Outline scroll view (left half) ──
        [self.scrollView.topAnchor constraintEqualToAnchor:hostsLabel.bottomAnchor constant:6],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:m],
        [self.scrollView.widthAnchor constraintEqualToAnchor:cv.widthAnchor multiplier:0.45 constant:-m],

        // ── Buttons below outline ──
        [self.addHostButton.topAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:4],
        [self.addHostButton.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.addHostButton.heightAnchor constraintEqualToConstant:24],

        [self.addFolderButton.centerYAnchor constraintEqualToAnchor:self.addHostButton.centerYAnchor],
        [self.addFolderButton.leadingAnchor constraintEqualToAnchor:self.addHostButton.trailingAnchor constant:4],
        [self.addFolderButton.heightAnchor constraintEqualToConstant:24],

        [self.removeButton.centerYAnchor constraintEqualToAnchor:self.addHostButton.centerYAnchor],
        [self.removeButton.leadingAnchor constraintEqualToAnchor:self.addFolderButton.trailingAnchor constant:4],
        [self.removeButton.heightAnchor constraintEqualToConstant:24],

        // ── Detail fields (right side, aligned to scroll view top) ──
        [self.detailNameLabel.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor constant:4],
        [self.detailNameLabel.leadingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor constant:16],
        [self.detailNameLabel.widthAnchor constraintEqualToConstant:50],
        [self.detailNameField.centerYAnchor constraintEqualToAnchor:self.detailNameLabel.centerYAnchor],
        [self.detailNameField.leadingAnchor constraintEqualToAnchor:self.detailNameLabel.trailingAnchor constant:4],
        [self.detailNameField.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-m],
        [self.detailNameField.heightAnchor constraintEqualToConstant:rowH],

        [self.detailCmdLabel.topAnchor constraintEqualToAnchor:self.detailNameField.bottomAnchor constant:8],
        [self.detailCmdLabel.leadingAnchor constraintEqualToAnchor:self.detailNameLabel.leadingAnchor],
        [self.detailCmdLabel.widthAnchor constraintEqualToConstant:50],
        [self.detailCmdField.centerYAnchor constraintEqualToAnchor:self.detailCmdLabel.centerYAnchor],
        [self.detailCmdField.leadingAnchor constraintEqualToAnchor:self.detailCmdLabel.trailingAnchor constant:4],
        [self.detailCmdField.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-m],
        [self.detailCmdField.heightAnchor constraintEqualToConstant:rowH],

        [self.detailThemeLabel.topAnchor constraintEqualToAnchor:self.detailCmdField.bottomAnchor constant:8],
        [self.detailThemeLabel.leadingAnchor constraintEqualToAnchor:self.detailNameLabel.leadingAnchor],
        [self.detailThemeLabel.widthAnchor constraintEqualToConstant:50],
        [self.detailThemeField.centerYAnchor constraintEqualToAnchor:self.detailThemeLabel.centerYAnchor],
        [self.detailThemeField.leadingAnchor constraintEqualToAnchor:self.detailThemeLabel.trailingAnchor constant:4],
        [self.detailThemeField.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-m],
        [self.detailThemeField.heightAnchor constraintEqualToConstant:rowH],

        [self.detailTitleLabel.topAnchor constraintEqualToAnchor:self.detailThemeField.bottomAnchor constant:8],
        [self.detailTitleLabel.leadingAnchor constraintEqualToAnchor:self.detailNameLabel.leadingAnchor],
        [self.detailTitleLabel.widthAnchor constraintEqualToConstant:50],
        [self.detailTitleField.centerYAnchor constraintEqualToAnchor:self.detailTitleLabel.centerYAnchor],
        [self.detailTitleField.leadingAnchor constraintEqualToAnchor:self.detailTitleLabel.trailingAnchor constant:4],
        [self.detailTitleField.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-m],
        [self.detailTitleField.heightAnchor constraintEqualToConstant:rowH],

        [self.detailInTerminalLabel.topAnchor constraintEqualToAnchor:self.detailTitleField.bottomAnchor constant:8],
        [self.detailInTerminalLabel.leadingAnchor constraintEqualToAnchor:self.detailNameLabel.leadingAnchor],
        [self.detailInTerminalLabel.widthAnchor constraintEqualToConstant:50],
        [self.detailInTerminalPopup.centerYAnchor constraintEqualToAnchor:self.detailInTerminalLabel.centerYAnchor],
        [self.detailInTerminalPopup.leadingAnchor constraintEqualToAnchor:self.detailInTerminalLabel.trailingAnchor constant:4],
        [self.detailInTerminalPopup.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-m],

        // ── Cancel / Save at bottom ──
        [self.saveButton.bottomAnchor constraintEqualToAnchor:cv.bottomAnchor constant:-m],
        [self.saveButton.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-m],
        [self.saveButton.widthAnchor constraintGreaterThanOrEqualToConstant:80],

        [self.cancelButton.centerYAnchor constraintEqualToAnchor:self.saveButton.centerYAnchor],
        [self.cancelButton.trailingAnchor constraintEqualToAnchor:self.saveButton.leadingAnchor constant:-8],

        // ── Scroll view bottom: above the buttons row ──
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.addHostButton.topAnchor constant:-4],
        [self.addHostButton.bottomAnchor constraintEqualToAnchor:self.saveButton.topAnchor constant:-12],
    ]];
}

#pragma mark - UI Helpers

- (NSTextField *)makeLabel:(NSString *)text {
    NSTextField *label = [NSTextField labelWithString:text];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

- (NSTextField *)makeTextField {
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSZeroRect];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    return field;
}

- (NSPopUpButton *)makePopup:(NSArray<NSString *> *)items {
    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    popup.translatesAutoresizingMaskIntoConstraints = NO;
    [popup addItemsWithTitles:items];
    return popup;
}

- (NSButton *)makeSmallButton:(NSString *)title action:(SEL)action {
    NSButton *btn = [NSButton buttonWithTitle:title target:self action:action];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.controlSize = NSControlSizeSmall;
    btn.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
    return btn;
}

#pragma mark - Config Loading

- (void)loadConfig {
    NSData *data = [NSData dataWithContentsOfFile:self.configPath];
    if (!data) {
        self.configDict = [NSMutableDictionary dictionary];
        self.rootItems = [NSMutableArray array];
        return;
    }
    NSError *error = nil;
    self.configDict = [NSJSONSerialization JSONObjectWithData:data
                                                     options:NSJSONReadingMutableContainers
                                                       error:&error];
    if (!self.configDict) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Error reading configuration";
        alert.informativeText = error.localizedDescription ?: @"Invalid JSON";
        [alert runModal];
        self.configDict = [NSMutableDictionary dictionary];
        self.rootItems = [NSMutableArray array];
        return;
    }
    NSArray *hosts = self.configDict[@"hosts"] ?: @[];
    self.rootItems = [ShuttleConfigItem itemsFromJSONArray:hosts];
}

- (void)populateGlobalSettings {
    NSString *terminal = [self.configDict[@"terminal"] lowercaseString];
    if ([terminal containsString:@"iterm"]) {
        [self.terminalPopup selectItemWithTitle:@"iTerm"];
    } else {
        [self.terminalPopup selectItemWithTitle:@"Terminal.app"];
    }

    NSString *iTermVersion = [self.configDict[@"iTerm_version"] lowercaseString];
    if ([iTermVersion isEqualToString:@"nightly"]) {
        [self.iTermVersionPopup selectItemWithTitle:@"nightly"];
    } else {
        [self.iTermVersionPopup selectItemWithTitle:@"stable"];
    }

    NSString *openIn = [self.configDict[@"open_in"] lowercaseString];
    if ([openIn isEqualToString:@"new"]) {
        [self.openInPopup selectItemWithTitle:@"new"];
    } else if ([openIn isEqualToString:@"current"]) {
        [self.openInPopup selectItemWithTitle:@"current"];
    } else {
        [self.openInPopup selectItemWithTitle:@"tab"];
    }

    self.defaultThemeField.stringValue = self.configDict[@"default_theme"] ?: @"";

    BOOL launchAtLogin = [self.configDict[@"launch_at_login"] boolValue];
    self.launchAtLoginCheckbox.state = launchAtLogin ? NSControlStateValueOn : NSControlStateValueOff;
}

#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (item == nil) return (NSInteger)self.rootItems.count;
    ShuttleConfigItem *node = (ShuttleConfigItem *)item;
    return (node.itemType == ShuttleConfigItemTypeFolder) ? (NSInteger)node.children.count : 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if (item == nil) return self.rootItems[index];
    return ((ShuttleConfigItem *)item).children[index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return ((ShuttleConfigItem *)item).itemType == ShuttleConfigItemTypeFolder;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    ShuttleConfigItem *node = (ShuttleConfigItem *)item;
    if (node.itemType == ShuttleConfigItemTypeFolder) {
        return [NSString stringWithFormat:@"\U0001F4C1 %@", node.name ?: @"(unnamed)"];
    }
    return node.name ?: @"(unnamed)";
}

#pragma mark - NSOutlineViewDelegate

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    [self commitDetailEdits];

    NSInteger row = self.outlineView.selectedRow;
    if (row >= 0) {
        self.selectedItem = [self.outlineView itemAtRow:row];
    } else {
        self.selectedItem = nil;
    }
    [self updateDetailPanel];
}

#pragma mark - Detail Panel

- (void)updateDetailPanel {
    BOOL hasSelection = (self.selectedItem != nil);
    BOOL isHost = hasSelection && self.selectedItem.itemType == ShuttleConfigItemTypeHost;

    self.detailNameField.enabled = hasSelection;
    self.detailNameField.stringValue = hasSelection ? (self.selectedItem.name ?: @"") : @"";

    self.detailCmdField.hidden = !isHost;
    self.detailCmdLabel.hidden = !isHost;
    self.detailThemeField.hidden = !isHost;
    self.detailThemeLabel.hidden = !isHost;
    self.detailTitleField.hidden = !isHost;
    self.detailTitleLabel.hidden = !isHost;
    self.detailInTerminalPopup.hidden = !isHost;
    self.detailInTerminalLabel.hidden = !isHost;

    if (isHost) {
        self.detailCmdField.stringValue = self.selectedItem.cmd ?: @"";
        self.detailThemeField.stringValue = self.selectedItem.theme ?: @"";
        self.detailTitleField.stringValue = self.selectedItem.title ?: @"";

        NSString *inTerm = self.selectedItem.inTerminal;
        if (inTerm.length > 0) {
            [self.detailInTerminalPopup selectItemWithTitle:inTerm];
        } else {
            [self.detailInTerminalPopup selectItemWithTitle:@"(default)"];
        }
    }

    self.removeButton.enabled = hasSelection;
}

- (void)commitDetailEdits {
    if (!self.selectedItem) return;

    self.selectedItem.name = self.detailNameField.stringValue;

    if (self.selectedItem.itemType == ShuttleConfigItemTypeHost) {
        self.selectedItem.cmd = self.detailCmdField.stringValue;
        self.selectedItem.theme = self.detailThemeField.stringValue;
        self.selectedItem.title = self.detailTitleField.stringValue;
        NSString *inTerm = [self.detailInTerminalPopup titleOfSelectedItem];
        self.selectedItem.inTerminal = [inTerm isEqualToString:@"(default)"] ? nil : inTerm;
    }

    [self.outlineView reloadItem:self.selectedItem];
}

#pragma mark - NSTextFieldDelegate

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    [self commitDetailEdits];
}

#pragma mark - Actions

- (IBAction)addHost:(id)sender {
    [self commitDetailEdits];

    ShuttleConfigItem *newHost = [[ShuttleConfigItem alloc] init];
    newHost.itemType = ShuttleConfigItemTypeHost;
    newHost.name = @"New Host";
    newHost.cmd = @"ssh user@host";

    [self insertItem:newHost];
}

- (IBAction)addFolder:(id)sender {
    [self commitDetailEdits];

    ShuttleConfigItem *newFolder = [[ShuttleConfigItem alloc] init];
    newFolder.itemType = ShuttleConfigItemTypeFolder;
    newFolder.name = @"New Folder";
    newFolder.children = [NSMutableArray array];

    [self insertItem:newFolder];
}

- (void)insertItem:(ShuttleConfigItem *)item {
    ShuttleConfigItem *target = self.selectedItem;
    NSMutableArray *parentArray;

    if (target && target.itemType == ShuttleConfigItemTypeFolder) {
        parentArray = target.children;
        item.parent = target;
    } else if (target && target.parent) {
        parentArray = target.parent.children;
        item.parent = target.parent;
    } else {
        parentArray = self.rootItems;
        item.parent = nil;
    }

    [parentArray addObject:item];
    [self.outlineView reloadData];

    if (item.parent) {
        [self.outlineView expandItem:item.parent];
    }

    NSInteger row = [self.outlineView rowForItem:item];
    if (row >= 0) {
        [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
                      byExtendingSelection:NO];
    }
}

- (IBAction)removeItem:(id)sender {
    ShuttleConfigItem *item = self.selectedItem;
    if (!item) return;

    if (item.itemType == ShuttleConfigItemTypeFolder && item.children.count > 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Delete folder?";
        alert.informativeText = [NSString stringWithFormat:
            @"The folder \"%@\" contains %lu item(s). Delete it and all contents?",
            item.name, (unsigned long)item.children.count];
        [alert addButtonWithTitle:@"Delete"];
        [alert addButtonWithTitle:@"Cancel"];
        if ([alert runModal] != NSAlertFirstButtonReturn) return;
    }

    NSMutableArray *parentArray = item.parent ? item.parent.children : self.rootItems;
    [parentArray removeObject:item];
    self.selectedItem = nil;
    [self.outlineView reloadData];
    [self updateDetailPanel];
}

- (IBAction)save:(id)sender {
    [self commitDetailEdits];

    NSMutableDictionary *output = [NSMutableDictionary dictionary];

    for (NSString *key in self.configDict) {
        output[key] = self.configDict[key];
    }

    output[@"terminal"] = [self.terminalPopup titleOfSelectedItem];
    output[@"iTerm_version"] = [self.iTermVersionPopup titleOfSelectedItem];
    output[@"open_in"] = [self.openInPopup titleOfSelectedItem];
    output[@"default_theme"] = self.defaultThemeField.stringValue;
    output[@"launch_at_login"] = @(self.launchAtLoginCheckbox.state == NSControlStateValueOn);

    NSMutableArray *hostsJSON = [NSMutableArray array];
    for (ShuttleConfigItem *item in self.rootItems) {
        [hostsJSON addObject:[item toJSON]];
    }
    output[@"hosts"] = hostsJSON;

    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:output
                                                      options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                        error:&error];
    if (jsonData) {
        [jsonData writeToFile:self.configPath atomically:YES];

        LaunchAtLoginController *launchController = [[LaunchAtLoginController alloc] init];
        launchController.launchAtLogin = (self.launchAtLoginCheckbox.state == NSControlStateValueOn);

        [self.window close];
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Save failed";
        alert.informativeText = error.localizedDescription;
        [alert runModal];
    }
}

- (IBAction)cancel:(id)sender {
    [self.window close];
}

@end
