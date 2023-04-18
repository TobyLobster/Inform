//
//  IFPageBarCell.m
//  Inform
//
//  Created by Andrew Hunter on 06/04/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFPageBarCell.h"
#import "IFPageBarView.h"

@implementation IFPageBarCell {
    /// True if this cell is to be drawn on the right-hand side
    BOOL isRight;
    /// The frame of this cell reported when the last mouse tracking started
    NSRect trackingFrame;

    /// An identifier for this cell
    id identifier;

    // Pop-up
    /// The menu for this cell
    NSMenu* menu;

    // Radio
    /// The radio group identifier for this cell
    int radioGroup;

    // View
    /// The view for this cell
    NSView* view;

    // Key equivalent
    /// The key equivalent string for this cell
    NSString* keyEquivalent;
}

+ (NSImage*) dropDownImage {
	return [NSImage imageNamed: @"App/PageBar/BarMenuArrow"];
}

#pragma mark - Initialisation

- (instancetype) init {
	self = [super init];
	
	if (self) {
		radioGroup = -1;
		view = nil;
	}
	
	return self;
}

- (instancetype) initTextCell: (NSString*) text {
	self = [super init];
	
	if (self) {
        radioGroup = -1;
        view = nil;
        
		NSAttributedString* attrText = [[NSAttributedString alloc] initWithString: text
																	   attributes: 
			@{NSForegroundColorAttributeName: [NSColor controlTextColor],
				NSFontAttributeName: [NSFont systemFontOfSize: 11]}];
		
		[self setAttributedStringValue: attrText];
	}
	
	return self;
}

- (instancetype) initImageCell: (NSImage*) image {
	self = [super init];
	
	if (self) {
        radioGroup = -1;
        view = nil;

		[self setImage: image];
	}
	
	return self;
}

- (void) dealloc {
	 menu = nil;
	 view = nil;
	 identifier = nil;
	 keyEquivalent = nil;
	
}

@synthesize identifier;

- (void) setStringValue: (NSString*) text {
	NSAttributedString* attrText = [[NSAttributedString alloc] initWithString: text
																   attributes: 
		@{NSForegroundColorAttributeName: [NSColor controlTextColor],
			NSFontAttributeName: [NSFont systemFontOfSize: 11]}];
	
	[self setAttributedStringValue: attrText];
}

#pragma mark - Cell properties

- (void) update {
	[(NSControl*)[self controlView] updateCell: self];
}

- (void) setHighlighted: (BOOL) highlighted {
    super.highlighted = highlighted;
	[self update];
}

#pragma mark - Sizing and rendering

- (void) setIsRight: (BOOL) newIsRight {
	isRight = newIsRight;
}

- (NSSize) cellSize {
	NSSize size = NSZeroSize;

	// Work out the minimum size required to contain the text or the image
	NSImage* image = [self image];
	NSAttributedString* text = [self attributedStringValue];
	
	if (image && text && [text length] > 0) {
		NSSize imageSize = [image size];
		NSSize textSize = [text size];
		
		if (textSize.height > imageSize.height) {
			size.height = textSize.height;
		} else {
			size.height = imageSize.height;
		}
		
		size.width = imageSize.width + 2 + textSize.width;
		size.width += 4;
	} else if (image) {
		size = [image size];
		size.width += 4;
	} else if (text) {
		size = [text size];
		size.width += 4;
	}
	
	if ([self isPopup]) {
		NSImage* dropDownArrow = [IFPageBarCell dropDownImage];
		size.width += [dropDownArrow size].width + 4;
	}
	
	// Add a border for the margins
	size.width += 8;
	size.width = floor(size.width+0.5);
	size.height = floor(size.height);
	
	return size;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame 
					   inView:(NSView *)controlView {
	NSImage* image = [self image];
	NSAttributedString* text = [self attributedStringValue];
	
	// Draw the background
	NSColor * backgroundColor = nil;
	
	if (self.highlighted) {
		if ([self isPopup]) {
			backgroundColor = [NSColor colorNamed:@"GraphiteSelected"];
		} else {
			backgroundColor = [NSColor colorNamed:@"Highlighted"];
		}
	} else if ([self state] == NSControlStateValueOn) {
		backgroundColor = [NSColor colorNamed:@"Selected"];
	}
	
	if (backgroundColor) {
		IFPageBarView* barView = (IFPageBarView*)[self controlView];
		NSRect backgroundBounds = [barView bounds];
		backgroundBounds.size.width -= 9.0;
		
		NSRect backgroundFrame = cellFrame;
		backgroundFrame.size.width -= 1;

		if (isRight) {
			backgroundFrame.origin.x += 1;
		}

		[IFPageBarView drawOverlay: backgroundColor
							inRect: backgroundFrame
					   totalBounds: backgroundBounds
						  fraction: 1.0];
	}
	
	if ([self isPopup]) {
		// Draw the popup arrow
		NSImage* dropDownArrow = [IFPageBarCell dropDownImage];
		NSSize dropDownSize = [dropDownArrow size];
		
		NSRect dropDownDrawRect;
		
		dropDownDrawRect.origin = NSMakePoint(NSMaxX(cellFrame) - dropDownSize.width - 6,
											  cellFrame.origin.y + (cellFrame.size.height+2-dropDownSize.height)/2);
		dropDownDrawRect.size = dropDownSize;
		
		if (isRight) dropDownDrawRect.origin.x += 2;
		
        NSImage *layer = [[NSImage alloc] initWithSize:NSMakeSize(NSMaxX(dropDownDrawRect), NSMaxY(dropDownDrawRect))];
        [layer lockFocus];
		[dropDownArrow drawInRect: dropDownDrawRect
						 fromRect: NSZeroRect
						operation: NSCompositingOperationSourceOver
						 fraction: 1.0];
        if (dropDownArrow.template) {
            [NSColor.labelColor set];
            NSRectFillUsingOperation(dropDownDrawRect, NSCompositingOperationSourceAtop);
        }
        [layer unlockFocus];
        [layer drawAtPoint: NSZeroPoint
                  fromRect: NSZeroRect
                 operation: NSCompositingOperationSourceOver
                  fraction: 1];
        
		// Reduce the frame size
		cellFrame.size.width -= dropDownSize.width+4;
	}

	NSColor * textColor = NSColor.labelColor;
	if ([self state] == NSControlStateValueOn) {
		textColor = [NSColor colorNamed:@"SelectedText"];
	}
	// If the cell is highlighted we use the highlighted text colour whether the cell is selected or not.
	if (self.highlighted) {
		textColor = [NSColor colorNamed:@"HighlightedText"];
	}

	if (image && text && [text length] > 0) {
		// Work out the sizes
		NSSize imageSize = [image size];
		NSSize textSize = [text size];

		NSSize size;
		if (textSize.height > imageSize.height) {
			size.height = textSize.height;
		} else {
			size.height = imageSize.height;
		}
		
		size.width = imageSize.width + 2 + textSize.width;
		
		// Draw the image
		NSRect imageRect;
		
		imageRect.origin = NSMakePoint(cellFrame.origin.x + (cellFrame.size.width-size.width)/2,
									   cellFrame.origin.y + (cellFrame.size.height+2-imageSize.height)/2);
		imageRect.size = imageSize;
        
        NSImage *layer = [[NSImage alloc] initWithSize:NSMakeSize(NSMaxX(imageRect), NSMaxY(imageRect))];
        [layer lockFocus];
        
		[image drawInRect: imageRect
				 fromRect: NSZeroRect
				operation: NSCompositingOperationSourceOver
				 fraction: 1.0];
        
        if (image.template) {
            [NSColor.labelColor set];
            NSRectFillUsingOperation(imageRect, NSCompositingOperationSourceAtop);
        }
        [layer unlockFocus];
        [layer drawAtPoint: NSZeroPoint
                  fromRect: NSZeroRect
                 operation: NSCompositingOperationSourceOver
                  fraction: 1];
        
		// Draw the text
		NSPoint textPoint = NSMakePoint(cellFrame.origin.x + (cellFrame.size.width-size.width)/2 + imageSize.width + 2,
										cellFrame.origin.y + (cellFrame.size.height+2-textSize.height)/2);
		
		if (isRight) textPoint.x += 1;
		
		NSRect textRect;
		textRect.origin = textPoint;
		textRect.size = textSize;
		
		[text drawInRect: NSIntegralRect(textRect)];
	} else if (image) {
		// Draw the image
		NSSize imageSize = [image size];
		NSRect imageRect;
		
		imageRect.origin = NSMakePoint(cellFrame.origin.x + (cellFrame.size.width-imageSize.width)/2,
									   cellFrame.origin.y + (cellFrame.size.height+2-imageSize.height)/2);
		imageRect.size = imageSize;
        NSImage *layer = [[NSImage alloc] initWithSize:NSMakeSize(NSMaxX(imageRect), NSMaxY(imageRect))];
        [layer lockFocus];
        
		[image drawInRect: imageRect
				 fromRect: NSZeroRect
				operation: NSCompositingOperationSourceOver
				 fraction: 1.0];
        if (image.template) {
            [textColor set];
            NSRectFillUsingOperation(imageRect, NSCompositingOperationSourceAtop);
        }
        [layer unlockFocus];
        [layer drawAtPoint: NSZeroPoint
                  fromRect: NSZeroRect
                 operation: NSCompositingOperationSourceOver
                  fraction: 1];
	} else if (text) {
		// Draw the text
		NSSize textSize = [text size];
		NSPoint textPoint = NSMakePoint(cellFrame.origin.x + (cellFrame.size.width-textSize.width)/2,
										cellFrame.origin.y + (cellFrame.size.height+2-textSize.height)/2);
		
		if (isRight) textPoint.x += 1;

		NSRect textRect;
		textRect.origin = textPoint;
		textRect.size = textSize;
		NSMutableDictionary *mutDict = [text attributesAtIndex:0 effectiveRange:nil].mutableCopy;
		mutDict[NSForegroundColorAttributeName] = textColor;
		text = [[NSAttributedString alloc] initWithString:text.string attributes:mutDict];
		[text drawInRect: NSIntegralRect(textRect)];
	}
}

#pragma mark - Cell states

- (NSInteger) nextState {
	// Radio cells can be turned on (but get turned off manually)
	if (radioGroup >= 0) {
		return NSControlStateValueOn;
	}
	
	// TODO: allow for push-on/push-off cells
	return NSControlStateValueOff;
}

- (void) setState: (NSInteger) newState {
	if (newState == [self state]) {
		return;
	}
	
	[super setState: newState];
	[self update];
	
	if (radioGroup >= 0) {
		[(IFPageBarView*)[self controlView] setState: (int) newState
											 forCell: self];
	}
}

- (BOOL) isEnabled {
	if (menu) {
		if ([menu numberOfItems] <= 0) return NO;
	}
	
	return [super isEnabled];
}


#pragma mark - Acting as part of a radio group

@synthesize radioGroup;
	
#pragma mark - Acting as a tab

@synthesize view;

#pragma mark - Acting as a pop-up

- (BOOL) isPopup {
	if (menu) return YES;
	
	return NO;
}

- (void) showPopupAtPoint: (NSPoint) pointInWindow {
	if (menu) {
		[self setState: NSControlStateValueOn];
		self.highlighted = YES;
		
		NSEvent* fakeEvent = [NSEvent mouseEventWithType: NSEventTypeLeftMouseDown
												location: pointInWindow
										   modifierFlags: (NSEventModifierFlags) 0
											   timestamp: [[NSApp currentEvent] timestamp]
											windowNumber: [[[self controlView] window] windowNumber]
												 context: nil
											 eventNumber: [[NSApp currentEvent] eventNumber]
											  clickCount: 0
												pressure: 1.0];

		[NSMenu popUpContextMenu: menu
					   withEvent: fakeEvent
						 forView: [self controlView]
						withFont: [NSFont systemFontOfSize: 11]];
		
		[self setState: NSControlStateValueOff];
		[self update];
	}
}

- (void) setMenu: (NSMenu*) newMenu {
	menu = newMenu;
	[self update];
}

#pragma mark - Tracking

- (BOOL)trackMouse:(NSEvent *)theEvent
			inRect:(NSRect)cellFrame 
			ofView:(NSView *)controlView 
	  untilMouseUp:(BOOL)untilMouseUp {
	trackingFrame = cellFrame;
	
	if ([self isPopup]) {
		NSRect winFrame = [[self controlView] convertRect: trackingFrame
												   toView: nil];
		[self showPopupAtPoint: NSMakePoint(NSMinX(winFrame)+1, NSMinY(winFrame)-3)];
		
        self.highlighted = NO;
		
		return YES;
	}
	
	BOOL result = [super trackMouse: theEvent
							 inRect: cellFrame
							 ofView: controlView
					   untilMouseUp: untilMouseUp];
	
	if (result) {
		// Tracking was successful
		if (radioGroup >= 0) {
			
		}
	}
	
	return result;
}

- (BOOL)startTrackingAt: (NSPoint)startPoint 
				 inView: (NSView*)controlView {
    self.highlighted = YES;
	
	// TODO: if this is a menu or pop-up cell, only send the action when the user makes a selection
	// [self sendActionOn: 0];
	
	return YES;
}

- (BOOL)continueTracking:(NSPoint)lastPoint
					  at:(NSPoint)currentPoint 
				  inView:(NSView *)controlView {
	BOOL shouldBeHighlighted;
	
	shouldBeHighlighted = NSPointInRect(currentPoint, 
										trackingFrame);
	if (shouldBeHighlighted != self.highlighted) {
        self.highlighted = shouldBeHighlighted;
	}
	
	return YES;
}

- (void)stopTracking:(NSPoint)lastPoint 
				  at:(NSPoint)stopPoint
			  inView:(NSView *)controlView 
		   mouseIsUp:(BOOL)flag {
    self.highlighted = NO;

	return;
}

#pragma mark - Key equivalent

- (NSString*) keyEquivalent {
	if (keyEquivalent == nil) return @"";
	return keyEquivalent;
}

- (void) setKeyEquivalent: (NSString*) newKeyEquivalent {
	keyEquivalent = [newKeyEquivalent copy];
}

@end
