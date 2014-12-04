//
//  IFAdvancedPreferences.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 12/10/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFPreferencePane.h"


//
// Preference pane that contains options mainly intended for use by Inform 7 maintainers
//
@interface IFAdvancedPreferences : IFPreferencePane {
	IBOutlet NSButton* showDebugLogs;					// If checked, show the Inform 6 source and Inform 7 debugging logs
	IBOutlet NSButton* runBuildSh;						// Causes the Inform 7 build process to be run
	IBOutlet NSButton* showConsole;                     // If checked, show the Console during building
	IBOutlet NSButton* publicLibraryDebug;              // If checked, the public library is accessed from a different location (for debugging)
	
	IBOutlet NSButton* cleanBuildFiles;					// If checked, build files are cleaned out
	IBOutlet NSButton* alsoCleanIndexFiles;				// If checked, index files are cleaned out in addition to build files
	IBOutlet NSPopUpButton*	glulxInterpreter;			// The glulx interpreter to use
	
	NSMutableArray* interpreters;						// Array of interpreter names, indexed by tags in the glulxInterpreter menu
}

// Actions
- (IBAction) setPreference: (id) sender;				// Causes this view to update its preferences based on the values of the buttons
- (void) reflectCurrentPreferences;						// Causes this view to update its preferences according to the current values set in the preferences

@end
