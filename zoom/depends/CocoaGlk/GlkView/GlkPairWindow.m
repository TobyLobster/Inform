//
//  GlkPairWindow.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 19/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "GlkPairWindow.h"


@implementation GlkPairWindow

// = Initialisation =

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
	
	[key release]; key = nil;
	[left release]; left = nil;
	[right release]; right = nil;
	
	[super dealloc];
}

// = Setting the windows that make up this pair =

- (void) setKeyWindow: (GlkWindow*) newKey {
	[key release];
	
	key = [newKey retain];
	
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
	[left release]; 

	left = [newLeft retain];
	[left setParent: self];
	[left setScaleFactor: scaleFactor];
	
	needsLayout = YES;
}

- (void) setRightWindow: (GlkWindow*) newRight {
	[right setParent: nil];
	[right removeFromSuperview];
	[right release]; 
	
	right = [newRight retain];
	[right setParent: self];
	[right setScaleFactor: scaleFactor];
	
	needsLayout = YES;
}

- (GlkWindow*) keyWindow {
	return key;
}

- (GlkWindow*) leftWindow {
	return left;
}

- (GlkWindow*) rightWindow {
	return right;
}

// = Size and arrangement =

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

- (void) setAbove: (BOOL) newAbove {
	above = newAbove;
}

- (unsigned) size {
	return size;
}

- (BOOL) fixed {
	return fixed;
}

- (BOOL) horizontal {
	return horizontal;
}

- (BOOL) above {
	return above;
}

// = Custom settings =

- (void) setBorderWidth: (float) newBorderWidth {
	borderWidth = newBorderWidth;
	
	needsLayout = YES;
}

- (void) setInputBorder: (BOOL) newInputBorder {
	inputBorder = newInputBorder;
	
	needsLayout = YES;
}

// = Layout =

- (void) setScaleFactor: (float) scale {
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
		float availableSize = horizontal?parentRect.size.width:parentRect.size.height;
		availableSize -= borderWidth;
		
		float leftSize, rightSize;
		
		if (fixed) {
			if (horizontal) {
				rightSize = [right widthForFixedSize: size];
			} else {
				rightSize = [right heightForFixedSize: size];
			}
		} else {
			rightSize = (availableSize * ((float)size))/100.0;
		}
		
		if (rightSize > availableSize) rightSize = availableSize-1.0;

		rightSize = floorf(rightSize);		
		leftSize = floorf(availableSize - rightSize);
		
		NSRect leftRect;
		NSRect rightRect;
		float realBorderWidth = borderWidth;
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

- (float) widthForFixedSize: (unsigned) sz {
	if (key && [key closed]) {
		[key release]; key = nil;
	}
	
	if (key) {
		return [key widthForFixedSize: sz];
	} else {
		return 0;
	}
}

- (float) heightForFixedSize: (unsigned) sz {
	if (key && [key closed]) {
		[key release]; key = nil;
	}
	
	if (key) {
		return [key heightForFixedSize: sz];
	} else {
		return 0;
	}
}

// = Window control =

- (void) taskFinished {
	// Pass on the message
	[left taskFinished];
	[right taskFinished];
}

- (void) setEventTarget: (NSObject<GlkEventReceiver>*) newTarget {
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

// = Window metadata =

- (void) setClosed: (BOOL) newClosed {
	[super setClosed: newClosed];
	
	// This propagates
	[left setClosed: newClosed];
	[right setClosed: newClosed];
}

// = Drawing =

- (void) drawInputBorder: (GlkWindow*) view {
	NSRect r = [view frame];
	r = NSInsetRect(r, -borderWidth, -borderWidth);
	
	if ([view waitingForKeyboardInput]) {
		[[NSColor blueColor] set];
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

// = NSAccessibility =

- (NSString *)accessibilityActionDescription: (NSString*) action {
	return @"";
}

- (NSArray *)accessibilityActionNames {
	return [NSArray array];
}

- (BOOL)accessibilityIsAttributeSettable:(NSString *)attribute {
	return NO;
}

- (void)accessibilityPerformAction:(NSString *)action {
	// No actions
}

- (void)accessibilitySetValue: (id)value
				 forAttribute: (NSString*) attribute {
	// No settable attributes
}

- (NSArray*) accessibilityAttributeNames {
	NSMutableArray* result = [[[super accessibilityAttributeNames] mutableCopy] autorelease];
	if (!result) result = [[[NSMutableArray alloc] init] autorelease];
	
	[result addObjectsFromArray:[NSArray arrayWithObjects: 
		NSAccessibilityChildrenAttribute,
		nil]];
	
	return result;
}

- (id)accessibilityAttributeValue:(NSString *)attribute {
	if ([attribute isEqualToString: NSAccessibilityChildrenAttribute]) {
		//return [NSArray arrayWithObjects: left, right, nil];
	} else if ([attribute isEqualToString: NSAccessibilityRoleAttribute]) {
		return NSAccessibilityGroupRole;
	}
	
	return [super accessibilityAttributeValue: attribute];
}

- (BOOL)accessibilityIsIgnored {
	return NO;
}

@end
