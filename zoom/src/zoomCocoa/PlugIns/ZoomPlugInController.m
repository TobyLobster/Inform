//
//  ZoomPlugInController.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 29/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "ZoomPlugInController.h"
#import "ZoomPlugInManager.h"
#import "ZoomPlugInCell.h"

@implementation ZoomPlugInController

// = Initialisation =

+ (ZoomPlugInController*) sharedPlugInController {
	static ZoomPlugInController* sharedController = nil;
	
	if (!sharedController) {
		sharedController = [[ZoomPlugInController alloc] initWithWindowNibName: @"PluginManager"];
		[[ZoomPlugInManager sharedPlugInManager] setDelegate: sharedController];
	}
	
	return sharedController;
}

- (id) initWithWindowNibName: (NSString*) name {
	self = [super initWithWindowNibName: name];
	
	if (self) {
		// Set the cell type in the table (interface builder seems to be unable to do this itself)
	}
	
	return self;
}

- (void) windowDidLoad {
	NSTableColumn* pluginColumn = [pluginTable tableColumnWithIdentifier: @"Plugin"];
	[pluginColumn setDataCell: [[[ZoomPlugInCell alloc] init] autorelease]];	
}

// = The data source for the plugin table =

- (int)numberOfRowsInTableView:(NSTableView *)aTableView {
	return [[[ZoomPlugInManager sharedPlugInManager] informationForPlugins] count];
}

- (id)				tableView:(NSTableView *)aTableView 
	objectValueForTableColumn:(NSTableColumn *)aTableColumn 
						  row:(int)rowIndex {
	return [NSNumber numberWithInt: rowIndex];
}

// = Plugin manager delegate methods =

- (void) pluginInformationChanged {
	[pluginTable reloadData];
}

- (void) checkingForUpdates {
	[pluginProgress setIndeterminate: YES];
	[pluginProgress startAnimation: self];
	
	[statusField setStringValue: @"Checking for updates..."];
	[statusField setHidden: NO];
	
	[installButton setEnabled: NO];
	[checkForUpdates setEnabled: NO];
}

- (void) finishedCheckingForUpdates {
	// Re-enable the UI buttons
	[pluginProgress stopAnimation: self];
	[statusField setHidden: YES];

	[installButton setEnabled: YES];
	[checkForUpdates setEnabled: YES];
	
	// Note this as the last check time
	[[NSUserDefaults standardUserDefaults] setValue: [NSDate date]
											 forKey: @"ZoomLastPluginCheck"];
	
	// Show the window if there are any updates
	BOOL updated = NO;
	NSEnumerator* infoEnum = [[[ZoomPlugInManager sharedPlugInManager] informationForPlugins] objectEnumerator];
	ZoomPlugInInfo* info;
	while (info = [infoEnum nextObject]) {
		switch ([info status]) {
			case ZoomPlugInNew:
			case ZoomPluginUpdateAvailable:
				updated = YES;
				break;
			
			default:
				// Do nothing
				break;
		}
	}
	
	if (updated && ![[self window] isVisible]) {
		[self showWindow: self];

		NSBeginAlertSheet(@"Zoom found updates to some of the installed plugins", 
						  @"Install Now", @"Later", nil, [self window], self, 
						  @selector(finishUpdating:returnCode:contextInfo:), nil, nil,
						  @"Zoom has found some updates to some of the plugins that are installed. You can install these now to update your interpreters to the latest versions.");
	}
}

- (void) downloadingUpdates {
	[pluginProgress setIndeterminate: YES];
	[pluginProgress startAnimation: self];
	[pluginProgress setMinValue: 0];
	[pluginProgress setMaxValue: 100];
	
	[statusField setStringValue: @"Downloading updates..."];
	[statusField setHidden: NO];
	
	[installButton setEnabled: NO];
	[checkForUpdates setEnabled: NO];	
}

- (void) downloadProgress: (NSString*) status
			   percentage: (float) percent {
	if (percent >= 0) {
		[pluginProgress setIndeterminate: NO];
		[pluginProgress setDoubleValue: percent];
	} else {
		[pluginProgress setIndeterminate: YES];
	}

	[statusField setStringValue: status];
}

- (void) finishedDownloadingUpdates {
	[pluginProgress stopAnimation: self];
	[statusField setHidden: YES];
	
	[installButton setEnabled: YES];
	[checkForUpdates setEnabled: YES];	
}

- (void) needsRestart {
	[self showWindow: self];
	NSBeginAlertSheet(@"You must restart Zoom to complete the update", 
					  @"Restart Now", @"Later", nil, [self window], self, 
					  @selector(finishRestart:returnCode:contextInfo:), nil, nil,
					  @"Zoom has installed updates for its interpreter plugins. In order for the update to be completed, you will need to restart Zoom.");
}

// = Actions =

- (void) restartZoom {
	// Force Zoom to restart
	NSMutableString* zoomPath = [[[[NSBundle mainBundle] bundlePath] mutableCopy] autorelease];
	
	int x;
	for (x=0; x<[zoomPath length]; x++) {
		unichar c = [zoomPath characterAtIndex: x];
		if (c == '"') {
			[zoomPath replaceCharactersInRange: NSMakeRange(x, 1)
									withString: @"\\\""];
				x++;
			}
		}

	// Set some environment variables
	setenv("ZOOM_PATH", [zoomPath UTF8String], 1);
	setenv("ZOOM_PID", [[NSString stringWithFormat: @"%u", getpid()] UTF8String], 1);

	// Fork off a simple script to restart Zoom (based on the one in Sparkle)
	system("/bin/bash -c '{\n"
		   "echo Will restart\n"
		   "for ((x = 0; x < 3000 && $(echo $(/bin/ps -xp $ZOOM_PID|/usr/bin/wc -l))-1; x++)); do\n"
		   "  /bin/sleep .2\n"
		   "done\n"
		   "if [[ $(/bin/ps -xp $ZOOM_PID|/usr/bin/wc -l) -lt 2 ]]; then\n"
		   "  echo Restarting \"${ZOOM_PATH}\"\n"
		   "  /usr/bin/open \"${ZOOM_PATH}\"\n"
		   "else\n"
		   "  echo Not restarting: $(/bin/ps -xp $ZOOM_PID|/usr/bin/wc -l)\n"
		   "fi\n"
		   "echo Restart finished\n"
		   "} &'");

	// I'll be back
	[NSApp terminate: self];
}

- (void) finishRestart:(NSWindow *)sheet 
			returnCode:(int)returnCode 
		   contextInfo:(void  *)contextInfo {
	if (returnCode == NSAlertDefaultReturn) {
		[self restartZoom];
	}
}

- (void) finishUpdating:(NSWindow *)sheet 
			 returnCode:(int)returnCode 
			contextInfo:(void  *)contextInfo {
	if (returnCode == NSAlertDefaultReturn) {
		[self installUpdates: self];
	}
}

- (IBAction) installUpdates: (id) sender {
	// TODO: implement this properly
	
	// Download the updates
	[[ZoomPlugInManager sharedPlugInManager] downloadUpdates];
}

- (IBAction) checkForUpdates: (id) sender {
	[[ZoomPlugInManager sharedPlugInManager] checkForUpdates];
}

@end
