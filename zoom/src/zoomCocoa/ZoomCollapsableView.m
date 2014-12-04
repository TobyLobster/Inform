//
//  ZoomCollapsableView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Feb 21 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomCollapsableView.h"


@implementation ZoomCollapsableView

#define BORDER 4.0
#define FONTSIZE 14

// = Init/housekeeping =

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		views = [[NSMutableArray alloc] init];
		titles = [[NSMutableArray alloc] init];
		states = [[NSMutableArray alloc] init];
		
		rearranging = NO;
		
		[self setPostsFrameChangedNotifications: YES];
    	[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(subviewFrameChanged:)
													 name: NSViewFrameDidChangeNotification
												   object: self];
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
	return YES;
}

- (void)drawRect:(NSRect)rect {
	NSFont* titleFont = [NSFont boldSystemFontOfSize: FONTSIZE];
	NSColor* backgroundColour = [NSColor whiteColor];
	NSDictionary* titleAttributes = 
		[NSDictionary dictionaryWithObjectsAndKeys: 
			titleFont, NSFontAttributeName,
			[NSColor blackColor], NSForegroundColorAttributeName,
			backgroundColour, NSBackgroundColorAttributeName,
			nil];
	
	[backgroundColour set];
	NSRectFill(rect);
	
	NSRect bounds = [self bounds];
	
	// Draw the titles and frames
	NSColor* frameColour = [NSColor colorWithDeviceRed: 0.5
												 green: 0.5
												  blue: 0.5
												 alpha: 1.0];

	int x;
	
	for (x=0; x<[views count]; x++) {
		BOOL shown = [[states objectAtIndex: x] boolValue];
		NSView* thisView = [views objectAtIndex: x];
		NSString* thisTitle = [titles objectAtIndex: x];
		
		if (!shown) continue;
		
		NSSize titleSize = [thisTitle sizeWithAttributes: titleAttributes];
		NSRect thisFrame = [thisView frame];
		
		float ypos = thisFrame.origin.y;
		float titleHeight;
		
		if (![thisTitle isEqualToString: @""]) 
			titleHeight = (titleSize.height*1.2);
		else
			titleHeight = titleSize.height*0.2;
		ypos -= titleHeight;
		
		// Draw the border rect
		NSRect borderRect = NSMakeRect(floor(BORDER)+0.5, floor(ypos)+0.5, 
									   bounds.size.width-(BORDER*2), thisFrame.size.height + titleHeight + (BORDER));
		[frameColour set];
		[NSBezierPath strokeRect: borderRect];
		
		// IMPLEMENT ME: draw the show/hide triangle (or maybe add this as a view?)
		
		// Draw the title
		if (![thisTitle isEqualToString: @""]) {
			[thisTitle drawAtPoint: NSMakePoint(BORDER*2, ypos + 2 + titleSize.height * 0.1)
					withAttributes: titleAttributes];
		}
	}
	
	
	// Draw the rest
	[super drawRect: rect];
}

// = Management =

- (void) removeAllSubviews {
	NSView* subview;
	NSEnumerator* viewEnum = [views objectEnumerator];
	
	while (subview = [viewEnum nextObject]) {
		[subview removeFromSuperview];
	}
	
	[views removeAllObjects];
	[titles removeAllObjects];
	[states removeAllObjects];
	
	[self rearrangeSubviews];
}

- (void) setSubview: (NSView*) subview
		   isHidden: (BOOL) isHidden {
	int subviewIndex = [views indexOfObjectIdenticalTo: subview];
	
	if (subviewIndex != NSNotFound) {
		[states replaceObjectAtIndex: subviewIndex
						  withObject: [NSNumber numberWithBool: !isHidden]];
	}
	
	[self rearrangeSubviews];
}

- (void) addSubview: (NSView*) subview
		  withTitle: (NSString*) title {
	[views addObject: subview];
	[titles addObject: title];
	[states addObject: [NSNumber numberWithBool: YES]];

	NSRect bounds = [self bounds];
	
	// Set the width appropriately
	NSRect viewFrame = [subview frame];
	
	viewFrame.size.width = bounds.size.width - (BORDER*4);
	[subview setAutoresizingMask: 0];
	[subview setFrame: viewFrame];
	[subview setNeedsDisplay: YES];
	
	// Rearrange the views
	[self rearrangeSubviews];
	
	// Receive notifications about this view
	[subview setPostsFrameChangedNotifications: YES];
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(subviewFrameChanged:)
												 name: NSViewFrameDidChangeNotification
											   object: subview];
}

- (void) rearrangeSubviews {
	reiterate = YES;
	if (rearranging) return;
	
	// Mark as rearranging (stop re-entrance)
	rearranging = YES;
	reiterate = NO;
	
	// If we iterate deeply, then the scrollbar becomes mandatory
	NSView* parentView = [self superview];
	NSScrollView* scrollView = nil;
	while (parentView != nil && ![parentView isKindOfClass: [NSScrollView class]]) {
		parentView = [parentView superview];
	}

	// Find the containing scroll view
	if (parentView != nil) {
		scrollView = (NSScrollView*)parentView;
		[scrollView setAutohidesScrollers: NO];
	}
	
	if (parentView == nil) parentView = self;
	[parentView setNeedsDisplay: NO];
	[self setNeedsDisplay: NO];
	
	// Rearrange the views as necessary
	BOOL needsRedrawing = NO;
	
	NSRect oldBounds;
	NSRect newBounds = [self bounds];;
	
	NSEnumerator* viewEnum;
	NSEnumerator* stateEnum;
	NSEnumerator* titleEnum;
	NSView* subview;
	
	float bestWidth;
	float newHeight;
	
	NSFont* titleFont = [NSFont boldSystemFontOfSize: FONTSIZE];
	float titleHeight = [titleFont ascender] - [titleFont descender];
	
	oldBounds = newBounds;
	
	// First stage: resize all subviews to be the correct width
	bestWidth = oldBounds.size.width - (BORDER*4);
	
	viewEnum = [views objectEnumerator];
	stateEnum = [states objectEnumerator];

	while (subview = [viewEnum nextObject]) {
		NSRect viewFrame = [subview frame];
		BOOL shown = [[stateEnum nextObject] boolValue];
		
		if (shown && viewFrame.size.width != bestWidth) {
			needsRedrawing = YES;
			viewFrame.size.width = bestWidth;
			[subview setFrameSize: viewFrame.size];
			[subview setNeedsDisplay: NO];
		}
	}
	
	// Second stage: calculate our new height (and resize appropriately)
	newHeight = BORDER;
	
	viewEnum = [views objectEnumerator];
	stateEnum = [states objectEnumerator];
	titleEnum = [titles objectEnumerator];
	
	while (subview = [viewEnum nextObject]) {
		NSRect viewFrame = [subview frame];
		BOOL shown = [[stateEnum nextObject] boolValue];
		NSString* title = [titleEnum nextObject];
		
		if (shown) {
			if (![title isEqualToString: @""])
				newHeight += titleHeight * 1.2;
			else
				newHeight += titleHeight * 0.2;
			newHeight += viewFrame.size.height;
			newHeight += BORDER*2;
		}
	}
	
	oldBounds.size.height = floor(newHeight);
	[self setFrameSize: oldBounds.size];
	
	// Loop until our width settles down
	newBounds = [self bounds];
	
	// Stage three: Position the views appropriately
	float ypos = BORDER;
	
	viewEnum = [views objectEnumerator];
	stateEnum = [states objectEnumerator];
	titleEnum = [titles objectEnumerator];
	
	while (subview = [viewEnum nextObject]) {
		NSRect viewFrame = [subview frame];
		BOOL shown = [[stateEnum nextObject] boolValue];
		NSString* title = [titleEnum nextObject];
		
		if (shown) {
			if (![title isEqualToString: @""])
				ypos += titleHeight * 1.2;
			else
				ypos += titleHeight * 0.2;
		}
		
		if ([subview superview] != self || !shown) {
			if ([subview superview] != nil) [subview removeFromSuperview];
			if (shown) [self addSubview: subview];
		}
		
		if (shown) {
			if (viewFrame.origin.x != BORDER*2 ||
				viewFrame.origin.y != floor(ypos)) {
				viewFrame.origin.x = BORDER*2;
				viewFrame.origin.y = floor(ypos);
			
				[subview setFrameOrigin: viewFrame.origin];
				[subview setNeedsDisplay: NO];
				needsRedrawing = YES;
			}

			ypos += viewFrame.size.height;
			ypos += BORDER*2;
		}
	}
	
	// Show/hide the vertical scroll bar as necessary
	if (scrollView != nil && !reiterate) {
		BOOL showVerticalBar = NO;
		BOOL barVisible = [scrollView hasVerticalScroller];
		
		// Decide if we need to show a scrollbar or not
		NSView* docView = [scrollView contentView];
		float maxHeight = [docView bounds].size.height;
		
		if (newHeight > maxHeight || iterationCount > 1)
			showVerticalBar = YES;
		else
			showVerticalBar = NO;
		
		if (showVerticalBar != barVisible) {
			// If iteration count goes high, then only ever show the bar, never hide it
			if (!showVerticalBar) {
				// Hide the scrollbar
				[scrollView setHasVerticalScroller: NO];
				
				iterationCount++;
				rearranging = NO;
				[self rearrangeSubviews];
				iterationCount--;
				return;
			} else {
				// Show the scrollbar
				[scrollView setHasVerticalScroller: YES];
				
				iterationCount++;
				rearranging = NO;
				[self rearrangeSubviews];
				iterationCount--;
				return;
			}
		}
	}
	
	if (reiterate) {
		// Something has resized and messed up our beautiful arrangement!
		rearranging = NO;
		[self rearrangeSubviews];
		return;
	}
	
	// Final stage: tidy up, redraw if necessary
	[parentView display];
	
	[self setNeedsDisplay: NO];
	viewEnum = [views objectEnumerator];
	while (subview = [viewEnum nextObject]) [subview setNeedsDisplay: NO];
		
	rearranging = NO;
}

- (BOOL) isFlipped {
	return YES;
}

- (void) subviewFrameChanged: (NSNotification*) not {
	reiterate = YES;
	if (rearranging) return;
	
	if ([[[NSRunLoop currentRunLoop] currentMode] isEqualToString: NSEventTrackingRunLoopMode]) {
		[self rearrangeSubviews];
	} else {
		rearranging = YES;
		[[NSRunLoop currentRunLoop] performSelector: @selector(finishChangingFrames:)
											 target: self
										   argument: self
											  order: 32
											  modes: [NSArray arrayWithObjects: NSDefaultRunLoopMode, NSModalPanelRunLoopMode, NSEventTrackingRunLoopMode, nil]];
	}
}

- (void) finishChangingFrames: (id) sender {
	int x;
	NSRect bounds = [self bounds];
	
	for (x=0; x<[views count]; x++) {
		NSView* view = [views objectAtIndex: x];
		NSRect viewFrame = [view frame];
		
		if (viewFrame.size.width != bounds.size.width - (BORDER*4)) {
			viewFrame.size.width = bounds.size.width - (BORDER*4);
			[view setFrame: viewFrame];
			[view setNeedsDisplay: YES];
			[self setNeedsDisplay: YES];
		}
	}
	
	rearranging = NO;
	
	[self rearrangeSubviews];
}

- (void) startRearranging {
	rearranging = YES;
}

- (void) finishRearranging {
	rearranging = NO;
	
	[self rearrangeSubviews];
}

@end
