//
//  GlkTextView.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 01/04/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "GlkTextView.h"

#import "glk.h"
#import "GlkWindow.h"
#import "GlkTextWindow.h"
#import "GlkImage.h"
#import <GlkView/GlkPairWindow.h>
#import <GlkView/GlkView.h>

///
/// Private class used to store information about a custom glyph
///
@interface GlkTextViewGlyph : NSObject {
	NSInteger glyph;
	GlkCustomTextSection* textSection;
	
	NSRect bounds;
}

- (id) initWithGlyph: (NSInteger) glyph
		 textSection: (GlkCustomTextSection*) container;

@property NSRect bounds;
@property (readonly) NSInteger glyph;
@property (readonly, retain) GlkCustomTextSection *textSection;

@end

@implementation GlkTextViewGlyph

- (id) initWithGlyph: (NSInteger) newGlyph
		 textSection: (GlkCustomTextSection*) section {
	self = [super init];
	
	if (self) {
		glyph = newGlyph;
		textSection = section;
		bounds = NSMakeRect(0,0,0,0);
	}
	
	return self;
}

@synthesize bounds;
@synthesize glyph;
@synthesize textSection;

@end

@implementation GlkTextView {
	// Character input
	/// Set to true if we're waiting for single-character input
	BOOL receivingCharacters;
	
	// Custom glyphs (ordered)
	/// Ordered list of custom inline glyphs (images, mostly)
	NSMutableArray<GlkTextViewGlyph*>* customGlyphs;
	/// Ordered list of custom margin images
	NSMutableArray<GlkTextViewGlyph*>* marginGlyphs;
	/// The first unlaid margin glyph (index into marginGlyphs)
	NSInteger firstUnlaidMarginGlyph;
}

#pragma mark - Initialisation

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		receivingCharacters = NO;
		customGlyphs = [[NSMutableArray alloc] init];
		marginGlyphs = [[NSMutableArray alloc] init];
		firstUnlaidMarginGlyph = 0;
    }
    return self;
}

#pragma mark - Drawing

- (void) recalculateBoundsForGlyph: (GlkTextViewGlyph*) glyph {
}

- (void)drawRect:(NSRect)rect {
	[super drawRect: rect];
	
	NSLayoutManager* layout = [self layoutManager];
	[[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
	
	// = INLINE IMAGES =
	
	// Get the region of the text container that's being drawn
	NSRect bounds = [self bounds];
	
	NSRect containerRect = rect;
	NSSize inset = [self textContainerInset];
	containerRect.origin.x -= inset.width;
	containerRect.origin.y -= inset.height;
	
	NSRect usedRect;
	usedRect = [layout usedRectForTextContainer: [self textContainer]];
	containerRect = NSIntersectionRect(containerRect, usedRect);
	
	// Get the glyph range that we're drawing
	NSRange glyphRange = [layout glyphRangeForBoundingRectWithoutAdditionalLayout: containerRect
																  inTextContainer: [self textContainer]];
	
	// Find the first image to draw
	NSInteger top = [customGlyphs count]-1;
	NSInteger bottom = 0;
	NSInteger firstUnlaid = [layout firstUnlaidGlyphIndex];
	
	while (top >= bottom) {
		NSInteger middle = (top+bottom)>>1;
		GlkTextViewGlyph* glyph = [customGlyphs objectAtIndex: middle];
		
		NSInteger thisGlyph = [glyph glyph];
		
		if (thisGlyph < glyphRange.location) bottom = middle + 1;
		else if (thisGlyph > glyphRange.location) top = middle - 1;
		else {
			top = bottom = middle;
			break;
		}
	}
	
	NSInteger imageIndex = bottom;
	
	// Draw images until we reach the end of the glyph range
	while (imageIndex < [customGlyphs count]) {
		GlkTextViewGlyph* glyph = [customGlyphs objectAtIndex: imageIndex];
		NSInteger glyphNum = [glyph glyph];
		
		if (glyphNum >= firstUnlaid || glyphNum >= glyphRange.location + glyphRange.length) {
			break;
		}
		
		// Draw this glyph
		NSRange fragmentRange;
		NSRect fragment = [layout lineFragmentRectForGlyphAtIndex: [glyph glyph]
												   effectiveRange: &fragmentRange];
		NSPoint loc = [layout locationForGlyphAtIndex: glyphNum];
		
		loc.x += fragment.origin.x + inset.width;
		loc.y += fragment.origin.y + inset.height;
		
		[[glyph textSection] drawAtPoint: loc
								  inView: self];		
		
		// Move on
		imageIndex++;
	}
	
	// = MARGIN IMAGES =
	
	// Calculate the position of any so far unlaid margin images
	while (firstUnlaidMarginGlyph < [marginGlyphs count]) {
		GlkTextViewGlyph* glyph = [marginGlyphs objectAtIndex: firstUnlaidMarginGlyph];
		NSInteger glyphNum = [glyph glyph];
		if (glyphNum >= firstUnlaid) break;
		
		// Work out the bounding box for this glyph
		NSRange fragmentRange;
		NSRect fragment = [layout lineFragmentRectForGlyphAtIndex: [glyph glyph]
												   effectiveRange: &fragmentRange];
		NSPoint loc = [layout locationForGlyphAtIndex: glyphNum];
		
		loc.y += fragment.origin.y;
		
		loc.x = 0;
		
		NSRect glyphBounds;
		glyphBounds.origin = loc;
		glyphBounds.size.width = bounds.size.width;
		glyphBounds.size.height = [(GlkImage*)[glyph textSection] size].height;
		
		// Store these bounds
		[glyph setBounds: glyphBounds];
		
		firstUnlaidMarginGlyph++;
	}
	
	// Find the glyph nearest the top of rect
	CGFloat ypos = NSMaxY(rect)-inset.height;
	
	bottom = 0;
	top = [marginGlyphs count]-1;
	if (top >= firstUnlaidMarginGlyph) top = firstUnlaidMarginGlyph-1;
	
	while (top >= bottom) {
		NSInteger middle = (top+bottom)>>1;
		
		GlkTextViewGlyph* glyph = [marginGlyphs objectAtIndex: middle];
		NSRect bounds = [glyph bounds];
		CGFloat thisY = NSMinY(bounds);
		
		if (thisY > ypos) top = middle - 1;
		else if (thisY < ypos) bottom = middle + 1;
		else {
			// Go forward to the last glyph that shares our ypos
			while (middle < firstUnlaidMarginGlyph && middle < [marginGlyphs count]) {
				GlkTextViewGlyph* glyph = [marginGlyphs objectAtIndex: middle];
				if (NSMinY([glyph bounds]) != ypos) break;
				
				middle++;
			}
			
			top = bottom = middle-1;
			break;
		}
	}
	
	// top now contains the first glyph with a ypos <= the maximum position in the region we're drawing
	NSInteger marginIndex = top;
	
	while (marginIndex >= 0) {
		GlkTextViewGlyph* glyph = [marginGlyphs objectAtIndex: marginIndex];
		NSInteger glyphNum = [glyph glyph];
		NSRect bounds = [glyph bounds];
		
		if (NSMaxY(bounds) < NSMinY(rect)) break;
		
		// Draw this glyph
		if ([glyph glyph] < [layout firstUnlaidGlyphIndex]) {
			NSRange fragmentRange;
			NSRect fragment = [layout lineFragmentRectForGlyphAtIndex: [glyph glyph]
													   effectiveRange: &fragmentRange];
			NSPoint loc = [layout locationForGlyphAtIndex: glyphNum];
			
			loc.x += fragment.origin.x;
			loc.x += inset.width;
			loc.y += fragment.origin.y;
			loc.y += inset.height;
			
			[[glyph textSection] drawAtPoint: loc
									  inView: self];
		}
		
		// Move on		
		marginIndex--;
	}
}

#pragma mark - Receiving characters

- (void) requestCharacterInput {
	receivingCharacters = YES;
}

- (void) cancelCharacterInput {
	receivingCharacters = NO;
}

- (void) keyDown: (NSEvent*) evt {
	// Find the GlkWindow superview
	NSView* sview = [self superview];
	
	while (sview != nil && ![sview isKindOfClass: [GlkWindow class]]) {
		sview = [sview superview];
	}
	
	if ([sview isKindOfClass: [GlkTextWindow class]] && [(GlkTextWindow*)sview needsPaging]) {
		if ([[evt characters] isEqualToString: @"\n"]
			|| [[evt characters] isEqualToString: @"\r"]
			|| [[evt characters] isEqualToString: @" "]) {
			[(GlkTextWindow*)sview page];
		}
		
		return;
	}
	
	if ([[evt characters] isEqualToString: @"\t"]) {
		[[(GlkWindow*)sview containingView] performTabFrom: (GlkWindow*)sview
												   forward: ([evt modifierFlags]&NSEventModifierFlagShift)==0];
		return;
	}
	
	GlkWindow* win = (GlkWindow*) sview;

	if ([[win containingView] morePromptsPending]) {
		[[win containingView] pageAll];
	} else if (receivingCharacters && [GlkWindow keycodeForEvent: evt] != keycode_Unknown) {
		// Send character input events directly to the GlkWindow object
		[sview keyDown: evt];
	} else if (![win waitingForLineInput] && ([evt modifierFlags]&NSEventModifierFlagFunction) == 0) {
		// If not waiting for line input, then try changing the first responder to a view that
		// is actually waiting for input
		BOOL foundNewResponder = [[win containingView] setFirstResponder];
		if (foundNewResponder) {
			[[[win containingView] window] sendEvent: evt];
		}
	} else {
		// Move to the end of the text if we're behind the input position
		[(GlkWindow*)sview updateCaretPosition];
		
		// If this is a newline, then move to the end of the text
		if ([[evt characters] isEqualToString: @"\n"]
			|| [[evt characters] isEqualToString: @"\r"]) {
			[self setSelectedRange: NSMakeRange([[self textStorage] length], 0)];			
		}
		
		// Send certain character events to the superview, so they can deal with line history and similar events
		if ([[evt characters] length] > 0) {
			unichar chr = [[evt characters] characterAtIndex: 0];
			
			switch (chr) {
				case NSUpArrowFunctionKey:
				case NSDownArrowFunctionKey:
					[sview keyDown: evt];
					return;
				case '\n':
				case '\r':
					[sview keyDown: evt];
					break;
			}
		}
		
		// Send the event to our superclass
		[super keyDown: evt];
	}
}

#pragma mark - Dealing with custom glyphs

- (NSInteger) invalidateCustomGlyphs: (NSRange) range
							 inArray: (NSMutableArray*) glyphArray {
	// Binary search for the first glyph
	NSInteger top = [glyphArray count] - 1;
	NSInteger bottom = 0;
	
	while (top >= bottom) {
		NSInteger middle = (top + bottom)>>1;
		
		GlkTextViewGlyph* thisGlyph = [glyphArray objectAtIndex: middle];
		NSInteger thisLoc = [thisGlyph glyph];
		
		if (thisLoc > range.location) top = middle - 1;
		else if (thisLoc < range.location) bottom = middle + 1;
		else {
			top = bottom = middle;
			break;
		}
	}
	
	NSInteger firstToRemove = bottom;
	if (firstToRemove >= [glyphArray count]) return 0x7fffffff;
	
	// Binary search for the final glyph
	NSInteger finalGlyph = range.location + range.length;
	bottom = firstToRemove;
	top = [glyphArray count] - 1;
	while (top >= bottom) {
		NSInteger middle = (top + bottom)>>1;
		
		GlkTextViewGlyph* thisGlyph = [glyphArray objectAtIndex: middle];
		NSInteger thisLoc = [thisGlyph glyph];
		
		if (thisLoc > finalGlyph) top = middle - 1;
		else if (thisLoc < finalGlyph) bottom = middle + 1;
		else {
			top = bottom = middle - 1;
			break;
		}
	}
	
	NSInteger lastToRemove = top;
	if (lastToRemove < firstToRemove) return 0x7fffffff;
	
	[glyphArray removeObjectsInRange: NSMakeRange(firstToRemove, lastToRemove-firstToRemove+1)];
	
	return firstToRemove;
}

- (void) addCustomGlyph: (NSInteger) location
				section: (GlkCustomTextSection*) section
				inArray: (NSMutableArray<GlkTextViewGlyph*>*) glyphArray {
	GlkTextViewGlyph* newGlyph = [[GlkTextViewGlyph alloc] initWithGlyph: location
															 textSection: section];
	
	// Perform a binary search on the existing set of glyphs to find where to add this new glyph
	NSInteger top = [glyphArray count]-1;;
	NSInteger bottom = 0;
	
	while (top >= bottom) {
		NSInteger middle = (top + bottom)>>1;
		
		GlkTextViewGlyph* thisGlyph = [glyphArray objectAtIndex: middle];
		NSInteger thisLoc = [thisGlyph glyph];
		
		if (thisLoc > location) top = middle - 1;
		else if (thisLoc < location) bottom = middle + 1;
		else {
			[glyphArray replaceObjectAtIndex: middle
									withObject: newGlyph];
			return;
		}
	}
	
	// bottom is the first index that contains a glyph greater than this one
	[glyphArray insertObject: newGlyph
					   atIndex: bottom];
	
	// We're done
}

- (void) invalidateCustomGlyphs: (NSRange) range {
	// Invalidate both the custom and the margin glyph arrays
	[self invalidateCustomGlyphs: range
						 inArray: customGlyphs];
	NSInteger marginInvalid = [self invalidateCustomGlyphs: range
												   inArray: marginGlyphs];
	
	// Reset the first unlaid margin glyph
	if (marginInvalid < firstUnlaidMarginGlyph) {
		firstUnlaidMarginGlyph = marginInvalid;
	}
}

- (void) addCustomGlyph: (NSInteger) location
				section: (GlkCustomTextSection*) section {
	if ([section isKindOfClass: [GlkImage class]]) {
		GlkImage* image = (GlkImage*)section;
		int imageStyle = [image alignment];
		
		if (imageStyle == imagealign_MarginLeft || imageStyle == imagealign_MarginRight) {
			[self addCustomGlyph: location
						 section: section
						 inArray: marginGlyphs];
		} else {
			[self addCustomGlyph: location
						 section: section
						 inArray: customGlyphs];			
		}
	} else {
		[self addCustomGlyph: location
					 section: section
					 inArray: customGlyphs];
	}
}

#pragma mark - Mouse events

- (NSView*) mouseParent {
	// Find a parent view that might want to know about any mouse events we may have received
	NSView* windowParent = [self superview];
	
	while (windowParent != nil && ![windowParent isKindOfClass: [GlkWindow class]]) {
		windowParent = [windowParent superview];
	}
	
	return windowParent;
}

- (void) mouseDown: (NSEvent*) evt {
	[super mouseDown: evt];
	
	NSView* mouseParent = [self mouseParent];
	
	if (mouseParent) {
		[mouseParent mouseDown: evt];
	}
}

- (void) mouseDragged: (NSEvent*) evt {
	[super mouseDragged: evt];
	
	NSView* mouseParent = [self mouseParent];
	
	if (mouseParent) {
		[mouseParent mouseDragged: evt];
	}
}

- (void) mouseUp: (NSEvent*) evt {
	[super mouseUp: evt];
	
	NSView* mouseParent = [self mouseParent];
	
	if (mouseParent) {
		[mouseParent mouseUp: evt];
	}
}

#pragma mark - First responder

- (void) postFocusNotification {
	NSView* glkWindowView = self;
	while (glkWindowView != nil && ![glkWindowView isKindOfClass: [GlkWindow class]]) {
		glkWindowView = [glkWindowView superview];
	}
	NSAccessibilityPostNotification(glkWindowView, NSAccessibilityFocusedUIElementChangedNotification);
}

- (BOOL)becomeFirstResponder {
	[[NSRunLoop currentRunLoop] performSelector: @selector(postFocusNotification)
										 target: self
									   argument: nil
										  order: 32
										  modes: @[NSDefaultRunLoopMode]];

	if ([super becomeFirstResponder]) {
		return YES;
	}
	
	return NO;
}

- (BOOL)resignFirstResponder {
	[[NSRunLoop currentRunLoop] performSelector: @selector(postFocusNotification)
										 target: self
									   argument: nil
										  order: 32
										  modes: @[NSDefaultRunLoopMode]];
	
	if ([super resignFirstResponder]) {
		return YES;
	}
	
	return NO;
}

#pragma mark - NSAccessibility

- (NSString *)accessibilityHelp {
	if (!receivingCharacters) return @"Text window";
	return [NSString stringWithFormat: @"GLK text window%@%@", @"", receivingCharacters?@", waiting for a key press":@""];
}

- (id)accessibilityParent {
	return nil;
}

- (NSAccessibilityRole)accessibilityRole {
	return NSAccessibilityTextAreaRole;
}

@end
