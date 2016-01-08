//
//  IFIndexPage.h
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <WebKit/WebKit.h>
#import <Cocoa/Cocoa.h>
#import "IFPage.h"

typedef enum IFIndexTabType {
    IFIndexWelcome      = 1,
	IFIndexContents     = 2,
	IFIndexActions      = 3,
	IFIndexKinds        = 4,
	IFIndexPhrasebook   = 5,
	IFIndexRules        = 6,
	IFIndexScenes       = 7,
	IFIndexWorld        = 8,
} IFIndexTabType;

//
// The 'Index' page
//
@interface IFIndexPage : IFPage<WebFrameLoadDelegate>

// The index view
@property (atomic, readonly) BOOL indexAvailable;               // YES if the index tab is available

- (void) updateIndexView;										// Updates the index view with the current files in the index subdirectory
- (BOOL) canSelectIndexTab: (int) whichTab;						// Returns YES if we can select a specific tab in the index pane
- (void) switchToTab: (int) tabIdentifier;                      // Chooses a specific tab
- (IBAction) switchToCell: (id) sender;							// Switches to the page specified by the given cell

- (instancetype) initWithProjectController: (IFProjectController*) controller;

@end
