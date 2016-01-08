//
//  IFAdvancedPreferences.m
//  Inform
//
//  Created by Andrew Hunter on 12/10/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "IFAdvancedPreferences.h"
#import "IFPreferences.h"
#import "IFImageCache.h"
#import "IFUtility.h"

@implementation IFAdvancedPreferences {
    IBOutlet NSButton* showDebugLogs;					// If checked, show the Inform 6 source and Inform 7 debugging logs
    IBOutlet NSButton* runBuildSh;						// Causes the Inform 7 build process to be run
    IBOutlet NSButton* alwaysCompile;                   // If checked, always compile the story (no make-style dependency checking)
    IBOutlet NSButton* showConsole;                     // If checked, show the Console during building
    IBOutlet NSButton* publicLibraryDebug;              // If checked, the public library is accessed from a different location (for debugging)

    IBOutlet NSButton* cleanBuildFiles;					// If checked, build files are cleaned out
    IBOutlet NSButton* alsoCleanIndexFiles;				// If checked, index files are cleaned out in addition to build files
    IBOutlet NSPopUpButton*	glulxInterpreter;			// The glulx interpreter to use

    NSMutableArray* interpreters;						// Array of interpreter names, indexed by tags in the glulxInterpreter menu
}

// = Initialisation =

- (instancetype) init {
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
    BOOL willAlwaysCompile      = [alwaysCompile state]==NSOnState;
	BOOL willDebug              = [showDebugLogs state]==NSOnState;
    BOOL willShowConsole        = [showConsole state]==NSOnState;
    BOOL willPublicLibraryDebug = [publicLibraryDebug state]==NSOnState;
	BOOL willCleanBuild         = [cleanBuildFiles state]==NSOnState;
	BOOL willAlsoCleanIndex     = [alsoCleanIndexFiles state]==NSOnState;
	NSString* interpreter       = interpreters[[[glulxInterpreter selectedItem] tag]];
	
	// Set the shared preferences to suitable values
	[[IFPreferences sharedPreferences] setRunBuildSh: willBuildSh];
    [[IFPreferences sharedPreferences] setAlwaysCompile: willAlwaysCompile];
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
	
	interpreters = [[NSMutableArray alloc] initWithArray: [[NSBundle mainBundle] infoDictionary][@"InformConfiguration"][@"AvailableInterpreters"]];
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
			selIndex = (int)[terpMenu numberOfItems];
		}
		
		// Add it to the menu
		[terpMenu addItem: newItem];

	}
	
	// Select the appropriate item in the menu
	[glulxInterpreter selectItemAtIndex: selIndex];
	
    // Hide buttons that won't work when sandboxed
    [runBuildSh         setHidden: [IFUtility isSandboxed]];
    [publicLibraryDebug setHidden: [IFUtility isSandboxed]];

	// Set the buttons according to the current state of the preferences
	[runBuildSh          setState: [[IFPreferences sharedPreferences] runBuildSh]               ? NSOnState : NSOffState];
    [alwaysCompile       setState: [[IFPreferences sharedPreferences] alwaysCompile]            ? NSOnState : NSOffState];
	[showDebugLogs       setState: [[IFPreferences sharedPreferences] showDebuggingLogs]        ? NSOnState : NSOffState];
    [showConsole         setState: [[IFPreferences sharedPreferences] showConsoleDuringBuilds]  ? NSOnState : NSOffState];
    [publicLibraryDebug  setState: [[IFPreferences sharedPreferences] publicLibraryDebug]       ? NSOnState : NSOffState];
	
	[cleanBuildFiles setState: [[IFPreferences sharedPreferences] cleanProjectOnClose]          ? NSOnState : NSOffState];
	
	if ([[IFPreferences sharedPreferences] cleanProjectOnClose]) {
		[alsoCleanIndexFiles setState: [[IFPreferences sharedPreferences] alsoCleanIndexFiles]  ? NSOnState : NSOffState];
		[alsoCleanIndexFiles setEnabled: YES];
	} else {
		[alsoCleanIndexFiles setState: NSOffState];
		[alsoCleanIndexFiles setEnabled: NO];
	}
}

@end
