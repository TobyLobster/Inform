//
//  ZoomPlugInController.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 29/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ZoomPlugIns/ZoomPlugInInfo.h>
#import <ZoomPlugIns/ZoomPlugInManager.h>


///
/// NSWindowController object that runs the plugins window
///
@interface ZoomPlugInController : NSWindowController<NSTableViewDataSource, ZoomPlugInManagerDelegate> {
	//! The table of plugins
	IBOutlet NSTableView* pluginTable;
	//! Download progress indicator
	IBOutlet NSProgressIndicator* pluginProgress;
	//! The 'install' button
	IBOutlet NSButton* installButton;
	//! The 'check for updates' button
	IBOutlet NSButton* checkForUpdates;
	//! The status field
	IBOutlet NSTextField* statusField;
}

// Initialisation
//! The shared plugin controller window
@property (class, readonly, retain) ZoomPlugInController *sharedPlugInController;

// Actions
//! 'Install' button clicked
- (IBAction) installUpdates: (id) sender;
//! 'Check for updates' button clicked
- (IBAction) checkForUpdates: (id) sender;
//! Forces Zoom to restart
- (void) restartZoom;

@end
