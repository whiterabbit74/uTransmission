#import <AppKit/AppKit.h>

@interface SidebarController : NSViewController<NSOutlineViewDataSource, NSOutlineViewDelegate>

@property(nonatomic, strong) IBOutlet NSOutlineView* outlineView;

- (void)setCountAll:(NSUInteger)all
             active:(NSUInteger)active
        downloading:(NSUInteger)downloading
            seeding:(NSUInteger)seeding
             paused:(NSUInteger)paused
              error:(NSUInteger)error;

@end
