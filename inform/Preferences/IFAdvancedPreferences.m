//
//  IFAdvancedPreferences.m
//  Inform
//
//  Created by Andrew Hunter on 12/10/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "IFAdvancedPreferences.h"
#import "IFPreferences.h"
#import "IFUtility.h"

@implementation IFAdvancedPreferences {
    /// If checked, show the Inform 6 source and Inform 7 debugging logs
    IBOutlet NSButton* showDebugLogs;
    /// Causes the Inform 7 build process to be run
    IBOutlet NSButton* runBuildSh;
    /// If checked, always compile the story (no make-style dependency checking)
    IBOutlet NSButton* alwaysCompile;
    /// If checked, show the Console during building
    IBOutlet NSButton* showConsole;
    /// If checked, the public library is accessed from a different location (for debugging)
    IBOutlet NSButton* publicLibraryDebug;

    /// If checked, build files are cleaned out
    IBOutlet NSButton* cleanBuildFiles;
    /// If checked, index files are cleaned out in addition to build files
    IBOutlet NSButton* alsoCleanIndexFiles;
    /// The glulx interpreter to use
    IBOutlet NSPopUpButton*	glulxInterpreter;

    /// Array of interpreter names, indexed by tags in the glulxInterpreter menu
    NSMutableArray<NSString*>* interpreters;
}

#pragma mark - Initialisation

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


#pragma mark - Preference overrides

- (NSString*) preferenceName {
	return @"Advanced";
}

- (NSImage*) toolbarImage {
    return [[NSBundle bundleForClass: [self class]] imageForResource: @"App/gearshape.2"];
}

- (NSString*) tooltip {
	return [IFUtility localizedString: @"Advanced preferences tooltip"];
}

#pragma mark - Actions

- (IBAction) setPreference: (id) sender {
	// Read the current state of the buttons
	BOOL willBuildSh            = [runBuildSh state]==NSControlStateValueOn;
    BOOL willAlwaysCompile      = [alwaysCompile state]==NSControlStateValueOn;
	BOOL willDebug              = [showDebugLogs state]==NSControlStateValueOn;
    BOOL willShowConsole        = [showConsole state]==NSControlStateValueOn;
    BOOL willPublicLibraryDebug = [publicLibraryDebug state]==NSControlStateValueOn;
	BOOL willCleanBuild         = [cleanBuildFiles state]==NSControlStateValueOn;
	BOOL willAlsoCleanIndex     = [alsoCleanIndexFiles state]==NSControlStateValueOn;
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
	[runBuildSh          setState: [[IFPreferences sharedPreferences] runBuildSh]               ? NSControlStateValueOn : NSControlStateValueOff];
    [alwaysCompile       setState: [[IFPreferences sharedPreferences] alwaysCompile]            ? NSControlStateValueOn : NSControlStateValueOff];
	[showDebugLogs       setState: [[IFPreferences sharedPreferences] showDebuggingLogs]        ? NSControlStateValueOn : NSControlStateValueOff];
    [showConsole         setState: [[IFPreferences sharedPreferences] showConsoleDuringBuilds]  ? NSControlStateValueOn : NSControlStateValueOff];
    [publicLibraryDebug  setState: [[IFPreferences sharedPreferences] publicLibraryDebug]       ? NSControlStateValueOn : NSControlStateValueOff];
	
	[cleanBuildFiles setState: [[IFPreferences sharedPreferences] cleanProjectOnClose]          ? NSControlStateValueOn : NSControlStateValueOff];
	
	if ([[IFPreferences sharedPreferences] cleanProjectOnClose]) {
		[alsoCleanIndexFiles setState: [[IFPreferences sharedPreferences] alsoCleanIndexFiles]  ? NSControlStateValueOn : NSControlStateValueOff];
		[alsoCleanIndexFiles setEnabled: YES];
	} else {
		[alsoCleanIndexFiles setState: NSControlStateValueOff];
		[alsoCleanIndexFiles setEnabled: NO];
	}
}

@end
