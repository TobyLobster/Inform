//
//  IFPreferenceController.h
//  Inform
//
//  Created by Andrew Hunter on 12/01/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class IFPreferencePane;

///
/// Preferences are different from settings (settings are per-project, preferences are global)
/// There's some overlap, though. In particular, installed extensions is global, but can be
/// controlled from an individual project's Settings as well as overall.
///
@interface IFPreferenceController : NSWindowController<NSWindowDelegate, NSToolbarDelegate>

// Construction, etc
+ (IFPreferenceController*) sharedPreferenceController;				// The general preference controller

// Adding new preference views
- (void) addPreferencePane: (IFPreferencePane*) newPane;			// Adds a new preference pane
- (void) removeAllPreferencePanes;

// Choosing a preference pane
- (void) switchToPreferencePane: (NSString*) paneIdentifier;		// Switches to a specific preference pane
- (IFPreferencePane*) preferencePane: (NSString*) paneIdentifier;	// Retrieves a pane with a specific identifier

@end
