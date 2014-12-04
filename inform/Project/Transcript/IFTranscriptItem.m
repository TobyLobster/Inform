//
//  IFTranscriptItem.m
//  Inform-xc2
//
//  Created by Andrew Hunter on 10/05/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "IFTranscriptItem.h"

#import "IFDiff.h"

@implementation IFTranscriptItem

// = Initialisation =

static NSDictionary* defaultAttributes = nil;

// Colours
static NSColor* unplayedCol = nil;
static NSColor* unchangedCol = nil;
static NSColor* changedCol = nil; 

static NSColor* noExpectedCol = nil;
static NSColor* noMatchCol = nil;
static NSColor* nearMatchCol = nil;
static NSColor* exactMatchCol = nil;

static NSColor* commandCol = nil;

static NSColor* highlightCol = nil;
static NSColor* activeCol = nil;
static NSLayoutManager *layoutManager = nil;

+ (void) initialize {
	if (!unplayedCol) {
		unplayedCol = [[NSColor colorWithDeviceRed: 0.8
											 green: 0.8
											  blue: 0.8 
											 alpha: 1.0] retain];
		unchangedCol = [[NSColor colorWithDeviceRed: 0.6
											  green: 1.0
											   blue: 0.6
											  alpha: 1.0] retain];
		changedCol = [[NSColor colorWithDeviceRed: 1.0
											green: 0.6
											 blue: 0.6
											alpha: 1.0] retain];
		
		noExpectedCol = [[NSColor colorWithDeviceRed: 0.7
											   green: 0.7
												blue: 0.7 
											   alpha: 1.0] retain];
		noMatchCol = [[NSColor colorWithDeviceRed: 1.0
											green: 0.5
											 blue: 0.5
											alpha: 1.0] retain];
		nearMatchCol = [[NSColor colorWithDeviceRed: 1.0
											  green: 1.0
											   blue: 0.5
											  alpha: 1.0] retain];
		exactMatchCol = [[NSColor colorWithDeviceRed: 0.5
											   green: 1.0
												blue: 0.5
											   alpha: 1.0] retain];
		
		commandCol = [[NSColor colorWithDeviceRed: 0.6
											green: 0.8
											 blue: 1.0
											alpha: 1.0] retain];
		
		highlightCol = [[NSColor colorWithDeviceRed: 0.4
											  green: 0.4
											   blue: 1.0
											  alpha: 1.0] retain];
		activeCol = [[NSColor colorWithDeviceRed: 1.0
										   green: 1.0
											blue: 0.7
										   alpha: 1.0] retain];
	}
}

- (id) init {
	self = [super init];
	
	if (self) {
		if (!defaultAttributes) {
			defaultAttributes = [[NSDictionary dictionaryWithObjectsAndKeys: 
				[NSFont systemFontOfSize: 11], NSFontAttributeName,
				[[[NSParagraphStyle alloc] init] autorelease], NSParagraphStyleAttributeName,
				nil] retain];
		}
		
		attributes = [defaultAttributes retain];
		
		expected = [[NSTextStorage alloc] init];
		transcript = [[NSTextStorage alloc] init];
        
        if( !layoutManager ) {
            layoutManager = [[NSLayoutManager alloc] init];
        }
        else {
            [layoutManager retain];
        }
	}
	
	return self;
}

- (void) dealloc {
	[skein release]; skein = nil;
	[skeinItem release]; skeinItem = nil;
	
	[command release]; command = nil;
	[transcript setDelegate: nil]; [transcript release]; transcript = nil;
	[expected setDelegate: nil]; [expected release]; expected = nil;
	
	[attributes release]; attributes = nil;
	
	[transcriptContainer release]; transcriptContainer = nil;
	[expectedContainer release]; expectedContainer = nil;
	
	[fieldEditor setDelegate: nil];
	[fieldEditor release]; fieldEditor = nil;
    
    [layoutManager release]; layoutManager = nil;
	
	[super dealloc];
}

// = Setting the item data =

- (void) setSkeinItem: (ZoomSkeinItem*) item {
	[skeinItem release];
	skeinItem = [item retain];
}

- (void) setSkein: (ZoomSkein*) newSkein {
	[skein release];
	skein = [newSkein retain];
}

- (ZoomSkeinItem*) skeinItem {
	return skeinItem;
}

- (void) setCommand: (NSString*) newCommand {
	[command release]; command = [newCommand copy];
	
	calculated = NO;
}

- (void) setTranscript: (NSString*) newTranscript {
	[transcript setDelegate: nil];
	[transcript release]; transcript = nil;
	[transcriptContainer release]; transcriptContainer = nil;
	
	if (newTranscript == nil) newTranscript = @"";
	
	transcript = [[NSTextStorage alloc] initWithString: newTranscript
											attributes: attributes];
	
	calculated = NO;
}

- (void) setExpected: (NSString*) newExpected {
	[expected setDelegate: nil];
	[expected release]; expected = nil;
	[expectedContainer release]; expectedContainer = nil;
	
	if (newExpected == nil) newExpected = @"";
	
	expected = [[NSTextStorage alloc] initWithString: newExpected
										  attributes: attributes];
	
	calculated = NO;
}

- (void) setPlayed: (BOOL) newPlayed {
	played = newPlayed;
}

- (void) setChanged: (BOOL) newChanged {
	changed = newChanged;
}

- (void) setAttributes: (NSDictionary*) newAttributes {
	[attributes release]; attributes = [newAttributes copy];
	
	calculated = NO;
}

- (NSDictionary*) attributes {
	return attributes;
}

- (BOOL) isDifferent {
	return textEquality == 0;
}

// = Setting the data from the view =

- (void) setWidth: (float) newWidth {
	width = newWidth;
	
	calculated = NO;
}

- (void) setOffset: (float) newOffset {
	offset = newOffset;
}

- (float) offset {
	return offset;
}

// = Calculating the height of this item =

- (NSString*) stripWhitespace: (NSString*) otherString {
	NSMutableString* res = [[otherString mutableCopy] autorelease];
	
	// Sigh. Need perl. (stringByTrimmingCharactersInSet would have been perfect if it applied across the whole string)
	int pos;
	for (pos=0; pos<[res length]; pos++) {
		unichar chr = [res characterAtIndex: pos];
		
		if (chr == '\n' || chr == '\r' || chr == ' ' || chr == '\t') {
			// Whitespace character
			[res deleteCharactersInRange: NSMakeRange(pos, 1)];
			pos--;
		}
	}
	
	// Remove a trailing '>'
	if ([res length] > 0 && [res characterAtIndex: [res length]-1] == '>') {
		[res deleteCharactersInRange: NSMakeRange([res length]-1, 1)];
	}
	
	return res;
}

- (NSTextContainer*) containerForString: (NSTextStorage*) string
							  withWidth: (float) stringWidth {
	// Return nothing if it's not sensible to lay out this string
	if (!string) return nil;
	if (stringWidth <= 48) return nil;
	
	// Create the NSTextContainer and the layout manager
	NSTextContainer* container = [[NSTextContainer alloc] initWithContainerSize: NSMakeSize(stringWidth, 10e6)];
	NSLayoutManager* layout = [[NSLayoutManager alloc] init];

	[container setWidthTracksTextView: NO];
	[container setHeightTracksTextView: NO];
	
	[layout setBackgroundLayoutEnabled: NO];
	
	[layout addTextContainer: container];
	
	// Add the storage to the layout manager
	[string addLayoutManager: layout];
	
	// Return the results
	[layout autorelease];
	return [container autorelease];
}

- (float) heightForContainer: (NSTextContainer*) container {
	NSLayoutManager* layout = [container layoutManager];

	NSRange glyphs = [layout glyphRangeForCharacterRange: NSMakeRange(0, [[layout textStorage] length])
									actualCharacterRange: nil];
	NSRect bounds = [layout boundingRectForGlyphRange: glyphs
									  inTextContainer: container];
	
	return NSMaxY(bounds);
}

- (void) calculateEquality {
	NSAttributedString* expectedToCompare = expected;
	
	if (fieldEditor && editing == expected) expectedToCompare = [fieldEditor textStorage];
	
	// Compare the 'expected' text and the 'actual' text
	textEquality = 0;
	if (expected == nil || [[expectedToCompare string] isEqualToString: @""]) {
		textEquality = -1;				// No text
	} else if ([[expectedToCompare string] isEqualToString: [transcript string]]) {
		textEquality = 2;				// Exact match
	} else if ([[self stripWhitespace: [expectedToCompare string]] caseInsensitiveCompare: [self stripWhitespace: [transcript string]]] == 0) {
		textEquality = 1;				// Near match
	}
}

- (NSArray*) wordsForString: (NSString*) string {
	// Seperates 'string' into individual words
	NSMutableArray* res = [NSMutableArray array];
	
	int x;
	int len = [string length];
	int lastWord = 0;
	
	for (x=0; x<len; x++) {	
		unichar chr;
		
		chr = [string characterAtIndex: x];
		if (chr == ' ' || chr == '\n' || chr == '\r' || chr == '\t' || x == len-1) {
			// Word seperator
			[res addObject: [string substringWithRange: NSMakeRange(lastWord, (x+1)-lastWord)]];
			lastWord = x+1;
		}
	}
	
	return res;
}

- (void) underlineRegion: (NSRange) range
				  layout: (NSLayoutManager*) layout {
	static NSColor* underlineColour = nil;
	static NSNumber* underlineStyle = nil;
	static NSDictionary* underlineAttributes = nil;
	
	if (!underlineColour) {
		underlineColour = [[NSColor colorWithDeviceRed: 0
												 green: 0
												  blue: 0
												 alpha: 1.0] retain];
		underlineStyle = [[NSNumber numberWithInt: NSUnderlineStyleDouble] retain];
		
		underlineAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
			underlineStyle, NSUnderlineStyleAttributeName,
			underlineColour, NSUnderlineColorAttributeName,
			nil] retain];
	}
	
	[layout addTemporaryAttributes: underlineAttributes
				 forCharacterRange: range];
}

- (void) diffItem {
	// Compares this item's result to its 'expected' result
	if (diffed) return;
	// if (fieldEditor) return;
	
	NSTextStorage* exptStorage = expected;
	NSLayoutManager* exptLayout = [expectedContainer layoutManager];
	
	if (fieldEditor && editing == expected) {
		exptStorage = [fieldEditor textStorage];
		exptLayout = [fieldEditor layoutManager];
	}
	
	NSTextStorage* transStorage = transcript;
	NSLayoutManager* transLayout = [transcriptContainer layoutManager];
	
	if (fieldEditor && editing == transcript) {
		transStorage = [fieldEditor textStorage];
		transLayout = [fieldEditor layoutManager];
	}
	
	// Clear out any old temporary attributes we might have had
	[transLayout removeTemporaryAttribute: NSUnderlineStyleAttributeName
						forCharacterRange: NSMakeRange(0, [transStorage length])];
	[exptLayout removeTemporaryAttribute: NSUnderlineStyleAttributeName
					   forCharacterRange: NSMakeRange(0, [exptStorage length])];
	
	// Don't go any further if the expected storage is empty
	if ([exptStorage length] <= 0) {
		diffed = YES;
		return;
	}
	
	// Split the transcript and the expected items into arrays of words
	NSArray* transcriptWords = [self wordsForString: [transStorage string]];
	NSArray* expectedWords = [self wordsForString: [exptStorage string]];
	
	// Work out the difference
	IFDiff* difference = [[[IFDiff alloc] initWithSourceArray: transcriptWords
											 destinationArray: expectedWords] autorelease];
	
	NSArray* transcriptMap = [difference compareArrays];
	
	// Underline the words in the source array that have changed (words with value -1 in the map)
	int expectedMap[[expectedWords count]];
	
	int pos = 0;
	int x;
	int expectedWordCount = [expectedWords count];
	
	for (x=0; x<expectedWordCount; x++) expectedMap[x] = -1;
	
	int len = [transcriptWords count];

	for (x=0; x<len; x++) {
		int wordLen = [[transcriptWords objectAtIndex: x] length];
		int map = [[transcriptMap objectAtIndex: x] intValue];
		
		if (map < 0) {
			[self underlineRegion: NSMakeRange(pos, wordLen)
						   layout: transLayout];
		} else {
			expectedMap[map] = x;
		}
		
		pos += wordLen;
	}
	
    // Just paranoia on my part - check the expected word count hasn't changed
    NSAssert(expectedWordCount == [expectedWords count], @"Word count has changed??");
	pos = 0;
	
	for (x=0; x<expectedWordCount; x++) {
		int wordLen = [[expectedWords objectAtIndex: x] length];
		int map = expectedMap[x];
		
		if (map < 0) {
			[self underlineRegion: NSMakeRange(pos, wordLen)
						   layout: exptLayout];
		}
		
		pos += wordLen;
	}	
	
	// Mark this as done
	diffed = YES;
}

- (void) calculateItem {
	if (calculated) return;
	
	// Mark ourselves as un-diffed
	diffed = NO;
	
	// Make/resize the text containers
	float stringWidth = floorf(width/2.0 - 44.0);
	
	if (!transcriptContainer) {
		transcriptContainer = [[self containerForString: transcript
											  withWidth: stringWidth] retain];
	} else {
		[transcriptContainer setContainerSize: NSMakeSize(stringWidth, 10e6)];
	}
	
	if (!expectedContainer) {
		expectedContainer = [[self containerForString: expected
											withWidth: stringWidth] retain];
	} else {
		[expectedContainer setContainerSize: NSMakeSize(stringWidth, 10e6)];
	}
	
	// Height is:
	//   a = Maximum(height of transcript, height of extra)
	//   b = Height of font set in attributes
	// height = a + 2*b
	// (quarter-line gap above/below text and command)
	
	NSFont* font = [attributes objectForKey: NSFontAttributeName];
	
	float fontHeight = [layoutManager defaultLineHeightForFont:font];
	float transcriptHeight = [self heightForContainer: transcriptContainer];
	float expectedHeight = [self heightForContainer: expectedContainer];
	
	if (fieldEditor && editing == transcript) transcriptHeight = 0;
	if (fieldEditor && editing == expected) expectedHeight = 0;
	
	textHeight = floorf(transcriptHeight>expectedHeight ? transcriptHeight : expectedHeight);
	if (textHeight < 48.0) textHeight = 48.0;
	
	if (fieldEditor) {
		// If we're editing, the field editor height factors into this
		float fieldHeight = [self heightForContainer: [fieldEditor textContainer]];
		
		if (fieldHeight > textHeight) textHeight = fieldHeight;
	}
	
	height = floorf(textHeight + 2*fontHeight);
	
	// Compare the 'expected' text and the 'actual' text
	[self calculateEquality];

	// Mark this item as calculated
	calculated = YES;
}

- (BOOL) calculated {
	return calculated;
}

- (float) height {
	if (!calculated) return 18.0;
	
	return height;
}

- (float) textHeight {
	if (!calculated) return 18.0;
	
	return textHeight;
}

// = Drawing =

- (void) drawBorder: (NSRect) border
			  width: (float) borderWidth {
	NSRect r;
	
	// Top
	r = border;
	r.size = NSMakeSize(border.size.width, borderWidth);
	NSRectFill(r);
	
	// Left
	r = border;
	r.size = NSMakeSize(borderWidth, border.size.height);
	NSRectFill(r);
	
	// Bottom
	r = NSMakeRect(border.origin.x, NSMaxY(border) - borderWidth, border.size.width, borderWidth);
	NSRectFill(r);
	
	// Right
	r = NSMakeRect(NSMaxX(border) - borderWidth, border.origin.y, borderWidth, border.size.height);
	NSRectFill(r);
}

- (void) drawAtPoint: (NSPoint) point
		 highlighted: (BOOL) highlighted
			  active: (BOOL) active {
	// Draw nothing if we don't know our size yet
	if (!calculated) return;
	
	if (!diffed) [self diffItem];

	// Work out some metrics
	NSFont* font = [attributes objectForKey: NSFontAttributeName];
	
	float fontHeight = [layoutManager defaultLineHeightForFont:font];
	
	// Draw the command (blue background: this is also where we put control buttons for this object)
	[commandCol set];
	NSRectFill(NSMakeRect(point.x, point.y, width, fontHeight * 1.5));
	
	[command drawAtPoint: NSMakePoint(floorf(point.x + 12.0), floorf(point.y + fontHeight*.25))
		  withAttributes: attributes];
	
	// Draw the transcript background
	NSRect textRect;
	
	textRect.origin = NSMakePoint(floorf(point.x + 8.0), floorf(point.y + fontHeight * 1.75));
	textRect.size = NSMakeSize(floorf(width/2.0 - 44.0), floorf(textHeight));
	
	if (!played) {
		[unplayedCol set];
	} else if (!changed) {
		[unchangedCol set];
	} else {
		[changedCol set];
	}
	
	NSRectFill(NSMakeRect(point.x, floorf(point.y + fontHeight*1.5), floorf(width/2.0), floorf(textHeight + fontHeight*0.5)));
	
	NSPoint transcriptPoint = textRect.origin;
	
	// Draw the expected background
	textRect.origin = NSMakePoint(floorf(point.x + width/2.0 + 36.0), textRect.origin.y);
	
	switch (textEquality) {
		case -1: [noExpectedCol set]; break;
		case 1:  [nearMatchCol set]; break;
		case 2:  [exactMatchCol set]; break;
		default: [noMatchCol set]; break;
	}
	
	NSRectFill(NSMakeRect(point.x + floorf(width/2.0), floorf(point.y + fontHeight*1.5), floorf(width/2.0), floorf(textHeight + fontHeight*0.5)));
	
	NSPoint expectedPoint = textRect.origin;

	// Draw the separator lines
	[[NSColor controlShadowColor] set];
	NSRectFill(NSMakeRect(point.x+floorf(width/2.0), floorf(point.y + fontHeight*1.5), 1, floorf(textHeight + fontHeight*0.5)));	// Between the 'transcript' and the 'expected' text
	NSRectFill(NSMakeRect(point.x, floorf(point.y + fontHeight*1.5), width, 1));													// Between the command and the transcript
	NSRectFill(NSMakeRect(point.x, floorf(point.y + fontHeight*2.0 + textHeight)-1, width, 1));										// Along the bottom
	
	// Draw any borders we might want
	if (highlighted || active) {
		textRect.origin = NSMakePoint(point.x, point.y);
		textRect.size = NSMakeSize(width, height);
		
		if (active) {
			[activeCol set];
			[self drawBorder: textRect
					   width: 4.0];
		}
		
		if (highlighted) {
			[highlightCol set];
			[self drawBorder: textRect
					   width: 2.0];
		}
	}
		
	// Draw the transcript text
	if (!fieldEditor || editing != transcript) {
		NSLayoutManager* layout = [transcriptContainer layoutManager];
		NSRange glyphRange = [layout glyphRangeForTextContainer: transcriptContainer];
		[layout drawGlyphsForGlyphRange: glyphRange
								atPoint: transcriptPoint];
	}
	
	// Draw the expected text
	if (!fieldEditor || editing != expected) {
		NSLayoutManager* layout = [expectedContainer layoutManager];
		NSRange glyphRange = [layout glyphRangeForTextContainer: expectedContainer];
		[layout drawGlyphsForGlyphRange: glyphRange
								atPoint: expectedPoint];	
	}
}

// = Delegate =

- (void) setDelegate: (id) newDelegate {
	delegate = newDelegate;
}

- (void) transcriptItemHasChanged: (id) sender {
	if (delegate && [delegate respondsToSelector: @selector(transcriptItemHasChanged:)]) {
		[delegate transcriptItemHasChanged: self];
	}
}

// = Field editing =

- (void) setupFieldEditor: (NSTextView*) newFieldEditor
			  forExpected: (BOOL) editExpected
				  atPoint: (NSPoint) itemOrigin {
	NSRect editorFrame;
	float stringWidth = floorf(width/2.0 - 44.0);
	float fontHeight = [layoutManager defaultLineHeightForFont:[attributes objectForKey: NSFontAttributeName]];
	
	// Finish up the old editor, if there was one
	if (fieldEditor) {
		[fieldEditor setDelegate: nil];
		[fieldEditor release]; fieldEditor = nil;
	}
	
	fieldEditor = [newFieldEditor retain];
	
	// Work out the frame for the item
	editorFrame.origin = itemOrigin;
	editorFrame.size = NSMakeSize(stringWidth, textHeight);
	
	editorFrame.origin.y += floorf(1.75*fontHeight);
	
	if (!editExpected) {
		editorFrame.origin.x += 8.0;
	} else {
		editorFrame.origin.x += floorf(width/2.0 + 36.0);
	}
	
	// Get the item to edit
	NSTextStorage* storage;
	NSColor* background;
	
	if (!editExpected) {
		// Storage is the transcript
		storage = transcript;
		
		// Set the background colour appropriately
		if (!played) {
			background = unplayedCol;
		} else if (!changed) {
			background = unchangedCol;
		} else {
			background = changedCol;
		}
	} else {
		// Storage is the 'expected' text
		storage = expected;

		// Set the background colour appropriately
		switch (textEquality) {
			case -1: background = noExpectedCol; break;
			case 1:  background = nearMatchCol; break;
			case 2:  background = exactMatchCol; break;
			default: background = noMatchCol; break;
		}
	}
	
	// Prepare the field editor
	[[fieldEditor textStorage] setAttributedString: storage];
	[[fieldEditor textStorage] setDelegate: self];
	editing = storage;
	
	[fieldEditor setDelegate: self];
	[fieldEditor setFrame: editorFrame];
	
	[fieldEditor setRichText: NO];
	[fieldEditor setAllowsDocumentBackgroundColorChange: NO];
	[fieldEditor setBackgroundColor: background];
	[fieldEditor setFieldEditor: NO];							// (Sigh - hack, doesn't appear to be a better way to get newlines inserted properly. A field editor that is not a field editor: very zen)
	
	[fieldEditor setAlignment: NSNaturalTextAlignment];
	
	[fieldEditor setHorizontallyResizable:NO];
	[fieldEditor setVerticallyResizable:YES];
	[[fieldEditor textContainer] setContainerSize: NSMakeSize(editorFrame.size.width, 10e6)];
	[[fieldEditor textContainer] setWidthTracksTextView:NO];
	[[fieldEditor textContainer] setHeightTracksTextView:NO];
	[[fieldEditor textContainer] setLineFragmentPadding: [transcriptContainer lineFragmentPadding]];
	[fieldEditor setDrawsBackground: YES];
}

- (void) setupFieldEditorForCommand: (NSTextView*) newFieldEditor
							 margin: (float) margin
							atPoint: (NSPoint) itemOrigin {
	float stringWidth = floorf(width - 12.0 - margin);
	float fontHeight = [layoutManager defaultLineHeightForFont:[attributes objectForKey: NSFontAttributeName]];

	// Finish up the old editor, if there was one
	if (fieldEditor) {
		[fieldEditor setDelegate: nil];
		[fieldEditor release]; fieldEditor = nil;
	}
	
	fieldEditor = [newFieldEditor retain];
	
	// Work out the frame for this field editor
	NSRect commandFrame = NSMakeRect(itemOrigin.x + 12.0, floorf(itemOrigin.y + fontHeight*0.25), stringWidth, fontHeight);
	
	editing = nil;
	editingCommand = YES;
	
	// Prepare the field editor
	[[fieldEditor textStorage] setAttributedString: [[[NSAttributedString alloc] initWithString: command
																					 attributes: attributes] autorelease]];
	[[fieldEditor textStorage] setDelegate: self];
	
	[fieldEditor setDelegate: self];
	[fieldEditor setFrame: commandFrame];
	
	[fieldEditor setRichText: NO];
	[fieldEditor setAllowsDocumentBackgroundColorChange: NO];
	[fieldEditor setBackgroundColor: commandCol];
	[fieldEditor setFieldEditor: YES];
	
	[fieldEditor setAlignment: NSNaturalTextAlignment];
	
	[fieldEditor setHorizontallyResizable: NO];
	[fieldEditor setVerticallyResizable: NO];
	[[fieldEditor textContainer] setContainerSize: NSMakeSize(stringWidth, fontHeight)];
	[[fieldEditor textContainer] setWidthTracksTextView: NO];
	[[fieldEditor textContainer] setHeightTracksTextView: NO];
	[[fieldEditor textContainer] setLineFragmentPadding: 0];
	[fieldEditor setDrawsBackground: YES];	

	// Update the field editor with the difference information
	diffed = NO;
	[self diffItem];
}

- (void) finishEditing: (id) sender {	
	if (!fieldEditor) return;
	
	[[self retain] autorelease];						// Mild chance that the skein item will get destroyed, destroying us along with it. This preserves us for a while.
	updating = YES;
	diffed = NO;
	
	// Inform the delegate of what's happened
	[self transcriptItemHasChanged: self];

	// Update the skein item
	NSTextStorage* storage = [fieldEditor textStorage];
	[editing setAttributedString: storage];
	
	if (skeinItem) {
		if (editing == transcript) {
			BOOL wasChanged = [skeinItem changed];
			
			[skeinItem setResult: [storage string]];

			[skeinItem setChanged: wasChanged];
		} else if (editing == expected) {
			[skeinItem setCommentary: [storage string]];
		} else if (editing == nil && editingCommand) {
			NSString* newCommand = [[fieldEditor textStorage] string];
			
			if (newCommand && ![newCommand isEqualToString: [skeinItem command]]) {
				ZoomSkeinItem* otherItem = [[skeinItem parent] childWithCommand: newCommand];

				if (otherItem) {
					// Have to remove and re-add
					ZoomSkeinItem* parent = [skeinItem parent];
					[skeinItem removeFromParent];
					[skeinItem setCommand: newCommand];
					[parent addChild: skeinItem];
				} else {
					// Safe to just rename
					[skeinItem setCommand: newCommand];					
				}
				
				[skein zoomSkeinChanged];
			}
		}
	}
	
	// Don't need to be the delegate of these things any more
	[transcript setDelegate: nil];
	[expected setDelegate: nil];
	
	// Shut down the field editor
	[fieldEditor setFieldEditor: YES];
	[[fieldEditor textStorage] setDelegate: nil];
	[fieldEditor setDelegate: nil];
	[fieldEditor removeFromSuperview];
	
	[fieldEditor release]; fieldEditor = nil;
	
	// Recalculate this item
	calculated = NO;
	diffed = NO;
	[self calculateItem];
	
	updating = NO;
}

- (BOOL) updating {
	return updating;
}

- (void) textDidEndEditing: (NSNotification*) aNotificationn {
	// Check if the user left the field before committing changes and end the edit.
	[self finishEditing: fieldEditor];				// Store the results
}

- (void) textStorageDidProcessEditing: (NSNotification *)aNotification {
	NSTextStorage* storage = [aNotification object];
	
	// Set the attributes
	[storage addAttributes: attributes 
					 range: [storage editedRange]];
	
	// Queue up a recalculation request (we can't measure the text here, so we have to do it later)
	[[NSRunLoop currentRunLoop] performSelector: @selector(finishProcessingEditing:)
										 target: self
									   argument: storage
										  order: 64
										  modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
}

- (void) finishProcessingEditing: (NSTextStorage*) storage {
	// Recalculate appropriately
	float fontHeight = [layoutManager defaultLineHeightForFont:[attributes objectForKey: NSFontAttributeName]];
	float transcriptHeight = [self heightForContainer: transcriptContainer];
	float expectedHeight = [self heightForContainer: expectedContainer];
	
	if (editing == transcript) transcriptHeight = 0;
	if (editing == expected) expectedHeight = 0;
		
	float newTextHeight = floorf(transcriptHeight>expectedHeight ? transcriptHeight : expectedHeight);
	if (newTextHeight < 48.0) newTextHeight = 48.0;
	
	float fieldHeight = [self heightForContainer: [fieldEditor textContainer]];
	if (fieldHeight > newTextHeight) newTextHeight = floorf(fieldHeight);
	
	if (newTextHeight != textHeight) {
		textHeight = newTextHeight;
		height = floorf(textHeight + 2*fontHeight);
		
		[self transcriptItemHasChanged: self];
	}
	
	// If we're editing the expected text, set the background colour appropriately
	if (editing == expected) {
		int oldEquality = textEquality;
		[self calculateEquality];
		
		if (oldEquality != textEquality) {
			NSColor* background;
			switch (textEquality) {
				case -1: background = noExpectedCol; break;
				case 1:  background = nearMatchCol; break;
				case 2:  background = exactMatchCol; break;
				default: background = noMatchCol; break;
			}
			
			if (background != [fieldEditor backgroundColor] &&
				![background isEqualTo: [fieldEditor backgroundColor]]) {
				[fieldEditor setBackgroundColor: background];
				[self transcriptItemHasChanged: self];
			}
		}
	}

	// Spot the differences
	if (!willRecalculateDiff) {
		[self performSelector: @selector(performDiff:)
				   withObject: nil
				   afterDelay: 0.5];
		
		willRecalculateDiff = YES;
	}
}

- (void) performDiff: (id) arg {
	// Callback that periodically performs a diff operation
	willRecalculateDiff = NO;
	
	// Perform the diff
	diffed = NO;
	[self diffItem];
	
	// Notify of the change
	[fieldEditor setNeedsDisplay: YES];
	[self transcriptItemHasChanged: self];
}

@end
