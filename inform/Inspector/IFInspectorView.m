//
//  IFInspectorView.m
//  Inform
//
//  Created by Andrew Hunter on Mon May 03 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "IFInspectorView.h"
#import "IFInspectorWindow.h"
#import "IFAppDelegate.h"
#import "IFIsTitleView.h"
#import "IFIsArrow.h"

#define TitleHeight [IFIsTitleView titleHeight]
#define ViewOffset  [IFIsTitleView titleHeight]
#define ViewPadding 1

@implementation IFInspectorView {
    NSView* innerView;										// The actual inspector view

    IFIsTitleView* titleView;								// The title bar view
    IFIsArrow*     arrow;									// The open/closed arrow

    BOOL willLayout;										// YES if a layout event is pending
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		innerView = nil;
		
		arrow = [[IFIsArrow alloc] initWithFrame: NSMakeRect(8, 0, 24, 28)];
		[self addSubview: arrow];
		[arrow sizeToFit];
				
		willLayout = NO;
		
		titleView = [[IFIsTitleView alloc] initWithFrame: NSMakeRect(0, 0, frame.size.width, [IFIsTitleView titleHeight])];
		[titleView setTitle: @"Untitled"];
		
		[self setAutoresizesSubviews: NO];
		[titleView setAutoresizingMask: NSViewWidthSizable];
		[arrow setAutoresizingMask: NSViewMaxYMargin];
		
		[arrow setTarget: self];
		[arrow setAction: @selector(openChanged:)];
		
		[self addSubview: titleView];
		[titleView addSubview: arrow];
    }
    return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

// = The view =

- (void) setTitle: (NSString*) title {
	[titleView setTitle: title];
}

- (void) setView: (NSView*) view {
	if (innerView) {
		[[NSNotificationCenter defaultCenter] removeObserver: self
														name: NSViewFrameDidChangeNotification
													  object: innerView];
		[innerView removeFromSuperview];
	}
	
    innerView = view;
	[innerView setPostsFrameChangedNotifications: YES];
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(innerSizeChanged:)
												 name: NSViewFrameDidChangeNotification
											   object: innerView];
	
	[self queueLayout];
}

- (NSView*) view {
	return innerView;
}

- (void) innerSizeChanged: (NSNotification*) not {
	if ([arrow intValue] == 3) {
		[self queueLayout];
	}
}

- (void) queueLayout {
	if (!willLayout) {
		// Annoyingly, this can be called from a different thread under certain circumstances
		[[IFAppDelegate mainRunLoop] performSelector: @selector(layoutViews)
											  target: self
											argument: nil
											   order: 64
											   modes: @[NSDefaultRunLoopMode, NSModalPanelRunLoopMode]];
		willLayout = YES;
	}
}

- (void) layoutViews {
	willLayout = NO;
	
	switch ([arrow intValue]) {
		default:
			NSLog(@"Bug: arrow should be 1, 2 or 3, but is %d", [arrow intValue]);
		case 1:
		case 2:
			// Closed
			if ([innerView superview] != nil)
				[innerView removeFromSuperview];
			
			NSRect ourFrame = [self frame];
			ourFrame.size.height = TitleHeight;
			[self setFrame: ourFrame];
			[self setNeedsDisplay: YES];
			break;
			
		case 3:
		{
			// Open
			NSRect bounds = [self bounds];
			NSRect newFrame = [self frame];
			NSRect oldFrame = newFrame;
			
			NSRect innerFrame = bounds;
			
			innerFrame.size.height = [innerView frame].size.height;
			innerFrame.origin.y += ViewOffset;
			newFrame.size.height = innerFrame.size.height + ViewOffset + ViewPadding;

			if ([innerView superview] != self) {
				[innerView removeFromSuperview];
			
				[innerView setFrame: innerFrame];
				[self addSubview: innerView
					  positioned: NSWindowBelow
					  relativeTo: titleView];
			}
			
			if (!NSEqualRects(newFrame, oldFrame)) {
				[self setFrame: newFrame];
			}
			
			// [self setNeedsDisplay: YES];
			break;
		}
	}

	// Notify the containingwindow of the change in state
	IFInspectorWindow* control = [[self window] windowController];
	if (control && [control isKindOfClass: [IFInspectorWindow class]]) {
		[control inspectorViewDidChange: self
								toState: [arrow intValue] == 3];
	}	
}

- (void) openChanged: (id) sender {
	[self queueLayout];
}

- (void) mouseUp: (NSEvent*) evt {
	NSPoint region = [evt locationInWindow];
	region = [self convertPoint: region
					   fromView: nil];
	
	if (!NSPointInRect(region, [titleView frame])) return; // Not in the title view
	
	// Clicking in the title will open the view if it's not already (you need to use the arrow to close it, though)
	[arrow performFlip];
}

- (BOOL) acceptsFirstMouse: (NSEvent*) evt {
	return YES;
}

// = Drawing =

- (void)drawRect:(NSRect)rect {
#if ViewPadding > 0
	NSRect bounds = [self bounds];
	
	[[NSColor windowFrameColor] set];
	[NSBezierPath strokeLineFromPoint: NSMakePoint(NSMinX(bounds), NSMaxY(bounds)-0.5)
							  toPoint: NSMakePoint(NSMaxX(bounds), NSMaxY(bounds)-0.5)];
#endif
}

- (BOOL) isFlipped {
	return YES;
}

- (BOOL) isOpaque {
	return NO;
}

- (void) setExpanded: (BOOL) isExpanded {
	[arrow setOpen: isExpanded];
	[self layoutViews];
}

- (BOOL) expanded {
	return [arrow intValue] == 3;
}

@end
