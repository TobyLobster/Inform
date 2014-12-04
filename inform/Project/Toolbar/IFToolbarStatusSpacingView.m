//
//  IFToolbarStatusSpacingView.m
//  Inform
//
//  Created by Toby Nelson, 2014.
//

#import "IFToolbarStatusSpacingView.h"
#import "IFUtility.h"
#import "IFImageCache.h"

@implementation IFToolbarStatusSpacingView

// Nothing to see here. This serves as a flexible spacing for the toolbar with a view that we can use to 
// position the "Status" view. See IFToolbarStatusView, and IFToolbarManager.

- (void)drawRect:(NSRect)dirtyRect {
    // For debugging:
    //[[NSColor blackColor] set];
    //[[NSBezierPath bezierPathWithRect:self.bounds] fill];
}

@end
