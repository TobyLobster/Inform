//
//  GlkTextWindow.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 20/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#include <tgmath.h>
#import "GlkTextWindow.h"

#import "GlkImage.h"
#import "GlkClearMargins.h"
#import "GlkMoreView.h"
#import <GlkView/GlkPairWindow.h>
#import <GlkView/GlkView.h>


// Number of pixels to shorten the maximum length of text before a more prompt is shown
#define MoreMargin 16.0
// Height below which no more prompt will ever be shown
#define MinimumMoreHeight 32.0
// Time to show/hide the [ MORE ] prompt
#define MoreAnimationTime 1

@implementation GlkTextWindow

- (void) setupTextview {
	// Construct the text system
	textStorage = [[NSTextStorage alloc] init];
	
	layoutManager = [[NSLayoutManager alloc] init];
	[textStorage addLayoutManager: layoutManager];
	
	margin = 0;
	
	// Create the typesetter
	typesetter = [[GlkTypesetter alloc] init];
	[layoutManager setTypesetter: typesetter];
	[layoutManager setShowsControlCharacters: NO];
	[layoutManager setShowsInvisibleCharacters: NO];
	
	// Create the text container
	lastMorePos = 0;
	nextMorePos = [self frame].size.height - MoreMargin;
	NSTextContainer* newContainer = [[NSTextContainer alloc] initWithContainerSize: NSMakeSize(1e8, [self frame].size.height - MoreMargin)];
	
	[newContainer setLayoutManager: layoutManager];
	[layoutManager addTextContainer: newContainer];
	
	[newContainer setContainerSize: NSMakeSize(1e8, 1e8)];
	[newContainer setWidthTracksTextView: YES];
	[newContainer setHeightTracksTextView: NO];
				
	// Create the text view and the scroller
	textView = [[GlkTextView alloc] initWithFrame: [self frame]];
	scrollView = [[NSScrollView alloc] initWithFrame: [self frame]];
	
	[typesetter setDelegate: textView];
	[textView setTextContainer: newContainer];
	[newContainer setTextView: textView];
				
	// [[textView textContainer] setWidthTracksTextView: YES];
	//[[textView textContainer] setContainerSize: NSMakeSize(1e8, 1e8)];
	[textView setMinSize:NSMakeSize(0.0, 0.0)];
	[textView setMaxSize:NSMakeSize(1e8, 1e8)];
	[textView setVerticallyResizable:YES];
	[textView setHorizontallyResizable:NO];
	[textView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
	[textView setEditable: NO];
    [textView setRichText: YES];
	[textView setUsesFindPanel: YES]; // FIXME: Won't work on Jaguar
	
	inputPos = 0;
	[[textView textStorage] setDelegate: self];
	[textView setDelegate: self];
	
	[scrollView setDocumentView: textView];
	[scrollView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
	[scrollView setHasHorizontalScroller: NO];
	[scrollView setHasVerticalScroller: YES];
	[scrollView setAutohidesScrollers: NO];
	
	// Set up kerning/ligatures
	if ([preferences useLigatures]) {
		[textView useStandardLigatures: self];
	} else {
		[textView turnOffLigatures: self];
	}
	if ([preferences useKerning]) {
		[textView useStandardKerning: self];
	} else {
		[textView turnOffKerning: self];
	}
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
		// Build the text view
		hasMorePrompt = YES;
		[self setupTextview];
		//[self addSubview: scrollView];
		
		// Set the hyperlink style
		NSDictionary* hyperStyle = @{
			NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
			NSCursorAttributeName: [NSCursor pointingHandCursor]};
		[textView setLinkTextAttributes: hyperStyle];
		
		// Construct the window that shows the [ MORE ] prompt
		NSView* moreView = [[GlkMoreView alloc] init];
		moreWindow = [[NSWindow alloc] initWithContentRect: [moreView bounds]
												 styleMask: NSWindowStyleMaskBorderless
												   backing: NSBackingStoreBuffered
													 defer: YES];

		[moreWindow setBackgroundColor: [NSColor clearColor]];
		[moreWindow setOpaque: NO];
		[moreWindow setContentView: moreView];
    }
    
	return self;
}

- (void) dealloc {
	[textView setDelegate: nil];
	[[textView textStorage] setDelegate: nil];
	
	[[moreWindow parentWindow] removeChildWindow: moreWindow];
	[moreWindow orderOut: self];
}

- (void) updateWithPrefs: (GlkPreferences*) prefs {
	margin = [prefs textMargin];
	[textView setTextContainerInset: NSMakeSize(margin, margin)];
	[[textView layoutManager] setUsesScreenFonts: [prefs useScreenFonts]];
	if (@available(macOS 10.15, *)) {
		[[textView layoutManager] setUsesDefaultHyphenation: [prefs useHyphenation]];
	} else {
		[[textView layoutManager] setHyphenationFactor: [prefs useHyphenation]?1:0];
	}
}

- (void) setPreferences: (GlkPreferences*) prefs {
	[super setPreferences: prefs];
	
	// Adding a new method makes this easier to customise for the grid window (which still needs the
	// standard window behaviour, but doesn't want to use hyphenation or the text container inset)
	[self updateWithPrefs: prefs];
}

#pragma mark - Drawing

- (void) drawRect: (NSRect) r {
	[[self backgroundColour] set];
	NSRectFill(r);
}

#pragma mark - Window control

- (void) taskFinished {
	// The text should be made non-editable
	if (lineInput) [self cancelLineInput];
	if (charInput) [self cancelCharInput];
	
	[textView setEditable: NO];
}
	
- (void) clearWindow {
	[[[textView textStorage] mutableString] deleteCharactersInRange: NSMakeRange(0, inputPos)];
	inputPos = 0;
	moreOffset = 0;
	lastMorePos = 0;
	nextMorePos = [[scrollView contentView] frame].size.height - MoreMargin;
	[textView setNeedsDisplay: YES];
	[self setMoreShown: NO];
	[self resetMorePrompt: 0
				   paging: NO];
}

- (void) setStyles: (NSDictionary*) newStyles {
	[super setStyles: newStyles];
	
	[textView setBackgroundColor: [self backgroundColour]];
}

- (void) bufferIsFlushing {
	// Tell the text storage that some editing is due to come along shortly
	if (!flushing) {
		[[textView textStorage] beginEditing];
		flushing = YES;
	}
}

- (void) bufferHasFlushed {
	// We've finished editing
	if (flushing) {
		flushing = NO;
		[[textView textStorage] endEditing];
		
		[self resetMorePrompt: moreOffset
					   paging: NO];

		[self scrollToEnd];
		[self displayMorePromptIfNecessary];
	}
}

#pragma mark - Layout

- (void) layoutInRect: (NSRect) parentRect {
	BOOL wasFlushing = flushing;
	if (wasFlushing) {
		[[textView textStorage] endEditing];
		flushing = NO;
	}
	
	if ([scrollView superview] != self) {
		[scrollView removeFromSuperview];
		[self addSubview: scrollView];
	}
	
	[self setFrame: parentRect];
	[scrollView setFrame: [self bounds]];

	GlkSize newSize = [self glkSize];
	if (newSize.width != lastSize.width || newSize.height != lastSize.height) {
		[containingView requestClientSync];
	}
	
	lastSize = [self glkSize];
	
	if (wasFlushing) {
		[[textView textStorage] beginEditing];
		flushing = YES;
	}
}

- (CGFloat) widthForFixedSize: (unsigned) size {
	NSSize baseSize = [@"M" sizeWithAttributes: [self currentTextAttributes]];
	
	return floor(size * baseSize.width) + (margin*2);
}

- (CGFloat) heightForFixedSize: (unsigned) size {
	return floor(size * [self lineHeight]) + (margin*2);
}

- (void) setScaleFactor: (CGFloat) newScaleFactor {
	if (scaleFactor == newScaleFactor) return;
	
	// First, do whatever GlkWindow wants to do with the scale factor
	[super setScaleFactor: newScaleFactor];
	
	// Next, adjust all of the styles in this window appropriately
	BOOL wasFlushing = flushing;
	if (!wasFlushing) {
		flushing = YES;
		[textStorage beginEditing];
	}
	
	// Iterate through all of the attribute runs in this view...
	if ([textStorage length] > 0) {
		NSRange attributeRange;
		NSDictionary* oldAttributes = [textStorage attributesAtIndex: 0
													  effectiveRange: &attributeRange];
		while (attributeRange.location < [textStorage length]) {
			GlkStyle* oldStyle = [oldAttributes objectForKey: GlkStyleAttributeName];
			
			if (oldStyle) {
				// Generate the new attributes for the old style
				NSDictionary* newAttributes = [oldStyle attributesWithPreferences: preferences
																	  scaleFactor: newScaleFactor];
				[textStorage setAttributes: newAttributes
									 range: attributeRange];
			}
			
			// Move on
			if (attributeRange.length <= 0) {
				attributeRange.length = 1;
			}
			if (attributeRange.location + attributeRange.length >= [textStorage length]) break;
			oldAttributes = [textStorage attributesAtIndex: attributeRange.location + attributeRange.length
											effectiveRange: &attributeRange];
		}
	}
	
	if (!wasFlushing) {
		flushing = NO;
		[textStorage endEditing];
	}
}

#pragma mark - Hyperlink input

- (BOOL) textView: (NSTextView*) view
	clickedOnLink: (id) link 
		  atIndex: (NSUInteger) charIndex {
	if ([link isKindOfClass: [NSNumber class]]) {
		if (hyperlinkInput) {
			// Generate the event for this hyperlink
			GlkEvent* evt = [[GlkEvent alloc] initWithType: evtype_Hyperlink
										  windowIdentifier: [self glkIdentifier]
													  val1: [link unsignedIntValue]
													  val2: 0];
			[target queueEvent: evt];

			hyperlinkInput = NO;
		}
		
		return YES;
	}
	
	return NO;
}

#pragma mark - Line input

- (void) updateCaretPosition {
	if (inputPos > [textView selectedRange].location) {
		[textView setSelectedRange: NSMakeRange([[textView textStorage] length], 0)];
	}
}

- (void) keyDown: (NSEvent*) evt {
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
				history = [[self containingView] nextHistoryItem];
				break;
		}
		
		if (history != nil) {
			// Move to a specific history item
			[[textView textStorage] replaceCharactersInRange: NSMakeRange(inputPos, [[textView textStorage] length]-inputPos)
												  withString: history];
		}
	} else {
		[super keyDown: evt];
	}
}

- (BOOL)    	textView:(NSTextView *)aTextView
 shouldChangeTextInRange:(NSRange)affectedCharRange
	   replacementString:(NSString *)replacementString {
    if (affectedCharRange.location < inputPos) {
        return NO;
    } else {
        return YES;
    }
}

- (void)textStorage:(NSTextStorage *)textStorage
 willProcessEditing:(NSTextStorageEditActions)editedMask
			  range:(NSRange)editedRange
	 changeInLength:(NSInteger)delta {
	// Force the typesetter to reset so that it doesn't try to lay out new glyphs with out-of-date metrics
	[(GlkTypesetter*)[[textView layoutManager] typesetter] flushCache];
	
	// Perform no other action on edits that aren't in the input range
	if (editedRange.location < inputPos) {
		return;
	}
	
	// Anything newly added should be in the input style
	[[textView textStorage] setAttributes: [self attributes: style_Input]
									range: editedRange];
}

@synthesize inputPos;

- (void) forceLineInput: (NSString*) forcedInput {
	if (lineInput) {
		// Switch off line input so our edits don't get sent to the task
		lineInput = NO;
		
		// Write out the forced input line
		NSMutableString* buffer = [[textView textStorage] mutableString];
		[buffer replaceCharactersInRange: NSMakeRange(inputPos, [buffer length]-inputPos)
							  withString: forcedInput];
		[buffer appendString: @"\n"];
		
		// Reset the input position
		inputPos = [buffer length];
		
		// Generate the event
		GlkEvent* evt = [[GlkEvent alloc] initWithType: evtype_LineInput
									  windowIdentifier: [self glkIdentifier]
												  val1: (int)[forcedInput length]
												  val2: 0];
		[evt setLineInput: forcedInput];

		// Add to the line history
		[[self containingView] resetHistoryPosition];
		[[self containingView] addHistoryItem: forcedInput
							  forWindowWithId: [self glkIdentifier]];
		
		// ... send it
		[target queueEvent: evt];
		
		// We're no longer editable
		[self makeTextNonEditable];
	} else if (charInput) {
		[super forceLineInput: forcedInput];
	}
}

- (void)hackTextStorageDidProcessEditing:(NSNotification *)aNotification {
	// hack!
	[self textStorage: [textView textStorage] didProcessEditing: NSTextStorageEditedCharacters range: NSMakeRange(0, 0) changeInLength: 0];
}

- (void)textStorage:(NSTextStorage *)textStorage
  didProcessEditing:(NSTextStorageEditActions)editedMask
			  range:(NSRange)editedRange
	 changeInLength:(NSInteger)delta {
	if (!lineInput) {
		return;
	}
	
	if (flushing) {
		return;
	}

	// Check for any newlines in the input, and generate an event if we find one
	// We only process one line at a time
	NSString* string = [textStorage string];
	NSInteger pos;
	
	for (pos = inputPos; pos < [string length]; pos++) {
		unichar chr = [string characterAtIndex: pos];
		
		if (chr == '\n') {
			// We found a newline
			NSString* inputLine = [string substringWithRange: NSMakeRange(inputPos, pos - inputPos)];
			
			// Generate the event, then...
			GlkEvent* evt = [[GlkEvent alloc] initWithType: evtype_LineInput
										  windowIdentifier: [self glkIdentifier]
													  val1: (int)[inputLine length]
													  val2: 0];
			[evt setLineInput: inputLine];
			
			// ... send it
			[target queueEvent: evt];
			
			// Add to the line history
			[[self containingView] resetHistoryPosition];
			[[self containingView] addHistoryItem: inputLine
								  forWindowWithId: [self glkIdentifier]];
			
			// Move the input position
			inputPos = pos+1;
			
			lineInput = NO;
			[self makeTextNonEditable];
			
			// We're done
			break;
		}
	}
}

- (void) setInputLine: (NSString*) inputLine {
	NSMutableString* string = [[textView textStorage] mutableString];
	
	if ([inputLine length] > 0) {
		[string replaceCharactersInRange: NSMakeRange(inputPos, [string length]-inputPos)
							  withString: inputLine];
	}
}

- (NSResponder*) windowResponder {
	return textView;
}

- (void) deferredMakeNonEditable {
	if (willMakeEditable) NSLog(@"Warning: text buffer window has deferred both an edit and a non-edit request (this is a bug)");
	
	if (charInput) [textView setEditable: NO];
	willMakeNonEditable = NO;
}

- (void) deferredMakeEditable {
	if (willMakeNonEditable) NSLog(@"Warning: text buffer window has deferred both an edit and a non-edit request (this is a bug)");
	
	[textView setEditable: YES];
	willMakeEditable = NO;
}

- (void) makeTextEditable {
	// setEditable: sometimes causes layout of the window, which results in an exception if the buffer is
	// in the process of flushing. This call defers the request.
	
	// If the request is already pending, then there's nothing to do
	if (willMakeEditable) return;
	
	// If there's no request pending, and we're not flushing the buffer, then perform the request immediately
	if (!flushing && !willMakeNonEditable) {
		[textView setEditable: YES];
		return;
	}
	
	// Cancel any request to make the text non-editable that might be pending
	if (willMakeNonEditable) {
		[[NSRunLoop currentRunLoop] cancelPerformSelector: @selector(deferredMakeNonEditable)
												   target: self
												 argument: nil];
		willMakeNonEditable = NO;
	}
	
	// Defer a request to make the text editable until later (when flushing has finished)
	willMakeEditable = YES;
	[[NSRunLoop currentRunLoop] performSelector: @selector(deferredMakeEditable)
										 target: self
									   argument: nil
										  order: 128
										  modes: @[NSDefaultRunLoopMode]];
}

- (void) fixInputStatus {
	[super fixInputStatus];
	
	if (!lineInput) {
		[textView setEditable: NO];
	}
}

- (void) makeTextNonEditable {
	// setEditable: sometimes causes layout of the window, which results in an exception if the buffer is
	// in the process of flushing. This call defers the request.
	
	// If the request is already pending, then there's nothing to do
	if (willMakeNonEditable) return;
	
	// If there's no request pending, and we're not flushing the buffer, then perform the request immediately
	if (!flushing && !willMakeEditable) {
		[textView setEditable: YES];
		return;
	}
	
	// Cancel any request to make the text non-editable that might be pending
	if (willMakeEditable) {
		[[NSRunLoop currentRunLoop] cancelPerformSelector: @selector(deferredMakeEditable)
												   target: self
												 argument: nil];
		willMakeEditable = NO;
	}
	
	// Defer a request to make the text editable until later (when flushing has finished)
	willMakeNonEditable = YES;
	[[NSRunLoop currentRunLoop] performSelector: @selector(deferredMakeNonEditable)
										 target: self
									   argument: nil
										  order: 128
										  modes: @[NSDefaultRunLoopMode]];
}

- (void) requestLineInput {
	if (!lineInput) {
		lineInput = YES;
		
		[self makeTextEditable];
	}
	
	if (charInput) {
		NSLog(@"Oops: line input requested while char input was pending");
		[self cancelCharInput];
	}
	
	BOOL wasFlushing = flushing;
	if (wasFlushing) {
		[[textView textStorage] endEditing];
		flushing = NO;
	}
	
	// Calling this means that if there's any lines we haven't processed yet, then they will
	// be added to the buffer (generating an immediate event)
	//
	// This allows us to successfully copy+paste lines of text and have things look like they're working OK
	[[NSRunLoop currentRunLoop] performSelector: @selector(hackTextStorageDidProcessEditing:)
										 target: self
									   argument: nil 
										  order: 32
										  modes: @[NSDefaultRunLoopMode]];

	if (wasFlushing) {
		[[textView textStorage] beginEditing];
		flushing = YES;
	}

	[[self window] invalidateCursorRectsForView: self];
}

- (NSString*) cancelLineInput {
	if (lineInput) {
		lineInput = NO;
		
		[self makeTextNonEditable];
		[[self window] invalidateCursorRectsForView: self];
		
		return [[textStorage string] substringWithRange: NSMakeRange(inputPos, [textStorage length] - inputPos)];
	}
	
	return @"";
}

- (void) requestCharInput {	
	BOOL wasFlushing = flushing;
	if (wasFlushing) {
		[[textView textStorage] endEditing];
		flushing = NO;
	}
	if (wasFlushing) {
		[[textView textStorage] beginEditing];
		flushing = YES;
	}
	
	[textView setEditable: NO];
	[textView requestCharacterInput];
	[super requestCharInput];
}

- (void) cancelCharInput {
	[textView setEditable: YES];
	[textView cancelCharacterInput];
	[super cancelCharInput];
}

#pragma mark - Streaming

- (void) putString: (in bycopy NSString*) string {
	NSAttributedString* atStr = [[NSAttributedString alloc] initWithString: string
																attributes: [self currentTextAttributes]];
	
	NSInteger insertionPos = inputPos;
	inputPos += [atStr length];
	[[textView textStorage] insertAttributedString: atStr
										   atIndex: insertionPos];

	CGFloat sb = [preferences scrollbackLength];
	if (sb < 100.0) {
		// Number of characters to preserve (4096 -> 1 million)
		NSInteger len = [[textView textStorage] length];
		CGFloat preserve = 4096.0 + pow(sb * 10.0, 2.0);

		if (len > ((int)preserve + 2048)) {
			// Need to truncate
			[[textView textStorage] deleteCharactersInRange: NSMakeRange(0, (NSInteger)(len - preserve))];
			inputPos -= (NSInteger)(len-preserve);
		}
	}
	
	if (inputPos > [[textView textStorage] length]) inputPos = [[textView textStorage] length];			// Shouldn't happen, but does for reasons that probably make sense to someone
}

#pragma mark - Graphics

- (void) addImage: (NSImage*) image
	withAlignment: (unsigned) alignment
			 size: (NSSize) sz {
	// Construct the GlkImage object
	GlkImage* newImage = [[GlkImage alloc] initWithImage: image
											   alignment: alignment
													size: sz
												position: (int)[textStorage length]];
	
	// Add a suitable control character to the text
	unichar imageChar = 11;
	NSString* imageString = [NSString stringWithCharacters: &imageChar
													length: 1];
	
	// Construct the attributes that describe this image
	NSMutableDictionary* imageDict = [[self currentTextAttributes] mutableCopy];
	[imageDict setObject: newImage
				  forKey: GlkCustomSectionAttributeName];
	NSAttributedString* imageAttributedString = [[NSAttributedString alloc] initWithString: imageString
																				attributes: imageDict];
	
	// Append the image to the text storage object
	NSInteger insertionPos = inputPos;
	inputPos += [imageAttributedString length];
	[[textView textStorage] insertAttributedString: imageAttributedString
										   atIndex: insertionPos];
}

- (void) addFlowBreak {
	// Creaate a flow break character
	GlkClearMargins* clear = [[GlkClearMargins alloc] init];
	unichar clearChar = 11;
	NSString* clearString = [NSString stringWithCharacters: &clearChar
													length: 1];
	
	// Construct the attributes that describe this clear margins character
	NSDictionary* clearDict = @{GlkCustomSectionAttributeName: clear};
	NSAttributedString* clearAttributedString = [[NSAttributedString alloc] initWithString: clearString
																				attributes: clearDict];
	
	// Append the clear margins object to the text storage object
	NSInteger insertionPos = inputPos;
	inputPos += [clearAttributedString length];
	[[textView textStorage] insertAttributedString: clearAttributedString
										   atIndex: insertionPos];
	
	// Add a newline (GlkAlignTop will normally force the following line to the bottom of the current margn images)
	// TODO: Put this in a very tiny font in case there's no flow to break
	[self putString: @"\n"];
}

#pragma mark - Resizing and the more prompt

- (void) positionMoreWindow {
	// Work out the frame of this view, in screen coordinates
	NSRect bounds = [[scrollView contentView] convertRect: [[scrollView contentView] bounds]
												   toView: nil];
	NSRect windowFrame = [NSWindow contentRectForFrameRect: [[self window] frame]
												 styleMask: [[self window] styleMask]];
	
	bounds.origin.x += windowFrame.origin.x;
	bounds.origin.y += windowFrame.origin.y;
	
	// Work out where to position the more window
	NSRect moreFrame = [moreWindow frame];
	moreFrame.origin.x = NSMaxX(bounds)-moreFrame.size.width;
	moreFrame.origin.y = NSMinY(bounds);
	
	moreFrame.origin.y -= 4;
	moreFrame.origin.x += 3;
	
	[moreWindow setFrame: moreFrame
				 display: NO];
	[moreWindow setAlphaValue: [self currentMoreState]];
	[[self window] addChildWindow: moreWindow
						  ordered: NSWindowAbove];
}

- (void) setFrame: (NSRect) frame {
	[super setFrame: frame];
	
	// Resize the text container for this window so that we can display the more prompt
	[self resetMorePrompt: moreOffset
				   paging: NO];
	
	// Show the [ MORE ] prompt if we need to
	[self positionMoreWindow];
	[self displayMorePromptIfNecessary];
}

- (void) displayMorePromptIfNecessary {
	BOOL wasFlushing = flushing;
	if (flushing) {
		[[textView textStorage] endEditing];
		flushing = NO;
	}
	
	// Pick the last character
	if ([[textView textStorage] length] <= 0) return;
    NSRange endGlyph = [textView selectionRangeForProposedRange: NSMakeRange([[textView textStorage] length]-1, 1)
                                                    granularity: NSSelectByCharacter];
    if (endGlyph.location == NSNotFound) {
		if (wasFlushing) {
			[[textView textStorage] beginEditing];
			flushing = YES;
		}
		
        return; // Doesn't exist
    }
	
	// See if it has fallen off the end
	NSLayoutManager* mgr = [textView layoutManager];
    NSRect endRect = [mgr boundingRectForGlyphRange: endGlyph
                                    inTextContainer: [textView textContainer]];

    if ((endRect.size.height == 0 && endRect.origin.y == 0 && endRect.origin.x == 0 && endRect.size.width == 0)) {
		[self setMoreShown: YES];
    }

	if (wasFlushing) {
		[[textView textStorage] beginEditing];
		flushing = YES;
	}
}

- (CGFloat) currentMoreState {
	CGFloat percent = 1.0;
	
	if (whenMoreShown != nil) {
		percent = (CGFloat)([[NSDate date] timeIntervalSinceDate: whenMoreShown]/MoreAnimationTime);
	}
	
	if (percent < 0) percent = 0;
	if (percent > 1) percent = 1;
	
	return (finalMoreState-lastMoreState)*percent + lastMoreState;
}

- (void) setUsesMorePrompt: (BOOL) useMorePrompt {
	hasMorePrompt = useMorePrompt;
	[self resetMorePrompt];
}

- (void) setInfiniteSize {
	[[textView textContainer] setContainerSize: NSMakeSize(1e8, 1e8)];
}

- (void) animateMore {
	// Update the window alpha
	CGFloat newMoreState = [self currentMoreState];
	[moreWindow setAlphaValue: newMoreState];
	
	// Stop the timer, if necessary
	if (newMoreState == finalMoreState || newMoreState < 0 || newMoreState > 1) {
		[moreAnimationTimer invalidate];
		moreAnimationTimer = nil;
	}
}

- (void) scrollToEnd {
	NSRange lastGlyph = [[textView layoutManager] glyphRangeForCharacterRange: NSMakeRange(0, [textStorage length])
														 actualCharacterRange: nil];
	
	// Force the layout manager to lay out the final glyph so we can scroll there
	if (lastGlyph.location + lastGlyph.length > 0) {
		[[textView layoutManager] boundingRectForGlyphRange: lastGlyph
											inTextContainer: [textView textContainer]];
	}

	[textView scrollPoint: NSMakePoint(0, NSMaxY([textView bounds]))];
}

- (void) setMoreShown: (BOOL) isShown {
	BOOL wasFlushing = flushing;
	
	if (wasFlushing) {
		flushing = NO;
		[[textView textStorage] endEditing];
	}

	// Set the current/final state of the prompt appropriately
	lastMoreState = [self currentMoreState];
	CGFloat newState = isShown?1.0:0.0;
	
	if (newState == finalMoreState) {
		// Nothing to do
		if (wasFlushing) {
			flushing = YES;
			[[textView textStorage] beginEditing];
		}
		return;
	}
	
	finalMoreState = newState;
	
	// Scroll to the end of the file (quite often toggling the state screws up Cocoa's default behaviour)
	if (isShown) {
		[textView scrollPoint: NSMakePoint(0, NSMaxY([textView bounds]))];
	} else {
		[[NSRunLoop currentRunLoop] performSelector: @selector(scrollToEnd)
											 target: self
										   argument: nil
											  order: 32
											  modes: @[NSDefaultRunLoopMode]];
	}
	
	// Set the time that we started animating
	whenMoreShown = [NSDate date];
	
	// Reposition the more window
	[self positionMoreWindow];
	[moreWindow orderFront: self];
	
	// Reset the timer
	[moreAnimationTimer invalidate];
	
	moreAnimationTimer = [NSTimer scheduledTimerWithTimeInterval: 0.01
														  target: self
														selector: @selector(animateMore)
														userInfo: nil
														 repeats: YES];
	
	if (wasFlushing) {
		flushing = YES;
		[[textView textStorage] beginEditing];
	}
	
	// Page if necessary
	if (isShown && [[self containingView] alwaysPageOnMore]) {
		[[NSRunLoop currentRunLoop] performSelector: @selector(page)
											 target: self 
										   argument: nil 
											  order: 16
											  modes: @[NSDefaultRunLoopMode]];
	}
}

- (void) resetMorePrompt {
	[self resetMorePrompt: inputPos-1
				   paging: NO];
}

- (void) resetMorePrompt: (NSInteger) moreChar
				  paging: (BOOL) paging {
	// Do nothing if the more prompt is turned off for this window
	if (!hasMorePrompt) return;
	
	NSRect frame = [[scrollView contentView] bounds];
	moreOffset = moreChar;
	
	if (finalMoreState > 0) return;
	
	BOOL wasFlushing = flushing;
	flushing = NO;
	if (wasFlushing) {
		[[textView textStorage] endEditing];
	}
	
	// Default is just to scroll forever
	CGFloat maxHeight = 1e8;
	
	// Get the visible rect of the current window
	NSRect visibleRect = [textView visibleRect];
	
	// If this window is larger than the minimum height for a window with MORE prompt, then set the new more marker
	// position using the last position as a base
	if (frame.size.height > MinimumMoreHeight) {
		maxHeight = frame.size.height - MoreMargin;
	}
	
	// Get the location of the final glyph
	if ([[textView textStorage] length] <= 0) {
		NSSize containerSize = [[textView textContainer] containerSize];
		nextMorePos = maxHeight;
		[[textView textContainer] setContainerSize: NSMakeSize(containerSize.width, nextMorePos)];	
		
		if (wasFlushing) {
			[[textView textStorage] beginEditing];
			flushing = YES;
		}
        return; // Doesn't exist
	}

    NSRange endGlyph = [textView selectionRangeForProposedRange: NSMakeRange(moreChar, 1)
                                                    granularity: NSSelectByCharacter];
    if (endGlyph.location == NSNotFound) {
		NSSize containerSize = [[textView textContainer] containerSize];
		nextMorePos = maxHeight;
		[[textView textContainer] setContainerSize: NSMakeSize(containerSize.width, nextMorePos)];	

		if (wasFlushing) {
			[[textView textStorage] beginEditing];
			flushing = YES;
		}
        return; // Doesn't exist
    }
	
	// See if it has fallen off the end
	NSLayoutManager* mgr = [textView layoutManager];
    NSRect endRect = [mgr boundingRectForGlyphRange: endGlyph
                                    inTextContainer: [textView textContainer]];
	NSSize containerSize = [[textView textContainer] containerSize];
	
    if ((endRect.size.height == 0 && endRect.origin.y == 0 && endRect.origin.x == 0 && endRect.size.width == 0)) {
		static BOOL recursing = NO;
		
		[[textView textContainer] setContainerSize: NSMakeSize(containerSize.width, 1e8)];	

		if (!recursing) {
			recursing = YES;
			[self resetMorePrompt: moreChar
						   paging: paging];
			recursing = NO;
		}

		if (wasFlushing) {
			[[textView textStorage] beginEditing];
			flushing = YES;
		}
		return;
    }
	
	// Change the position the more prompt will show at
	lastMorePos = NSMaxY(endRect);
	if (moreChar == 0) lastMorePos = 0;
	if (lastMorePos < NSMinY(visibleRect)) {
		lastMorePos = NSMinY(visibleRect);
	}
	
	// Resize the text container for this window so that we can display the more prompt
	if (paging && (lastMorePos + maxHeight) == nextMorePos) {
		nextMorePos = nextMorePos + maxHeight;
	} else {
		nextMorePos = lastMorePos + maxHeight;		
	}
	
	// Set the text container size
	[[textView textContainer] setContainerSize: NSMakeSize(containerSize.width, nextMorePos)];	

	if (wasFlushing) {
		[[textView textStorage] beginEditing];
		flushing = YES;
	}
}

- (BOOL) needsPaging {
	return finalMoreState > 0;
}

- (void) page {
	// Page down if the scroll bar is not yet at the bottom of the window
	NSRect visible = [textView visibleRect];
	NSRect bounds = [textView bounds];
	
	if (NSMaxY(visible) < NSMaxY(bounds)) {
		[scrollView pageDown: self];
		return;
	}
	
	// Hide the more prompt
	[self setMoreShown: NO];
	
	// Reset the more prompt using the first unlaid character
	NSRange glyphRange = [[textView layoutManager] glyphRangeForTextContainer: [textView textContainer]];
	NSInteger firstUnlaid = glyphRange.location + glyphRange.length;
	firstUnlaid = [[textView layoutManager] characterRangeForGlyphRange: NSMakeRange(firstUnlaid-1, 1)
													   actualGlyphRange: nil].location;
	[self resetMorePrompt: firstUnlaid
				   paging: YES];
	
	// Redisplay the more prompt if required
	[self displayMorePromptIfNecessary];
	
	if (finalMoreState <= 0) {
		[self resetMorePrompt: inputPos
					   paging: NO];
	}
}

#pragma mark - NSAccessibility

- (NSArray *)accessibilityContents {
	return @[textView];
}

- (NSArray *)accessibilityChildren {
	return @[textView];
}

- (id)accessibilityParent {
	return parentWindow;
}

- (NSString *)accessibilityRoleDescription {
	if (!lineInput && !charInput) return @"Text window";
	return [NSString stringWithFormat: @"GLK text window%@%@", lineInput?@", waiting for commands":@"", charInput?@", waiting for a key press":@""];;
}

- (BOOL)isAccessibilityFocused {
	return NO;
	/* return [NSNumber numberWithBool: [[self window] firstResponder] == self ||
		[[self window] firstResponder] == textView]; */
}

//- (id)accessibilityFocusedUIElement {
//	return [self accessibilityFocusedUIElement];
//}

- (id)accessibilityFocusedUIElement {
	return textView;
}

#pragma mark -
- (void) hideMoreWindow {
    [[moreWindow parentWindow] removeChildWindow: moreWindow];
    [moreWindow orderOut: self];
}

- (void) showMoreWindow {
    [[self window] addChildWindow: moreWindow
                          ordered: NSWindowAbove];
    [moreWindow orderFront: self];
}

@end
