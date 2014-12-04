//
//  GlkTextGridWindow.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 20/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "GlkTextGridWindow.h"

#import "GlkImage.h"
#import "GlkClearMargins.h"
#import "GlkMoreView.h"
#import "GlkGridTypesetter.h"

@implementation GlkTextGridWindow

// = Initialisation =

- (void) setupTextview {
	// Text grid windows never have a more prompt
	[self setUsesMorePrompt: NO];
	
	// Construct the text system
	textStorage = [[NSTextStorage alloc] init];
	
	layoutManager = [[NSLayoutManager alloc] init];
	[textStorage addLayoutManager: layoutManager];
	
	margin = 0;
	
	// Create the typesetter (TODO? Use the Grid typesetter)
	typesetter = [[GlkGridTypesetter alloc] init];
	[layoutManager setTypesetter: typesetter];
	[layoutManager setShowsControlCharacters: NO];
	[layoutManager setShowsInvisibleCharacters: NO];
	
	// Create the text container
	NSTextContainer* newContainer = [[NSTextContainer alloc] initWithContainerSize: NSMakeSize(1e8, 1e8)];
	
	[newContainer setLayoutManager: layoutManager];
	[layoutManager addTextContainer: newContainer];
	
	[newContainer setContainerSize: NSMakeSize(1e8, 1e8)];
	[newContainer setWidthTracksTextView: YES];
	[newContainer setHeightTracksTextView: NO];
    [newContainer setLineFragmentPadding:0.0f];
				
	// Create the text view and the scroller
	textView = [[GlkTextView alloc] initWithFrame: [self frame]];
	scrollView = [[NSScrollView alloc] initWithFrame: [self frame]];
	
	[typesetter setDelegate: textView];
	[textView setTextContainer: newContainer];
	[newContainer setTextView: textView];
    [newContainer autorelease];
				
	[textView setMinSize:NSMakeSize(0.0, 0.0)];
	[textView setMaxSize:NSMakeSize(1e8, 1e8)];
	[textView setVerticallyResizable:YES];
	[textView setHorizontallyResizable:NO];
	[textView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
	[textView setEditable: NO];
	[textView setUsesFindPanel: YES]; // FIXME: Won't work on Jaguar
	
	inputPos = 0;
	[[textView textStorage] setDelegate: self];
	[textView setDelegate: self];
	
	[scrollView setDocumentView: textView];
	[scrollView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
	[scrollView setHasHorizontalScroller: NO];
	[scrollView setHasVerticalScroller: NO];
	[scrollView setAutohidesScrollers: NO];
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    
	if (self) {
		xpos = 0;
		ypos = 0;
		
		[self setForceFixed: YES];
    }
	
    return self;
}

- (void) dealloc {
	[nextInputLine release]; nextInputLine = nil;
	
	[super dealloc];
}

// = Drawing =

- (void)drawRect:(NSRect)rect {
	[super drawRect: rect];
}

// = Layout =

- (float) charWidth {
	// FIXME: we should cache this
	return [@"M" sizeWithAttributes: [self currentTextAttributes]].width;
}

- (float) widthForFixedSize: (unsigned) size {
	NSSize baseSize = [@"M" sizeWithAttributes: [self currentTextAttributes]];
	
	return floorf(size * baseSize.width) + [textView textContainerInset].width*2 + [[textView textContainer] lineFragmentPadding]*2;
}

- (float) heightForFixedSize: (unsigned) size {
	return floorf(size * [self lineHeight]) + [textView textContainerInset].height*2;
}

- (GlkSize) glkSize {
	GlkSize res;
	
	res.width = width;
	res.height = height;
	
	return res;
}

- (void) layoutInRect: (NSRect) parentRect {
	int x;
	
	// Set our frame
	[super layoutInRect: parentRect];
	
	// Lay out the lines
	int lastWidth = width;
	int lastHeight = height;
	
	width  = (parentRect.size.width - [textView textContainerInset].width*2 - [[textView textContainer] lineFragmentPadding]*2)  / [self charWidth];
	height = (parentRect.size.height - [textView textContainerInset].height*2) / [self lineHeight];
	
	if (width < 0) width = 0;
	if (height < 0) height = 0;
	
	// Adjust the text container size
	[[textView textContainer] setContainerSize: NSMakeSize(width * [self charWidth], height * [self lineHeight])];
	
	// Adjust the typesetter
	[(GlkGridTypesetter*)typesetter setCellSize: NSMakeSize([self charWidth], [self lineHeight])];
	[(GlkGridTypesetter*)typesetter setGridWidth: width
										  height: height];
	[layoutManager invalidateLayoutForCharacterRange: NSMakeRange(0, [textStorage length])
											  isSoft: NO
								actualCharacterRange: nil];
	
	// Adjust the text storage object
	if (lastWidth < width) {
		// Expand the width of this grid view
		int numSpaces = width-lastWidth;
		unichar spaces[numSpaces];
		
		for (x=0; x<numSpaces; x++) {
			spaces[x] = ' ';
		}
		
		NSAttributedString* blankSpace = [[NSAttributedString alloc] initWithString: [NSString stringWithCharacters: spaces
																											 length: numSpaces]
																		 attributes: [self attributes: style_Normal]];
		
		for (x=0; x<lastHeight; x++) {
			[textStorage insertAttributedString: blankSpace
										atIndex: x*width + lastWidth];
		}
		
		[blankSpace release];
	} else if (lastWidth > width) {
		// Shrink the width of this grid view
		for (x=0; x<lastHeight; x++) {
			[textStorage deleteCharactersInRange: NSMakeRange(x*width+width, lastWidth-width)];
		}
	}
	
	// Increase the height of the view
	int totalSize = width * height;
	if (width < 0 || height < 0) 
		totalSize = 0;
	
	int numSpaces = totalSize - [textStorage length];
	
	if (numSpaces < 0) {
		// Remove lines from the storage object
		[textStorage deleteCharactersInRange: NSMakeRange([textStorage length]+numSpaces, -numSpaces)];
	} else {
		// Add lines to the storage object
		unichar spaces[numSpaces];
		
		for (x=0; x<numSpaces; x++) spaces[x] = ' ';
		NSAttributedString* blankSpace = [[NSAttributedString alloc] initWithString: [NSString stringWithCharacters: spaces
																											 length: numSpaces]
																		 attributes: [self attributes: style_Normal]];
		
		[textStorage appendAttributedString: blankSpace];
		[blankSpace release];
	}
	
	// Request a sync if necessary
	GlkSize newSize = [self glkSize];
	if (newSize.width != lastSize.width || newSize.height != lastSize.height) {
		[containingView requestClientSync];
	}
	lastSize = [self glkSize];
}

// = Cursor positioning =

- (void) moveCursorToXposition: (int) newXpos
					 yPosition: (int) newYpos {
	xpos = newXpos;
	ypos = newYpos;
}

// = Window control =

- (void) taskFinished {
	// The text should be made non-editable
	if (lineInput) [self cancelLineInput];
	if (charInput) [self cancelCharInput];
	
	[textView setEditable: NO];
}

- (void) clearWindow {
	[textStorage deleteCharactersInRange: NSMakeRange(0, [textStorage length])];
	
	xpos = ypos = 0;
	width = height = 0;
	
	// This forces us to recreate the lines appropriately (ie, this works as if the window was shrunk to 0,0 then resized back to normal)
	[self layoutInRect: [self frame]];
}

// = Streams =

- (void) putString: (in bycopy NSString*) string {
	int pos = 0;
	
	[containingView performLayoutIfNecessary];
		
	// Check for newlines
	int x;
	for (x=0; x<[string length]; x++) {
		if ([string characterAtIndex: x] == '\n' || [string characterAtIndex: x] == '\r') {
			[self putString: [string substringToIndex: x]];
			xpos = 0; ypos++;
			[self putString: [string substringFromIndex: x+1]];
			return;
		} else if ([string characterAtIndex: x] < 32) {
			[self putString: [string substringToIndex: x]];
			[self putString: [string substringFromIndex: x+1]];
			return;
		}
	}
	
	// Write this string
	while (pos < [string length]) {
		// Can't draw if we've fallen off the end of the window
		if (ypos >= height) 
			break;
		
		// Can only draw a certain number of characters
		if (xpos >= width) {
			xpos = 0;
			ypos++;
			continue;
		}
		
		int bufPos = xpos + ypos*width;
		
		// Get the number of characters to draw
		int amountToDraw = width - xpos;
		if (bufPos + amountToDraw > [textStorage length]) {
			amountToDraw = [textStorage length] - bufPos;
		}
		if (pos+amountToDraw > [string length]) amountToDraw = [string length]-pos;
		if (amountToDraw <= 0) break;
		
		// Draw the characters
		NSAttributedString* partString = [[NSAttributedString alloc] initWithString: [string substringWithRange: NSMakeRange(pos, amountToDraw)]
																		 attributes: [self currentTextAttributes]];
		[textStorage replaceCharactersInRange: NSMakeRange(bufPos, amountToDraw)
						 withAttributedString: partString];
		[partString release];
		
		//[self setNeedsDisplay: YES];
		
		// Update the x position (and the y position if necessary)
		xpos += amountToDraw;
		pos += amountToDraw;
		if (xpos >= width) {
			xpos = 0;
			ypos++;
		}
	}
}

// = Mouse input =

- (void) mouseDown: (NSEvent*) event {
	NSPoint mousePos = [textView convertPoint: [event locationInWindow] 
									 fromView: nil];
		
	int glyphPos = [[textView layoutManager] glyphIndexForPoint: mousePos
												inTextContainer: [textView textContainer]];
	int clickPos = [[textView layoutManager] characterIndexForGlyphAtIndex: glyphPos];
	
	int clickX = clickPos % width;
	int clickY = clickPos / width;
	
	// TODO: do not report mouse dragged events (ie, things resulting in a selection)
	
	if (mouseInput) {
		// Generate the event
		GlkEvent* evt = [[GlkEvent alloc] initWithType: evtype_MouseInput
									  windowIdentifier: [self identifier]
												  val1: clickX
												  val2: clickY];
		
		// ... send it
		[target queueEvent: [evt autorelease]];
	} else {
		[super mouseUp: event];
	}
}

// = MORE prompt =

- (void) resetMorePrompt: (int) moreChar {
	// Text grid windows are not scrollable
}

- (void) displayMorePromptIfNecessary {
	// Text grid windows are not scrollable
}

// = Preferences =

- (void) updateWithPrefs: (GlkPreferences*) prefs {
	// Overridden from GlkTextWindow
	margin = 0;
	[textView setTextContainerInset: NSMakeSize(margin, margin)];
	[[textView layoutManager] setUsesScreenFonts: [prefs useScreenFonts]];
	[[textView layoutManager] setHyphenationFactor: [prefs useHyphenation]?1:0];
}

// = Line input =

- (NSString*) cancelLineInput {
	if (lineInput) {
		lineInput = NO;
		[nextInputLine release]; nextInputLine = nil;
		
		[self makeTextNonEditable];
		[[self window] invalidateCursorRectsForView: self];
		
		int startPos = xpos + ypos*width;
		return [[textStorage string] substringWithRange: NSMakeRange(startPos, lineInputLength)];
	}
	
	return @"";	
}

- (void) requestLineInput {
	if (!lineInput) {
		[self makeTextEditable];
	}
	
	if (charInput) {
		NSLog(@"Oops: line input requested while char input was pending");
		[self cancelCharInput];
	}

	[containingView performLayoutIfNecessary];

	BOOL wasFlushing = flushing;
	if (wasFlushing) {
		[[textView textStorage] endEditing];
		flushing = NO;
	}
	
	lineInput = YES;
	lineInputLength = 0;
	
	if (wasFlushing) {
		[[textView textStorage] beginEditing];
		flushing = YES;
	}
	
	NSMutableString* string = [[textView textStorage] mutableString];
	
	if (nextInputLine != nil && [nextInputLine length] > 0 && xpos + [nextInputLine length] < width) {
		lineInputLength = 0;
		int startPos = xpos + ypos*width;
		
		[string replaceCharactersInRange: NSMakeRange(startPos, [nextInputLine length])
							  withString: nextInputLine];
		lineInputLength = [nextInputLine length];
	}
	
	[[self window] invalidateCursorRectsForView: self];
	
	// Calling this means that if there's any lines we haven't processed yet, then they will
	// be added to the buffer (generating an immediate event)
	//
	// This allows us to successfully copy+paste lines of text and have things look like they're working OK
	[self textStorageDidProcessEditing: nil];
}


- (void) setInputLine: (NSString*) inputLine {
	[nextInputLine release]; 
	nextInputLine = [inputLine copy];
}

- (BOOL)    	textView:(NSTextView *)aTextView
 shouldChangeTextInRange:(NSRange)affectedCharRange
	   replacementString:(NSString *)replacementString {
	if (!lineInput) return NO;
	
	int startPos = xpos + ypos*width;
	int endPos = startPos + lineInputLength;
	
	int lengthChange = [replacementString length] - affectedCharRange.length;
	
    if (affectedCharRange.location < startPos || affectedCharRange.location > endPos) {
        return NO;
	} else if (xpos + lineInputLength + lengthChange >= width) {
		return NO;
	} else if (lineInputLength < -lengthChange) {
		return NO;
	} else if (lengthChange < 0 && affectedCharRange.location >= endPos) {
		return NO;
    } else {
        return YES;
    }
}

- (void)textStorageWillProcessEditing:(NSNotification*) aNotification {
	if (!lineInput) return;
	
	int startPos = xpos + ypos*width;
	int endPos = startPos + lineInputLength;
	
	NSRange edited = [[textView textStorage] editedRange];

	if (edited.location < startPos || edited.location > endPos) {
		return;
	}
	
	if (edited.location == endPos && edited.length != [[textView textStorage] changeInLength]) {
		return;
	}
	
	// Anything newly added should be in the input style
	[[textView textStorage] setAttributes: [self attributes: style_Input]
									range: [[textView textStorage] editedRange]];
	
	// Text editing should replace any text outside of the editable range
	int lenChange = [[textView textStorage] changeInLength];
	
	if (lenChange > 0) {
		[[textView textStorage] deleteCharactersInRange: NSMakeRange(endPos+lenChange, lenChange)];
	} else if (lenChange < 0) {
		unichar spaces[-lenChange];
		int x;
		
		for (x=0; x<-lenChange; x++) {
			spaces[x] = ' ';
		}
		
		[[textView textStorage] insertAttributedString: [[[NSAttributedString alloc] initWithString: [NSString stringWithCharacters: spaces
																															 length: -lenChange]
																						 attributes: [self currentTextAttributes]] autorelease]
											   atIndex: endPos+lenChange];
	}
	
	// Change the line input length appropriately
	lineInputLength += lenChange;
	
	// Unfortunately, while this fixes the contents of the view, it screws up the caret location
	// This way of fixing this behaviour is hardly ideal but is really the only opportunity
	[[NSRunLoop currentRunLoop] performSelector: @selector(fixHorribleCaretBehaviour:)
										 target: self
									   argument: [NSValue valueWithRange: NSMakeRange(edited.location+edited.length, 0)]
										  order: 0
										  modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
}

- (void) fixHorribleCaretBehaviour: (NSValue*) caretPos {
	[textView setSelectedRange: [caretPos rangeValue]];
}

- (void) updateCaretPosition {
	int startPos = xpos + ypos*width;
	int endPos = startPos + lineInputLength;

	if (startPos > [textView selectedRange].location ||
		endPos <= [textView selectedRange].location) {
		[textView setSelectedRange: NSMakeRange(endPos, 0)];
	}
}

- (int) inputPos {
	return xpos + ypos*width;
}

- (void) keyDown: (NSEvent*) evt {
	int startPos = xpos + ypos*width;

	if ([containingView morePromptsPending]) {
		[containingView pageAll];
	} else if (lineInput) {
		// Deal with line input key events
		unichar chr = [[evt characters] characterAtIndex: 0];
		
		// Set to non-nil to change to a history item
		NSString* history = nil;
		
		switch (chr) {
			case NSUpArrowFunctionKey:
				history = [[self containingView] previousHistoryItem];
				break;
				
			case NSDownArrowFunctionKey:
				history = [[self containingView] previousHistoryItem];
				break;
				
			case '\n':
			case '\r':
				if (lineInput)
				{
					// We found a newline
					NSString* inputLine = [[textStorage string] substringWithRange: NSMakeRange(startPos, lineInputLength)];
					
					// Generate the event, then...
					GlkEvent* evt = [[GlkEvent alloc] initWithType: evtype_LineInput
												  windowIdentifier: [self identifier]
															  val1: [inputLine length]
															  val2: 0];
					[evt setLineInput: inputLine];
					
					// ... send it
					[target queueEvent: [evt autorelease]];
					
					// Add to the line history
					[[self containingView] resetHistoryPosition];
					[[self containingView] addHistoryItem: inputLine
										  forWindowWithId: [self identifier]];
					
					lineInput = NO;
					[nextInputLine release]; nextInputLine = nil;
					[self makeTextNonEditable];
					
					// We're done
					break;
				}
		}
		
		if (history != nil) {
			// Move to a specific history item
			[[textView textStorage] replaceCharactersInRange: NSMakeRange(startPos, lineInputLength)
												  withString: history];
		}
	} else {
		[super keyDown: evt];
	}
}

// = NSAccessibility =

- (id)accessibilityAttributeValue:(NSString *)attribute {
	if ([attribute isEqualToString: NSAccessibilityRoleDescriptionAttribute]) {
		if (!lineInput && !charInput) return @"Text grid";
		return [NSString stringWithFormat: @"GLK text grid window%@%@", lineInput?@", waiting for commands":@"", charInput?@", waiting for a key press":@""];;
	}	
	
	return [super accessibilityAttributeValue: attribute];
}

- (id)accessibilityFocusedUIElement {
	return textView;
}

@end
