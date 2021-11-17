//
//  GlkWindow.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 19/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#ifndef __GLKVIEW_GLKWINDOW_H__
#define __GLKVIEW_GLKWINDOW_H__

#import <GlkView/GlkViewDefinitions.h>
#if defined(COCOAGLK_IPHONE)
# import <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

#import <GlkView/GlkStreamProtocol.h>
#import <GlkView/GlkSessionProtocol.h>

#import <GlkView/GlkEvent.h>
#import <GlkView/GlkPreferences.h>
#import <GlkView/GlkStyle.h>

@class GlkPairWindow;
@class GlkView;

///
/// Class that represents a Glk window
///
@interface GlkWindow : NSView<GlkStream> {
	/// The pair window that contains this window (or NULL for the root window) !NOT RETAINED!
	__weak GlkPairWindow* parentWindow;
	
	/// \c YES if this window is closed
	BOOL closed;
	/// The window's unique identifier number (shared with the client)
	unsigned windowIdentifier;
	
	/// Active stream style
	int style;
	/// Whether or not we should always use fixed-pitch and size fonts
	BOOL forceFixed;
	
	/// Border
	CGFloat border;
	/// The scale factor to use
	CGFloat scaleFactor;
	
	// Styles
	/// Preferences defines things like fonts
	GlkPreferences* preferences;
	/// Maps style numbers to GlkStyle objects
	NSDictionary* styles;
	/// The immediate style as set by the user
	GlkStyle* immediateStyle;
	/// The custom attributes to merge with the current style
	NSDictionary* customAttributes;
	
	// Hyperlinks
	/// Object defining the current hyperlink
	NSObject* linkObject;
	
	// These event variables are useful to subclasses
	/// Where the events go !NOT RETAINED!
	__weak id<GlkEventReceiver> target;
	/// \c YES if we're receiving character input
	BOOL charInput;
	/// \c YES if we're receiving text input
	BOOL lineInput;
	/// \c YES if we're receiving mouse input
	BOOL mouseInput;
	/// \c YES if we're receiving hyperlink input
	BOOL hyperlinkInput;
	
	/// The view that contains this window !NOT RETAINED!
	__weak GlkView* containingView;
	
	/// The last known size of this window
	GlkSize lastSize;
}

/// Given a string from a keyboard event, returns the associated Glk keycode
+ (unsigned) keycodeForString: (NSString*) string;
/// Given a keyboard event, produces the associated Glk keycode
+ (unsigned) keycodeForEvent: (NSEvent*) evt;

/// Closed windows can hang around
@property BOOL closed;

// Window metadata
/// The unique window identifier, (shared with and assigned by the client)
/// Sometimes we need to know this
@property unsigned glkIdentifier;

// Layout
/// If the layout has changed, then update/redraw this window
- (void) layoutInRect: (NSRect) parentRect;
/// Meaning depends on the window format. Returns the preferred size in pixels
- (CGFloat) widthForFixedSize: (unsigned) size;
/// Meaning depends on the window format. Returns the preferred size in pixels
- (CGFloat) heightForFixedSize: (unsigned) size;

/// The border around the window's contents
@property CGFloat border;

/// Size of the content, taking the border into account
@property (readonly) NSRect contentRect;
/// Size in window units
@property (readonly) GlkSize glkSize;

/// Sets the scale factor for this window
@property (nonatomic) CGFloat scaleFactor;

// Styles
/// Whether or not we're currently forcing fixed fonts
@property BOOL forceFixed;

/// Maps style numbers to GlkStyles
- (void) setStyles: (NSDictionary<NSNumber*,GlkStyle*>*) styles;
/// Retrieves a specific style
- (GlkStyle*) style: (unsigned) style;
/// Gets the attributes to use for a specific style
- (NSDictionary<NSAttributedStringKey, id>*) attributes: (unsigned) style;

/// Sets a style hint with immediate effect (glk extension)
- (void) setImmediateStyleHint: (glui32) hint
					   toValue: (glsi32) value;
/// Clears a style hint with immediate effect (glk extension)
- (void) clearImmediateStyleHint: (glui32) hint;
/// Sets some custom attributes to merge with those from the current style
- (void) setCustomAttributes: (NSDictionary*) customAttributes;

/// Sets the \c GlkPreferences object to use for fonts.
- (void) setPreferences: (GlkPreferences*) prefs;
/// Force a reformat of this window (call when the preferences change, for example)
- (void) reformat;

/// The base proportional font we're using
- (NSFont*) proportionalFont;
/// The base fixed-pitch font we're using
- (NSFont*) fixedFont;

/// The background colour for this window
- (NSColor*) backgroundColour;

/// The amount of leading to use
@property (readonly) CGFloat leading;
/// Height of a line in the current font
@property (readonly) CGFloat lineHeight;

/// The attributes for the currently active style
- (NSDictionary<NSAttributedStringKey, id>*) currentTextAttributes;

// Cursor positioning
/// Not supported for most window styles
- (void) moveCursorToXposition: (int) xpos
					 yPosition: (int) ypos;

// Window control
/// Does whatever is appropriate for the window type
- (void) clearWindow;

/// Sets the target for any events this window generates !NOT RETAINED!
@property (nonatomic, weak) id<GlkEventReceiver> eventTarget;

- (void) requestCharInput;
/// Request that the window generate the appropriate events
- (void) requestLineInput;

- (void) requestMouseInput;
- (void) requestHyperlinkInput;

- (void) cancelCharInput;
/// Request that the window stop generating these events
- (NSString*) cancelLineInput;

- (void) cancelMouseInput;
- (void) cancelHyperlinkInput;

/// Sets the input text to a given pre-defined value
- (void) setInputLine: (NSString*) inputLine;
/// Forces this window to act on the specified input string as if it had been entered by the user
- (void) forceLineInput: (NSString*) forcedInput;

/// Returns \c YES if this window is waiting for line input
@property (readonly) BOOL waitingForLineInput;
/// Returns \c YES if this window is waiting for character input
@property (readonly) BOOL waitingForCharInput;
/// Returns \c YES if this window is waiting for keyboard input
@property (readonly) BOOL waitingForKeyboardInput;
/// Returns \c YES if this window is waiting for keyboard input for user interaction with the running story
@property (readonly) BOOL waitingForUserKeyboardInput;
/// The control that responds to events for this window
- (NSResponder*) windowResponder;

/// Called just before the buffer flushes (mostly used to tell the text windows to wait before performing layout)
- (void) bufferIsFlushing;
/// Called once the buffer has finished flushing
- (void) bufferHasFlushed;

/// The text position beyond which input is possible
@property (nonatomic, readonly) NSInteger inputPos;
/// Called on a key down event, to give this view a chance to set the caret position appropriately
- (void) updateCaretPosition;

/// If YES, then this view is showing a [ MORE ] prompt and may need paging
@property (readonly) BOOL needsPaging;
/// Perform paging
- (void) page;

/// Select has been called: make the cancelled/requested state 'fixed'
- (void) fixInputStatus;

/// The glk task has finished: tidy up time
- (void) taskFinished;

// The parent window
/// The parent window !NOT RETAINED!
@property (readwrite, nonatomic, weak) GlkPairWindow *parent;

// The containing view
/// The GlkView that contains this window !NOT RETAINED!
@property (readwrite, nonatomic, weak) GlkView *containingView;

@end

#endif
