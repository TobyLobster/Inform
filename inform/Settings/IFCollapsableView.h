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
@interface IFCollapsableView : NSView

- (void) addSubview: (NSView*) subview						// Adds a new subview with a given title
		  withTitle: (NSString*) title;
- (void) removeAllSubviews;									// Cleans out all the subviews
- (void) startRearranging;									// Called when rearranging starts
- (void) finishRearranging;									// Called when rearranging finishes
- (void) rearrangeSubviews;									// Lays out the subviews

@end
