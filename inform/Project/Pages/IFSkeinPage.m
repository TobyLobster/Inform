//
//  IFSkeinPage.m
//  Inform-xc2
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFSkeinPage.h"
#import "IFProject.h"
#import "IFPreferences.h"
#import "IFUtility.h"

@implementation IFSkeinPage

// = Initialisation =

- (id) initWithProjectController: (IFProjectController*) controller {
	self = [super initWithNibName: @"Skein"
				projectController: controller];

	if (self) {
		IFProject* doc = [parent document];

		// The skein view
		[skeinView setSkein: [doc skein]];
		[skeinView setDelegate: parent];

		[skeinView setItemWidth: 82.0f];
		[skeinView setItemHeight: 64.0f];

		// (Problem with this is that it updates the menu on every change, which might get to be slow)
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(skeinDidChange:)
													 name: ZoomSkeinChangedNotification
												   object: [doc skein]];

		// Create the cells for the page bar
		labelsCell  = [[IFPageBarCell alloc] initTextCell: [IFUtility localizedString: @"Labels"]];
		playAllCell = [[IFPageBarCell alloc] initTextCell: [IFUtility localizedString: @"Play All Blessed"]];

		[labelsCell setMenu: [[[NSMenu alloc] init] autorelease]];
        
		[playAllCell setTarget: self];
		[playAllCell setAction: @selector(replayEntireSkein:)];

		// Update the skein settings
		[self skeinDidChange: nil];
		[skeinView scrollToItem: [[doc skein] rootItem]];
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	if (lastAnnotation) [lastAnnotation release];
	
	[playAllCell release];
	[labelsCell release];
	
	[super dealloc];
}

// = Details about this view =

- (NSString*) title {
	return [IFUtility localizedString: @"Skein Page Title"
                              default: @"Skein"];
}

// = The skein view =

- (ZoomSkeinView*) skeinView {
	return skeinView;
}

- (void) skeinDidChange: (NSNotification*) not {
	[labelsCell setMenu: [[[parent document] skein] populateMenuWithAction: @selector(skeinLabelSelected:)
																	target: self]];
}

- (void) clearSkeinDidEnd: (NSWindow*) sheet
			   returnCode: (int) returnCode
			  contextInfo: (void*) contextInfo {
	if (returnCode == NSAlertAlternateReturn) {
		ZoomSkein* skein = [[parent document] skein];
		
		[skein removeTemporaryItems: 0];
		[skein zoomSkeinChanged];
	}
}

- (IBAction) skeinLabelSelected: (id) sender {
	NSMenuItem* menuItem;
	
	if ([sender isKindOfClass: [NSMenuItem class]]) {
		menuItem = sender;
	} else {
		menuItem = [sender selectedItem];
	}
	
	NSString* annotation = [menuItem title];
	
	// Reset the annotation count if required
	if (![annotation isEqualToString: lastAnnotation]) {
		annotationCount = 0;
	}
	
	[lastAnnotation release];
	lastAnnotation = [annotation retain];
	
	// Get the list of items for this annotation
	NSArray* availableItems = [[[parent document] skein] itemsWithAnnotation: lastAnnotation];
	if (!availableItems || [availableItems count] == 0) return;
	
	// Reset the annotation count if required
	if ([availableItems count] <= annotationCount) annotationCount = 0;
	
	// Scroll to the appropriate item
	[skeinView scrollToItem: [availableItems objectAtIndex: annotationCount]];
	
	// Will scroll to the next item in the list if there's more than one
	annotationCount++;
}

- (IBAction) replayEntireSkein: (id) sender {
	[[NSApp targetForAction: @selector(replayEntireSkein:)] replayEntireSkein: sender];
}

// = The page bar =

- (NSArray*) toolbarCells {
	return [NSArray arrayWithObjects: playAllCell, labelsCell, nil];
}

@end
