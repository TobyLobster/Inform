//
//  ZoomInputLine.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Jun 26 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomInputLine.h"


@implementation ZoomInputLine {
	ZoomCursor* cursor;
	
	NSMutableString* lineString;
	NSMutableDictionary<NSAttributedStringKey, id>* attributes;
	NSInteger		 insertionPos;
}

// Initialisation
- (id) initWithCursor: (ZoomCursor*) csr
		   attributes: (NSDictionary<NSAttributedStringKey, id>*) attr {
	self = [super init];
	
	if (self) {
		lineString = [[NSMutableString alloc] init];
		cursor = csr;
		attributes = [attr mutableCopy];
		
		[attributes removeObjectForKey: NSBackgroundColorAttributeName];
	}
	
	return self;
}

// Drawing
- (void) drawAtPoint: (NSPoint) point {
	NSFont* font = [attributes objectForKey: NSFontAttributeName];
	
	point.y += [font descender];
	
	[lineString drawAtPoint: point
			 withAttributes: attributes];
}

- (NSSize) size {
	return [lineString sizeWithAttributes: attributes];
}

- (NSRect) rectForPoint: (NSPoint) point {
	NSRect r;
	
	r.origin = point;
	r.size = [self size];
	
	return r;
}

#pragma mark Keys, editing
- (void) updateCursor {
	[cursor positionInString: lineString
			  withAttributes: attributes
			atCharacterIndex: (int)insertionPos];
}

- (void) stringHasUpdated {
	if (delegate && [delegate respondsToSelector: @selector(inputLineHasChanged:)]) {
		[delegate inputLineHasChanged: self];
	}
}

- (void) keyDown: (NSEvent*) evt {
	NSString* input = [evt characters];
	
	NSEventModifierFlags flags = [evt modifierFlags];
	
	// Ignore events with modifier keys
	if ((flags&(NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagCommand|NSEventModifierFlagHelp)) != 0) {
		return;
	}
	
	[self stringHasUpdated];
	
	// Deal with/strip characters 0xf700-0xf8ff from the input string
	BOOL endOfLine = NO;
	NSMutableString* inString = [[NSMutableString alloc] init];
		
	for (NSInteger x=0; x<[input length]; x++) {
		unichar chr = [input characterAtIndex: x];
		
		if (chr == 13 || chr == 10) {
			// EOL
			endOfLine = YES;
			break;
		} else if (chr == 8 || chr == 127) {
			// Delete the last character
			if (insertionPos > 0) {
				[lineString deleteCharactersInRange: NSMakeRange(insertionPos-1, 1)];
				insertionPos--;
				[self stringHasUpdated];
				[self updateCursor];
				
				[inString setString: @""];
				break;
			} else {
				NSBeep();
			}
		} else if (chr == NSDeleteFunctionKey) {
			if (insertionPos < [lineString length]) {
				[lineString deleteCharactersInRange: NSMakeRange(insertionPos, 1)];
				[self stringHasUpdated];
				[self updateCursor];
				
				[inString setString: @""];
				break;
			} else {
				NSBeep();
			}
		} else if (chr == NSUpArrowFunctionKey) {
			NSString* newItem = [self lastHistoryItem];
			
			if (newItem) {
				[lineString setString: newItem];
				insertionPos = [lineString length];
				
				[self stringHasUpdated];
				[self updateCursor];
				[inString setString: @""];
				break;
			}
		} else if (chr == NSDownArrowFunctionKey) {
			NSString* newItem = [self nextHistoryItem];
			
			if (newItem) {
				[lineString setString: newItem];
			} else {
				[lineString setString: @""];
			}

			insertionPos = [lineString length];

			[self stringHasUpdated];
			[self updateCursor];
			[inString setString: @""];
			break;
		} else if (chr == NSLeftArrowFunctionKey) {
			if (insertionPos > 0) {
				insertionPos--;
				[self updateCursor];
				
				[inString setString: @""];
				break;
			} else {
				NSBeep();
			}
		} else if (chr == NSRightArrowFunctionKey) {
			if (insertionPos < [lineString length]) {
				insertionPos++;
				[self updateCursor];
				
				[inString setString: @""];
				break;
			} else {
				NSBeep();
			}
		} else if (chr == NSEndFunctionKey) {
			insertionPos = [lineString length];
			[self updateCursor];
		} else if (chr == NSHomeFunctionKey) {
			insertionPos = 0;
			[self updateCursor];
		} else if (chr < 0xf700 || chr > 0xf8ff) {
			[inString appendString: [NSString stringWithCharacters:&chr
															length:1]];
		}
	}
	
	// Add to the string
	if ([inString length] > 0) {
		[lineString insertString: inString
						 atIndex: insertionPos];
		insertionPos += [inString length];
		
		[self stringHasUpdated];
		[self updateCursor];
	}
	
	// Deal with end of line
	if (endOfLine) {
		if (delegate && [delegate respondsToSelector: @selector(endOfLineReached:)]) {
			[delegate endOfLineReached: self];
		}
	}
}

// Delegate
@synthesize delegate;

- (NSString*) lastHistoryItem {
	if (delegate && [delegate respondsToSelector: @selector(lastHistoryItem)]) {
		return [delegate lastHistoryItem];
	} else {
		return nil;
	}
}

- (NSString*) nextHistoryItem {
	if (delegate && [delegate respondsToSelector: @selector(nextHistoryItem)]) {
		return [delegate nextHistoryItem];
	} else {
		return nil;
	}
}

// Results
- (NSString*) inputLine {
	return [lineString copy];
}

@end
