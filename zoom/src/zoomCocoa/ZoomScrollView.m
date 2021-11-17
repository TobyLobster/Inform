//
//  ZoomScrollView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Oct 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomScrollView.h"


@implementation ZoomScrollView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        zoomView = nil;

        upperDivider = [[NSBox alloc] initWithFrame:
            NSMakeRect(0,0,2,2)];
        [upperDivider setBoxType: NSBoxSeparator];
		
		lastTileSize = NSMakeSize(-1,-1);
		lastUpperSize = -1;
		useDivider = YES;
    }
    return self;
}

- (id) initWithFrame: (NSRect) frame
            zoomView: (ZoomView*) zView {
    self = [self initWithFrame:frame];
    if (self) {
        zoomView = zView; // Not retained, as this is a component of a ZoomView
		scaleFactor = 1.0;
        
        upperView = [[ZoomUpperWindowView alloc] initWithFrame: frame
													  zoomView: zView];
    }
    return self;
}

- (void) tile {
	// Position the scroll view
	NSSize thisTileSize = [self bounds].size;
	
    if (!NSEqualSizes(lastTileSize, thisTileSize)) {
		[super tile];
	}

	int upperHeight  = [zoomView upperWindowSize];
	NSSize fixedSize = [@"M" sizeWithAttributes:
		[NSDictionary dictionaryWithObjectsAndKeys:
		 [zoomView fontFromStyle:ZFontStyleFixed], NSFontAttributeName, nil]];
	
	if (!NSEqualSizes(lastTileSize, thisTileSize) || lastUpperSize != upperHeight || !NSEqualSizes(lastFixedSize, fixedSize)) {
		// Move the content view to accomodate the upper window

		double upperMargin = (upperHeight * fixedSize.height) / scaleFactor;

		// Resize the content frame so that it doesn't cover the upper window
		NSClipView* contentView = [self contentView];
		NSRect contentFrame = [contentView frame];
		NSRect upperFrame, sepFrame;
		
		//contentFrame.size = [self contentSize];
		contentFrame.origin = [self bounds].origin;
		contentFrame.size = [[self class] contentSizeForFrameSize: [self frame].size
										  horizontalScrollerClass: [[self horizontalScroller] class]
											verticalScrollerClass: [[self verticalScroller] class]
													   borderType: [self borderType]
													  controlSize: NSControlSizeRegular
													scrollerStyle: NSScrollerStyleOverlay];

		contentFrame.size.height -= upperMargin;
		contentFrame.origin.y    += upperMargin;

		upperFrame.origin.x = contentFrame.origin.x;
		upperFrame.origin.y = contentFrame.origin.y - upperMargin;
		upperFrame.size.width = contentFrame.size.width;
		upperFrame.size.height = upperMargin;

		double sepHeight = [upperDivider frame].size.height;
		if (!useDivider) sepHeight = 0;

		// Actually resize the contentView
		contentFrame.origin.y    += sepHeight;
		contentFrame.size.height -= sepHeight;
			
		[contentView setFrame: contentFrame];

		// The upper/lower view seperator
		if (useDivider) {
			sepFrame = [upperDivider frame];
			sepFrame = contentFrame;
			sepFrame.origin.y -= sepHeight;
			sepFrame.size.height = sepHeight;
			[upperDivider setFrame: sepFrame];
			if ([upperDivider superview] == nil) [self addSubview: upperDivider];
			[upperDivider setNeedsDisplay: YES];
		} else {
			if ([upperDivider superview] != nil) [upperDivider removeFromSuperview];
		}

		// The upper window view
		[zoomView setUpperBufferHeight: (upperMargin*scaleFactor) + sepHeight];
		
		if (upperMargin > 0) {
			// Resize the upper window
			[upperView setFrame: upperFrame];
			
			// Scale it
			NSRect upperBounds;
			upperBounds.origin = NSMakePoint(0,0);
			upperBounds.size = NSMakeSize(floor(upperFrame.size.width * scaleFactor),
										  floor(upperFrame.size.height * scaleFactor));
			[upperView setBounds: upperBounds];
			
			// Add it to our view
			if ([upperView superview] == nil) {
				[self addSubview: upperView];
				[upperView setNeedsDisplay: YES];
			}
		} else {
			[upperView removeFromSuperview];
		}
	}

	// Update the cache of how we were last resized
	lastTileSize = [self bounds].size;
	lastUpperSize = upperHeight;
	lastFixedSize = fixedSize;
}

- (void) updateUpperWindows {
    // Force a refresh of the upper window views
    [upperView setNeedsDisplay: YES];
}

@synthesize scaleFactor;
- (void) setScaleFactor: (CGFloat) factor {
	scaleFactor = factor;
	[self tile];
}

@synthesize upperWindowView = upperView;

- (BOOL) setUseUpperDivider: (BOOL) newUseDivider {
	useDivider = newUseDivider;
	[self tile];
	return YES;
}


@end
