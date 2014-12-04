//
//  ZoomView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#include <signal.h>
#include <unistd.h>

#import "ZoomView.h"
#import "ZoomLowerWindow.h"
#import "ZoomUpperWindow.h"
#import "ZoomPixmapWindow.h"

#import "ZoomScrollView.h"
#import "ZoomConnector.h"

// Sets variables to force extreme memory checking in the Zoom task; this provides a fairly huge performance
// decrease, but provides 'earliest possible' warning of heap corruption.
#undef  ZoomTaskMaximumMemoryDebug

// Turn on tracing of text editing events
#undef  ZoomTraceTextEditing

@implementation ZoomView

static ZoomView** allocatedViews = nil;
static int        nAllocatedViews = 0;

NSString* ZoomStyleAttributeName = @"ZoomStyleAttributeName";

static void finalizeViews(void);

+ (void) initialize {
    atexit(finalizeViews);
}

+ (void) selfDestruct {
    int view;
    
    for (view=0;view<nAllocatedViews;view++) {
        [allocatedViews[view] killTask];
    }
}

static void finalizeViews(void) {
    [ZoomView selfDestruct];
}

-(void) prepare
{
    restoring = NO;
    
    // Mark views as allocated
    allocatedViews = realloc(allocatedViews, sizeof(ZoomView*) * (nAllocatedViews+1));
    allocatedViews[nAllocatedViews] = self;
    nAllocatedViews++;
    
    // Output receivers
    outputReceivers = nil;
    
    // Input source
    inputSource = nil;
    inputPos = 0;
    
    // No upper/lower windows
    upperWindows = [[NSMutableArray alloc] init];
    lowerWindows = [[NSMutableArray alloc] init];
    
    // No Zmachine/task to start with
    zMachine = nil;
    zoomTask = nil;
    delegate = nil;
    
    // Yep, we autoresize our subviews
    [self setAutoresizesSubviews: YES];
    
    // Autosave
    lastAutosave = nil;
    upperWindowsToRestore = 0;
    
    // Default scale factor
    scaleFactor = 1.0;
    
    // Default creator code is YZZY (Zoom's creator code)
    creatorCode = 'YZZY';
    typeCode = '\?\?\?\?';
    
    // Set up the scroll view...
    textScroller = [[ZoomScrollView alloc] initWithFrame: [self bounds]
                                                zoomView: self];
    [textScroller setAutoresizingMask: NSViewHeightSizable|NSViewWidthSizable];
    
    [textScroller setHasHorizontalScroller: NO];
    [textScroller setHasVerticalScroller: YES];
    [textScroller setBackgroundColor: [NSColor whiteColor]];
    [textScroller setDrawsBackground: YES];
    
    NSSize contentSize = [textScroller contentSize];
    
    // Now the content view
    textView = [[ZoomTextView alloc] initWithFrame:
                NSMakeRect(0,0,contentSize.width,contentSize.height)];
    
    [textView setMinSize:NSMakeSize(0.0, contentSize.height)];
    [textView setMaxSize:NSMakeSize(1e8, contentSize.height)];
    [textView setVerticallyResizable:YES];
    [textView setHorizontallyResizable:NO];
    [textView setAutoresizingMask:NSViewWidthSizable];
    [textView setEditable: NO];
    [textView setAllowsUndo: NO];
    [textView setUsesFontPanel: NO];
    
    receiving = NO;
    receivingCharacters = NO;
    moreOn    = NO;
    moreReferencePoint = 0.0;
    
    [textView setDelegate: self];
    [[textView textStorage] setDelegate: self];
    
    // Next, a text container used as a 'buffer' - contains the text 'hidden'
    // by the upper window
    upperWindowBuffer = [[NSTextContainer alloc] init];
    [upperWindowBuffer setContainerSize: NSMakeSize(100, 100)];
    [[textView layoutManager] insertTextContainer: upperWindowBuffer
                                          atIndex: 0];
    
    // Set up the text view container
    NSTextContainer* container = [textView textContainer];
    
    [container setContainerSize: NSMakeSize(contentSize.width, 1e8)];
    [container setWidthTracksTextView:YES];
    [container setHeightTracksTextView:NO];
    
    [textScroller setDocumentView: textView];
    [self addSubview: textScroller];
    
    moreView = [[ZoomMoreView alloc] init];
    [moreView setAutoresizingMask: NSViewMinXMargin|NSViewMinYMargin];
    
    // Styles, fonts, etc
    viewPrefs = nil;
    [self setPreferences: [ZoomPreferences globalPreferences]];
    fonts = [[viewPrefs fonts] retain];
    colours = [[viewPrefs colours] retain];
    
    // Get notifications
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(boundsChanged:)
                                                 name: NSViewBoundsDidChangeNotification
                                               object: self];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(boundsChanged:)
                                                 name: NSViewFrameDidChangeNotification
                                               object: self];
    [self setPostsBoundsChangedNotifications: YES];
    [self setPostsFrameChangedNotifications: YES];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(preferencesHaveChanged:)
                                                 name: ZoomPreferencesHaveChangedNotification
                                               object: viewPrefs];
    
    // Command history
    commandHistory = [[NSMutableArray alloc] init];
    historyPos     = 0;
    
    // Resources
    resources = nil;
    
    // Terminating characters
    terminatingChars = nil;
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        [self prepare];
    }

    return self;
}

- (void) dealloc {    
	if (textToSpeechReceiver) {
		[textToSpeechReceiver release];
		textToSpeechReceiver = nil;
	}
	
    if (zMachine) {
        [zMachine release];
    }

    if (zoomTask) {
        [zoomTask terminate];
        [zoomTask release];
    }

    if (zoomTaskStdout) {
        [zoomTaskStdout release];
    }

    if (zoomTaskData) {
        [zoomTaskData release];
    }

    int view;
    for (view=0;view<nAllocatedViews;view++) {
        if (allocatedViews[view] == self) {
            memmove(allocatedViews + view, allocatedViews + view + 1,
                    sizeof(ZoomView*)*(nAllocatedViews-view-1));
            nAllocatedViews--;
        }
    }
	
	if (pixmapWindow) {
		[pixmapCursor setDelegate: nil];
		[pixmapCursor release];
		[pixmapWindow release];
	}

    [[NSNotificationCenter defaultCenter] removeObserver: self];
	
	if (lowerWindows) [lowerWindows release];
	if (upperWindows) [upperWindows release];

    [textScroller release];
    [textView release];
    [moreView release];
    [fonts release];
    [colours release];
    [upperWindowBuffer release];
	[viewPrefs release];
	[commandHistory release];
	[outputReceivers release];
	if (lastAutosave) [lastAutosave release];
	
	if (inputLine) [inputLine release];
	
	if (inputSource) [inputSource release];
	
	if (resources) [resources release];
	
	if (terminatingChars) [terminatingChars release];
	
	if (originalFonts) [originalFonts release];

    [super dealloc];
}

// Drawing
- (void) drawRect: (NSRect) rect {
	if (pixmapWindow != nil) {
		NSRect bounds = [self bounds];
		NSImage* pixmap = [pixmapWindow pixmap];
		NSSize pixSize = [pixmap size];
		
		NSRect realFrame = [self convertRect: bounds 
									  toView: [[self window] contentView]];
		
		/*
		[pixmap drawAtPoint: NSMakePoint(floor(bounds.origin.x + (bounds.size.width-pixSize.width)/2.0), floor(bounds.origin.y + (bounds.size.height-pixSize.height)/2.0))
				   fromRect: NSMakeRect(0,0,pixSize.width, pixSize.height)
				  operation: NSCompositeSourceOver
				   fraction: 1.0];
		 */
		
		/*
		bounds.origin.y += bounds.size.height;
		bounds.size.height = -bounds.size.height;
		 */
		
		NSAffineTransform* invertTransform = [NSAffineTransform transform];
		
		[[NSGraphicsContext currentContext] saveGraphicsState];
		[invertTransform invert];
		[invertTransform translateXBy: realFrame.origin.x
								  yBy: realFrame.origin.y];
		[invertTransform set];

		[pixmap drawInRect: bounds
				  fromRect: NSMakeRect(0,0,pixSize.width, pixSize.height)
				 operation: NSCompositeSourceOver
				  fraction: 1.0];
		
		[[NSGraphicsContext currentContext] restoreGraphicsState];
				
		[pixmapCursor draw];
		
		if (inputLine) {
			[inputLine drawAtPoint: inputLinePos];
		}
	}
}

- (BOOL) isFlipped {
	return YES;
}

// Scaling
- (void) setScaleFactor: (float) scaling {
	scaleFactor = scaling;
	[textView setPastedLineScaleFactor: 1.0/scaling];
	
	// Scale up all the fonts
	// Previously we used OS X scaling, but this is problematic (largely because NSLayoutManager is fragile)
	
	if (scaling == 1.0) {
		// Scale factor of 1 is a special case: restore the standard fonts
		if (originalFonts) {
			[fonts release];
			fonts = originalFonts;
			originalFonts = nil;
		}
	} else {
		// If we don't currently know the 'original' fonts, set them to the current fonts
		// This will cause errors if somehow the scale factor gets set without the original
		// fonts being copied
		if (!originalFonts) {
			originalFonts = [fonts copy];
		}
		
		// Scale up all of the fonts
		NSMutableArray* newFonts = [[NSMutableArray alloc] init];
		NSEnumerator* fontEnum = [originalFonts objectEnumerator];
		NSFont* origFont;
		
		while (origFont = [fontEnum nextObject]) {
			NSFont* scaledFont = [[NSFontManager sharedFontManager] convertFont: origFont
																		 toSize: [origFont pointSize] / scaleFactor];
			
			[newFonts addObject: scaledFont];
		}
		
		// Done
		[fonts release];
		fonts = newFonts;
	}
	
	[self reformatWindow];
	[self scrollToEnd];
	
	if (zMachine) {
		[zMachine displaySizeHasChanged];
	}
}

- (void) setZMachine: (NSObject<ZMachine>*) machine {
    if (zMachine) [zMachine release];

    zMachine = [machine retain];
	if (delegate && [delegate respondsToSelector: @selector(zMachineStarted:)]) {
		[delegate zMachineStarted: self];
	}
    [zMachine startRunningInDisplay: self];
}

- (NSObject<ZMachine>*) zMachine {
    return zMachine;
}

// = ZDisplay functions =

- (int) interpreterVersion {
	return [viewPrefs interpreter];
}

- (int) interpreterRevision {
	return [viewPrefs revision];
}

- (void) beep {
	// All the sound we support at the moment
	if (delegate && [delegate respondsToSelector: @selector(beep)]) {
		[delegate beep];
	} else {
		NSBeep();
	}
}

- (out byref NSObject<ZLowerWindow>*) createLowerWindow {
	// Can only have one lower window
	if ([lowerWindows count] > 0) return [lowerWindows objectAtIndex: 0];
	
    ZoomLowerWindow* win = [[ZoomLowerWindow alloc] initWithZoomView: self];

    [lowerWindows addObject: win];

    [win clearWithStyle: [[[ZStyle alloc] init] autorelease]];
    return [win autorelease];
}

- (out byref NSObject<ZUpperWindow>*) createUpperWindow {
	if (upperWindowsToRestore > 0) {
		// Restoring upper windows from autosave
		upperWindowsToRestore--;
		return [upperWindows objectAtIndex: [upperWindows count] - (upperWindowsToRestore+1)];
	}
	
	// Otherwise, create a brand new upper window
    ZoomUpperWindow* win = [[ZoomUpperWindow alloc] initWithZoomView: self];

    [upperWindows addObject: win];

    [win clearWithStyle: [[[ZStyle alloc] init] autorelease]];
    return [win autorelease];
}

- (out byref NSObject<ZPixmapWindow>*) createPixmapWindow {
	if (pixmapWindow == nil) {
		pixmapWindow = [[ZoomPixmapWindow alloc] initWithZoomView: self];

		pixmapCursor = [[ZoomCursor alloc] init];
		[pixmapCursor setDelegate: self];
		
		// FIXME: test of the cursor
		[pixmapCursor positionAt: NSMakePoint(100, 100)
						withFont: [self fontWithStyle: 0]];
		[pixmapCursor setShown: NO];
		[pixmapCursor setBlinking: YES];
		[pixmapCursor setActive: YES];
	}
	
	[textScroller removeFromSuperview];
	
	if (delegate != nil && [delegate respondsToSelector: @selector(zoomViewIsNotResizable)]) {
		[delegate zoomViewIsNotResizable];
	}
	
	return pixmapWindow;
}

- (oneway void) startExclusive {
    exclusiveMode = YES;

    while (exclusiveMode) {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

        [[NSRunLoop currentRunLoop] acceptInputForMode: NSConnectionReplyMode
                                            beforeDate: [NSDate distantFuture]];

        [pool release];
    }

    [self rearrangeUpperWindows];
}

- (oneway void) stopExclusive {
    exclusiveMode = NO;
}

- (float) bufferHeight {
	NSLayoutManager* mgr = [textView layoutManager];
	NSTextStorage* textStorage = [textView textStorage];
	
	NSRange lastGlyph = [mgr glyphRangeForCharacterRange: NSMakeRange(0, [textStorage length])
									actualCharacterRange: nil];
	
	if (lastGlyph.location + lastGlyph.length > 0) {
		return NSMaxY([mgr boundingRectForGlyphRange: lastGlyph
									 inTextContainer: [textView textContainer]]);
	}
	
	return 0;
}

- (oneway void) flushBuffer: (in bycopy ZBuffer*) toFlush {
#ifdef ZoomTraceTextEditing
	NSLog(@"Begin editing: flushBuffer");
#endif
	
	[[textView layoutManager] setBackgroundLayoutEnabled: NO];
	BOOL truncated = NO;
	float oldHeight = [self bufferHeight];

	[[textView textStorage] beginEditing];
	editingTextView = YES;

    [toFlush blat];
	
	// Cut down the scrollback if the user has requested it
	float sb = [viewPrefs scrollbackLength];
	if (sb < 100.0) {
		// Number of characters to preserve (4096 -> 1 million)
		int len = [[textView textStorage] length];
		float preserve = 4096.0 + powf(sb*10.0, 2);
		
		if (len > ((int)preserve + 2048)) {
			// Need to truncate
			[[textView textStorage] deleteCharactersInRange: NSMakeRange(0, len - preserve)];
			inputPos -= len-preserve;
			truncated = YES;
		}
	}
	
#ifdef ZoomTraceTextEditing
	NSLog(@"End editing: flushBuffer");
#endif
	[[textView textStorage] endEditing];
	editingTextView = NO;
	
	float newHeight = [self bufferHeight];
	if (newHeight != oldHeight && truncated) {
		[textView offsetPastedLines: oldHeight-newHeight];
	}
	
	if (willScrollToEnd) [self scrollToEnd];
	[[textView layoutManager] setBackgroundLayoutEnabled: YES];
}

// Set whether or not we recieve certain types of data
- (void) shouldReceiveCharacters {
	if (lastAutosave) [lastAutosave release];
	lastAutosave = [[zMachine createGameSave] retain];
		
	if (pixmapWindow == nil) {
		// Input into a non-v6 window
		[self rearrangeUpperWindows];
		
		int currentSize = [self upperWindowSize];
		if (currentSize != lastTileSize) {
			[textScroller tile];
			[self updateMorePrompt];
			lastTileSize = currentSize;
		}
		
		// Paste stuff
		NSEnumerator* upperEnum = [upperWindows objectEnumerator];
		ZoomUpperWindow* win;
		while (win = [upperEnum nextObject]) {
			[textView pasteUpperWindowLinesFrom: win];
		}
		
		if ([focusedView isKindOfClass: [ZoomUpperWindow class]]) {
			[[textScroller upperWindowView] setFlashCursor: YES]; 
		}
		
		// If the more prompt is off, then set up for editing
		if (!moreOn) {
			[self resetMorePrompt];
		}
		[self scrollToEnd];
	}
    
    receivingCharacters = YES;
	[self orWaitingForInput];
	
	// Position the cursor
	if (pixmapWindow != nil) {
		ZStyle* style = [pixmapWindow inputStyle];
		int fontnum =
			([style bold]?1:0)|
			([style underline]?2:0)|
			([style fixed]?4:0)|
			([style symbolic]?8:0);
		
		[pixmapCursor positionAt: [pixmapWindow inputPos]
						withFont: [self fontWithStyle: fontnum]];
		
		[pixmapCursor setShown: !moreOn];
	}
	
	// Set the first responder correctly
	if (pixmapWindow != nil) {
		[[self window] makeFirstResponder: self];
	} else if ([focusedView isKindOfClass: [ZoomUpperWindow class]]) {
		[[self window] makeFirstResponder: [textScroller upperWindowView]];
	} else {
		[[self window] makeFirstResponder: textView];
	}
	
	// Deal with the input source
	if (inputSource != nil && [inputSource respondsToSelector: @selector(nextCommand)]) {
		NSString* nextInput = [inputSource nextCommand];
		
		if (nextInput == nil) {
			// End of input
			if (delegate && [delegate respondsToSelector: @selector(inputSourceHasFinished:)]) {
				[delegate inputSourceHasFinished: inputSource];
			}
			
			[inputSource release];
			inputSource = nil;
		} else {			
			if ([nextInput length] == 0) nextInput = @"\n";
			
			// We've got some input: perform it
			[self stopReceiving];
			
			[zMachine inputText: nextInput];
			[self orInputCharacter: nextInput];
			historyPos = [commandHistory count];
		}
	}	
}

- (void) shouldReceiveText: (in int) maxLength {
	if (lastAutosave) [lastAutosave release];
	lastAutosave = [[zMachine createGameSave] retain];
	
	if (pixmapWindow == nil) {
		// == Version 1-5/7/8 routines ==
		[self rearrangeUpperWindows];
		
		int currentSize = [self upperWindowSize];
		if (currentSize != lastTileSize) {
			[textScroller tile];
			[self updateMorePrompt];
			lastTileSize = currentSize;
		}
	
		historyPos = [commandHistory count];

		// Paste stuff
		NSEnumerator* upperEnum = [upperWindows objectEnumerator];
		ZoomUpperWindow* win;
		while (win = [upperEnum nextObject]) {
			[textView pasteUpperWindowLinesFrom: win];
		}
    
		BOOL isUpperWindow = [focusedView isKindOfClass: [ZoomUpperWindow class]];
		
		// If the more prompt is off, then set up for editing
		if (!isUpperWindow && !moreOn) {
			[textView setEditable: YES];

			[self resetMorePrompt];
		} else {
			[textView setEditable: NO];
		}
		
		// If we're using the upper window, run using the inputLine system
		if (isUpperWindow) {
			[[textScroller upperWindowView] activateInputLine];
		}
		
		// Scroll, input
		if (!isUpperWindow) {
			[self scrollToEnd];
			// inputPos = [[textView textStorage] length];
			[self textStorageDidProcessEditing: nil];
		}
	} else {
		// == Version 6 pixmap entry routines ==
		
		// Move the cursor to the appropriate position
		ZStyle* style = [pixmapWindow inputStyle];
		int fontnum =
			([style bold]?1:0)|
			([style underline]?2:0)|
			([style fixed]?4:0)|
			([style symbolic]?8:0);
		
		[pixmapCursor positionAt: [pixmapWindow inputPos]
						withFont: [self fontWithStyle: fontnum]];

		// Display the cursor
		[pixmapCursor setShown: YES];
		
		// Setup the command history
		// historyPos = [commandHistory count];
		
		// Setup the input line
		if (inputLine == nil) {
			[self setInputLine: [[[ZoomInputLine alloc] initWithCursor: pixmapCursor
																			  attributes: [self attributesForStyle: [pixmapWindow inputStyle]]]
				autorelease]];
		}
		[self setInputLinePos: [pixmapWindow inputPos]];
		[inputLine updateCursor];
	}
	
	// Set the first responder appropriately
	if (pixmapWindow != nil) {
		[[self window] makeFirstResponder: self];
	} else if ([focusedView isKindOfClass: [ZoomUpperWindow class]]) {
		[[self window] makeFirstResponder: [textScroller upperWindowView]];
	} else {
		[[self window] makeFirstResponder: textView];
		
		if (!moreOn) {
			[textView scrollRangeToVisible: NSMakeRange([[textView string] length], 0)];
			[textView setSelectedRange: NSMakeRange([[textView string] length], 0)];
		}
	}	
	
    receiving = YES;
	[self orWaitingForInput];
	
	// Dealing with the input source
	if (inputSource != nil && [inputSource respondsToSelector: @selector(nextCommand)]) {
		NSString* nextInput = [inputSource nextCommand];
		
		if (nextInput == nil) {
			// End of input
			if (delegate && [delegate respondsToSelector: @selector(inputSourceHasFinished:)]) {
				[delegate inputSourceHasFinished: inputSource];
			}
			
			[inputSource release];
			inputSource = nil;
		} else {
			nextInput = [nextInput stringByAppendingString: @"\n"];
			
			// We've got some input: write it, perform it
			[self stopReceiving];
			
			// FIXME: maybe do this in the current style? (At least this way, it's obvious what's come from where)
			ZStyle* inputStyle = [[[ZStyle alloc] init] autorelease];
			[inputStyle setUnderline: YES];
			[inputStyle setBold: YES];
			[inputStyle setBackgroundColour: 7];
			[inputStyle setForegroundColour: 4];
			
			[focusedView writeString: nextInput
						   withStyle: inputStyle];
			
			[commandHistory addObject: nextInput];
			
			[zMachine inputText: nextInput];
			[self orInputCommand: nextInput];
			historyPos = [commandHistory count];
		}
	}
}

- (void) stopReceiving {
    receiving = NO;
    receivingCharacters = NO;
	[[textScroller upperWindowView] setFlashCursor: NO]; 
	[self resetMorePrompt];
}

- (void) dimensionX: (out int*) xSize
                  Y: (out int*) ySize {
    NSSize fixedSize = [@"M" sizeWithAttributes:
        [NSDictionary dictionaryWithObjectsAndKeys:
            [self fontWithStyle:ZFixedStyle], NSFontAttributeName, nil]];
    NSRect ourBounds = NSMakeRect(0,0,0,0);
	
	if (pixmapWindow == nil)
		ourBounds = [textView bounds];
	else
		ourBounds.size = [[pixmapWindow pixmap] size];

    *xSize = floor(ourBounds.size.width  / fixedSize.width);
    *ySize = floor(ourBounds.size.height / fixedSize.height);
}

- (void) pixmapX: (out int*) xSize
			   Y: (out int*) ySize {
	if (pixmapWindow == nil) {
		[self dimensionX: xSize Y: ySize];
	} else {
		NSSize pixSize = [[pixmapWindow pixmap] size];
		
		*xSize = pixSize.width;
		*ySize = pixSize.height;
	}
}

- (void) fontWidth: (out int*) width
			height: (out int*) height {
	if (pixmapWindow == nil) {
		*width = 1;
		*height = 1;
	} else {
		NSFont* font = [self fontWithStyle: ZFixedStyle];
	
        *width = [@"M" sizeWithAttributes:
                            [NSDictionary dictionaryWithObjectsAndKeys:
                             font, NSFontAttributeName, nil]].width;
        NSLayoutManager* lm = [[[NSLayoutManager alloc] init] autorelease];
		*height = ceilf([lm defaultLineHeightForFont: font])+1.0;
	}
}

- (void) boundsChanged: (NSNotification*) not {
    if (zMachine) {
        [zMachine displaySizeHasChanged];
    }
}

// = Utility functions =

- (void) writeAttributedString: (NSAttributedString*) string {
	// Writes the given string to the lower window
	[[textView textStorage] insertAttributedString: string
										   atIndex: inputPos];
	inputPos += [string length];
}

- (void) clearLowerWindowWithStyle: (ZStyle*) style {
    [[[textView textStorage] mutableString] replaceCharactersInRange: NSMakeRange(0, inputPos)
																	 withString: @""];
    [textView setBackgroundColor: [style reversed]?[self foregroundColourForStyle: style]:[self backgroundColourForStyle: style]];
    [textView clearPastedLines]; 
	
	inputPos = 0;
}

- (void) scrollToEnd {
	BOOL wasEditingTextView = editingTextView;

	if (editingTextView) {
		// Re-queue for later
		if (!willScrollToEnd) {
			willScrollToEnd = YES;
		}

		return;
	}
	
	if (wasEditingTextView) {
#ifdef ZoomTraceTextEditing
		NSLog(@"End editing: scroll to end");
#endif
		editingTextView = NO;
		[[textView textStorage] endEditing];
	}
	
	willScrollToEnd = NO;
	
	if ([[textView textStorage] length] <= 0) {
		// No scrolling to do if the view is empty
		if (wasEditingTextView && !editingTextView) {
#ifdef ZoomTraceTextEditing
			NSLog(@"Begin editing: scroll to end");
#endif
			editingTextView = YES;
			[[textView textStorage] beginEditing];
		}
		return;
	}
	
    NSLayoutManager* mgr = [textView layoutManager];
	NSTextStorage* textStorage = [textView textStorage];
	
	NSRange lastGlyph = [mgr glyphRangeForCharacterRange: NSMakeRange(0, [textStorage length])
									actualCharacterRange: nil];
	
	// Force the layout manager to lay out the final glyph so we can scroll there
	if (lastGlyph.location + lastGlyph.length > 0) {
		[mgr boundingRectForGlyphRange: lastGlyph
					   inTextContainer: [textView textContainer]];
	}
	
	[textView scrollPoint: NSMakePoint(0, NSMaxY([textView bounds]))];

	if (wasEditingTextView && !editingTextView) {
#ifdef ZoomTraceTextEditing
		NSLog(@"Begin editing: scroll to end");
#endif
		editingTextView = YES;
		[[textView textStorage] beginEditing];
	}
}

- (void) displayMore: (BOOL) shown {
	moreOn = shown;
	[self setShowsMorePrompt: moreOn];
}

- (void) displayMoreIfNecessary {
	if (editingTextView) {
		if (!willDisplayMore) {
			[[NSRunLoop currentRunLoop] performSelector: @selector(displayMoreIfNecessary)
												 target: self
											   argument: nil
												  order: 65
												  modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
			willDisplayMore = YES;
		}
		
		return;
	}

	willDisplayMore = NO;

    NSLayoutManager* mgr = [textView layoutManager];
	
	if (inputSource && [inputSource respondsToSelector: @selector(disableMorePrompt)]) {
		if ([inputSource disableMorePrompt]) {
			[self resetMorePrompt];
			moreOn = NO;
		}
	}
	
	if ([[textView textStorage] length] <= 0) {
		// Nothing to do
		return;
	}
	
	// Find the last glyph in the text view
    NSRange endGlyph = [textView selectionRangeForProposedRange:
        NSMakeRange([[textView textStorage] length]-1, 1)
                                                    granularity: NSSelectByCharacter];
    if (endGlyph.location > 0xf0000000) {
        return; // Doesn't exist
    }

	// See if it has fallen off the end
    NSRect endRect = [mgr boundingRectForGlyphRange: endGlyph
                                    inTextContainer: [textView textContainer]];
    double endPoint = endRect.origin.y + endRect.size.height;
    NSSize maxSize = [textView maxSize];

    if (endPoint > maxSize.height) {
        morePoint = maxSize.height;
        moreOn = YES;
    }
	
	if (moreOn) {
		// Turn more off if the text view is below a certain size
		ZStyle* standardStyle = [[ZStyle alloc] init];
		
		NSRect textSize = [textView frame];
		NSSize fontSize = [@"M" sizeWithAttributes: [self attributesForStyle: standardStyle]];
		[standardStyle release];
		
		if (textSize.size.height < fontSize.height * 1.25) {
			moreOn = NO;
		}
	}

    [self setShowsMorePrompt: moreOn];

    [self setNeedsDisplay: YES];
    
    if ([textView isEditable] && moreOn) {
        [textView setEditable: NO];
    }
}

- (void) resetMorePrompt {
    // Resets the point at which paging will next occur
    // Does NOT reset the point if paging is already going on
	
    double maxHeight;
    NSLayoutManager* mgr = [textView layoutManager];

    if (moreOn) {
        return; // More prompt is currently being displayed
    }

	BOOL wasEditingTextView = editingTextView;
	editingTextView = NO;
    if (wasEditingTextView) {
#ifdef ZoomTraceTextEditing
		NSLog(@"End editing: reset more prompt");
#endif
		[[textView textStorage] endEditing];
		if (willScrollToEnd) [self scrollToEnd];
	}

    NSRange endGlyph;
	int length = [[textView textStorage] length];
	
	if (length > 0) {
		endGlyph = [textView selectionRangeForProposedRange:
			NSMakeRange([[textView textStorage] length]-1, 1)
												   granularity: NSSelectByCharacter];
	} else {
		endGlyph = NSMakeRange(0xffffffff,0);
	}
    if (endGlyph.location < 0xf0000000) {
        NSRect endRect = [mgr boundingRectForGlyphRange: endGlyph
                                        inTextContainer: [textView textContainer]];
        maxHeight = endRect.origin.y;
    } else {
        maxHeight = 0;
    }

    moreReferencePoint = maxHeight;
    maxHeight += [textScroller contentSize].height;

    [textView setMaxSize: NSMakeSize(1e8, maxHeight)];
	
    [self scrollToEnd];
	
    if (wasEditingTextView) {
#ifdef ZoomTraceTextEditing
		NSLog(@"Begin editing: reset more prompt");
#endif
		[[textView textStorage] beginEditing];
		editingTextView = YES;
	}
}

- (void) updateMorePrompt {
	if (pixmapWindow) return; // Nothing to do
	
	BOOL wasEditingTextView = editingTextView;
	if (wasEditingTextView) {
		editingTextView = NO;
		[[textView textStorage] endEditing]; 
	}
	
    // Updates the more prompt to represent the new height of the window
	NSSize contentSize = [textScroller contentSize];
	contentSize = [textView convertSize: contentSize
							   fromView: textScroller];
	
    double maxHeight = moreReferencePoint + contentSize.height;

    [textView setMaxSize: NSMakeSize(1e8, maxHeight)];
    [textView sizeToFit];
    [self scrollToEnd];
    [self displayMoreIfNecessary];

	if (wasEditingTextView) {
		editingTextView = YES;
		[[textView textStorage] beginEditing]; 
	}
}

- (void) page {
    if (!moreOn) {
        return; // Nothing to do
    }

    moreOn = NO;
    [self setShowsMorePrompt: NO];
    
    double maxHeight = [textView maxSize].height;
	
    moreReferencePoint = maxHeight;

    [self updateMorePrompt];

    if (!moreOn && receiving) {
        [textView setEditable: YES];
    }
}

- (void) setShowsMorePrompt: (BOOL) shown {
    [moreView removeFromSuperview];
    if (shown) {
        // We put the 'more' prompt in as a subview of the text view: this
        // ensures that it behaves correctly when scrolling, and also ensures
        // that it always appears at the bottom of the text.
        // This technique has one failure, though: when the more prompt moves,
        // bits may get left on the screen as a result of scrolling
        NSRect content = [textView bounds];
		if (pixmapWindow) content = [self bounds];
        
        [moreView setSize];
        NSSize moreSize = [moreView frame].size;

        // Remember that NSTextViews use a flipped coordinate system!
        // (Sigh, I much preferred RISC OS's negative coordinate system
        // to this: all calculations worked regardless of whether or not
        // something was flipped)
        NSRect moreFrame = NSMakeRect(NSMaxX(content) - moreSize.width,
                                      NSMaxY(content) - moreSize.height,
                                      moreSize.width, moreSize.height);
        
        [moreView setFrame: moreFrame];
		
		if (pixmapWindow) {
			[self addSubview: moreView];
		} else {
			[textView addSubview: moreView];
		}
    }
}

- (ZoomTextView*) textView {
    return textView;
}

// = TextView delegate methods =
- (BOOL)    	textView:(NSTextView *)aTextView
shouldChangeTextInRange:(NSRange)affectedCharRange
    replacementString:(NSString *)replacementString {
    if (affectedCharRange.location < inputPos) {
        return NO;
    } else {
        return YES;
    }
}

- (void)textStorageDidProcessEditing:(NSNotification *)aNotification {
    if (!receiving) return;
    
    // Set the input character attributes to the input style
    //[text setAttributes: [self attributesForStyle: style_Input]
    //              range: NSMakeRange(inputPos,
    //[text length]-inputPos)];

    NSTextStorage* text = [textView textStorage];
	
	// Format according to the input style (if required)
	if ([focusedView inputStyle] != nil) {
		NSDictionary* inputAttributes = [self attributesForStyle: [focusedView inputStyle]];
		[text setAttributes: inputAttributes
					  range: [text editedRange]];
	}
    
    // Check to see if there's any newlines in the input...
    int newlinePos = -1;
    do {
        int x;
        NSString* str = [text string];
        int len = [str length];

        newlinePos = -1;

        for (x=inputPos; x < len; x++) {
            if ([str characterAtIndex: x] == '\n') {
                newlinePos = x;
                break;
            }
        }

        if (newlinePos >= 0) {
			NSString* inputText = [str substringWithRange: NSMakeRange(inputPos,
																	   newlinePos-inputPos+1)];
			
			[commandHistory addObject: [str substringWithRange: NSMakeRange(inputPos,
																			newlinePos-inputPos)]];
            [zMachine inputText: inputText];
			[self orInputCommand: inputText];
			historyPos = [commandHistory count];

            inputPos = newlinePos + 1;
        }
    } while (newlinePos >= 0);
}

// = Event methods =

- (BOOL)handleKeyDown:(NSEvent *)theEvent {
    if (moreOn && pixmapWindow==nil) {
        // FIXME: maybe only respond to certain keys
        [self page];
        return YES;
    }
	
	if (receiving && terminatingChars != nil) {
		// Deal with terminating characters
		NSString* chars = [theEvent characters];
		unichar chr = [chars characterAtIndex: 0];
		NSNumber* recv = [NSNumber numberWithInt: chr];
		
		BOOL canTerminate = YES;
		if (chr == 252 || chr == 253 || chr == 254) {
			// Mouse characters
			canTerminate = NO;
		}
		
		if (chr == NSUpArrowFunctionKey   ||
			chr == NSDownArrowFunctionKey ||
			chr == NSLeftArrowFunctionKey ||
			chr == NSRightArrowFunctionKey) {
			canTerminate = ([theEvent modifierFlags]&NSAlternateKeyMask)==1 && ([theEvent modifierFlags]&NSCommandKeyMask)==0;
		}
		
		if (canTerminate && [terminatingChars containsObject: recv]) {
			// Set the terminating character
			[zMachine inputTerminatedWithCharacter: [recv intValue]];
			
			// Send the input text
			NSString* str = [textView string];
			NSString* inputText = [str substringWithRange: NSMakeRange(inputPos,
																	   [str length]-inputPos)];
			inputPos = [str length];
			
			[zMachine inputText: inputText];
			historyPos = [commandHistory count];
			
			return YES;
		}
	}
	
	if (inputLine) {
		[inputLine keyDown: theEvent];
		return YES;
	}
	
	if (receiving && [focusedView isKindOfClass: [ZoomUpperWindow class]]) {
		// Don't do anything more here: history, etc is handled by the class itself
		return NO;
	}
    
    if (receivingCharacters) {
        NSString* chars = [theEvent characters];
        
        [zMachine inputText: chars];
		[self orInputCharacter: chars];
		historyPos = [commandHistory count];
        
        return YES;
    }
	
    if (receiving) {
        // Move the input position if required
        int modifiers = [theEvent modifierFlags];
        
        NSString* chars = [theEvent characters];
        
        modifiers &= NSControlKeyMask|NSCommandKeyMask|NSAlternateKeyMask|NSFunctionKeyMask;
        
        if (modifiers == 0) {
            NSRange selRange = [textView selectedRange];
                        
            if (selRange.location < inputPos || [chars isEqualToString: @"\n"] || [chars isEqualToString: @"\r"]) {
                [textView setSelectedRange: NSMakeRange([[textView textStorage] length], 0)];
            }
        }
		
		// Up and down arrow keys have a different meaning if the cursor is beyond the
		// end inputPos.
		// (Arrow keys won't be caught above thanks to the NSFunctionKeyMask)
		unsigned cursorPos = [textView selectedRange].location;
		
		if (modifiers == NSFunctionKeyMask) {
			int key = [chars characterAtIndex: 0];
			
			if (cursorPos >= inputPos && (key == NSUpArrowFunctionKey || key == NSDownArrowFunctionKey)) {
				// Move historyPos
				int oldPos = historyPos;
				
				if (key == NSUpArrowFunctionKey) historyPos--;
				if (key == NSDownArrowFunctionKey) historyPos++;
				
				if (historyPos < 0) historyPos = 0;
				if (historyPos > [commandHistory count]) historyPos = [commandHistory count];
				
				if (historyPos == oldPos) return YES;
				
				// Clear the input
				[[textView textStorage] deleteCharactersInRange: NSMakeRange(inputPos,
																			 [[textView textStorage] length] - inputPos)];
				
				// Put in the new string
				if (historyPos < [commandHistory count]) {
					[[[textView textStorage] mutableString] insertString: [commandHistory objectAtIndex: historyPos]
																 atIndex: inputPos];
				}
				
				// Move to the end
				[textView setSelectedRange: NSMakeRange([[textView textStorage] length], 0)];
				
				// Done
				return YES;
			}
		}
    }

    return NO;
}

- (void) keyDown: (NSEvent*) event {
	[self handleKeyDown: event];
}

- (void) mouseUp: (NSEvent*) event {
	[self clickAtPointInWindow: [event locationInWindow]
					 withCount: [event clickCount]];
	
	[super mouseUp: event];
}

- (void) clickAtPointInWindow: (NSPoint) windowPos
					withCount: (int) count {
	// Note that clicking can only be accurate in the 'upper' window
	// We'll have problems if the lower window is scrolled, too.
	NSPoint pointInView = [self convertPoint: windowPos
									fromView: nil];
	
	if (pixmapWindow != nil) {
		// Point is in X,Y coordinates
		[zMachine inputMouseAtPositionX: pointInView.x
									  Y: pointInView.y];
	} else {
		// Point is in character coordinates
		NSDictionary* fixedAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
            [self fontWithStyle:ZFixedStyle], NSFontAttributeName, nil];
        NSSize fixedSize = [@"M" sizeWithAttributes: fixedAttributes];
		
		int charX = floorf(pointInView.x / fixedSize.width);
		int charY = floorf(pointInView.y / fixedSize.height);
		
		// Report the position to the remote server
		[zMachine inputMouseAtPositionX: charX+1
									  Y: charY+1];
	}
	
	// Send the appropriate 'mouse down' character to the remote system
	// We use NSF34/NSF35 as 'pretend' mouse down characters
	unichar clickChar = NSF34FunctionKey;
	
	if (count == 2) clickChar = NSF35FunctionKey;
	
	NSEvent* fakeKeyDownEvent = [NSEvent keyEventWithType: NSKeyDown
												 location: NSMakePoint(0,0)
											modifierFlags: 0
												timestamp: 0
											 windowNumber: [[self window] windowNumber]
												  context: nil
											   characters: [NSString stringWithCharacters: &clickChar length: 1]
							  charactersIgnoringModifiers: [NSString stringWithCharacters: &clickChar length: 1]
												isARepeat: NO
												  keyCode: 0];
	[self handleKeyDown: fakeKeyDownEvent];
}

// = Formatting, fonts, colours, etc =

- (NSDictionary*) attributesForStyle: (ZStyle*) style {
    // Strings come from Zoom's server formatted with ZStyles rather than
    // actual styles (so that the interface can choose it's own formatting).
    // So we need this to translate those styles into 'real' ones.
	
    // Font
    NSFont* fontToUse = nil;
    int fontnum;
	
    fontnum =
        ([style bold]?1:0)|
        ([style underline]?2:0)|
        ([style fixed]?4:0)|
        ([style symbolic]?8:0);
	
    fontToUse = [fonts objectAtIndex: fontnum];
	
    // Colour
    NSColor* foregroundColour = [style foregroundTrue];
    NSColor* backgroundColour = [style backgroundTrue];
	
    if (foregroundColour == nil) {
        foregroundColour = [colours objectAtIndex: [style foregroundColour]];
    }
    if (backgroundColour == nil) {
        backgroundColour = [colours objectAtIndex: [style backgroundColour]];
    }
	
    if ([style reversed]) {
        NSColor* tmp = foregroundColour;
		
        foregroundColour = backgroundColour;
        backgroundColour = tmp;
    }
	
	// The foreground colour must have 100% alpha
	foregroundColour = [NSColor colorWithDeviceRed: [foregroundColour redComponent]
											 green: [foregroundColour greenComponent]
											  blue: [foregroundColour blueComponent]
											 alpha: 1.0];
	
    // Generate the new attributes
    NSDictionary* newAttr = [NSDictionary dictionaryWithObjectsAndKeys:
        fontToUse, NSFontAttributeName,
        foregroundColour, NSForegroundColorAttributeName,
        backgroundColour, NSBackgroundColorAttributeName,
		[NSNumber numberWithBool: [viewPrefs useLigatures]], NSLigatureAttributeName,
		[[style copy] autorelease], ZoomStyleAttributeName,
        nil];
	
	return newAttr;
}

- (NSAttributedString*) formatZString: (NSString*) zString
                            withStyle: (ZStyle*) style {
    // Strings come from Zoom's server formatted with ZStyles rather than
    // actual styles (so that the interface can choose it's own formatting).
    // So we need this to translate those styles into 'real' ones.

    NSMutableAttributedString* result;

    // Font
    NSFont* fontToUse = nil;
    int fontnum;

    fontnum =
        ([style bold]?1:0)|
        ([style underline]?2:0)|
        ([style fixed]?4:0)|
        ([style symbolic]?8:0);

    fontToUse = [fonts objectAtIndex: fontnum];

    // Colour
    NSColor* foregroundColour = [style foregroundTrue];
    NSColor* backgroundColour = [style backgroundTrue];

    if (foregroundColour == nil) {
        foregroundColour = [colours objectAtIndex: [style foregroundColour]];
    }
    if (backgroundColour == nil) {
        backgroundColour = [colours objectAtIndex: [style backgroundColour]];
    }
	
    if ([style reversed]) {
        NSColor* tmp = foregroundColour;

        foregroundColour = backgroundColour;
        backgroundColour = tmp;
    }
	
	// The foreground colour must have 100% alpha
	foregroundColour = [NSColor colorWithDeviceRed: [foregroundColour redComponent]
											 green: [foregroundColour greenComponent]
											  blue: [foregroundColour blueComponent]
											 alpha: 1.0];
	
    // Generate the new attributes
    NSDictionary* newAttr = [NSDictionary dictionaryWithObjectsAndKeys:
        fontToUse, NSFontAttributeName,
        foregroundColour, NSForegroundColorAttributeName,
        backgroundColour, NSBackgroundColorAttributeName,
		[[style copy] autorelease], ZoomStyleAttributeName,
        nil];

    // Create + append the newly attributed string
    result = [[NSMutableAttributedString alloc] initWithString: zString
                                                    attributes: newAttr];

    return [result autorelease];
}

- (void) setFonts: (NSArray*) newFonts {
    // FIXME: check that fonts is valid
	// FIXME: better to do this with preferences now, but Inform still uses these calls
    
    [originalFonts release];
    originalFonts = [[NSArray alloc] initWithArray: newFonts
                                         copyItems: YES];

	[self setScaleFactor: scaleFactor];
}

- (void) setColours: (NSArray*) newColours {
    [colours release];
    colours = [[NSArray alloc] initWithArray: newColours
                                   copyItems: YES];
	
	[self reformatWindow];
}

- (NSColor*) foregroundColourForStyle: (ZStyle*) style {
    NSColor* res;

    if ([style reversed]) {
        res = [style backgroundTrue];
    } else {
        res = [style foregroundTrue];
    }

    if (res == nil) {
        if ([style reversed]) {
            res = [colours objectAtIndex: [style backgroundColour]];
        } else {
            res = [colours objectAtIndex: [style foregroundColour]];
        }
    }
	
	// The foreground colour must have 100% alpha
	res = [NSColor colorWithDeviceRed: [res redComponent]
								green: [res greenComponent]
								 blue: [res blueComponent]
								alpha: 1.0];	
    
    return res;
}

- (NSColor*) backgroundColourForStyle: (ZStyle*) style {
    NSColor* res;

    if (![style reversed]) {
        res = [style backgroundTrue];
    } else {
        res = [style foregroundTrue];
    }

    if (res == nil) {
        if (![style reversed]) {
            res = [colours objectAtIndex: [style backgroundColour]];
        } else {
            res = [colours objectAtIndex: [style foregroundColour]];
        }
    }

    return res;
}

- (NSFont*) fontWithStyle: (int) style {
    if (style < 0 || style >= 16) {
        return nil;
    }

    return [fonts objectAtIndex: style];
}

- (int) upperWindowSize {
    int height;
    NSEnumerator* upperEnum;

    upperEnum = [upperWindows objectEnumerator];

    ZoomUpperWindow* win;

    height = 0;
    while (win = [upperEnum nextObject]) {
        int winHeight = [win length];
        if (winHeight > 0) height += winHeight;
    }

    return height;
}

- (void) setUpperBuffer: (double) bufHeight {
    // Update the upper window buffer
	BOOL wasEditingTextView = editingTextView;
	editingTextView = NO;
	if (wasEditingTextView) {
#ifdef ZoomTraceTextEditing
		NSLog(@"End editing: set upper buffer");
#endif
		[[textView textStorage] endEditing];
		if (willScrollToEnd) [self scrollToEnd];
	}
    NSSize contentSize = [textScroller contentSize];
    [upperWindowBuffer setContainerSize: NSMakeSize(contentSize.width*scaleFactor, bufHeight)];
	if (wasEditingTextView) {
		if (willScrollToEnd) [self scrollToEnd];
#ifdef ZoomTraceTextEditing
		NSLog(@"Begin editing: set upper buffer");
#endif
		[[textView textStorage] beginEditing];
		editingTextView = YES;
	}
}

- (double) upperBufferHeight {
    return [upperWindowBuffer containerSize].height;
}

- (void) rearrangeUpperWindows {
    int newSize = [self upperWindowSize];
    if (newSize != lastUpperWindowSize) {
		// Stop editing the text view (if we are editing it)
		BOOL wasEditingTextView = editingTextView;
		editingTextView = NO;
		if (wasEditingTextView) {
#ifdef ZoomTraceTextEditing
			NSLog(@"End editing: rearrange upper windows");
#endif
			[[textView textStorage] endEditing];
			if (willScrollToEnd) [self scrollToEnd];
		}
		
        // Lay things out
        lastUpperWindowSize = newSize;

        // Force text display onto lower window (or where the lower window will be)
        NSDictionary* fixedAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
            [self fontWithStyle:ZFixedStyle], NSFontAttributeName, nil];
        NSSize fixedSize = [@"M" sizeWithAttributes: fixedAttributes];

        NSAttributedString* newLine = [[[NSAttributedString alloc] initWithString: @"\n"
                                                                       attributes: fixedAttributes]
            autorelease];

        double sepHeight = fixedSize.height * (double)newSize;
        sepHeight -= [upperWindowBuffer containerSize].height;
		
		if (inputPos > [[textView textStorage] length])
			inputPos = [[textView textStorage] length];
		
        if ([[textView textStorage] length] == 0) {
            [[[textView textStorage] mutableString] insertString: @"\n"
														 atIndex: inputPos];
			inputPos++;
        }

        do {
            NSRange endGlyph = [textView selectionRangeForProposedRange:
                NSMakeRange([[textView textStorage] length]-1, 1)
                                                            granularity: NSSelectByCharacter];
            if (endGlyph.location > 0xf0000000) {
                return; // Doesn't exist
            }

            NSRect endRect = [[textView layoutManager] boundingRectForGlyphRange: endGlyph
                                                                 inTextContainer: [textView textContainer]];

            if (NSMinY(endRect) < sepHeight) {
                [[textView textStorage] insertAttributedString: newLine
													   atIndex: inputPos];
				inputPos += [newLine length];
            } else {
                break;
            }
        } while (1);

        // The place where we need to put the more prompt may have changed
        [self updateMorePrompt];

		// Restart editing the text view (if we are editing it)
		if (wasEditingTextView) {
#ifdef ZoomTraceTextEditing
			NSLog(@"Begin editing: rearrange upper windows");
#endif
			[[textView textStorage] beginEditing];
			editingTextView = YES;
		}
	}

    // Redraw the upper windows if necessary
    if (upperWindowNeedsRedrawing) {
        [textScroller updateUpperWindows];
        upperWindowNeedsRedrawing = NO;
    }
}

- (NSArray*) upperWindows {
    return upperWindows;
}

- (void) upperWindowNeedsRedrawing {
    upperWindowNeedsRedrawing = YES;
}

- (void) padToLowerWindow {
    // This is a kind of poorly documented feature of the Z-Machine display model
    // (But often used in modern games, unfortunately)
    // It is usually impossible to move the cursor while in the lower window.
    // However, there is one way to move it vertically: split the window so that
    // the upper window overlaps the cursor. Officially this is not reliable
    // behaviour, but a sufficient number of games make use of it (not helped
    // by the Glk interpreter window model) that we have to emulate it or
    // things start to look a bit crappy.
    //
    // Behaviour is: if the upper window overlaps the cursor, then we move the cursor
    // until this is no longer the case. Text previously printed is unaffected.
    // Only applies when the lower window is sufficiently empty to contain no
    //
    // Here we do this by adding newlines. This may occasionally cause some
    // 'bouncing', as Cocoa is not designed to allow for a line of text that
    // appears in two containers (you can probably hack it to do it, though,
    // so there's a project for some brave future volunteer)
    //
    // Er, right, the code:
    NSTextContainer* theContainer;
	BOOL wasEditingTextView = editingTextView;
	editingTextView = NO;
	
	if (wasEditingTextView) {
#ifdef ZoomTraceTextEditing
		NSLog(@"End editing: pad to lower window");
#endif
		[[textView textStorage] endEditing];
		if (willScrollToEnd) [self scrollToEnd];
	}

    if (upperWindowBuffer == nil) return;

    if ([[textView textStorage] length] == 0) {
        [[[textView textStorage] mutableString] insertString: @"\n"
													 atIndex: inputPos];
		inputPos++;
    }
    
    do {
        NSRange endGlyph = [textView selectionRangeForProposedRange:
            NSMakeRange([[textView textStorage] length]-1, 1)
                                                    granularity: NSSelectByCharacter];
        if (endGlyph.location > 0xf0000000) {
			if (editingTextView) {
#ifdef ZoomTraceTextEditing
				NSLog(@"Begin editing: pad to lower window");
#endif
				[[textView textStorage] beginEditing];
			}
            return; // Doesn't exist
        }

        NSRange eRange;
        theContainer = [[textView layoutManager] textContainerForGlyphAtIndex: endGlyph.location effectiveRange: &eRange];

        if (theContainer == upperWindowBuffer) {
            [[[textView textStorage] mutableString] insertString: @"\n"
														 atIndex: inputPos];
			inputPos++;
        }

        // I suppose there's an outside chance of an infinite loop here
    } while (theContainer == upperWindowBuffer);

	if (wasEditingTextView) {
#ifdef ZoomTraceTextEditing
		NSLog(@"Begin editing: pad to lower window");
#endif
		[[textView textStorage] beginEditing];
		editingTextView = YES;
	}
}

- (void) runNewServer: (NSString*) serverName {
	// Kill off any previously running machine
    if (zMachine != nil) {
        [zMachine release];
        zMachine = nil;
	}
    
    if (zoomTask != nil) {
		NSTask* oldTask = zoomTask;
		
        zoomTask = nil; // Changes tidy up behaviour
		
        [oldTask terminate];
        [oldTask release];
    }

    if (zoomTaskStdout != nil) {
        [zoomTaskStdout release];
        zoomTaskStdout = nil;
    }

    if (zoomTaskData != nil) {
        [zoomTaskData release];
        zoomTaskData = nil;
    }
	
	// Reset the display
	if (!restoring) {
		if (pixmapCursor) [pixmapCursor release];
		pixmapCursor = nil;
		if (pixmapWindow) [pixmapWindow release];
		pixmapWindow = nil;
		focusedView = nil;
	
		[textView setString: @""];
	
		[upperWindows release];
		[lowerWindows release];
		upperWindows = [[NSMutableArray alloc] init];
		lowerWindows = [[NSMutableArray alloc] init];
	}
	restoring = NO;
	
	receiving = NO;
	receivingCharacters = NO;
	moreOn = NO;
	
	[self orInterpreterRestart];
	[self rearrangeUpperWindows];

	// Start a new machine
    zoomTask = [[NSTask alloc] init];
    zoomTaskData = [[NSMutableString alloc] init];
	
#ifdef ZoomTaskMaximumMemoryDebug
	NSMutableDictionary* taskEnvironment = [[[NSProcessInfo processInfo] environment] mutableCopy];
	
	[taskEnvironment setObject: @"1"
						forKey: @"MallocCheckHeapStart"];
	[taskEnvironment setObject: @"1"
						forKey: @"MallocCheckHeapEach"];
	[taskEnvironment setObject: @"1"
						forKey: @"MallocScribble"];
	[taskEnvironment setObject: @"1"
						forKey: @"MallocGuardEdges"];
	[taskEnvironment setObject: @"YES"
						forKey: @"NSZombieEnabled"];
	
	[zoomTask setEnvironment: [taskEnvironment autorelease]];
#endif

    if (serverName == nil) {
        serverName = [[NSBundle mainBundle] pathForResource: @"ZoomServer"
                                                     ofType: nil];
    }
	
	if (serverName == nil) {
		serverName = [[NSBundle bundleForClass: [self class]] pathForResource: @"ZoomServer"
																	   ofType: nil];
	}

    // Prepare for launch
    [zoomTask setLaunchPath: serverName];	
	[zoomTask setArguments: [NSArray arrayWithObjects: 
		[NSString stringWithFormat: @"%i", getpid()], nil]];
    
#if 0
    zoomTaskStdout = [[NSPipe alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(zoomTaskNotification:)
                                                 name: NSFileHandleDataAvailableNotification
                                               object: [zoomTaskStdout fileHandleForReading]];
    [[zoomTaskStdout fileHandleForReading] waitForDataInBackgroundAndNotify];

    [zoomTask setStandardOutput: zoomTaskStdout];
#endif
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(zoomTaskFinished:)
                                                 name: NSTaskDidTerminateNotification
                                               object: zoomTask];
	
	// Notify the connector that we're waiting for a Z-Machine to arrive on the scene
	[[ZoomConnector sharedConnector] addViewWaitingForServer: self];
    
    // Light the blue touch paper
    [zoomTask launch];

	//    \||/
    // ***FOOM***
}//        ||
//		   ||
//		   ||
//		   ||
//		  \||/
//         \/
//	     (phut)
- (void) zoomTaskFinished: (NSNotification*) not {
	if ([not object] != zoomTask) return; // Not our task
	
	// In case we're self-destructing, retain + autorelease
	[self retain];
	[self autorelease];

	[[ZoomConnector sharedConnector] removeView: self];

    // The task has finished
    if (zMachine) {
        [zMachine release];
        zMachine = nil;
    }
	
	if (receiving || receivingCharacters) [self stopReceiving];
	
    // Notify the user (display a message)
    ZStyle* notifyStyle = [[ZStyle alloc] init];
    ZStyle* standardStyle = [[ZStyle alloc] init];
    [notifyStyle setForegroundColour: 7];
    [notifyStyle setBackgroundColour: 1];

    NSString* finishString = @"[ The game has finished ]";
    if ([zoomTask terminationStatus] != 0) {
        finishString = @"[ The Zoom interpreter has quit unexpectedly ]";
    } else {
		if (lastAutosave != nil) {
			[lastAutosave release];
			lastAutosave = nil;
		}
	}
	
    NSAttributedString* newline = [self formatZString: @"\n"
                                            withStyle: [standardStyle autorelease]];
    NSAttributedString* string = [self formatZString: finishString
                                           withStyle: [notifyStyle autorelease]];

    [[textView textStorage] appendAttributedString: newline];
    [[textView textStorage] appendAttributedString: string];
    [[textView textStorage] appendAttributedString: newline];
	inputPos = [[textView textStorage] length];
	[textView setEditable: NO];

    // Update the windows
    [self rearrangeUpperWindows];

    int currentSize = [self upperWindowSize];
    if (currentSize != lastTileSize) {
        [textScroller tile];
        [self padToLowerWindow];
        [self updateMorePrompt];
        lastTileSize = currentSize;
    }
	
	[self scrollToEnd];

    // Paste stuff
    NSEnumerator* upperEnum = [upperWindows objectEnumerator];
    ZoomUpperWindow* win;
    while (win = [upperEnum nextObject]) {
        [textView pasteUpperWindowLinesFrom: win];
    }
    
    // Notify the delegate
    if (delegate && [delegate respondsToSelector: @selector(zMachineFinished:)]) {
        [delegate zMachineFinished: self];
    }
	
	// Cursor is not blinking any more
	if (pixmapCursor) {
		[pixmapCursor setBlinking: NO];
		[pixmapCursor setShown: NO];
		[pixmapCursor setActive: NO];
	}

	// Free things up
    [zoomTask release];
    [zoomTaskStdout release];
    [zoomTaskData release];

    zoomTask = nil;
    zoomTaskStdout = nil;
    zoomTaskData = nil;
}

- (BOOL) isRunning {
	return zMachine != nil;
}

- (void) zoomTaskNotification: (NSNotification*) not {
	if ([not object] != [zoomTaskStdout fileHandleForReading]) return;
	
    // Data is waiting on stdout: receive it
    NSData* inData = [[zoomTaskStdout fileHandleForReading] availableData];

    if ([inData length]) {
        [zoomTaskData appendString: [[[NSString alloc] initWithData: inData
                                                           encoding: NSUTF8StringEncoding] autorelease]];

		// Yeesh, it must have been REALLY late at night when I wrote this, umm, thing. Contender for most braindead code ever, I think.
		//printf("%s", [[NSString stringWithCString: [inData bytes]
		//								   length: [inData length]] cString]);
		
		[[zoomTaskStdout fileHandleForReading] waitForDataInBackgroundAndNotify];
    } else {
		// No data is waiting (dead task/filehandle?)
    }
}

- (BOOL)panel:(id)sender shouldShowFilename:(NSString *)filename {
	NSSavePanel* panel = sender;
	
    if( [[panel allowedFileTypes] containsObject: [filename pathExtension]] ) {
        return YES;
    }
	
    if( [[panel allowedFileTypes] containsObject: @"zoomSave"] ) {
		if ([[filename pathExtension] isEqualToString: @"qut"]) {
			return YES;
		}
	}
	
	BOOL isDir;
	
	if ([[NSFileManager defaultManager] fileExistsAtPath: filename isDirectory: &isDir]) {
		if (isDir) return YES;
	}
	
	return NO;
}

- (BOOL)panel:(id)sender isValidFilename:(NSString *)filename {
	NSSavePanel* panel = sender;
	
    if( [[panel allowedFileTypes] containsObject: [filename pathExtension]] ) {
        return YES;
    }
	
    if( [[panel allowedFileTypes] containsObject: @"zoomSave"] ) {
		if ([[filename pathExtension] isEqualToString: @"qut"]) {
			return YES;
		}
	}
	
	return NO;
}

// = Prompting for files =
- (void) setupPanel: (NSSavePanel*) panel
               type: (ZFileType) type {
    BOOL supportsMessage = [panel respondsToSelector: @selector(setMessage:)];
    [panel setCanSelectHiddenExtension: YES];
	[panel setDelegate: self];
    
    NSString* saveOpen = @"Save as";
    
    if ([panel isKindOfClass: [NSOpenPanel class]]) {
        saveOpen = @"Open";
    } else {
        saveOpen = @"Save as";
    }
    
    [panel setExtensionHidden: 
        [[[NSUserDefaults standardUserDefaults] objectForKey: 
            @"ZoomHiddenExtension"] boolValue]];
	
	BOOL usePackage = NO;
	
	if (type == ZFileQuetzal && delegate && [delegate respondsToSelector: @selector(useSavePackage)]) {
		usePackage = [delegate useSavePackage];
	}
		
    switch (type) {
        default:
        case ZFileQuetzal:
			if (usePackage) {
				[panel setAllowedFileTypes: [NSArray arrayWithObject:@"zoomSave"]];
			} else {
				[panel setAllowedFileTypes: [NSArray arrayWithObject:@"qut"]];
			}
            typeCode = 'IFZS';
            if (supportsMessage) {
                [panel setMessage: [NSString stringWithFormat: @"%@ saved game (quetzal) file", saveOpen]];
                [panel setAllowedFileTypes: [NSArray arrayWithObjects: usePackage?@"zoomSave":@"qut", nil]];
            }
            break;
            
        case ZFileData:
            [panel setAllowedFileTypes: [NSArray arrayWithObject:@"dat"]];
            typeCode = '\?\?\?\?';
            if (supportsMessage) {
                [panel setMessage: [NSString stringWithFormat: @"%@ data file", saveOpen]];
                
                // (Assume if setMessage is supported, we have 10.3)
                [panel setAllowsOtherFileTypes: YES];
                [panel setAllowedFileTypes: [NSArray arrayWithObjects: @"dat", @"qut", nil]];
            }
            break;
            
        case ZFileRecording:
            [panel setAllowedFileTypes: [NSArray arrayWithObject:@"txt"]];
            typeCode = 'TEXT';
            if (supportsMessage) {
                [panel setMessage: [NSString stringWithFormat: @"%@ command recording file", saveOpen]];
                [panel setAllowedFileTypes: [NSArray arrayWithObjects: @"txt", @"rec", nil]];
            }
            break;
            
        case ZFileTranscript:
            [panel setAllowedFileTypes: [NSArray arrayWithObject:@"txt"]];
            typeCode = 'TEXT';
            if (supportsMessage) {
                [panel setMessage: [NSString stringWithFormat: @"%@ transcript recording file", saveOpen]];
                [panel setAllowedFileTypes: [NSArray arrayWithObjects: @"txt", nil]];
            }
            break;
    }
}

- (void) storePanelPrefs: (NSSavePanel*) panel {
    if( [panel directoryURL] ) {
        [[NSUserDefaults standardUserDefaults] setObject: [[panel directoryURL] absoluteURL]
                                                  forKey: @"ZoomSaveURL"];
    }
    [[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithBool: [panel isExtensionHidden]]
                                              forKey: @"ZoomHiddenExtension"];
}

- (long) creatorCode {
    return creatorCode;
}

- (void) setCreatorCode: (long) code {
    creatorCode = code;
}

- (void) promptForFileToWrite: (in ZFileType) type
                  defaultName: (in bycopy NSString*) name {
    // Setup a save panel
    NSSavePanel* panel = [NSSavePanel savePanel];
    
    [self setupPanel: panel
                type: type];
	
	NSURL* directoryURL = nil;
	if (delegate && [delegate respondsToSelector: @selector(defaultSaveDirectory)]) {
		directoryURL = [NSURL fileURLWithPath: [delegate defaultSaveDirectory]];
	}
	
	if (directoryURL == nil) {
		directoryURL = [[NSUserDefaults standardUserDefaults] objectForKey: @"ZoomSaveURL"];
	}

	if (directoryURL != nil) {
        [panel setDirectoryURL: directoryURL];
    }

    // Show it
    [panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger returnCode)
     {
         if (returnCode != NSOKButton) {
             [zMachine filePromptCancelled];
         } else {
             NSString* fn = [[panel URL] path];
             NSFileHandle* file = nil;
             
             BOOL usePackage = NO;
             
             [self storePanelPrefs: panel];
             
             if (type == ZFileQuetzal && delegate && [delegate respondsToSelector: @selector(useSavePackage)]) {
                 usePackage = [delegate useSavePackage];
             }
             
             if (usePackage) {
                 // We store information about the current screen state in the package
                 ZPackageFile* f = [[ZPackageFile alloc] initWithPath: fn
                                                          defaultFile: @"save.qut"
                                                           forWriting: YES];
                 
                 if (f) {
                     int windowNumber = 0;
                     ZoomUpperWindow* previewWin;
                     
                     [f setAttributes: [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithLong: creatorCode], NSFileHFSCreatorCode,
                                        [NSNumber numberWithLong: typeCode], NSFileHFSTypeCode,
                                        [NSNumber numberWithBool: [panel isExtensionHidden]], NSFileExtensionHidden,
                                        nil]];
                     
                     if ([upperWindows count] <= 0 || [(ZoomUpperWindow*)[upperWindows objectAtIndex: 0] length] > 0) {
                         windowNumber = 0;
                     } else {
                         windowNumber = 1;
                     }
                     
                     if ([upperWindows count] <= 0) {
                         previewWin = nil;
                     } else {
                         previewWin = [upperWindows objectAtIndex: windowNumber];
                     }
                     
                     [f addData: [NSArchiver archivedDataWithRootObject: previewWin]
                    forFilename: @"ZoomPreview.dat"];
                     [f addData: [NSArchiver archivedDataWithRootObject: self]
                    forFilename: @"ZoomStatus.dat"];
                     
                     if (delegate && [delegate respondsToSelector: @selector(prepareSavePackage:)]) {
                         [delegate prepareSavePackage: f];
                     }
                     
                     [zMachine promptedFileIs: [f autorelease]
                                         size: 0];
                 } else {
                     [zMachine filePromptCancelled];				
                 }
             } else {
                 int creator = creatorCode;
                 
                 if (typeCode == 'TEXT') creator = 0;
                 
                 if ([[NSFileManager defaultManager] createFileAtPath:fn
                                                             contents:[NSData data]
                                                           attributes:
                      [NSDictionary dictionaryWithObjectsAndKeys: 
                       [NSNumber numberWithLong: creator], NSFileHFSCreatorCode,
                       [NSNumber numberWithLong: typeCode], NSFileHFSTypeCode,
                       [NSNumber numberWithBool: [panel isExtensionHidden]], NSFileExtensionHidden,
                       nil]]) {
                          file = [NSFileHandle fileHandleForWritingAtPath: fn];
                      }
                 
                 if (file) {
                     ZHandleFile* f;
                     
                     f = [[ZHandleFile alloc] initWithFileHandle: file];
                     
                     [zMachine promptedFileIs: [f autorelease]
                                         size: 0];
                 } else {
                     [zMachine filePromptCancelled];
                 }
             }
         }
     }];
}

- (void) promptForFileToRead: (in ZFileType) type
                 defaultName: (in bycopy NSString*) name {
    // Set up an open panel
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    
    [self setupPanel: panel
                type: type];

	NSURL* directoryURL = nil;
	if (delegate && [delegate respondsToSelector: @selector(defaultSaveDirectory)]) {
		directoryURL = [NSURL fileURLWithPath: [delegate defaultSaveDirectory]];
	}
	
	if (directoryURL == nil) {
		directoryURL = [[NSUserDefaults standardUserDefaults] objectForKey: @"ZoomSaveURL"];
	}

	if (directoryURL != nil) {
        [panel setDirectoryURL: directoryURL];
    }

    // Show it
    [panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger returnCode)
     {
        if (returnCode != NSOKButton) {
            [zMachine filePromptCancelled];
        } else {
            NSString* fn = [[panel URL] path];
            NSFileHandle* file = nil;

            [self storePanelPrefs: panel];
            
            if ([[fn pathExtension] isEqualToString: @"zoomSave"]) {
                ZPackageFile* f;
                
                f = [[ZPackageFile alloc] initWithPath: fn
                                           defaultFile: @"save.qut"
                                            forWriting: NO];
                
                if (f) {
                    NSData* skeinData = [f dataForFile: @"Skein.skein"];
                    if (skeinData) {
                        if (delegate && [delegate respondsToSelector: @selector(loadedSkeinData:)]) {
                            [delegate loadedSkeinData: skeinData];
                        }
                    }
                    
                    [zMachine promptedFileIs: [f autorelease]
                                        size: [f fileSize]];
                } else {
                    [zMachine filePromptCancelled];
                }
            } else {
                file = [NSFileHandle fileHandleForReadingAtPath: fn];
            
                if (file) {
                    ZDataFile* f;
                    NSData* fData = [file readDataToEndOfFile];
                
                    f = [[ZDataFile alloc] initWithData: fData];
                
                    [zMachine promptedFileIs: [f autorelease]
                                        size: [fData length]];
                } else {
                    [zMachine filePromptCancelled];
                }
            }
        }
     }];
}

// = The delegate =
- (void) setDelegate: (id) dg {
    // (Not retained)
    delegate = dg;
}

- (id) delegate {
    return delegate;
}

- (void) killTask {
    if (zoomTask) [zoomTask terminate];
}

- (void) debugTask {
	if (zoomTask) kill([zoomTask processIdentifier], SIGUSR1);
}

// = Warnings/errors =
- (void) displayWarning: (in bycopy NSString*) warning {
	// FIXME
	NSString* warningString;
	
	warningString = [NSString stringWithFormat: @"[ Warning: %@ ]", warning];
	
	if ([viewPrefs fatalWarnings]) {
		[self displayFatalError: warningString];
		return;
	}
	
	if ([viewPrefs displayWarnings]) {
		if ([lowerWindows count] <= 0) {
			NSBeginInformationalAlertSheet(@"Warning", @"OK", nil, nil, [self window], nil, nil, nil, NULL, @"%@", warning);
			return;
		}
		
		ZStyle* warningStyle = [[ZStyle alloc] init];
		[warningStyle setBackgroundColour: 4];
		[warningStyle setForegroundColour: 7];
		[warningStyle setBold: NO];
		[warningStyle setFixed: NO];
		[warningStyle setSymbolic: NO];
		[warningStyle setUnderline: YES];
		
		[[lowerWindows objectAtIndex: 0] writeString: warningString
										   withStyle: warningStyle];
        [warningStyle autorelease];
	}
}

- (void) displayFatalError: (in bycopy NSString*) error {
	NSBeginCriticalAlertSheet(@"Fatal error", @"Stop", nil, nil, [self window], nil, nil, nil, NULL, @"%@", error);
}

// = Setting/updating preferences =
- (void) setPreferences: (ZoomPreferences*) prefs {
	if (viewPrefs) {
		[[NSNotificationCenter defaultCenter] removeObserver: self
														name: ZoomPreferencesHaveChangedNotification
													  object: viewPrefs];
		[viewPrefs release];
	}
	
	viewPrefs = [prefs retain];
	
	[self preferencesHaveChanged: [NSNotification notificationWithName: ZoomPreferencesHaveChangedNotification
																object: viewPrefs]];
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(preferencesHaveChanged:)
												 name: ZoomPreferencesHaveChangedNotification
											   object: viewPrefs];
}

- (void) preferencesHaveChanged: (NSNotification*)not {
	// Usually called by the notification manager
	if ([not object] != viewPrefs) {
		NSLog(@"(BUG?) notification recieved for preferences that do not belong to us");
		return;
	}
	
	// Update fonts, colours according to specification
	[fonts release];
	[colours release];
	
	fonts = [[viewPrefs fonts] retain];
	colours = [[viewPrefs colours] retain];
	
	// Switch on the text-to-speech if required
	if (!textToSpeechReceiver) {
		textToSpeechReceiver = [[ZoomTextToSpeech alloc] init];
		[self addOutputReceiver: textToSpeechReceiver];
	}
	[textToSpeechReceiver setImmediate: [viewPrefs speakGameText]];
	
	[textView setTextContainerInset: NSMakeSize([viewPrefs textMargin], [viewPrefs textMargin])]; 
	[[textView layoutManager] setHyphenationFactor: [viewPrefs useHyphenation]?1:0];
	[[textView layoutManager] setUsesScreenFonts: [viewPrefs useScreenFonts]];
	
	if ([viewPrefs useKerning]) {
		[textView useStandardKerning: self];
	} else {
		[textView turnOffKerning: self];
	}
	if ([viewPrefs useLigatures]) {
		[textView useStandardLigatures: self];
	} else {
		[textView turnOffLigatures: self];
	}
	
	[textScroller setUseUpperDivider: [viewPrefs showBorders]];
	[textScroller tile];
	
	[self reformatWindow];
}

- (void) reformatWindow {
	// Reformats the entire window according to currently set fonts/colours
	NSMutableAttributedString* storage = [textView textStorage];
	NSRange attributedRange;
	NSDictionary* attr;
	int len = [storage length];
	
	attributedRange.location = 0;
	
#ifdef ZoomTraceTextEditing
	NSLog(@"Begin editing: reformat window");
#endif
	[storage beginEditing];
	
	while (attributedRange.location < len) {
		attr = [storage attributesAtIndex: attributedRange.location
						   effectiveRange: &attributedRange];

		if (attributedRange.location == NSNotFound) break;
		if (attributedRange.length == 0) break;
		
		// Re-apply the style associated with this block of text
		ZStyle* sty = [attr objectForKey: ZoomStyleAttributeName];
		
		if (sty) {
			//
			// Uhh... FIXME: weird bug here when we're loading a game. The endEditing call below throws an exception
			// which says 'endEditing not called'. Errm.
			//
			// Have implemented a sort-of fix. The problem occurs when you call setAttributedString: on an
			// NSTextStorage where the attributed string is an NSTextStorage.
			//
			NSDictionary* newAttr = [self attributesForStyle: sty];
			
			[storage setAttributes: newAttr
							 range: attributedRange];
		}
		
		attributedRange.location += attributedRange.length;
	}
	
#ifdef ZoomTraceTextEditing
	NSLog(@"End editing: reformat window");
#endif
	[storage endEditing];
	
	// Reset the background colour of the lower window
	if ([lowerWindows count] > 0) {
		[textView setBackgroundColor: [self backgroundColourForStyle: [(ZoomLowerWindow*)[lowerWindows objectAtIndex: 0] backgroundStyle]]];
	}

	// Reformat the upper window(s) as necessary
	[textScroller tile];
	
	NSEnumerator* upperWindowEnum = [upperWindows objectEnumerator];
	ZoomUpperWindow* upperWin;
	
	while (upperWin = [upperWindowEnum nextObject]) {
		[upperWin reformatLines];
	}
	
	[textScroller updateUpperWindows];
}

- (void) retileUpperWindowIfRequired {
    int currentSize = [self upperWindowSize];
    if (currentSize != lastTileSize) {
        [textScroller tile];
        [self updateMorePrompt];
        lastTileSize = currentSize;
    }
}

- (int) foregroundColour {
	return [viewPrefs foregroundColour];
}

- (int) backgroundColour {
	return [viewPrefs backgroundColour];
}

// = Autosave =

- (BOOL) createAutosaveDataWithCoder: (NSCoder*) encoder {
	if (lastAutosave == nil) return NO;
	
#if 0
	// BORKED
	int autosaveVersion = 101;
	
	[encoder encodeValueOfObjCType: @encode(int) 
								at: &autosaveVersion];
	
	[encoder encodeObject: lastAutosave];
	
	[encoder encodeObject: upperWindows];
	[encoder encodeObject: lowerWindows];
	
	// The rest of the view state
	[encoder encodeObject: [textView textStorage]];
	[encoder encodeObject: commandHistory];
	
	// DOH!
	[encoder encodeObject: pixmapWindow];
#else
	int autosaveVersion = 102;

	[encoder encodeValueOfObjCType: @encode(int) 
								at: &autosaveVersion]; // HACK: required to support the old, broken, format
	
	NSDictionary* saveData = [NSDictionary dictionaryWithObjectsAndKeys:
		lastAutosave, @"lastAutosave",
		upperWindows, @"upperWindows",
		lowerWindows, @"lowerWindows",
		[textView textStorage], @"textStorage",
		commandHistory, @"commandHistory",
		pixmapWindow, @"pixmapWindow",
		nil];
	
	[encoder encodeRootObject: saveData];
#endif
	
	// All we need, I think
	
	// Done
	return YES;
}

- (void) restoreAutosaveFromCoder: (NSCoder*) decoder {
	int autosaveVersion;
	
	[decoder decodeValueOfObjCType: @encode(int)
								at: &autosaveVersion];
	
	if (autosaveVersion == 102) {
		if (lastAutosave) [lastAutosave release];
		if (upperWindows) [upperWindows release];
		if (lowerWindows) [lowerWindows release];
		if (commandHistory) [commandHistory release];
		
		NSDictionary* restored = [decoder decodeObject];
		
		lastAutosave = [[restored objectForKey: @"lastAutosave"] retain];
		upperWindows = [[restored objectForKey: @"upperWindows"] retain];
		lowerWindows = [[restored objectForKey: @"lowerWindows"] retain];
		commandHistory = [[restored objectForKey: @"commandHistory"] retain];
		
		NSTextStorage* storage = [restored objectForKey: @"textStorage"];
		
		// Workaround for a Cocoa bug
		[[textView textStorage] setAttributedString: [[[NSAttributedString alloc] initWithAttributedString: storage] autorelease]];
		inputPos = [[textView textStorage] length];
		
		// Final setup
		upperWindowsToRestore = [upperWindows count];
		
		[upperWindows makeObjectsPerformSelector: @selector(setZoomView:)
									  withObject: self];
		[lowerWindows makeObjectsPerformSelector: @selector(setZoomView:)
									  withObject: self];
		
		if (pixmapWindow) {
			[pixmapWindow setZoomView: self];
		}
		
		// Load the state into the z-machine
		if (zMachine) {
			[zMachine restoreSaveState: lastAutosave];
		}
		
		[self reformatWindow];
		[self resetMorePrompt];
		[self scrollToEnd];
		inputPos = [[textView textStorage] length];		
	} else if (autosaveVersion == 100 || autosaveVersion == 101) {
		// (Autosave versions only used up to 1.0.2beta1)
		if (lastAutosave) [lastAutosave release];
		if (upperWindows) [upperWindows release];
		if (lowerWindows) [lowerWindows release];
		if (commandHistory) [commandHistory release];

		lastAutosave = [[decoder decodeObject] retain];
		upperWindows = [[decoder decodeObject] retain];
		lowerWindows = [[decoder decodeObject] retain];
		
		NSTextStorage* storage = [decoder decodeObject];
		
		// Workaround for a Cocoa bug
		[[textView textStorage] setAttributedString: [[[NSAttributedString alloc] initWithAttributedString: storage] autorelease]];
		inputPos = [[textView textStorage] length];
		
		commandHistory = [[decoder decodeObject] retain];
		if (autosaveVersion == 101) pixmapWindow = [[decoder decodeObject] retain];
		
		// Final setup
		upperWindowsToRestore = [upperWindows count];
		
		[upperWindows makeObjectsPerformSelector: @selector(setZoomView:)
									  withObject: self];
		[lowerWindows makeObjectsPerformSelector: @selector(setZoomView:)
									  withObject: self];
		
		if (pixmapWindow) {
			[pixmapWindow setZoomView: self];
		}
		
		// Load the state into the z-machine
		if (zMachine) {
			[zMachine restoreSaveState: lastAutosave];
		}
		
		[self reformatWindow];
		[self resetMorePrompt];
		[self scrollToEnd];
		inputPos = [[textView textStorage] length];
	} else {
		NSLog(@"Unknown autosave version (ignoring)");
	}
}

// = NSCoding =
- (void) encodeWithCoder: (NSCoder*) encoder {
	int encodingVersion = 101;
	
	[encoder encodeValueOfObjCType: @encode(int) 
								at: &encodingVersion];
	
	[encoder encodeObject: upperWindows];
	[encoder encodeObject: lowerWindows];
	
	// The rest of the view state
	[encoder encodeObject: [textView textStorage]];
	[encoder encodeObject: commandHistory];
	[encoder encodeObject: pixmapWindow];
	
	// All we need, I think
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder: decoder];
	
    if (self) {
        [self setFrame: NSMakeRect(0,0, 200, 200)];
        [self prepare];

		int encodingVersion;
		
		restoring = YES;
		
		[decoder decodeValueOfObjCType: @encode(int)
									at: &encodingVersion];
		
		if (encodingVersion == 100 || encodingVersion == 101) {
			if (lastAutosave) [lastAutosave release];
			if (upperWindows) [upperWindows release];
			if (lowerWindows) [lowerWindows release];
			if (commandHistory) [commandHistory release];
			
			lastAutosave = nil;
			upperWindows = [[decoder decodeObject] retain];
			lowerWindows = [[decoder decodeObject] retain];
			
			NSTextStorage* storage = [decoder decodeObject];
			
			[[textView textStorage] beginEditing];
			// Workaround for a bug in Cocoa
			[[textView textStorage] setAttributedString: [[[NSAttributedString alloc] initWithAttributedString: storage] autorelease]];
			inputPos = [[textView textStorage] length];
			
			commandHistory = [[decoder decodeObject] retain];
			
			if (encodingVersion == 101) {
				pixmapWindow = [[decoder decodeObject] retain];
			}
			
			// Final setup
			upperWindowsToRestore = [upperWindows count];
			
			[upperWindows makeObjectsPerformSelector: @selector(setZoomView:)
										  withObject: self];
			[lowerWindows makeObjectsPerformSelector: @selector(setZoomView:)
										  withObject: self];
			if (pixmapWindow) [pixmapWindow setZoomView: self];
			
			// Load the state into the z-machine
			if (zMachine) {
				[zMachine restoreSaveState: lastAutosave];
			}
			
			[self reformatWindow];
			[self resetMorePrompt];
			[self scrollToEnd];
			[[textView textStorage] endEditing];
			inputPos = [[textView textStorage] length];
		} else {
			NSLog(@"Unknown autosave version (ignoring)");
			[self release];
			return nil;
		}
    }
	
    return self;
}

- (void) restoreSaveState: (NSData*) state {
	NSString* error = [zMachine restoreSaveState: state];
	
	if (error) {
		NSLog(@"Failed to restore save state: %@", error);
	}
	
	if (moreOn) {
		moreOn = NO;
		[self setShowsMorePrompt: NO];
	}
	
	[self reformatWindow];
	[self resetMorePrompt];
	[self scrollToEnd];
	inputPos = [[textView textStorage] length];
}

// = Debugging =
- (void) hitBreakpointAt: (int) pc {
	if (delegate && [delegate respondsToSelector: @selector(hitBreakpoint:)]) {
		[delegate hitBreakpoint: pc];
	} else {
		NSLog(@"Breakpoint without handler");
		[zMachine continueFromBreakpoint];
	}
}

// = Focused view =
- (void) setFocusedView: (NSObject<ZWindow>*) view {
	focusedView = view;
}

- (NSObject<ZWindow>*) focusedView {
	return focusedView;
}

// = Cursor delegate =
- (void) viewWillMoveToWindow: (NSWindow*) newWindow {
	// Will observe events in a new window
	if ([self window] != nil) {
		[[NSNotificationCenter defaultCenter] removeObserver: self
														name: NSWindowDidBecomeKeyNotification
													  object: [self window]];
		[[NSNotificationCenter defaultCenter] removeObserver: self
														name: NSWindowDidResignKeyNotification
													  object: [self window]];
	}
	
	if (newWindow != nil) {
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(windowDidBecomeKey:)
													 name: NSWindowDidBecomeKeyNotification
												   object: [self window]];
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(windowDidResignKey:)
													 name: NSWindowDidResignKeyNotification
												   object: [self window]];		
	}
}

- (void) windowDidBecomeKey: (NSNotification*) not {
	if (pixmapCursor) {
		[pixmapCursor setActive: YES];
	}
	[[textScroller upperWindowView] windowDidBecomeKey: not];
}

- (void) windowDidResignKey: (NSNotification*) not {
	if (pixmapCursor) {
		[pixmapCursor setActive: NO];
	}
	[[textScroller upperWindowView] windowDidResignKey: not];
}

- (void) blinkCursor: (ZoomCursor*) sender {
	[self setNeedsDisplayInRect: [sender cursorRect]];
}

- (BOOL) acceptsFirstResponder {
	if (pixmapWindow != nil) {
		return YES;
	}
	
	return [super acceptsFirstResponder];
}

- (BOOL) becomeFirstResponder {
	if (pixmapCursor) {
		[pixmapCursor setFirst: YES];
		return YES;
	}
	
	return [super becomeFirstResponder];
}

- (BOOL) resignFirstResponder {
	if (pixmapCursor) {
		[pixmapCursor setFirst: NO];
	}
	
	return [super resignFirstResponder];
}

// = Manual input =

- (void) setInputLinePos: (NSPoint) pos {
	inputLinePos = pos;
}

- (ZoomInputLine*) inputLine {
	return inputLine;
}

- (void) setInputLine: (ZoomInputLine*) input {
	if (inputLine) [inputLine release];
	inputLine = [input retain];
	
	if ([inputLine delegate] == nil)
		[inputLine setDelegate: self];
}

- (void) inputLineHasChanged: (ZoomInputLine*) sender {
	[self setNeedsDisplayInRect: [inputLine rectForPoint: inputLinePos]];
}

- (void) endOfLineReached: (ZoomInputLine*) sender {
	if (receiving) {
		NSString* inputText = [sender inputLine];
		
		[commandHistory addObject: inputText];
		
		inputText = [inputText stringByAppendingString: @"\n"];
		
		[zMachine inputText: inputText];
		[self orInputCommand: inputText];		
		historyPos = [commandHistory count];
	}
	
	if (sender == inputLine) {
		// When inputting in the upper window, sender might not be inputLine
		[self setNeedsDisplayInRect: [sender rectForPoint: inputLinePos]];
		[inputLine release];
		inputLine = nil;
	}
}

- (bycopy NSString*) receivedTextToDate {
	// Used to retrieve the text received in the view so far: for example, to find out what the user typed prior to a timeout
	
	if (inputLine != nil) {
		return [inputLine inputLine];
	} else {
		NSString* str = [[textView textStorage] string];
		
		NSString* res = [str substringWithRange: NSMakeRange(inputPos,
															 [str length]-inputPos)];
		
		// FIXME: might fail if there's an errant newline somewhere around
		// Reset inputPos (accepting the input, but the z-machine allows the game to unaccept it later on, so that's alright)
		inputPos = [str length];
		return res;
	}
}

- (bycopy NSString*) backtrackInputOver: (in bycopy NSString*) prefix {
	if (prefix == nil) return nil;
		
	if (inputLine != nil) {
		// Input lines currently are unable to backtrack, so the prefix remains unaltered
		return prefix;
	} else {
		NSString* str = [[textView textStorage] string];
		
		// 'len' contains the amount of text we'll attempt to backtrack across
		int len = [prefix length];
		if (len > [str length]) len = [str length];
		
		// Cut out a substring according to the length (and the current input position)
		if (inputPos > [str length]) inputPos = [str length];
		str = [str substringWithRange: NSMakeRange(inputPos-len, len)];
		
		// We compare lowercase versions of the string: this allows for things like Beyond Zork which write 'EXAMINE' but add 'examine' to the buffer
		NSString* lowerPrefix = [prefix lowercaseString];
		str = [str lowercaseString];
		
		// See how far back we can go
		int offset = len-1;
		int prefixOffset = [lowerPrefix length]-1;
		
		while (offset >= 0 && prefixOffset >= 0 && [lowerPrefix characterAtIndex: prefixOffset] == [str characterAtIndex: offset]) {
			offset--;
			prefixOffset--;
		}
		
		// offset, prefixOffset indicate the last character that wasn't matched
		offset++;
		
		int matchLength = len-offset;
		
		inputPos -= matchLength;
		
		return [prefix substringToIndex: offset];
	}
}

// = Output receivers =

- (void) addOutputReceiver: (id) receiver {
	if (!outputReceivers) {
		outputReceivers = [[NSMutableArray alloc] init];
	}
	
	if ([outputReceivers indexOfObjectIdenticalTo: receiver] == NSNotFound) {
		[outputReceivers addObject: receiver];
	}
}

- (void) removeOutputReceiver: (id) receiver {
	if (!outputReceivers) return;
	[outputReceivers removeObjectIdenticalTo: receiver];
	
	if ([outputReceivers count] <= 0) {
		[outputReceivers release];
		outputReceivers = nil;
	}
}

// These functions are really for internal use only: they actually call the output receivers as appropriate
- (void) orInputCommand: (NSString*) command {
	if (!outputReceivers) return;
	NSEnumerator* orEnum = [outputReceivers objectEnumerator];
	NSObject* or;
	
	while (or = [orEnum nextObject]) {
		if ([or respondsToSelector: @selector(inputCommand:)]) {
			[or inputCommand: command];
		}
	}
}

- (void) orInputCharacter: (NSString*) character {
	if (!outputReceivers) return;
	NSEnumerator* orEnum = [outputReceivers objectEnumerator];
	NSObject* or;
	
	while (or = [orEnum nextObject]) {
		if ([or respondsToSelector: @selector(inputCharacter:)]) {
			[or inputCharacter: character];
		}
	}
}

- (void) orOutputText:   (NSString*) outputText {
	if (!outputReceivers) return;
	NSEnumerator* orEnum = [outputReceivers objectEnumerator];
	NSObject* or;
	
	while (or = [orEnum nextObject]) {
		if ([or respondsToSelector: @selector(outputText:)]) {
			[or outputText: outputText];
		}
	}
}

- (void) orWaitingForInput {
	if (!outputReceivers) return;
	NSEnumerator* orEnum = [outputReceivers objectEnumerator];
	NSObject* or;
	
	if (delegate && [delegate respondsToSelector: @selector(zoomWaitingForInput)]) {
		[delegate zoomWaitingForInput];
	}
	
	while (or = [orEnum nextObject]) {
		if ([or respondsToSelector: @selector(zoomWaitingForInput)]) {
			[or zoomWaitingForInput];
		}
	}
}

- (void) orInterpreterRestart {
	if (!outputReceivers) return;
	NSEnumerator* orEnum = [outputReceivers objectEnumerator];
	NSObject* or;
	
	while (or = [orEnum nextObject]) {
		if ([or respondsToSelector: @selector(zoomInterpreterRestart)]) {
			[or zoomInterpreterRestart];
		}
	}
}

- (void) zMachineHasRestarted {
	[self orInterpreterRestart];
}

// = Input sources =

- (void) setInputSource: (id) source {
	if (inputSource) [inputSource release];
	inputSource = [source retain];
	
	if (receivingCharacters && [inputSource respondsToSelector: @selector(nextCommand)]) {
		// Get the next command
		NSString* nextInput = [inputSource nextCommand];
		
		if (nextInput == nil) {
			// End of input
			if (delegate && [delegate respondsToSelector: @selector(inputSourceHasFinished:)]) {
				[delegate inputSourceHasFinished: inputSource];
			}
			
			[inputSource release];
			inputSource = nil;
		} else {			
			if ([nextInput length] == 0) nextInput = @"\n";
			
			// We've got some input: perform it
			[self stopReceiving];
			
			[zMachine inputText: nextInput];
			[self orInputCharacter: nextInput];
			historyPos = [commandHistory count];
		}
	} else if (receiving && [inputSource respondsToSelector: @selector(nextCommand)]) {
		NSString* nextInput = [inputSource nextCommand];
		
		if (nextInput == nil) {
			// End of input
			if (delegate && [delegate respondsToSelector: @selector(inputSourceHasFinished:)]) {
				[delegate inputSourceHasFinished: inputSource];
			}
			
			[inputSource release];
			inputSource = nil;
		} else {
			nextInput = [nextInput stringByAppendingString: @"\n"];
			
			// We've got some input: write it, perform it
			[self stopReceiving];
			
			// FIXME: maybe do this in the current style? (At least this way, it's obvious what's come from where)
			ZStyle* inputStyle = [[[ZStyle alloc] init] autorelease];
			[inputStyle setUnderline: YES];
			[inputStyle setBold: YES];
			[inputStyle setBackgroundColour: 7];
			[inputStyle setForegroundColour: 4];
			
			[focusedView writeString: nextInput
						   withStyle: inputStyle];
			
			[commandHistory addObject: nextInput];
			
			[zMachine inputText: nextInput];
			[self orInputCommand: nextInput];
			historyPos = [commandHistory count];
		}
	}
}

- (void) removeInputSource: (id) source {
	if (source == inputSource) {
		[inputSource release];
		inputSource = nil;
	}
}

// = Resources =

- (void) setResources: (ZoomBlorbFile*) res {
	if (resources) [resources release];
	resources = [res retain];
}

- (ZoomBlorbFile*) resources {
	return resources;
}

- (BOOL) containsImageWithNumber: (int) number {
	if (resources == nil) return NO;
		
	return [resources containsImageWithNumber: number];
}

- (NSSize) sizeOfImageWithNumber: (int) number {
	return [resources sizeForImageWithNumber: number
							   forPixmapSize: [pixmapWindow size]];
	NSImage* img = [resources imageWithNumber: number];
	
	if (img != nil) {
		return [img size];
	} else {
		return NSMakeSize(0,0);
	}
}

// = Terminating characters =

- (void) setTerminatingCharacters: (NSSet*) termChars {
	if (terminatingChars) [terminatingChars release];
	
	terminatingChars = [termChars copy];
}

- (NSSet*) terminatingCharacters {
	return terminatingChars;
}


// = Dealing with the history =

- (NSString*) lastHistoryItem {
	int oldPos = historyPos;
	
	historyPos--;
				
	if (historyPos < 0) historyPos = 0;
	if (historyPos > [commandHistory count]) historyPos = [commandHistory count];

	if (historyPos == oldPos) return nil;

	if (historyPos < [commandHistory count]) {
		return [commandHistory objectAtIndex: historyPos];
	} else {
		return nil;
	}
}

- (NSString*) nextHistoryItem {
	int oldPos = historyPos;
				
	historyPos++;
				
	if (historyPos < 0) historyPos = 0;
	if (historyPos > [commandHistory count]) historyPos = [commandHistory count];
	
	if (historyPos == oldPos) return nil;
	
	if (historyPos < [commandHistory count]) {
		return [commandHistory objectAtIndex: historyPos];
	} else {
		return nil;
	}
}

- (ZoomTextToSpeech*) textToSpeech {
	if (!textToSpeechReceiver) {
		textToSpeechReceiver = [[ZoomTextToSpeech alloc] init];
		[self addOutputReceiver: textToSpeechReceiver];
	}
	return textToSpeechReceiver;
}

// = Accessibility=

- (NSString *)accessibilityActionDescription: (NSString*) action {
	return [super accessibilityActionDescription:  action];
}

- (NSArray *)accessibilityActionNames {
	return [super accessibilityActionNames];
}

- (BOOL)accessibilityIsAttributeSettable:(NSString *)attribute {
	return [super accessibilityIsAttributeSettable: attribute];;
}

- (void)accessibilityPerformAction:(NSString *)action {
	[super accessibilityPerformAction: action];
}

- (void)accessibilitySetValue: (id)value
				 forAttribute: (NSString*) attribute {
	// No settable attributes
	[super accessibilitySetValue: value
					forAttribute: attribute];
}

- (NSArray*) accessibilityAttributeNames {
	NSMutableArray* result = [[super accessibilityAttributeNames] mutableCopy];
	
	[result addObjectsFromArray:[NSArray arrayWithObjects: 
								 NSAccessibilityChildrenAttribute,
								 nil]];
	
	return [result autorelease];
}

- (id)accessibilityAttributeValue:(NSString *)attribute {
	if ([attribute isEqualToString: NSAccessibilityChildrenAttribute]) {
		return [NSArray arrayWithObjects: [textScroller upperWindowView], textView, nil];
	} else if ([attribute isEqualToString: NSAccessibilityRoleDescriptionAttribute]) {
		return [NSString stringWithFormat: @"Zoom view"];
	} else if ([attribute isEqualToString: NSAccessibilityRoleAttribute]) {
		return NSAccessibilityUnknownRole;
	} else if ([attribute isEqualToString: NSAccessibilityFocusedAttribute]) {
		NSView* viewResponder = (NSView*)[[self window] firstResponder];
		if ([viewResponder isKindOfClass: [NSView class]]) {
			while (viewResponder != nil) {
				if (viewResponder == self) return [NSNumber numberWithBool: YES];
				
				viewResponder = [viewResponder superview];
			}
		}
		
		return [NSNumber numberWithBool: NO];
	} else if ([attribute isEqualToString: NSAccessibilityParentAttribute]) {
		//return nil;
	}
	
	return [super accessibilityAttributeValue: attribute];
}

- (BOOL)accessibilityIsIgnored {
	return YES;
}
		 
@end
