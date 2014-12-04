//
//  IFSkeinPage.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFPage.h"
#import <ZoomView/ZoomSkeinView.h>

//
// The 'skein' page
//
@interface IFSkeinPage : IFPage {
	// The skein view
	IBOutlet ZoomSkeinView* skeinView;					// The skein view
	int annotationCount;								// The number of annotations (labels)
	NSString* lastAnnotation;							// The last annotation skipped to using the label button
	
	// The page bar buttons
	IFPageBarCell* labelsCell;							// The 'Labels' button
	IFPageBarCell* playAllCell;							// The 'Play All Blessed' button
}

// The skein view
- (ZoomSkeinView*) skeinView;									// The skein view
- (IBAction) skeinLabelSelected: (id) sender;					// The user has selected a skein item from the drop-down list (so we should scroll there)
- (void) skeinDidChange: (NSNotification*) not;					// Called by Zoom to notify that the skein has changed

- (id) initWithProjectController: (IFProjectController*) controller;

@end
