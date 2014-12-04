//
//  IFPreferencePane.h
//  Inform
//
//  Created by Andrew Hunter on 01/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>


//
// Class that represents a specific preference pane in the preferences window
//
@interface IFPreferencePane : NSObject {
	IBOutlet NSView* preferenceView;				// The view for these preferences
}

- (id) initWithNibName: (NSString*) nibName;		// Initialises and loads the given nib

// Information about the preference window
- (NSImage*)  toolbarImage;							// The image that should show up in the toolbar
- (NSString*) preferenceName;						// The name of this pane (appears until the toolbar item)
- (NSString*) identifier;							// The unique identifier for this pane (subclasses don't need to override this)
- (NSString*) tooltip;								// The tooltip for this preference
- (NSView*)   preferenceView;						// The view that describes the UI for this preference pane

@end
