#import "SidebarController.h"
#import "FilterBarController.h"
#import "GroupsController.h"

static CGFloat const kSidebarRowHeight = 24.0;
static CGFloat const kSidebarIconSize = 16.0;

typedef NS_ENUM(NSInteger, SidebarItemKind) { SidebarItemKindSection = 0, SidebarItemKindStatus = 1, SidebarItemKindTag = 2 };

@interface SidebarItem : NSObject
@property(nonatomic, copy) NSString* title;
@property(nonatomic, copy) NSString* identifier;
@property(nonatomic, strong) NSImage* image;
@property(nonatomic, assign) NSInteger tag;
@property(nonatomic, assign) NSUInteger count;
@property(nonatomic, assign) SidebarItemKind kind;
@property(nonatomic, strong) NSMutableArray<SidebarItem*>* children;
@end

@implementation SidebarItem
- (instancetype)init
{
    if (self = [super init])
    {
        _children = [NSMutableArray array];
    }
    return self;
}
@end

@implementation SidebarController
{
    NSArray<SidebarItem*>* _topLevelItems;
    SidebarItem* _statusSection;
    SidebarItem* _tagsSection;
    NSMutableDictionary<NSString*, SidebarItem*>* _statusItemsByIdentifier;
    NSMutableDictionary<NSNumber*, SidebarItem*>* _tagItemsByValue;
    BOOL _updatingProgrammatically;
}

- (void)loadView
{
    NSScrollView* scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 200, 400)];
    scrollView.hasVerticalScroller = YES;
    scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scrollView.drawsBackground = NO;

    NSOutlineView* outline = [[NSOutlineView alloc] initWithFrame:scrollView.bounds];
    outline.headerView = nil;
    outline.delegate = self;
    outline.dataSource = self;
    outline.selectionHighlightStyle = NSTableViewSelectionHighlightStyleSourceList;
    outline.rowHeight = kSidebarRowHeight;
    outline.indentationPerLevel = 12.0;
    outline.floatsGroupRows = NO;
    outline.rowSizeStyle = NSTableViewRowSizeStyleDefault;
    if (@available(macOS 11.0, *))
    {
        outline.style = NSTableViewStyleSourceList;
    }

    NSTableColumn* column = [[NSTableColumn alloc] initWithIdentifier:@"SidebarColumn"];
    column.resizingMask = NSTableColumnAutoresizingMask;
    column.minWidth = 50;
    [outline addTableColumn:column];
    outline.outlineTableColumn = column;
    outline.autoresizesOutlineColumn = YES;

    scrollView.documentView = outline;
    self.view = scrollView;
    self.outlineView = outline;

    [outline sizeLastColumnToFit];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupItems];
    [self.outlineView reloadData];
    [self expandAllSections];

    [self selectCurrentFilter];
    [self.outlineView sizeLastColumnToFit];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(filterChanged:) name:@"ApplyFilter" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(groupsChanged:) name:@"UpdateGroups" object:nil];
}

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)viewDidLayout
{
    [super viewDidLayout];
    [self.outlineView sizeLastColumnToFit];
}

- (void)setupItems
{
    _statusItemsByIdentifier = [NSMutableDictionary dictionary];
    _tagItemsByValue = [NSMutableDictionary dictionary];
    _statusSection = [self makeSectionWithTitle:NSLocalizedString(@"Transfers", "Sidebar -> section header")];
    _statusSection.children = [[self statusItems] mutableCopy];

    _tagsSection = [self makeSectionWithTitle:NSLocalizedString(@"Tags", "Sidebar -> section header")];
    [self rebuildTagItems];

    _topLevelItems = @[ _statusSection, _tagsSection ];
}

- (SidebarItem*)makeSectionWithTitle:(NSString*)title
{
    SidebarItem* sectionItem = [[SidebarItem alloc] init];
    sectionItem.title = title;
    sectionItem.kind = SidebarItemKindSection;
    return sectionItem;
}

- (NSImage*)symbolImageWithName:(NSString*)name description:(NSString*)description
{
    NSImage* symbol = [NSImage imageWithSystemSymbolName:name accessibilityDescription:description];
    if (!symbol)
    {
        return nil;
    }

    if (@available(macOS 12.0, *))
    {
        NSImageSymbolConfiguration* config = [NSImageSymbolConfiguration configurationWithHierarchicalColor:NSColor.secondaryLabelColor];
        symbol = [symbol imageWithSymbolConfiguration:config];
    }

    return symbol;
}

- (SidebarItem*)makeStatusItemWithTitle:(NSString*)title identifier:(NSString*)identifier symbol:(NSString*)symbolName
{
    SidebarItem* item = [[SidebarItem alloc] init];
    item.title = title;
    item.identifier = identifier;
    item.kind = SidebarItemKindStatus;
    item.image = [self symbolImageWithName:symbolName description:title];
    _statusItemsByIdentifier[identifier] = item;
    return item;
}

- (NSArray<SidebarItem*>*)statusItems
{
    return @[
        [self makeStatusItemWithTitle:NSLocalizedString(@"All", "Sidebar -> filter") identifier:FilterTypeNone symbol:@"tray.full"],
        [self makeStatusItemWithTitle:NSLocalizedString(@"Active", "Sidebar -> filter") identifier:FilterTypeActive
                               symbol:@"bolt.horizontal.circle"],
        [self makeStatusItemWithTitle:NSLocalizedString(@"Downloading", "Sidebar -> filter") identifier:FilterTypeDownload
                               symbol:@"arrow.down.circle"],
        [self makeStatusItemWithTitle:NSLocalizedString(@"Seeding", "Sidebar -> filter") identifier:FilterTypeSeed
                               symbol:@"arrow.up.circle"],
        [self makeStatusItemWithTitle:NSLocalizedString(@"Paused", "Sidebar -> filter") identifier:FilterTypePause
                               symbol:@"pause.circle"],
        [self makeStatusItemWithTitle:NSLocalizedString(@"Error", "Sidebar -> filter") identifier:FilterTypeError
                               symbol:@"exclamationmark.triangle"]
    ];
}

- (SidebarItem*)makeTagItemWithTitle:(NSString*)title tagValue:(NSInteger)tagValue image:(NSImage*)image
{
    SidebarItem* item = [[SidebarItem alloc] init];
    item.title = title;
    item.tag = tagValue;
    item.image = image;
    item.kind = SidebarItemKindTag;
    _tagItemsByValue[@(tagValue)] = item;
    return item;
}

- (void)rebuildTagItems
{
    [_tagsSection.children removeAllObjects];
    [_tagItemsByValue removeAllObjects];

    NSImage* allTagsImage = [self symbolImageWithName:@"tag" description:NSLocalizedString(@"All Tags", "Sidebar -> tags filter")];
    [_tagsSection.children addObject:[self makeTagItemWithTitle:NSLocalizedString(@"All Tags", "Sidebar -> tags filter")
                                                       tagValue:kGroupFilterAllTag
                                                          image:allTagsImage]];

    [_tagsSection.children addObject:[self makeTagItemWithTitle:NSLocalizedString(@"No Tag", "Sidebar -> tags filter") tagValue:-1
                                                          image:[GroupsController.groups imageForIndex:-1]]];

    NSInteger const numberOfGroups = GroupsController.groups.numberOfGroups;
    for (NSInteger row = 0; row < numberOfGroups; row++)
    {
        NSInteger const groupIndex = [GroupsController.groups indexForRow:row];
        NSString* groupName = [GroupsController.groups nameForIndex:groupIndex];
        if (groupName.length == 0)
        {
            groupName = NSLocalizedString(@"(Unnamed Tag)", "Sidebar -> unnamed tag");
        }

        NSImage* image = [GroupsController.groups imageForIndex:groupIndex];
        [_tagsSection.children addObject:[self makeTagItemWithTitle:groupName tagValue:groupIndex image:image]];
    }
}

- (void)expandAllSections
{
    for (SidebarItem* item in _topLevelItems)
    {
        [self.outlineView expandItem:item];
    }
}

- (SidebarItem*)statusItemForIdentifier:(NSString*)identifier
{
    SidebarItem* item = _statusItemsByIdentifier[identifier];
    if (!item)
    {
        item = _statusItemsByIdentifier[FilterTypeNone];
    }
    return item;
}

- (SidebarItem*)tagItemForValue:(NSInteger)value
{
    SidebarItem* item = _tagItemsByValue[@(value)];
    if (!item)
    {
        item = _tagItemsByValue[@(kGroupFilterAllTag)];
    }
    return item;
}

- (void)selectCurrentFilter
{
    NSInteger const groupFilterValue = [NSUserDefaults.standardUserDefaults integerForKey:@"FilterGroup"];
    SidebarItem* selectedItem = nil;

    if (groupFilterValue != kGroupFilterAllTag)
    {
        selectedItem = [self tagItemForValue:groupFilterValue];
    }
    else
    {
        NSString* currentFilter = [NSUserDefaults.standardUserDefaults stringForKey:@"Filter"];
        if (currentFilter.length == 0)
        {
            currentFilter = FilterTypeNone;
        }
        selectedItem = [self statusItemForIdentifier:currentFilter];
    }

    if (!selectedItem)
    {
        return;
    }

    if (selectedItem.kind == SidebarItemKindStatus)
    {
        [self.outlineView expandItem:_statusSection];
    }
    else if (selectedItem.kind == SidebarItemKindTag)
    {
        [self.outlineView expandItem:_tagsSection];
    }

    NSInteger row = [self.outlineView rowForItem:selectedItem];
    if (row != -1 && row != self.outlineView.selectedRow)
    {
        _updatingProgrammatically = YES;
        [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        _updatingProgrammatically = NO;
    }
}

- (void)filterChanged:(NSNotification*)notification
{
    [self selectCurrentFilter];
}

- (void)groupsChanged:(NSNotification*)notification
{
    [self rebuildTagItems];
    [self.outlineView reloadData];
    [self expandAllSections];
    [self selectCurrentFilter];
}

#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView*)outlineView numberOfChildrenOfItem:(id)item
{
    if (item == nil)
        return _topLevelItems.count;
    return [[item children] count];
}

- (id)outlineView:(NSOutlineView*)outlineView child:(NSInteger)index ofItem:(id)item
{
    if (item == nil)
        return _topLevelItems[index];
    return [item children][index];
}

- (BOOL)outlineView:(NSOutlineView*)outlineView isItemExpandable:(id)item
{
    return [[item children] count] > 0;
}

#pragma mark - NSOutlineViewDelegate

- (NSView*)outlineView:(NSOutlineView*)outlineView viewForTableColumn:(NSTableColumn*)tableColumn item:(id)item
{
    SidebarItem* sidebarItem = (SidebarItem*)item;

    if (sidebarItem.kind == SidebarItemKindSection)
    {
        NSTableCellView* cell = [outlineView makeViewWithIdentifier:@"HeaderCell" owner:self];
        if (!cell)
        {
            cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
            cell.identifier = @"HeaderCell";

            NSTextField* tf = [NSTextField labelWithString:@""];
            tf.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize] weight:NSFontWeightSemibold];
            tf.textColor = [NSColor secondaryLabelColor];
            tf.lineBreakMode = NSLineBreakByTruncatingTail;
            tf.translatesAutoresizingMaskIntoConstraints = NO;
            [cell addSubview:tf];
            cell.textField = tf;

            [NSLayoutConstraint activateConstraints:@[
                [tf.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:4],
                [tf.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-4],
                [tf.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor]
            ]];
        }
        cell.textField.stringValue = [sidebarItem.title uppercaseStringWithLocale:NSLocale.currentLocale];
        return cell;
    }

    NSTableCellView* cell = [outlineView makeViewWithIdentifier:@"DataCell" owner:self];
    if (!cell)
    {
        cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
        cell.identifier = @"DataCell";

        NSImageView* iv = [NSImageView imageViewWithImage:[NSImage new]];
        iv.translatesAutoresizingMaskIntoConstraints = NO;
        iv.imageScaling = NSImageScaleProportionallyUpOrDown;
        [cell addSubview:iv];
        cell.imageView = iv;

        NSTextField* tf = [NSTextField labelWithString:@""];
        tf.font = [NSFont systemFontOfSize:13];
        tf.lineBreakMode = NSLineBreakByTruncatingTail;
        tf.translatesAutoresizingMaskIntoConstraints = NO;
        [tf setContentHuggingPriority:NSLayoutPriorityDefaultLow - 1 forOrientation:NSLayoutConstraintOrientationHorizontal];
        [tf setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
        [cell addSubview:tf];
        cell.textField = tf;

        NSTextField* badge = [NSTextField labelWithString:@""];
        badge.tag = 1001;
        badge.font = [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightMedium];
        badge.textColor = [NSColor secondaryLabelColor];
        badge.alignment = NSTextAlignmentRight;
        badge.translatesAutoresizingMaskIntoConstraints = NO;
        [badge setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
        [badge setContentHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];
        [cell addSubview:badge];

        [NSLayoutConstraint activateConstraints:@[
            [iv.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:0],
            [iv.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
            [iv.widthAnchor constraintEqualToConstant:kSidebarIconSize],
            [iv.heightAnchor constraintEqualToConstant:kSidebarIconSize],
            [tf.leadingAnchor constraintEqualToAnchor:iv.trailingAnchor constant:4],
            [tf.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
            [tf.trailingAnchor constraintLessThanOrEqualToAnchor:badge.leadingAnchor constant:-6],
            [tf.trailingAnchor constraintLessThanOrEqualToAnchor:cell.trailingAnchor constant:-2],
            [badge.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-4],
            [badge.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
        ]];
    }

    cell.textField.stringValue = sidebarItem.title;
    cell.imageView.image = sidebarItem.image;
    cell.imageView.hidden = sidebarItem.image == nil;

    NSTextField* badge = [cell viewWithTag:1001];
    BOOL const showStatusCount = sidebarItem.kind == SidebarItemKindStatus && sidebarItem.count > 0;
    if (showStatusCount)
    {
        badge.stringValue = [NSString stringWithFormat:@"%lu", (unsigned long)sidebarItem.count];
        badge.hidden = NO;
    }
    else
    {
        badge.stringValue = @"";
        badge.hidden = YES;
    }

    return cell;
}

- (BOOL)outlineView:(NSOutlineView*)outlineView shouldSelectItem:(id)item
{
    SidebarItem* sidebarItem = (SidebarItem*)item;
    return sidebarItem.kind != SidebarItemKindSection;
}

- (BOOL)outlineView:(NSOutlineView*)outlineView shouldShowOutlineCellForItem:(id)item
{
    SidebarItem* sidebarItem = (SidebarItem*)item;
    return sidebarItem.kind == SidebarItemKindSection;
}

- (void)outlineViewSelectionDidChange:(NSNotification*)notification
{
    if (_updatingProgrammatically)
    {
        return;
    }

    NSInteger selectedRow = [self.outlineView selectedRow];
    if (selectedRow < 0)
    {
        return;
    }

    SidebarItem* item = [self.outlineView itemAtRow:selectedRow];
    if (!item)
    {
        return;
    }

    NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
    NSString* oldFilterType = [defaults stringForKey:@"Filter"] ?: FilterTypeNone;
    NSInteger const oldGroupValue = [defaults integerForKey:@"FilterGroup"];
    NSString* newFilterType = oldFilterType;
    NSInteger newGroupValue = oldGroupValue;

    if (item.kind == SidebarItemKindStatus && item.identifier.length > 0)
    {
        newFilterType = item.identifier;
    }
    else if (item.kind == SidebarItemKindTag)
    {
        newGroupValue = item.tag;
    }

    if ([oldFilterType isEqualToString:newFilterType] && oldGroupValue == newGroupValue)
    {
        return;
    }

    [defaults setObject:newFilterType forKey:@"Filter"];
    [defaults setInteger:newGroupValue forKey:@"FilterGroup"];

    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:@"ApplyFilter" object:nil];
    });
}

- (void)setCountAll:(NSUInteger)all
             active:(NSUInteger)active
        downloading:(NSUInteger)downloading
            seeding:(NSUInteger)seeding
             paused:(NSUInteger)paused
              error:(NSUInteger)error
{
    for (SidebarItem* item in _statusSection.children)
    {
        if ([item.identifier isEqualToString:FilterTypeNone])
        {
            item.count = all;
        }
        else if ([item.identifier isEqualToString:FilterTypeActive])
        {
            item.count = active;
        }
        else if ([item.identifier isEqualToString:FilterTypeDownload])
        {
            item.count = downloading;
        }
        else if ([item.identifier isEqualToString:FilterTypeSeed])
        {
            item.count = seeding;
        }
        else if ([item.identifier isEqualToString:FilterTypePause])
        {
            item.count = paused;
        }
        else if ([item.identifier isEqualToString:FilterTypeError])
        {
            item.count = error;
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableIndexSet* rowIndexes = [NSMutableIndexSet indexSet];

        for (SidebarItem* item in _statusSection.children)
        {
            NSInteger row = [self.outlineView rowForItem:item];
            if (row != -1)
            {
                [rowIndexes addIndex:row];
            }
        }

        if (rowIndexes.count > 0)
        {
            [self.outlineView reloadDataForRowIndexes:rowIndexes columnIndexes:[NSIndexSet indexSetWithIndex:0]];
        }
    });
}

@end
