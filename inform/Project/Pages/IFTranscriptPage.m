//
//  IFTranscriptPage.m
//  Inform-xc2
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFTranscriptPage.h"
#import "IFProject.h"
#import "IFProjectPane.h"
#import "IFProjectController.h"
#import "IFImageCache.h"
#import "IFUtility.h"

@implementation IFTranscriptPage

// = Initialisation =

- (id) initWithProjectController: (IFProjectController*) controller {
	self = [super initWithNibName: @"Transcript"
				projectController: controller];
	
	if (self) {
		IFProject* doc = [parent document];
		
		// The transcript
		[[transcriptView transcriptLayout] setSkein: [doc skein]];
		[transcriptView setDelegate: self];
		
		// The page bar cells
		blessAllCell = [[IFPageBarCell alloc] initTextCell: [IFUtility localizedString: @"Bless All Button"
                                                                               default: @"Bless All"]];
		
		[blessAllCell setTarget: self];
		[blessAllCell setAction: @selector(transcriptBlessAll:)];

		nextDiffCell = [[IFPageBarCell alloc] initTextCell: [IFUtility localizedString: @"Next Difference Button"
                                                                               default: @"Next"]];
		[nextDiffCell setImage: [IFImageCache loadResourceImage: @"App/PageBar/NextDiff.png"]];
		[nextDiffCell setTarget: self];
		[nextDiffCell setAction: @selector(nextDiff:)];

		prevDiffCell = [[IFPageBarCell alloc] initTextCell: [IFUtility localizedString: @"Previous Difference Button"
                                                                               default: @"Previous"]];
		[prevDiffCell setImage: [IFImageCache loadResourceImage: @"App/PageBar/PrevDiff.png"]];
		[prevDiffCell setTarget: self];
		[prevDiffCell setAction: @selector(prevDiff:)];

		nextBySkeinCell = [[IFPageBarCell alloc] initTextCell: [IFUtility localizedString: @"Next by Skein Button"
                                                                                  default: @"Next by Skein"]];
		[nextBySkeinCell setImage: [IFImageCache loadResourceImage: @"App/PageBar/NextBySkein.png"]];
		[nextBySkeinCell setTarget: self];
		[nextBySkeinCell setAction: @selector(nextDiffBySkein:)];
	}
	
	return self;
}

- (void) dealloc {
	[transcriptView setDelegate: nil];
	[blessAllCell release];
	[nextBySkeinCell release];
	[prevDiffCell release];
	[nextDiffCell release];

	[super dealloc];
}

// = Details about this view =

- (NSString*) title {
	return [IFUtility localizedString: @"Transcript Page Title"
                              default: @"Transcript"];
}

// = The transcript view =

- (IFTranscriptLayout*) transcriptLayout {
	return [transcriptView transcriptLayout];
}

- (IFTranscriptView*) transcriptView {
	return transcriptView;
}

- (void) transcriptPlayToItem: (ZoomSkeinItem*) itemToPlayTo {
	ZoomSkein* skein = [[parent document] skein];
	ZoomSkeinItem* activeItem = [skein activeItem];
	
	ZoomSkeinItem* firstPoint = nil;
	
	// See if the active item is a parent of the point we're playing to (in which case, continue playing. Otherwise, restart and play to that point)
	ZoomSkeinItem* parentItem = [itemToPlayTo parent];
	while (parentItem) {
		if (parentItem == activeItem) {
			firstPoint = activeItem;
			break;
		}
		
		parentItem = [parentItem parent];
	}
	
	if (firstPoint == nil) {
        [parent stopProcess: self];
		firstPoint = [skein rootItem];
	}
	
	// Play to this point
	[parent playToPoint: itemToPlayTo
			  fromPoint: firstPoint];
}

- (void) transcriptShowKnot: (ZoomSkeinItem*) knot {
	// Switch to the skein view
	IFProjectPane* skeinPane = [parent skeinPane];
	
	[skeinPane selectViewOfType: IFSkeinPane];
	
	// Scroll to the knot
	[[[skeinPane skeinPage] skeinView] scrollToItem: knot];
}

- (IBAction) transcriptBlessAll: (id) sender {
	// Display a confirmation dialog (as this can't be undone. Well, not easily)
	NSBeginAlertSheet([IFUtility localizedString: @"Are you sure you want to bless all these items?"],
					  [IFUtility localizedString: @"Bless All"],
					  [IFUtility localizedString: @"Cancel"],
					  nil, [transcriptView window], self, 
					  @selector(transcriptBlessAllDidEnd:returnCode:contextInfo:), nil,
					  nil, @"%@", [IFUtility localizedString: @"Bless all explanation"]);
}

- (void) transcriptBlessAllDidEnd: (NSWindow*) sheet
					   returnCode: (int) returnCode
					  contextInfo: (void*) contextInfo {
	if (returnCode == NSAlertDefaultReturn) {
		[transcriptView blessAll];
	} else {
	}
}

// = The page bar =

- (NSArray*) toolbarCells {
	return [NSArray arrayWithObjects: blessAllCell, prevDiffCell, nextDiffCell, nextBySkeinCell, nil];
}

- (void) nextDiffBySkein: (id) sender {
	[parent nextDifferenceBySkein: self];
}

- (void) nextDiff: (id) sender {
	[parent nextDifference: self];
}

- (void) prevDiff: (id) sender {
	[parent lastDifference: self];
}

@end
