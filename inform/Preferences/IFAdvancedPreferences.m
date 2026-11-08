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
    /// The preferences the pane shows and sets
    IFPreferences* preferences;

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

    /// If checked, use the external Inform Core directory
    IBOutlet NSButton* useExternalInformCore;
    /// Text field to show the external Inform Core driectory
    IBOutlet NSTextField* externalInformCoreDirectory;
    NSOpenPanel* openInformCorePanel;

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
	return [self initWithPreferences: [IFPreferences sharedPreferences]];
}

- (instancetype) initWithPreferences: (IFPreferences*) thePreferences {
	self = [super initWithNibName: @"AdvancedPreferences"];
	
	if (self) {
		preferences = thePreferences;
		[self reflectCurrentPreferences];
		
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(reflectCurrentPreferences)
													 name: IFPreferencesAdvancedDidChangeNotification
												   object: preferences];
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
	BOOL willBuildSh            = runBuildSh.state==NSControlStateValueOn;
    BOOL willAlwaysCompile      = alwaysCompile.state==NSControlStateValueOn;
	BOOL willDebug              = showDebugLogs.state==NSControlStateValueOn;
    BOOL willShowConsole        = showConsole.state==NSControlStateValueOn;
    BOOL willPublicLibraryDebug = publicLibraryDebug.state==NSControlStateValueOn;
	BOOL willCleanBuild         = cleanBuildFiles.state==NSControlStateValueOn;
	BOOL willAlsoCleanIndex     = alsoCleanIndexFiles.state==NSControlStateValueOn;
	NSString* interpreter       = interpreters[glulxInterpreter.selectedItem.tag];
    BOOL useInformCore          = useExternalInformCore.state==NSControlStateValueOn;
    NSString* informCoreDirectory = externalInformCoreDirectory.stringValue;

	// Set the preferences to suitable values
	preferences.runBuildSh = willBuildSh;
    preferences.alwaysCompile = willAlwaysCompile;
	preferences.showDebuggingLogs = willDebug;
	preferences.showConsoleDuringBuilds = willShowConsole;
  	preferences.publicLibraryDebug = willPublicLibraryDebug;
	preferences.cleanProjectOnClose = willCleanBuild;
	preferences.alsoCleanIndexFiles = willAlsoCleanIndex;
	preferences.glulxInterpreter = interpreter;
    preferences.useExternalInformCoreDirectory = useInformCore;
    preferences.externalInformCoreDirectory = informCoreDirectory;
}

- (IBAction) toggleUseExternalDirectory: (id) sender {
    [self setPreference: sender];

    [self reflectCurrentPreferences];
}

- (IBAction) chooseExternalInformCoreDirectory: (id) sender {
    // Present a panel for choosing an external Inform Core directory
    NSOpenPanel* panel;

    if (!openInformCorePanel) {
        openInformCorePanel = [NSOpenPanel openPanel];
    }
    panel = openInformCorePanel;

    [panel setCanChooseFiles: NO];
    [panel setCanChooseDirectories: YES];
    [panel setResolvesAliases: YES];
    [panel setAllowsMultipleSelection: NO];
    panel.title = [IFUtility localizedString:@"Choose Inform Core directory"];

    [panel beginWithCompletionHandler:^(NSInteger result)
    {
        if (result != NSModalResponseOK) return;

        self->externalInformCoreDirectory.stringValue = panel.URL.path;
        self->useExternalInformCore.state = NSControlStateValueOn;
        [self setPreference: sender];
     }];
}

- (void) reflectCurrentPreferences {
	// Update the list of interpreters
	NSMenu* terpMenu = glulxInterpreter.menu;
	while (terpMenu.numberOfItems > 0) { [terpMenu removeItemAtIndex: 0]; }
	
	interpreters = [[NSMutableArray alloc] initWithArray: [NSBundle mainBundle].infoDictionary[@"InformConfiguration"][@"AvailableInterpreters"]];
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
		newItem.tag = terpMenu.numberOfItems;
		if ([terp isEqualToString: preferences.glulxInterpreter]) {
			selIndex = (int)terpMenu.numberOfItems;
		}
		
		// Add it to the menu
		[terpMenu addItem: newItem];

	}
	
	// Select the appropriate item in the menu
	[glulxInterpreter selectItemAtIndex: selIndex];
	
    // Hide buttons that won't work when sandboxed
    runBuildSh.hidden = [IFUtility isSandboxed];
    publicLibraryDebug.hidden = [IFUtility isSandboxed];

	// Set the buttons according to the current state of the preferences
	runBuildSh.state = preferences.runBuildSh              ? NSControlStateValueOn : NSControlStateValueOff;
    alwaysCompile.state = preferences.alwaysCompile           ? NSControlStateValueOn : NSControlStateValueOff;
	showDebugLogs.state = preferences.showDebuggingLogs       ? NSControlStateValueOn : NSControlStateValueOff;
    showConsole.state = preferences.showConsoleDuringBuilds ? NSControlStateValueOn : NSControlStateValueOff;
    publicLibraryDebug.state = preferences.publicLibraryDebug      ? NSControlStateValueOn : NSControlStateValueOff;

	cleanBuildFiles.state = preferences.cleanProjectOnClose         ? NSControlStateValueOn : NSControlStateValueOff;
	
	if (preferences.cleanProjectOnClose) {
		alsoCleanIndexFiles.state = preferences.alsoCleanIndexFiles ? NSControlStateValueOn : NSControlStateValueOff;
		[alsoCleanIndexFiles setEnabled: YES];
	} else {
		alsoCleanIndexFiles.state = NSControlStateValueOff;
		[alsoCleanIndexFiles setEnabled: NO];
	}

    // External inform core
    useExternalInformCore.state = preferences.useExternalInformCoreDirectory ? NSControlStateValueOn : NSControlStateValueOff;
    externalInformCoreDirectory.stringValue = preferences.externalInformCoreDirectory;

    // Set text colour of label, based on if the 'Use Inform Core directory' is checked.
    BOOL use = preferences.useExternalInformCoreDirectory;
    if (!use) {
        externalInformCoreDirectory.textColor = [NSColor disabledControlTextColor];
    } else {
        externalInformCoreDirectory.textColor = [NSColor controlTextColor];
    }
}

@end
