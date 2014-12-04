//
//  GlkTextWindow.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 20/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <GlkView/GlkWindow.h>
#import <GlkView/GlkTextView.h>
#import <GlkView/GlkTypesetter.h>

@interface GlkTextWindow : GlkWindow<NSTextStorageDelegate, NSTextViewDelegate> {
	NSScrollView* scrollView;							// The scroller for the text view
	GlkTextView* textView;								// The inner text view
	GlkTypesetter* typesetter;							// The typesetter we should use for laying out images and other Glk-specific things
	NSLayoutManager* layoutManager;						// The layout manager
	NSTextStorage* textStorage;							// The text storage
	
	int inputPos;										// The position in the text view that the game-supplied text ends, and the user-supplied text begins
	float margin;										// The size of the margin for this window
	
	NSMutableString* inputBuffer;						// The input data
	
	BOOL flushing;										// YES if the buffer is flushing
	
	BOOL willMakeEditable;								// YES if a request to make the text editable is pending
	BOOL willMakeNonEditable;							// YES if a request to make the text non-editable is pending
	
	BOOL hasMorePrompt;									// YES if this window has a more prompt
	int moreOffset;										// The character that should be the first on the current 'page'
	float lastMorePos;									// The last y position a [ MORE ] prompt appeared
	float nextMorePos;									// The y position that the next [ MORE ] prompt should appear at
	
	NSWindow* moreWindow;								// The window containing the [ MORE ] prompt
	NSDate* whenMoreShown;								// The time that the [ MORE ] prompt was shown
	float lastMoreState;								// Initial state of the [ MORE ] prompt
	float finalMoreState;								// Final state fo the [ MORE ] prompt
	NSTimer* moreAnimationTimer;						// Timer for the [ MORE ] animation
}

- (void) setupTextview;									// Initialise the text view and typesetters

- (void) addImage: (NSImage*) image						// Adds an image at the end of this view
	withAlignment: (unsigned) alignment
			 size: (NSSize) sz;
- (void) addFlowBreak;									// Adds a flow break at the end of this view

- (void) makeTextEditable;								// Requests that the text buffer view be made editable (ie, ready for command input), takes account of buffering issues
- (void) makeTextNonEditable;							// Requests that the text buffer view be made non-editable, takes account of buffering issues

- (void) setUsesMorePrompt: (BOOL) useMorePrompt;		// Sets whether or not a [ MORE ] prompt should be displayed for this window
- (void) setInfiniteSize;								// Sets this window to be infinite size
- (float) currentMoreState;								// The current [ MORE ] animation state (0 = hidden, 1 = shown)
- (void) displayMorePromptIfNecessary;					// A request to display the [ MORE ] prompt if necessary
- (void) setMoreShown: (BOOL) shown;					// Sets whether or not the [ MORE ] prompt is shown
- (void) resetMorePrompt: (int) pos						// Resets the [ MORE ] prompt position from the specified character position
				  paging: (BOOL) paging;
- (void) resetMorePrompt;								// Resets the [ MORE ] prompt position from the current input position
- (void) scrollToEnd;									// Scroll to the end of the text view

@end
