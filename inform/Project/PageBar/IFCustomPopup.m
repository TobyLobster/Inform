//
//  IFCustomPopup.m
//  Inform-xc2
//
//  Created by Andrew Hunter on 22/08/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

// TODO: wheel scrolling still works while the popup is visible (it shouldn't)

#import "IFCustomPopup.h"

static IFCustomPopup* shownPopup = nil;

// = Custom view interfaces used by this class =

@interface IFPopupContentView : NSView {
}

- (IBAction) closePopup: (id) sender;

@end

// = The main event =
@implementation IFCustomPopup

// = General methods =

+ (void) closeAllPopups {
	if (shownPopup != nil) {
		[shownPopup hidePopup];
	}
}

+ (void) closeAllPopupsWithSender: (id) sender {
	if (shownPopup != nil) {
		[shownPopup closePopup: sender];
	}
}

// = Initialisation =

- (id) init {
	self = [super init];
	
	if (self) {
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(applicationDidResignActive:)
													 name: NSApplicationDidResignActiveNotification
												   object: nil];				
	}
	
	return self;
}

- (void) dealloc {
	[IFCustomPopup closeAllPopups];
	
	[popupView release];
	[popupWindow release];
	[lastCloseValue autorelease];
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	[super dealloc];
}

// = Setting up =

- (void) setPopupView: (NSView*) newPopupView {
	if (popupView != nil) {
		[[NSNotificationCenter defaultCenter] removeObserver: self
														name: NSViewFrameDidChangeNotification
													  object: popupView];
	}

	[popupView release];
	popupView = [newPopupView retain];
	
	[popupView setPostsFrameChangedNotifications: YES];
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(popupViewFrameChanged:)
												 name: NSViewFrameDidChangeNotification
											   object: popupView];
}

- (void) setDelegate: (id) newDelegate {
	delegate = newDelegate;
}

// = Getting down =

- (BOOL) isPopup {
	return YES;
}

- (void) hidePopup {
	[popupWindow orderOut: self];
	
	[self setHighlighted: NO];
	[self update];
	
	if (shownPopup == self) {
		[shownPopup release];
		shownPopup = nil;
	}
}

- (void) popupViewFrameChanged: (NSNotification*) not {
	if ([not object] != popupView) return;
	if (![popupWindow isVisible]) return;
	
	// Calculate the popup window position
	NSScreen* currentScreen = [[[self controlView] window] screen];
	NSRect screenFrame = [currentScreen frame];

	NSSize windowSize = [popupView frame].size;

	NSRect windowFrame;
	windowFrame.size = windowSize;
	
	windowFrame.origin = openPosition;
	
	windowFrame.origin.y -= windowFrame.size.height;
	
	// Move back onscreen (left/right)
	float offscreenRight = NSMaxX(windowFrame) - NSMaxX(screenFrame);
	float offscreenLeft = NSMinX(screenFrame) - NSMinX(windowFrame);
	
	if (offscreenRight > 0) windowFrame.origin.x -= offscreenRight;
	if (offscreenLeft > 0) windowFrame.origin.x += offscreenLeft;
	
	// Move back onscreen (bottom)
	float offscreenBottom = NSMinY(screenFrame) - NSMinY(windowFrame);
	if (offscreenBottom > 0) windowFrame.origin.y += offscreenBottom;
	
	// Position the window
	[popupWindow setFrame: windowFrame
				  display: YES];
}

- (void) showPopupAtPoint: (NSPoint) pointInWindow {
	// Close any open popups
	[[self class] closeAllPopups];
	
	[shownPopup release];
	shownPopup = [self retain];
	
	// Talk to the delegate
	if (delegate && [delegate respondsToSelector: @selector(customPopupOpening:)]) {
		[delegate customPopupOpening: self];
	}
	
	// Get the current screen
	NSScreen* currentScreen = [[[self controlView] window] screen];
	NSRect screenFrame = [currentScreen frame];
	
	// Not a lot we can do if the control is not visible
	if (currentScreen == nil) return;
	
	// Create the windows if they do not already exist
	if (popupWindow == nil) {
		// Construct the windows
		popupWindow = [[NSPanel alloc] initWithContentRect: NSMakeRect(0,0, 100, 100)
												 styleMask: NSBorderlessWindowMask
												   backing: NSBackingStoreBuffered
													 defer: NO];
		[popupWindow setWorksWhenModal: YES];
		
		// Set up the popup window
		IFPopupContentView* contentView = [[IFPopupContentView alloc] initWithFrame: [[popupWindow contentView] frame]];
		[popupWindow setContentView: contentView];
		
		[popupWindow setLevel: NSPopUpMenuWindowLevel];
		[popupWindow setHasShadow: YES];
		[popupWindow setHidesOnDeactivate: YES];
		[popupWindow setAlphaValue: 0.95];
	}
	
	// Set up the content window view
	IFPopupContentView* contentView	 = [popupWindow contentView];
	[contentView setAutoresizesSubviews: NO];
	
	[[[[contentView subviews] copy] autorelease] makeObjectsPerformSelector: @selector(removeFromSuperview)];
	
	NSSize windowSize = [contentView frame].size;
	if (popupView != nil) {
		// Set the content view
		[contentView addSubview: popupView];
		
		// Get the size we need to set the window to
		windowSize = [popupView frame].size;
		
		// Move the popup view so that it is displayed
		[popupView setFrameOrigin: [contentView bounds].origin];
	}
	
	// Set the cell state
	[self setHighlighted: YES];
	[self update];
	
	// Get the control position
	NSPoint windowOrigin = [[[self controlView] window] frame].origin;
	
	// Calculate the popup window position
	NSRect windowFrame;
	windowFrame.size = windowSize;
	
	windowFrame.origin = pointInWindow;
	windowFrame.origin.x += windowOrigin.x;
	windowFrame.origin.y += windowOrigin.y;
	windowFrame.origin.y += 4;
	
	openPosition = windowFrame.origin;
	
	windowFrame.origin.y -= windowFrame.size.height;
	
	// Move back onscreen (left/right)
	float offscreenRight = NSMaxX(windowFrame) - NSMaxX(screenFrame);
	float offscreenLeft = NSMinX(screenFrame) - NSMinX(windowFrame);
	
	if (offscreenRight > 0) windowFrame.origin.x -= offscreenRight;
	if (offscreenLeft > 0) windowFrame.origin.x += offscreenLeft;
	
	// Move back onscreen (bottom)
	float offscreenBottom = NSMinY(screenFrame) - NSMinY(windowFrame);
	if (offscreenBottom > 0) windowFrame.origin.y += offscreenBottom;
	
	// Position the window
	[popupWindow setFrame: windowFrame
				  display: NO];
	
	// Display the windows
	[popupWindow makeKeyAndOrderFront: self];
	
	unichar escape = 27;
	NSString* escapeString = [NSString stringWithCharacters: &escape
													 length: 1];
	
	// Run modally until it's time to close the window
	// This is not true modal behaviour: however, we're not acting like a modal dialog and want to do some
	// weird stuff with the events.
	// TODO: annoyingly, we don't seem to be able to intercept main menu open events, which mucks things up a bit
	NSModalSession ses = [NSApp beginModalSessionForWindow: popupWindow];
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	while (shownPopup == self) {
		[pool release];
		pool = [[NSAutoreleasePool alloc] init];
		
		NSEvent* ev = 
			[NSApp nextEventMatchingMask: NSAnyEventMask
							   untilDate: [NSDate distantFuture]
								  inMode: NSEventTrackingRunLoopMode
								 dequeue: YES];
		
		if (([ev type] == NSKeyDown ||
					[ev type] == NSKeyUp) &&
				   [[ev characters] isEqualToString: escapeString]) {
			// Escape pressed
			break;
		} else if (([ev type] == NSKeyDown ||
					[ev type] == NSKeyUp)) {
			// Redirect any key events to the popup window [TODO: direct this properly]
			ev = [NSEvent keyEventWithType: [ev type]
								  location: [ev locationInWindow]
							 modifierFlags: [ev modifierFlags]
								 timestamp: [ev timestamp]
							  windowNumber: [popupWindow windowNumber]
								   context: nil
								characters: [ev characters]
			   charactersIgnoringModifiers: [ev charactersIgnoringModifiers]
								 isARepeat: [ev isARepeat]
								   keyCode: [ev keyCode]];
			
			if ([ev type] == NSKeyDown) {
				[popupView keyDown: ev];
			} else if ([ev type] == NSKeyUp) {
				[popupView keyUp: ev];
			}
			ev = nil;
		} else if (([ev type] == NSLeftMouseDown ||
					[ev type] == NSRightMouseDown ||
					[ev type] == NSOtherMouseDown ||
					[ev type] == NSScrollWheel) &&
				   [ev window] != popupWindow) {
			// Click outside of the window
			if ([ev type] != NSLeftMouseDown ||
				![NSApp isActive]) {
				[NSApp sendEvent: ev];
			}
			break;
		}
		
		// Pass the event through
		if (ev != nil) [NSApp sendEvent: ev];
	}
	[NSApp endModalSession: ses];
	
	// TODO: if the last event was a mouse down event, loop until we get the mouse up
	// TODO: send a mouse up event directed at this control (or something; we have a problem where if we close the control by clicking on the close button of a window, then we click the close button again, the control pops up again!)

	// Finish up
	[pool release];
	[self hidePopup];
}

- (IBAction) closePopup: (id) sender {
	[self hidePopup];
	
	[lastCloseValue release];
	lastCloseValue = [sender retain];
	
	if ([self target] != nil) {
		// For some reason (modality?), the standard action dispatch isn't working here, so do things the hard way
		if ([[self target] respondsToSelector: [self action]]) {
			[[self target] performSelector: [self action]
								withObject: self];
		}
	} else {
		[(NSControl*)[self controlView] sendAction: [self action]
											 to: [self target]];
	}
}

- (id) lastCloseValue {
	return lastCloseValue;
}

- (void) mouseDragged: (NSEvent*) evt {
	// TODO: offer this event to objects in the popup view
}

- (void) mouseUp: (NSEvent*) evt {
	// TODO: only actually close the popup if the mouse up event was outside the popup view, otherwise forward the event on
	//[self hidePopup];
}

- (void) applicationDidResignActive: (NSNotification*) not {
	// Abort any active popup when the application stops being active
	[[self class] closeAllPopups];
}

@end

// = Custom view implementations =

@implementation IFPopupContentView

- (BOOL) isFlipped { return YES; }

- (IBAction) closePopup: (id) sender {
	if (shownPopup) [shownPopup closePopup: sender];
}

@end
