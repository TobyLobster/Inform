//
//  IFInspectorView.h
//  Inform
//
//  Created by Andrew Hunter on Mon May 03 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>


//
// The inspector view.
//
// This contains the inspector, the title bar and the arrow used to open/close it.
// These are created by IFInspectorWindow as required.
//
@interface IFInspectorView : NSView

// The view
@property (atomic, strong) NSView *view;					// Sets/retrieves the 'real' inspector view
@property (atomic) BOOL expanded;							// YES if the view is expanded

- (void) setTitle: (NSString*) title;						// Sets the title of the inspector view

- (void) queueLayout;										// If one is not already pending, queues up a layout request
- (void) layoutViews;										// Lay out the various views as appropriate


@end
