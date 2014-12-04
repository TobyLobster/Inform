//
//  IFAdvancedPreferences.m
//  Inform-xc2
//
//  Created by Andrew Hunter on 12/10/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "IFAdvancedPreferences.h"
#import "IFPreferences.h"
#import "IFImageCache.h"
#import "IFUtility.h"

@implementation IFAdvancedPreferences

// = Initialisation =

- (id) init {
	self = [super initWithNibName: @"AdvancedPreferences"];
	
	if (self) {
		[self reflectCurrentPreferences];
		
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(reflectCurrentPreferences)
													 name: IFPreferencesAdvancedDidChangeNotification
												   object: [IFPreferences sharedPreferences]];
	}
	
	return self;
}

- (void) dealloc {
	[interpreters release];
	
	[super dealloc];
}

// = Preference overrides =

- (NSString*) preferenceName {
	return @"Advanced";
}

- (NSImage*) toolbarImage {
	// Use the OS X standard 'advanced' image if we can
	NSImage* image = [NSImage imageNamed: @"NSAdvanced"];
	if (!image) image = [IFImageCache loadResourceImage: @"App/Preferences/Advanced.png"];
	return image;
}

- (NSString*) tooltip {
	return [IFUtility localizedString: @"Advanced preferences tooltip"];
}

// = Actions =

- (IBAction) setPreference: (id) sender {
	// Read the current state of the buttons
	BOOL willBuildSh            = [runBuildSh state]==NSOnState;
	BOOL willDebug              = [showDebugLogs state]==NSOnState;
    BOOL willShowConsole        = [showConsole state]==NSOnState;
    BOOL willPublicLibraryDebug = [publicLibraryDebug state]==NSOnState;
	BOOL willCleanBuild         = [cleanBuildFiles state]==NSOnState;
	BOOL willAlsoCleanIndex     = [alsoCleanIndexFiles state]==NSOnState;
	NSString* interpreter       = [interpreters objectAtIndex: [[glulxInterpreter selectedItem] tag]];
	
	// Set the shared preferences to suitable values
	[[IFPreferences sharedPreferences] setRunBuildSh: willBuildSh];
	[[IFPreferences sharedPreferences] setShowDebuggingLogs: willDebug];
	[[IFPreferences sharedPreferences] setShowConsoleDuringBuilds: willShowConsole];
  	[[IFPreferences sharedPreferences] setPublicLibraryDebug: willPublicLibraryDebug];
	[[IFPreferences sharedPreferences] setCleanProjectOnClose: willCleanBuild];
	[[IFPreferences sharedPreferences] setAlsoCleanIndexFiles: willAlsoCleanIndex];
	[[IFPreferences sharedPreferences] setGlulxInterpreter: interpreter];
}

- (void) reflectCurrentPreferences {
	// Update the list of interpreters
	NSMenu* terpMenu = [glulxInterpreter menu];
	while ([terpMenu numberOfItems] > 0) { [terpMenu removeItemAtIndex: 0]; }
	
	[interpreters autorelease];
	interpreters = [[NSMutableArray alloc] initWithArray: [[[[NSBundle mainBundle] infoDictionary] objectForKey: @"InformConfiguration"] objectForKey: @"AvailableInterpreters"]];
	int	selIndex = 0;
	for( NSString* terp in interpreters ) {
		// Get the description of this interpreter from the localised strings
		NSString* terpDesc = [NSString stringWithFormat: @"terp-%@", terp];
		terpDesc = [IFUtility localizedString: terpDesc
                                      default: terp];

		// Create the menu item for this interpreter
		NSMenuItem* newItem = [[NSMenuItem alloc] initWithTitle: terpDesc
														 action: nil
												  keyEquivalent: @""];
		[newItem setTag: [terpMenu numberOfItems]];
		if ([terp isEqualToString: [[IFPreferences sharedPreferences] glulxInterpreter]]) {
			selIndex = [terpMenu numberOfItems];
		}
		
		// Add it to the menu
		[terpMenu addItem: newItem];

        [newItem release];
	}
	
	// Select the appropriate item in the menu
	[glulxInterpreter selectItemAtIndex: selIndex];
	
    // Hide buttons that won't work when sandboxed
    [runBuildSh         setHidden: [IFUtility isSandboxed]];
    [publicLibraryDebug setHidden: [IFUtility isSandboxed]];

	// Set the buttons according to the current state of the preferences
	[runBuildSh          setState: [[IFPreferences sharedPreferences] runBuildSh]?NSOnState:NSOffState];
	[showDebugLogs       setState: [[IFPreferences sharedPreferences] showDebuggingLogs]?NSOnState:NSOffState];
    [showConsole         setState: [[IFPreferences sharedPreferences] showConsoleDuringBuilds]?NSOnState:NSOffState];
    [publicLibraryDebug  setState: [[IFPreferences sharedPreferences] publicLibraryDebug]?NSOnState:NSOffState];
	
	[cleanBuildFiles setState: [[IFPreferences sharedPreferences] cleanProjectOnClose]?NSOnState:NSOffState];
	
	if ([[IFPreferences sharedPreferences] cleanProjectOnClose]) {
		[alsoCleanIndexFiles setState: [[IFPreferences sharedPreferences] alsoCleanIndexFiles]?NSOnState:NSOffState];
		[alsoCleanIndexFiles setEnabled: YES];
	} else {
		[alsoCleanIndexFiles setState: NSOffState];
		[alsoCleanIndexFiles setEnabled: NO];
	}
}

@end
