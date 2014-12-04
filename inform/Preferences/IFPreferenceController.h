//
//  IFPreferenceController.h
//  Inform
//
//  Created by Andrew Hunter on 12/01/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFPreferencePane.h"

///
/// Preferences are different from settings (settings are per-project, preferences are global)
/// There's some overlap, though. In particular, installed extensions is global, but can be
/// controlled from an individual project's Settings as well as overall.
///
@interface IFPreferenceController : NSWindowController<NSWindowDelegate, NSToolbarDelegate> {
	// The toolbar
	NSToolbar* preferenceToolbar;					// Contains the list of settings panes
	NSMutableArray* preferenceViews;				// The settings panes themselves
	NSMutableDictionary* toolbarItems;				// The toolbar items
}

// Construction, etc
+ (IFPreferenceController*) sharedPreferenceController;				// The general preference controller

// Adding new preference views
- (void) addPreferencePane: (IFPreferencePane*) newPane;			// Adds a new preference pane
- (void) removeAllPreferencePanes;

// Choosing a preference pane
- (void) switchToPreferencePane: (NSString*) paneIdentifier;		// Switches to a specific preference pane
- (IFPreferencePane*) preferencePane: (NSString*) paneIdentifier;	// Retrieves a pane with a specific identifier

@end
