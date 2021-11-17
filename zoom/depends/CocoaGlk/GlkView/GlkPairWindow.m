//
//  GlkPairWindow.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 19/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#include <tgmath.h>
#import "GlkPairWindow.h"
#import <GlkView/GlkPairWindow.h>
#import <GlkView/GlkView.h>


@implementation GlkPairWindow

#pragma mark - Initialisation

- (id) init {
	self = [super init];
	
	if (self) {
		borderWidth = 0;
		inputBorder = NO;
	}
	
	return self;
}

- (void) dealloc {
	[left setParent: nil];
	[right setParent: nil];
}

#pragma mark - Setting the windows that make up this pair

- (void) setKeyWindow: (GlkWindow*) newKey {
	key = newKey;
	
	needsLayout = YES;
}

- (GlkWindow*) nonKeyWindow {
	if (key == left)
		return right;
	else
		return left;
}

- (void) setLeftWindow: (GlkWindow*) newLeft {
	[left setParent: nil];
	[left removeFromSuperview];

	left = newLeft;
	[left setParent: self];
	[left setScaleFactor: scaleFactor];
	
	needsLayout = YES;
}

- (void) setRightWindow: (GlkWindow*) newRight {
	[right setParent: nil];
	[right removeFromSuperview];
	
	right = newRight;
	[right setParent: self];
	[right setScaleFactor: scaleFactor];
	
	needsLayout = YES;
}

@synthesize keyWindow = key;
@synthesize leftWindow = left;
@synthesize rightWindow = right;

#pragma mark - Size and arrangement

- (void) setSize: (unsigned) newSize {
	size = newSize;
	
	needsLayout = YES;
}

- (void) setFixed: (BOOL) newFixed {
	fixed = newFixed;
	
	needsLayout = YES;
}

- (void) setHorizontal: (BOOL) newHorizontal {
	horizontal = newHorizontal;
	
	needsLayout = YES;
}

@synthesize size;
@synthesize fixed;
@synthesize horizontal;
@synthesize above;

#pragma mark - Custom settings

- (void) setBorderWidth: (CGFloat) newBorderWidth {
	borderWidth = newBorderWidth;
	
	needsLayout = YES;
}

- (void) setInputBorder: (BOOL) newInputBorder {
	inputBorder = newInputBorder;
	
	needsLayout = YES;
}

@synthesize borderWidth;
@synthesize inputBorder;

#pragma mark - Layout

- (void) setScaleFactor: (CGFloat) scale {
	if (scale == scaleFactor) return;
	
	[super setScaleFactor: scale];
	needsLayout = YES;
	
	[left setScaleFactor: scale];
	[right setScaleFactor: scale];
}

- (void) layoutInRect: (NSRect) parentRect {
	if (needsLayout || !NSEqualRects(parentRect, [self frame])) {
		// Set our own frame
		[self setFrame: parentRect];
		
		NSRect bounds = [self bounds];
		
		// Work out the sizes for the child windows
		CGFloat availableSize = horizontal?parentRect.size.width:parentRect.size.height;
		availableSize -= borderWidth;
		
		CGFloat leftSize, rightSize;
		
		if (fixed) {
			if (horizontal) {
				rightSize = [right widthForFixedSize: size];
			} else {
				rightSize = [right heightForFixedSize: size];
			}
		} else {
			rightSize = (availableSize * ((CGFloat)size))/100.0;
		}
		
		if (rightSize > availableSize) rightSize = availableSize-1.0;

		rightSize = floor(rightSize);
		leftSize = floor(availableSize - rightSize);
		
		NSRect leftRect;
		NSRect rightRect;
		CGFloat realBorderWidth = borderWidth;
		if (inputBorder) realBorderWidth = 0;
		
		if (horizontal) {
			borderSliver.size.width = realBorderWidth;
			
			if (above) {
				leftRect.origin.x = bounds.origin.x + rightSize + realBorderWidth;
				rightRect.origin.x = bounds.origin.x;
				borderSliver.origin.x = bounds.origin.x + rightSize;
			} else {
				leftRect.origin.x = bounds.origin.x;
				rightRect.origin.x = bounds.origin.x + leftSize + realBorderWidth;
				borderSliver.origin.x = bounds.origin.x + leftSize;
			}
			
			borderSliver.origin.y = leftRect.origin.y = rightRect.origin.y = bounds.origin.y;
			borderSliver.size.height = leftRect.size.height = rightRect.size.height = bounds.size.height;
			leftRect.size.width = leftSize;
			rightRect.size.width = rightSize;
		} else {
			borderSliver.size.height = realBorderWidth;
			
			if (!above) {
				leftRect.origin.y = bounds.origin.y + rightSize + realBorderWidth;
				rightRect.origin.y = bounds.origin.y;
				borderSliver.origin.y = bounds.origin.y + rightSize;
			} else {
				leftRect.origin.y = bounds.origin.y;
				rightRect.origin.y = bounds.origin.y + leftSize + realBorderWidth;
				borderSliver.origin.y = bounds.origin.y + leftSize;
			}
			
			borderSliver.origin.x = leftRect.origin.x = rightRect.origin.x = bounds.origin.x;
			borderSliver.size.width = leftRect.size.width = rightRect.size.width = bounds.size.width;
			leftRect.size.height = leftSize;
			rightRect.size.height = rightSize;
		}
		
		if (inputBorder) {
			// Shrink the windows by the size of the input border, if they are text or grid windows
			if (![left isKindOfClass: [GlkPairWindow class]]) {
				leftRect = NSInsetRect(leftRect, borderWidth, borderWidth);
			}
			if (![right isKindOfClass: [GlkPairWindow class]]) {
				rightRect = NSInsetRect(rightRect, borderWidth, borderWidth);
			}
		}
		
		if ([left parent] != self) {
			NSLog(@"GlkPairWindow: left parent does not match self");
			return;
		}
		
		if ([right parent] != self) {
			NSLog(@"GlkPairWindow: right parent does not match self");
			return;
		}
		
		// Perform the layout
		if ([left superview] != self) {
			[left removeFromSuperview];
			[self addSubview: left];
		}
		
		if ([right superview] != self) {
			[right removeFromSuperview];
			[self addSubview: right];
		}
		
		[left layoutInRect: leftRect];
		[right layoutInRect: rightRect];
		
		[self setNeedsDisplay: YES];
		
		needsLayout = NO;
	} else {
		// Nothing major to do, but pass the buck anyway
		[left layoutInRect: [left frame]];
		[right layoutInRect: [right frame]];
	}
	
	GlkSize newSize = [self glkSize];
	if (newSize.width != lastSize.width || newSize.height != lastSize.height) {
		[containingView requestClientSync];
	}
	lastSize = [self glkSize];
}

- (CGFloat) widthForFixedSize: (unsigned) sz {
	if (key && [key closed]) {
		key = nil;
	}
	
	if (key) {
		return [key widthForFixedSize: sz];
	} else {
		return 0;
	}
}

- (CGFloat) heightForFixedSize: (unsigned) sz {
	if (key && [key closed]) {
		key = nil;
	}
	
	if (key) {
		return [key heightForFixedSize: sz];
	} else {
		return 0;
	}
}

#pragma mark - Window control

- (void) taskFinished {
	// Pass on the message
	[left taskFinished];
	[right taskFinished];
}

- (void) setEventTarget: (id<GlkEventReceiver>) newTarget {
	[super setEventTarget: newTarget];
	
	// Propagate the handler
	[left setEventTarget: newTarget];
	[right setEventTarget: newTarget];
}

- (void) bufferIsFlushing {
	[super bufferIsFlushing];
	
	[left bufferIsFlushing];
	[right bufferIsFlushing];
}

- (void) bufferHasFlushed {
	[super bufferHasFlushed];
	
	[left bufferHasFlushed];
	[right bufferHasFlushed];
}

- (void) fixInputStatus {
	[super fixInputStatus];
	
	[left fixInputStatus];
	[right fixInputStatus];
}

#pragma mark - Window metadata

- (void) setClosed: (BOOL) newClosed {
	[super setClosed: newClosed];
	
	// This propagates
	[left setClosed: newClosed];
	[right setClosed: newClosed];
}

#pragma mark - Drawing

- (void) drawInputBorder: (GlkWindow*) view {
	NSRect r = [view frame];
	r = NSInsetRect(r, -borderWidth, -borderWidth);
	
	if ([view waitingForKeyboardInput]) {
		[[NSColor systemBlueColor] set];
	} else {
		[[NSColor whiteColor] set];
	}
	NSRectFill(r);
}

- (void)drawRect:(NSRect)rect {
	[[NSColor windowBackgroundColor] set];
	NSRectFill(borderSliver);
	
	if (borderWidth >= 2) {
		if (inputBorder) {
			// Draw the input border around the left/right views as necessary
			[self drawInputBorder: left];
			[self drawInputBorder: right];				
		} else {
			NSRect bounds = [self bounds];
			
			if (!horizontal) {
				// Draw lines at top and bottom of border
				[[NSColor controlHighlightColor] set];
				NSRectFill(NSMakeRect(NSMinX(bounds), NSMinY(borderSliver), bounds.size.width, 1));
				
				[[NSColor controlShadowColor] set];
				NSRectFill(NSMakeRect(NSMinX(bounds), NSMaxY(borderSliver)-1, bounds.size.width, 1));
			} else {
				// Draw lines at left and right of border
				[[NSColor controlHighlightColor] set];
				NSRectFill(NSMakeRect(NSMinX(borderSliver), NSMinY(bounds), 1, bounds.size.height));
				
				[[NSColor controlShadowColor] set];
				NSRectFill(NSMakeRect(NSMaxX(borderSliver)-1, NSMinY(bounds), 1, bounds.size.height));
			}
		}
	}
}

#pragma mark - NSAccessibility


- (NSAccessibilityRole)accessibilityRole {
	return NSAccessibilityGroupRole;
}

- (NSArray *)accessibilityChildren {
	return @[left, right];
}

@end
