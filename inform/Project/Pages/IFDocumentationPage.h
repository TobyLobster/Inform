//
//  IFDocumentationPage.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFPage.h"

#import "IFPageBarCell.h"

//
// The 'documentation' page
//
@interface IFDocumentationPage : IFPage {
	// The documentation view
	WebView* wView;										// The web view that displays the documentation
	
	// Page cells
	IFPageBarCell* contentsCell;						// The 'table of contents' cell
	IFPageBarCell* examplesCell;						// The 'Examples' cell
	IFPageBarCell* generalIndexCell;					// The 'General Index' cell
    NSDictionary* tabDictionary;                        // Maps URL paths to cells
    
    bool reloadingBecauseCensusCompleted;
}

// The documentation view
- (void) openURL: (NSURL*) url;							// Tells the documentation view to open a specific URL
- (IBAction) showToc: (id) sender;						// Opens the table of contents

- (id) initWithProjectController: (IFProjectController*) controller;

@end
