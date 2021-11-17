//
//  GlkWindow.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 19/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "GlkWindow.h"
#import <GlkView/GlkPairWindow.h>
#import <GlkView/GlkView.h>

@implementation GlkWindow

#pragma mark - Initialisation

- (id)initWithFrame:(GlkRect)frame {
    self = [super initWithFrame:frame];
    
	if (self) {
		border = 4;
		scaleFactor = 1.0;
	}
    
	return self;
}

#pragma mark - Drawing

- (void)drawRect:(GlkRect)rect {
	[[self backgroundColour] set];
	GlkRectFill(rect);
}

- (BOOL) isOpaque {
	return YES;
}

#pragma mark - Window metadata

@synthesize closed;
@synthesize glkIdentifier=windowIdentifier;

#pragma mark - The parent window

@synthesize parent = parentWindow;

#pragma mark - Layout

- (void) layoutInRect: (GlkRect) parentRect {
	[self setFrame: parentRect];
	
	GlkSize newSize = [self glkSize];
	if (newSize.width != lastSize.width || newSize.height != lastSize.height) {
		[containingView requestClientSync];
	}
	lastSize = [self glkSize];
}

- (CGFloat) widthForFixedSize: (unsigned) size {
	return size;
}

- (CGFloat) heightForFixedSize: (unsigned) size {
	return size;
}

@synthesize border;

- (GlkRect) contentRect {
	return GlkInsetRect([self bounds], border, border);
}

- (GlkSize) glkSize {
	GlkRect contentRect = [self contentRect];
	GlkSize res;
	
	res.width = (int)contentRect.size.width;
	res.height = (int)contentRect.size.height;
	
	return res;
}

@synthesize scaleFactor;

#pragma mark - Styles

@synthesize forceFixed;

- (GlkColor*) backgroundColour {
	return [[self style: style_Normal] backColour];
}

- (GlkFont*) proportionalFont {
	if (forceFixed) {
		return [self fixedFont];
	} else {
		return [[self attributes: style_Normal] objectForKey: NSFontAttributeName];
	}
}

- (GlkFont*) fixedFont {
	return [[self attributes: style_Preformatted] objectForKey: NSFontAttributeName];
}

- (NSDictionary*) currentTextAttributes {
	NSDictionary* res = [self attributes: style];
	
	if (linkObject != nil) {
		NSMutableDictionary* linkRes = [res mutableCopy];
		
		[linkRes setObject: linkObject
					forKey: NSLinkAttributeName];
		
		return linkRes;
	}
	
	return res;
}

- (CGFloat) leading {
	return 0;
}

- (CGFloat) lineHeight {
    NSFont* font = [[self currentTextAttributes] objectForKey: NSFontAttributeName];
    NSLayoutManager* layoutManager = [[NSLayoutManager alloc] init];
    
    return [layoutManager defaultLineHeightForFont: font];
}

- (void) setStyles: (NSDictionary*) newStyles {
	styles = [[NSDictionary alloc] initWithDictionary: newStyles
											copyItems: YES];
}

- (GlkStyle*) style: (unsigned) glkStyle {
	// If there aren't any styles yet, get the default styles from the preferences
	if (!styles) {
		if (!preferences) preferences = [GlkPreferences sharedPreferences];
		[self setStyles: [preferences styles]];
	}
	
	// Get the result from the styles object (use a default if we can't find a suitable style)
	GlkStyle* res = [styles objectForKey: @(glkStyle)];	
	if (!res) res = [GlkStyle style];
	
	if (forceFixed && [res proportional]) [res setProportional: NO];
	if (forceFixed && glkStyle != style_Normal) [res setSize: [[self style: style_Normal] size]];
	
	return res;
}

- (NSDictionary*) attributes: (unsigned) glkStyle {
	if (!preferences) preferences = [GlkPreferences sharedPreferences];
	
	GlkStyle* sty;
	if (!immediateStyle) {
		// Use the standard glk style if no immediate style is overriding it
		sty = [self style: glkStyle];
	} else {
		// The immediate style overrides any standard Glk style
		sty = immediateStyle;
	}
	
	if (customAttributes) {
		// Merge in the custom attributes if they're set
		NSMutableDictionary* res = [[sty attributesWithPreferences: preferences
													   scaleFactor: scaleFactor] mutableCopy];
		[res addEntriesFromDictionary: customAttributes];
		
		return res;
	} else {
		// Just use the standard attributes for this style
		return [sty attributesWithPreferences: preferences
								  scaleFactor: scaleFactor];
	}
}

- (void) setPreferences: (GlkPreferences*) prefs {
	preferences = prefs;
}

- (void) reformat {
	// Blank window just needs laying out again
	[self layoutInRect: [self frame]];
}

- (void) setImmediateStyleHint: (glui32) hint
					   toValue: (glsi32) value {
	// Create the immediate style if it doesn't already exist
	if (!immediateStyle) {
		immediateStyle = [[self style: style] copy];
		if (!immediateStyle) immediateStyle = [[GlkStyle style] copy];
	} else {
		immediateStyle = [immediateStyle copy];
	}
	
	// Set the style hint in the immediate style
	[immediateStyle setHint: hint
					toValue: value];
}

- (void) clearImmediateStyleHint: (glui32) hint {
	// Create the immediate style if it doesn't already exist
	if (!immediateStyle) {
		immediateStyle = [[self style: style] copy];
		if (!immediateStyle) immediateStyle = [[GlkStyle style] copy];
	} else {
		immediateStyle = [immediateStyle copy];
	}
	
	// Get the default style
	GlkStyle* defaultStyle = [self style: style];
	if (!defaultStyle) defaultStyle = [GlkStyle style];
	
	// Set the style hint in the immediate style
	[immediateStyle setHint: hint
			   toMatchStyle: defaultStyle];
}

- (void) setCustomAttributes: (NSDictionary*) newCustomAttributes {
	// Set the new attribtues from the dictionary
	customAttributes = [[NSDictionary alloc] initWithDictionary: newCustomAttributes
													  copyItems: YES];
}

#pragma mark - Cursor positioning

- (void) moveCursorToXposition: (int) xpos
					 yPosition: (int) ypos {
	NSLog(@"Warning: attempt to move cursor in a window that doesn't support it");
}


#pragma mark - Window control

- (void) taskFinished {
	// This window never liked the subtask anyway and is happy it's dead
}

- (void) clearWindow {
	// We can't get any clearer
}

@synthesize eventTarget = target;

- (void) requestCharInput {
	if (lineInput) {
		NSLog(@"Oops: client requested char input while line input was pending");
		[self cancelLineInput];
	}
	charInput = YES;
	[[self window] invalidateCursorRectsForView: self];
}

- (void) requestLineInput {
	if (charInput) {
		NSLog(@"Oops: client requested line input while char input was pending");
		[self cancelCharInput];
	}
	lineInput = YES;
	[[self window] invalidateCursorRectsForView: self];
}

@synthesize waitingForLineInput = lineInput;

@synthesize waitingForCharInput = charInput;

- (BOOL) waitingForKeyboardInput {
	return charInput || lineInput || [self needsPaging];
}

- (BOOL) waitingForUserKeyboardInput {
	// This differs in that we ignore the case where the window needs paging
	return charInput || lineInput;
}

#if !defined(COCOAGLK_IPHONE)
- (NSResponder*) windowResponder {
	return self;
}
#endif

- (void) setInputLine: (NSString*) inputLine {
	// As we don't support line input, there's nothing to do here
}

- (void) forceLineInput: (NSString*) forcedInput {
	// Can't deal with line input events, but character input events are easy
	if (charInput) {
		// Generate a character input event
		GlkEvent* glkEvent = [[GlkEvent alloc] initWithType: evtype_CharInput
										   windowIdentifier: [self glkIdentifier]
													   val1: [[self class] keycodeForString: forcedInput]
													   val2: 0];		
		[self cancelCharInput];
		[target queueEvent: glkEvent];
	}
}

- (void) requestMouseInput {
	mouseInput = YES;
	[[self window] invalidateCursorRectsForView: self];
}

- (void) requestHyperlinkInput {
	hyperlinkInput = YES;
	[[self window] invalidateCursorRectsForView: self];
}

- (void) cancelCharInput {
	charInput = NO;
	[[self window] invalidateCursorRectsForView: self];
}

- (NSString*) cancelLineInput {
	lineInput = NO;
	[[self window] invalidateCursorRectsForView: self];
	
	return @"";
}

- (void) cancelMouseInput {
	mouseInput = NO;
	[[self window] invalidateCursorRectsForView: self];
}

- (void) cancelHyperlinkInput {
	hyperlinkInput = NO;
	[[self window] invalidateCursorRectsForView: self];
}

- (void) fixInputStatus {
	// Nothing to do for these windows
}

#pragma mark - Standard mouse and input handlers

- (BOOL)acceptsFirstResponder {
	// Note that we can't handle line input events by default, so we only accept if we have character events
	if (charInput) {
		return YES;
	} else {
		return NO;
	}
}

- (void) postFocusNotification {
	NSAccessibilityPostNotification(self, NSAccessibilityFocusedUIElementChangedNotification);
}

- (BOOL)becomeFirstResponder {
	if ([super becomeFirstResponder]) {
		[[NSRunLoop currentRunLoop] performSelector: @selector(postFocusNotification)
											 target: self
										   argument: nil
											  order: 32
											  modes: @[NSDefaultRunLoopMode]];
		return YES;
	}
	
	return NO;
}

- (BOOL)resignFirstResponder {
	[self postFocusNotification];
	
	if ([super resignFirstResponder]) {
		return YES;
	}
	
	return NO;
}

#if defined(COCOAGLK_IPHONE)
NS_ENUM(unichar) {
	NSUpArrowFunctionKey = 0xF700,
	NSDownArrowFunctionKey,
	NSLeftArrowFunctionKey,
	NSRightArrowFunctionKey,
	
	NSHomeFunctionKey = 0xF729,
	NSEndFunctionKey = 0xF72B,
	NSPageUpFunctionKey,
	NSPageDownFunctionKey,
};

#endif

+ (unsigned) keycodeForString: (NSString*) string {
	glui32 chr = keycode_Unknown;						// The Glk character
	
	if ([string length] <= 0) return chr;
	
	unichar inChar = [string characterAtIndex: 0];
	switch (inChar) {
		case '\n':
		case '\r':
			chr = keycode_Return;
			break;
		case '\t':
			chr = keycode_Tab;
			break;
			
		case NSUpArrowFunctionKey:
			chr = keycode_Up;
			break;
		case NSDownArrowFunctionKey:
			chr = keycode_Down;
			break;
		case NSLeftArrowFunctionKey:
			chr = keycode_Left;
			break;
		case NSRightArrowFunctionKey:
			chr = keycode_Right;
			break;
			
		case NSPageDownFunctionKey:
			chr = keycode_PageDown;
			break;
		case NSPageUpFunctionKey:
			chr = keycode_PageUp;
			break;
			
		case NSHomeFunctionKey:
			chr = keycode_Home;
			break;
			
		case NSEndFunctionKey:
			chr = keycode_End;
			break;
			
		case '\e':
			chr = keycode_Escape;
			break;
	}
	
	if (chr == keycode_Unknown) {
		NSData* latin1 = [string dataUsingEncoding: NSISOLatin1StringEncoding
							  allowLossyConversion: YES];
		
		if ([latin1 length] > 0) {
			chr = ((unsigned char*)[latin1 bytes])[0];
		}
	}
	
	return chr;
}

#if !defined(COCOAGLK_IPHONE)
+ (unsigned) keycodeForEvent: (NSEvent*) evt {
	return [[self class] keycodeForString: [evt characters]];
}

- (void) keyDown: (NSEvent*) evt {
	if ([containingView morePromptsPending]) {
		[containingView pageAll];
	} else if (!charInput) {
		//NSBeep();
	} else if ([[evt characters] length] >= 1) {
		GlkEvent* glkEvent = [[GlkEvent alloc] initWithType: evtype_CharInput
										   windowIdentifier: [self glkIdentifier]
													   val1: [[self class] keycodeForEvent: evt]
													   val2: 0];
		
		[self cancelCharInput];
		[target queueEvent: glkEvent];
	}
}
#endif

- (void) updateCaretPosition {
}

- (NSInteger) inputPos {
	// Default is 0 (not managing a text view)
	return 0;
}

- (void) bufferIsFlushing {
	// Default action is to catch flies
}

- (void) bufferHasFlushed {
	// The horrible taste of flies fails to wake us up
}

#pragma mark - Streaming

#pragma mark Control

- (void) closeStream {
	// Nothing to do really
}

- (void) setPosition: (in NSInteger) position
		  relativeTo: (in GlkSeekMode) seekMode {
	// No effect
}

- (unsigned long long) getPosition {
	// Spec isn't really clear on what do for window streams. We just say the position is always 0
	return 0;
}

#pragma mark Writing

- (void) putChar: (in unichar) ch {
	unichar buf[1];
	
	buf[0] = ch;
	
	[self putString: [NSString stringWithCharacters: buf
											 length: 1]];
}

- (void) putString: (in bycopy NSString*) string {
	// We're blank: nothing to do
}

- (void) putBuffer: (in bycopy NSData*) buffer {
	// Assume that buffers are in ISO Latin-1 format
	NSString* string = [[NSString alloc] initWithData: buffer
											 encoding: NSISOLatin1StringEncoding];

	// The view won't automate data events automatically
	[containingView automateStream: self
						 forString: string];
	
	// Put the string
	[self putString: string];
}

#pragma mark - Reading

- (unichar) getChar {
	return 0;
}

- (bycopy NSString*) getLineWithLength: (NSInteger) len {
	return nil;
}

- (bycopy NSData*) getBufferWithLength: (NSUInteger) length {
	return nil;
}

#pragma mark - Styles

- (void) setStyle: (int) styleId {
	style = styleId;

	if (immediateStyle) {
		immediateStyle = nil;
	}
}

@synthesize style;

#pragma mark - Cursor rects

#if !defined(COCOAGLK_IPHONE)
- (void)resetCursorRects {
	if (lineInput || charInput) {
		[self addCursorRect: [self bounds]
					 cursor: [NSCursor IBeamCursor]];
	} else if (mouseInput) {
		[self addCursorRect: [self bounds]
					 cursor: [NSCursor crosshairCursor]];
	} else {
	}
}
#endif


#pragma mark - The containing view

@synthesize containingView;

#pragma mark - Paging

- (BOOL) needsPaging {
	// By default, windows have no paging
	return NO;
}

- (void) page {
	
}

#pragma mark - Hyperlinks

- (void) setHyperlink: (unsigned int) value {
	linkObject = [[NSNumber alloc] initWithUnsignedInt: value];
}

- (void) clearHyperlink {
	linkObject = nil;
}

#pragma mark - Accessibility

- (NSString *)accessibilityRoleDescription {
	return [NSString stringWithFormat: @"GLK window%@%@", lineInput?@", waiting for commands":@"", charInput?@", waiting for a key press":@""];;
}

- (NSArray *)accessibilityChildren {
	// No children by default
	return @[];
}

- (BOOL)isAccessibilityFocused {
	NSView* viewResponder = (NSView*)[[self window] firstResponder];
	if ([viewResponder isKindOfClass: [NSView class]]) {
		while (viewResponder != nil) {
			if (viewResponder == self) return YES;

			viewResponder = [viewResponder superview];
		}
	}

	return NO;
}

- (id)accessibilityApplicationFocusedUIElement {
	return [self accessibilityFocusedUIElement];
}

- (NSString *)accessibilityLabel {
	return [NSString stringWithFormat: @"GLK window%@%@", lineInput?@", waiting for commands":@"", charInput?@", waiting for a key press":@""];
}

- (NSAccessibilityRole)accessibilityRole {
	return NSAccessibilityUnknownRole;
}

- (id)accessibilityFocusedUIElement {
	return self;
 }

@end
