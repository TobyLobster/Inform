//
//  IFCollapsableView.h
//  Inform
//
//  Created by Andrew Hunter on 06/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

///
/// Variant of ZoomCollapsableView. Used to display the set of settings views.
///
@interface IFCollapsableView : NSView

/// Adds a new subview with a given title
- (void) addSubview: (NSView*) subview
		  withTitle: (NSString*) title;
/// Cleans out all the subviews
- (void) removeAllSubviews;
/// Called when rearranging starts
- (void) startRearranging;
/// Called when rearranging finishes
- (void) finishRearranging;
/// Lays out the subviews
- (void) rearrangeSubviews;

@end
