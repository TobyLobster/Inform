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
	self = [super initWithNibName: @"AdvancedPreferences"];
	
	if (self) {
		[self reflectCurrentPreferences];
		
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(reflectCurrentPreferences)
													 name: IFPreferencesAdvancedDidChangeNotification
												   object: [IFPreferences sharedPreferences]];
        openInformCorePanel = nil;
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

	// Set the shared preferences to suitable values
	[IFPreferences sharedPreferences].runBuildSh = willBuildSh;
    [IFPreferences sharedPreferences].alwaysCompile = willAlwaysCompile;
	[IFPreferences sharedPreferences].showDebuggingLogs = willDebug;
	[IFPreferences sharedPreferences].showConsoleDuringBuilds = willShowConsole;
  	[IFPreferences sharedPreferences].publicLibraryDebug = willPublicLibraryDebug;
	[IFPreferences sharedPreferences].cleanProjectOnClose = willCleanBuild;
	[IFPreferences sharedPreferences].alsoCleanIndexFiles = willAlsoCleanIndex;
	[IFPreferences sharedPreferences].glulxInterpreter = interpreter;
    [IFPreferences sharedPreferences].useExternalInformCoreDirectory = useInformCore;
    [IFPreferences sharedPreferences].externalInformCoreDirectory = informCoreDirectory;
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

    [panel setAccessoryView: nil];
    [panel setCanChooseFiles: NO];
    [panel setCanChooseDirectories: YES];
    [panel setResolvesAliases: YES];
    [panel setAllowsMultipleSelection: NO];
    panel.title = [IFUtility localizedString:@"Choose Inform Core directory"];
    //[panel setDelegate: self];    // Extensions manager determines which file types are valid to choose (panel:shouldShowFilename:)

    [panel beginWithCompletionHandler:^(NSInteger result)
    {
        [panel setDelegate: nil];

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
		if ([terp isEqualToString: [IFPreferences sharedPreferences].glulxInterpreter]) {
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
	runBuildSh.state = [IFPreferences sharedPreferences].runBuildSh              ? NSControlStateValueOn : NSControlStateValueOff;
    alwaysCompile.state = [IFPreferences sharedPreferences].alwaysCompile           ? NSControlStateValueOn : NSControlStateValueOff;
	showDebugLogs.state = [IFPreferences sharedPreferences].showDebuggingLogs       ? NSControlStateValueOn : NSControlStateValueOff;
    showConsole.state = [IFPreferences sharedPreferences].showConsoleDuringBuilds ? NSControlStateValueOn : NSControlStateValueOff;
    publicLibraryDebug.state = [IFPreferences sharedPreferences].publicLibraryDebug      ? NSControlStateValueOn : NSControlStateValueOff;

	cleanBuildFiles.state = [IFPreferences sharedPreferences].cleanProjectOnClose         ? NSControlStateValueOn : NSControlStateValueOff;
	
	if ([IFPreferences sharedPreferences].cleanProjectOnClose) {
		alsoCleanIndexFiles.state = [IFPreferences sharedPreferences].alsoCleanIndexFiles ? NSControlStateValueOn : NSControlStateValueOff;
		[alsoCleanIndexFiles setEnabled: YES];
	} else {
		alsoCleanIndexFiles.state = NSControlStateValueOff;
		[alsoCleanIndexFiles setEnabled: NO];
	}

    // External inform core
    useExternalInformCore.state = [IFPreferences sharedPreferences].useExternalInformCoreDirectory ? NSControlStateValueOn : NSControlStateValueOff;
    externalInformCoreDirectory.stringValue = [IFPreferences sharedPreferences].externalInformCoreDirectory;

    // Set text colour of label, based on if the 'Use Inform Core directory' is checked.
    BOOL use = [IFPreferences sharedPreferences].useExternalInformCoreDirectory;
    if (!use) {
        externalInformCoreDirectory.textColor = [NSColor secondarySelectedControlColor];
    } else {
        externalInformCoreDirectory.textColor = [NSColor controlTextColor];
    }
}

@end
