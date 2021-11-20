//
//  IFInspectorView.h
//  Inform
//
//  Created by Andrew Hunter on Mon May 03 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>


///
/// The inspector view.
///
/// This contains the inspector, the title bar and the arrow used to open/close it.
/// These are created by \c IFInspectorWindow as required.
///
@interface IFInspectorView : NSView

// The view
/// Sets/retrieves the 'real' inspector view
@property (nonatomic, strong) NSView *view;
/// \c YES if the view is expanded
@property (atomic, getter=isExpanded) BOOL expanded;

/// Sets the title of the inspector view
- (void) setTitle: (NSString*) title;

/// If one is not already pending, queues up a layout request
- (void) queueLayout;
/// Lay out the various views as appropriate
- (void) layoutViews;


@end
