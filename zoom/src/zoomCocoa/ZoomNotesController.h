//
//  ZoomNotesController.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 30/12/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZoomStory.h"

///
/// Window controller for the Zoom notes window
///
@interface ZoomNotesController : NSWindowController {
	id owner;													// The object that owns the note window
	ZoomStory* story;											// The story which we should show notes for
	
	IBOutlet NSTextView* notes;									// The control that contains the notes
}

// The shared controller
+ (ZoomNotesController*) sharedNotesController;					// The shared notes controller

// Setting up the window
- (void) setGameInfo: (ZoomStory*) story;						// Set the story whose notes we should show (nil for no notes)
- (void) setInfoOwner: (id) owner;								// Sets the 'owner' for the notes window [NOT RETAINED]
- (id) infoOwner;													// Retrieves the 'owner' for the notes window

@end
