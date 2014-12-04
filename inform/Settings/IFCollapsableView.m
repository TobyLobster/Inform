//
//  IFCollapsableView.m
//  Inform
//
//  Created by Andrew Hunter on 06/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

// Based around 'ZoomCollapsableView', used by Zoom for the iFiction drawer.
// We want this for our preferences tab

#import "IFCollapsableView.h"


@implementation IFCollapsableView

#define BORDER 8.0
#define FONTSIZE 13.0

// = Init/housekeeping =

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		views = [[NSMutableArray alloc] init];
		titles = [[NSMutableArray alloc] init];
		states = [[NSMutableArray alloc] init];
		
		rearranging = NO;
	}
    return self;
}

- (void) dealloc {
	[views release];
	[titles release];
	[states release];

	[[NSNotificationCenter defaultCenter] removeObserver: self];

	[super dealloc];
}

// = Drawing =
- (BOOL) isOpaque {
	return NO;
}

- (void)drawRect:(NSRect)rect {
	NSFont* titleFont = [NSFont boldSystemFontOfSize: FONTSIZE];
	NSDictionary* titleAttributes = 
		[NSDictionary dictionaryWithObjectsAndKeys: 
			titleFont, NSFontAttributeName,
			[NSColor blackColor], NSForegroundColorAttributeName,
			nil];
	
	// Draw the titles and frames
	NSColor* frameColour = [NSColor colorWithDeviceRed: 0.5
												 green: 0.5
												  blue: 0.5
												 alpha: 1.0];

    // Calculate the maximum width of all subviews
    int maxWidth = 0;
	for (int x=0; x<[views count]; x++) {
		NSView* thisView = [views objectAtIndex: x];
		NSRect thisFrame = [thisView frame];
        
        maxWidth = MAX(maxWidth, (int) thisFrame.size.width);
    }

	for (int x=0; x<[views count]; x++) {
		NSView* thisView = [views objectAtIndex: x];
		NSString* thisTitle = [titles objectAtIndex: x];
		//BOOL visible = [[states objectAtIndex: x] boolValue];
		
		NSSize titleSize = [thisTitle sizeWithAttributes: titleAttributes];
		NSRect thisFrame = [thisView frame];
		
		float ypos = thisFrame.origin.y - (titleSize.height*1.2);
		
		// Draw the border rect
		NSRect borderRect = NSMakeRect(floorf(BORDER)+0.5,
                                       floorf(ypos)+0.5,
									   (float) maxWidth,
                                       floorf(thisFrame.size.height + (titleSize.height * 1.2)));
		[frameColour set];
		[NSBezierPath strokeRect: borderRect];
		
		// IMPLEMENT ME: draw the show/hide triangle (or maybe add this as a view?)
		
		// Draw the title
		[thisTitle drawAtPoint: NSMakePoint(BORDER*2, ypos + 2 + titleSize.height * 0.1)
				withAttributes: titleAttributes];
	}
	
	
	// Draw the rest
	[super drawRect: rect];
}

// = Management =

- (void) removeAllSubviews {
	for( NSView* subview in views ) {
		[subview removeFromSuperview];
	}

	[views removeAllObjects];
	[titles removeAllObjects];
	[states removeAllObjects];	
}

- (void) addSubview: (NSView*) subview
		  withTitle: (NSString*) title {
	[views addObject: subview];
	[titles addObject: title];
	[states addObject: [NSNumber numberWithBool: YES]];
	
    [self addSubview: subview];
    [subview setAutoresizingMask: (NSUInteger) (NSViewMaxYMargin | NSViewMaxXMargin)];
	[subview setNeedsDisplay: YES];
	
	// Rearrange the views
	[self rearrangeSubviews];
}

- (void) rearrangeSubviews {
	reiterate = YES;
	if (rearranging) return;
	rearranging = YES;
	reiterate = NO;
	
	NSRect oldBounds;
	NSRect newBounds = [self bounds];
	
	float newHeight;
	
	NSFont* titleFont = [NSFont boldSystemFontOfSize: FONTSIZE];
	float titleHeight = [titleFont ascender] - [titleFont descender];
	
	oldBounds = newBounds;
	
    //
	// Stage one: Calculate our new height
    //
	newHeight = BORDER;
	
	for( NSView* subview in views ) {
		NSRect viewFrame = [subview frame];
		
		newHeight += titleHeight * 1.2;
		newHeight += viewFrame.size.height;
		newHeight += BORDER;
	}
	
	oldBounds.size.height = floor(newHeight);
	[self setFrameSize: oldBounds.size];

    //
	// Stage two: Position the views appropriately
    //
	float ypos = BORDER;
	
	for( NSView* subview in views ) {
		NSRect viewFrame = [subview frame];

		ypos += titleHeight * 1.2;

		if ([subview superview] != self) {
			if ([subview superview] != nil) [subview removeFromSuperview];
			[self addSubview: subview];
		}		
		
		if (viewFrame.origin.x != BORDER ||
			viewFrame.origin.y != floor(ypos)) {
			viewFrame.origin.x = BORDER;
			viewFrame.origin.y = floor(ypos);
			
			[subview setFrameOrigin: viewFrame.origin];
			[subview setNeedsDisplay: YES];
		}
		
		ypos += viewFrame.size.height;
		ypos += BORDER;
	}
	
	// Final stage: redraw
	[self setNeedsDisplay: YES];
	rearranging = NO;
}

- (BOOL) isFlipped {
	return YES;
}

- (void) startRearranging {
	rearranging = YES;
}

- (void) finishRearranging {
	rearranging = NO;
	
	[self rearrangeSubviews];
}

@end
