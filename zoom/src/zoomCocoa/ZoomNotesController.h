//
//  ZoomNotesController.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 30/12/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <ZoomPlugIns/ZoomStory.h>

///
/// Window controller for the Zoom notes window
///
@interface ZoomNotesController : NSWindowController {
	/// The object that owns the note window
	__weak id owner;
	/// The story which we should show notes for
	ZoomStory* story;
	
	/// The control that contains the notes
	IBOutlet NSTextView* notes;
}

// The shared controller
/// The shared notes controller
+ (ZoomNotesController*) sharedNotesController;

// Setting up the window
/// Set the story whose notes we should show (nil for no notes)
- (void) setGameInfo: (ZoomStory*) story;
/// The story which we should show notes for
@property (nonatomic, strong) ZoomStory *gameInfo;

//! The object that owns the note window
@property (readwrite, weak) id infoOwner;
/// Sets the 'owner' for the notes window [NOT RETAINED]
- (void) setInfoOwner: (id) owner;
/// Retrieves the 'owner' for the notes window
- (id) infoOwner;

@end
