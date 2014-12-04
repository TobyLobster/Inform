//
//  IFTranscriptPage.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFPage.h"
#import "IFTranscriptView.h"
#import "IFTranscriptLayout.h"

//
// The 'transcript' page
//
@interface IFTranscriptPage : IFPage {
	// The transcript view
	IBOutlet IFTranscriptView* transcriptView;			// The transcript view	
	
	// The page bar cells
	IFPageBarCell* blessAllCell;
	IFPageBarCell* nextDiffCell;
	IFPageBarCell* prevDiffCell;
	IFPageBarCell* nextBySkeinCell;
}

// The transcript view
- (IFTranscriptView*) transcriptView;							// Returns the transcript view object associated with this pane
- (IFTranscriptLayout*) transcriptLayout;						// Returns the transcript layout object associated with this pane

- (IBAction) transcriptBlessAll: (id) sender;					// Causes, after a confirmation, all the items in the transcript to be blessed

- (id) initWithProjectController: (IFProjectController*) controller;

@end
