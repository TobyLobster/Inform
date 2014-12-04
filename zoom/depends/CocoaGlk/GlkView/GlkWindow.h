//
//  GlkWindow.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 19/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "GlkStreamProtocol.h"
#import "GlkSessionProtocol.h"

#import <GlkView/GlkEvent.h>
#import <GlkView/GlkPreferences.h>
#import <GlkView/GlkStyle.h>

@class GlkPairWindow;
@class GlkView;

//
// Class that represents a Glk window
//
@interface GlkWindow : NSView<GlkStream> {
	GlkPairWindow* parentWindow;								// The pair window that contains this window (or NULL for the root window) !NOT RETAINED!
	
	BOOL closed;												// YES if this window is closed
	unsigned windowIdentifier;									// The window's unique identifier number (shared with the client)
	
	int style;													// Active stream style
	BOOL forceFixed;											// Whether or not we should always use fixed-pitch and size fonts
	
	float border;												// Border
	float scaleFactor;											// The scale factor to use
	
	// Styles
	GlkPreferences* preferences;								// Preferences defines things like fonts
	NSDictionary* styles;										// Maps style numbers to GlkStyle objects
	GlkStyle* immediateStyle;									// The immediate style as set by the user
	NSDictionary* customAttributes;								// The custom attributes to merge with the current style
	
	// Hyperlinks
	NSObject* linkObject;										// Object defining the current hyperlink
	
	// These event variables are useful to subclasses
	NSObject<GlkEventReceiver>* target;							// Where the events go !NOT RETAINED!
	BOOL charInput;												// YES if we're receiving character input
	BOOL lineInput;												// YES if we're receiving text input
	BOOL mouseInput;											// YES if we're receiving mouse input
	BOOL hyperlinkInput;										// YES if we're receiving hyperlink input
	
	GlkView* containingView;									// The view that contains this window !NOT RETAINED!
	
	GlkSize lastSize;											// The last known size of this window
}

+ (unsigned) keycodeForString: (NSString*) string;				// Given a string from a keyboard event, returns the associated Glk keycode
+ (unsigned) keycodeForEvent: (NSEvent*) evt;					// Given a keyboard event, produces the associated Glk keycode

// Closed windows can hang around
- (void) setClosed: (BOOL) closed;
- (BOOL) closed;

// Window metadata
- (void) setIdentifier: (unsigned) windowIdentifier;			// Sometimes we need to know this

- (unsigned) identifier;										// The unique window identifier, (shared with and assigned by the client)

// Layout
- (void) layoutInRect: (NSRect) parentRect;						// If the layout has changed, then update/redraw this window
- (float) widthForFixedSize: (unsigned) size;					// Meaning depends on the window format. Returns the preferred size in pixels
- (float) heightForFixedSize: (unsigned) size;					// Meaning depends on the window format. Returns the preferred size in pixels

- (void) setBorder: (float) border;								// Sets the border around the window's contents
- (float) border;												// Retrieves the border width

- (NSRect) contentRect;											// Size of the content, taking the border into account
- (GlkSize) glkSize;											// Size in window units

- (void) setScaleFactor: (float) scaleFactor;					// Sets the scale factor for this window

// Styles
- (void) setForceFixed: (BOOL) forceFixed;						// Force use of fixed pitch fonts
- (BOOL) forceFixed;											// Whether or not we're currently forcing fixed fonts

- (void) setStyles: (NSDictionary*) styles;						// Maps style numbers to GlkStyles
- (GlkStyle*) style: (unsigned) style;							// Retrieves a specific style
- (NSDictionary*) attributes: (unsigned) style;					// Gets the attributes to use for a specific style

- (void) setImmediateStyleHint: (glui32) hint					// Sets a style hint with immediate effect (glk extension)
					   toValue: (glsi32) value;
- (void) clearImmediateStyleHint: (glui32) hint;				// Clears a style hint with immediate effect (glk extension)
- (void) setCustomAttributes: (NSDictionary*) customAttributes;	// Sets some custom attributes to merge with those from the current style

- (void) setPreferences: (GlkPreferences*) prefs;				// Sets the GlkPreferences object to use for fonts
- (void) reformat;												// Force a reformat of this window (call when the preferences change, for example)

- (NSFont*) proportionalFont;									// The base proportional font we're using
- (NSFont*) fixedFont;											// The base fixed-pitch font we're using

- (NSColor*) backgroundColour;									// The background colour for this window

- (float) leading;												// The amount of leading to use
- (float) lineHeight;											// Height of a line in the current font

- (NSDictionary*) currentTextAttributes;						// The attributes for the currently active style

// Cursor positioning
- (void) moveCursorToXposition: (int) xpos						// Not supported for most window styles
					 yPosition: (int) ypos;

// Window control
- (void) clearWindow;											// Does whatever is appropriate for the window type

- (void) setEventTarget: (NSObject<GlkEventReceiver>*) target;	// Sets the target for any events this window generates !NOT RETAINED!

- (void) requestCharInput;
- (void) requestLineInput;										// Request that the window generate the appropriate events
- (void) requestMouseInput;
- (void) requestHyperlinkInput;

- (void) cancelCharInput;
- (NSString*) cancelLineInput;									// Request that the window stop generating these events
- (void) cancelMouseInput;
- (void) cancelHyperlinkInput;

- (void) setInputLine: (NSString*) inputLine;					// Sets the input text to a given pre-defined value
- (void) forceLineInput: (NSString*) forcedInput;				// Forces this window to act on the specified input string as if it had been entered by the user

- (BOOL) waitingForLineInput;									// Returns YES if this window is waiting for line input
- (BOOL) waitingForCharInput;									// Returns YES if this window is waiting for character input
- (BOOL) waitingForKeyboardInput;								// Returns YES if this window is waiting for keyboard input
- (BOOL) waitingForUserKeyboardInput;							// Returns YES if this window is waiting for keyboard input for user interaction with the running story
- (NSResponder*) windowResponder;								// The control that responds to events for this window

- (void) bufferIsFlushing;										// Called just before the buffer flushes (mostly used to tell the text windows to wait before performing layout)
- (void) bufferHasFlushed;										// Called once the buffer has finished flushing

- (int) inputPos;												// The text position beyond which input is possible
- (void) updateCaretPosition;									// Called on a key down event, to give this view a chance to set the caret position appropriately

- (BOOL) needsPaging;											// If YES, then this view is showing a [ MORE ] prompt and may need paging
- (void) page;													// Perform paging

- (void) fixInputStatus;										// Select has been called: make the cancelled/requested state 'fixed'

- (void) taskFinished;											// The glk task has finished: tidy up time

// The parent window
- (void) setParent: (GlkPairWindow*) parent;					// Sets the parent window !NOT RETAINED!
- (GlkPairWindow*) parent;

// The containing view
- (GlkView*) containingView;									// The GlkView that contains this window
- (void) setContainingView: (GlkView*) view;					// Sets the GlkView that contains this window !NOT RETAINED!

@end

#import <GlkView/GlkPairWindow.h>
#import <GlkView/GlkView.h>
