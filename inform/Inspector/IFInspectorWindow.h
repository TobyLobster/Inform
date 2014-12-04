//
//  IFInspectorWindow.h
//  Inform
//
//  Created by Andrew Hunter on Thu Apr 29 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "IFInspector.h"

@class IFInspectorView;

//
// The window controller for the window that contains the inspectors
//
@interface IFInspectorWindow : NSWindowController<NSWindowDelegate> {
	NSMutableDictionary* inspectorDict;							// The dictionary of inspectors (maps inspector keys to inspectors)
	
	NSMutableArray* inspectors;									// The list of inspectors
	NSMutableArray* inspectorViews;								// The list of inspector views
	
	BOOL updating;												// YES if we're in the middle of updating
	
	// The main window
	BOOL newMainWindow;											// Flag that indicates if we've processed a new main window event yet
	NSWindow* activeMainWindow;									// The 'main window' that we're inspecting
	
	// Whether or not the main window should pop up when inspectors suddenly show up
	BOOL hidden;												// YES if the inspector window is currently offscreen (because, for example, none of the inspectors are returning yes to [available])
	BOOL shouldBeShown;											// YES if the inspector window should be shown again (ie, the window was closed because there was nothing to show, not because the user dismissed it)
	
	// List of most/least recently shown inspectors
	NSMutableArray* shownInspectors;							// Array of inspectors in the order that the user asked for them
}

// The shared instance
+ (IFInspectorWindow*) sharedInspectorWindow;					// The application-wide inspector controller

// Dealing with inspector views
- (void) addInspector: (IFInspector*) newInspector;				// Adds a new inspector to this window

- (void) setInspectorState: (BOOL) shown						// Sets whether or not a particular inspector should be displayed (expanded)
					forKey: (NSString*) key;
- (BOOL) inspectorStateForKey: (NSString*) key;					// Returns YES if a particular inspector is displayed (expanded)

- (void) showInspector: (IFInspector*) inspector;				// Shows a specific inspector
- (void) showInspectorWithKey: (NSString*) key;					// Shows an inspector with a specific key
- (void) hideInspector: (IFInspector*) inspector;				// Hides a specific inspector
- (void) hideInspectorWithKey: (NSString*) key;					// Hides an inspector with a specific key

// Dealing with updates
- (void) updateInspectors;										// Updates the layout of the inspectors (ie, rearranges shown/hidden inspectors, resizes the window, etc)
- (NSWindow*) activeWindow;										// Returns the 'active' window, which is usually the same as Cocoa's main window

- (void) inspectorViewDidChange: (IFInspectorView*) view		// Inspector views can call this to indicate they should be expanded/shrunk
						toState: (BOOL) expanded;

// Status
- (BOOL) isHidden;												// Returns YES if the window is not currently onscreen for some reason
- (bool) isInform7ProjectActive;

@end
