// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#import "InfoViewController.h"

@interface InfoOptionsViewController : NSViewController<InfoViewController>

- (NSRect)viewRect;
- (void)checkLayout;
- (void)checkWindowSize;
- (void)updateWindowLayout;

- (void)setInfoForTorrents:(NSArray<Torrent*>*)torrents;
- (void)updateInfo;
- (void)updateOptions;

- (IBAction)setUseSpeedLimit:(id)sender;
- (IBAction)setSpeedLimit:(id)sender;
- (IBAction)setUseGlobalSpeedLimit:(id)sender;

- (IBAction)setRatioSetting:(id)sender;
- (IBAction)setRatioLimit:(id)sender;

- (IBAction)setIdleSetting:(id)sender;
- (IBAction)setIdleLimit:(id)sender;

- (IBAction)setRemoveWhenSeedingCompletes:(id)sender;
- (IBAction)setSequentialDownload:(id)sender;

- (IBAction)setPriority:(id)sender;

- (IBAction)setPeersConnectLimit:(id)sender;

@property(nonatomic) IBOutlet NSView* fPriorityView;
@property(nonatomic) CGFloat oldHeight;

/// Set when the inspector is hosted inside the main window's split view,
/// where sizing is owned by the split view rather than by this controller.
@property(nonatomic) BOOL embedded;

@end
