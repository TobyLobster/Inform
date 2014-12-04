//
//  IFInspectorView.h
//  Inform
//
//  Created by Andrew Hunter on Mon May 03 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

#import "IFIsTitleView.h"
#import "IFIsArrow.h"

//
// The inspector view.
//
// This contains the inspector, the title bar and the arrow used to open/close it.
// These are created by IFInspectorWindow as required.
//
@interface IFInspectorView : NSView {
	NSView* innerView;										// The actual inspector view
	
	IFIsTitleView* titleView;								// The title bar view
	IFIsArrow*     arrow;									// The open/closed arrow
	
	BOOL willLayout;										// YES if a layout event is pending
}

// The view
- (void) setTitle: (NSString*) title;						// Sets the title of the inspector view
- (void) setView: (NSView*) innerView;						// Sets the 'real' inspector view
- (NSView*) view;											// Retrieves the 'real' inspector view

- (void) queueLayout;										// If one is not already pending, queues up a layout request
- (void) layoutViews;										// Lay out the various views as appropriate

- (void) setExpanded: (BOOL) isExpanded;					// Sets whether or not this view is expanded (showing the 'real' view)
- (BOOL) expanded;											// YES if the view is expanded

@end
