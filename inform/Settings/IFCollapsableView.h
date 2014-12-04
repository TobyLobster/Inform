//
//  IFCollapsableView.h
//  Inform
//
//  Created by Andrew Hunter on 06/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

//
// Variant of ZoomCollapsableView. Used to display the set of settings views.
//
@interface IFCollapsableView : NSView {
	NSMutableArray* views;						// Views to display
	NSMutableArray* titles;						// Titles of views to display (one-to-one mapping with views)
	NSMutableArray* states;						// Booleans, indicating if each view is shown or not. (UNUSED)
	
	BOOL rearranging;							// YES if a rearrangement is in progress
	BOOL reiterate;								// Set to YES to stop resizing that occurs while rearranging from causing infinite recursion (delays resizes if YES). Useful if we have, for example, auto-hiding scrollbars
}

- (void) addSubview: (NSView*) subview						// Adds a new subview with a given title
		  withTitle: (NSString*) title;
- (void) removeAllSubviews;									// Cleans out all the subviews
- (void) startRearranging;									// Called when rearranging starts
- (void) finishRearranging;									// Called when rearranging finishes
- (void) rearrangeSubviews;									// Lays out the subviews

@end
