//
//  IFIndexPage.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFPage.h"

enum IFIndexTabType {
    IFIndexWelcome = 1,
	IFIndexContents = 2,
	IFIndexActions = 3,
	IFIndexKinds = 4,
	IFIndexPhrasebook = 5,
	IFIndexRules = 6,
	IFIndexScenes = 7,
	IFIndexWorld = 8,
};

//
// The 'Index' page
//
@interface IFIndexPage : IFPage {
	BOOL indexAvailable;								// YES if the index tab should be active
	
	int indexMachineSelection;							// A reference count - number of 'machine' operations that might be affecting the index tab selection
	
	NSMutableArray* indexCells;							// IFPageBarCells used to select index pages
    NSDictionary* tabDictionary;                        // Dictionary of tab ids and their string names
    
    WebView* webView;
}

// The index view
- (void) updateIndexView;										// Updates the index view with the current files in the index subdirectory
- (BOOL) canSelectIndexTab: (int) whichTab;						// Returns YES if we can select a specific tab in the index pane
- (void) switchToTab: (int) tabIdentifier;                      // Chooses a specific tab
- (BOOL) indexAvailable;										// YES if the index tab is available
- (IBAction) switchToCell: (id) sender;							// Switches to the page specified by the given cell

- (id) initWithProjectController: (IFProjectController*) controller;

@end
