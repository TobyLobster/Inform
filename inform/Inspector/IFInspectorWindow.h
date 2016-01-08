//
//  IFInspectorWindow.h
//  Inform
//
//  Created by Andrew Hunter on Thu Apr 29 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

@class IFInspectorView;
@class IFInspector;

//
// The window controller for the window that contains the inspectors
//
@interface IFInspectorWindow : NSWindowController<NSWindowDelegate>

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
@property (atomic, readonly, strong) NSWindow *activeWindow;										// Returns the 'active' window, which is usually the same as Cocoa's main window

- (void) inspectorViewDidChange: (IFInspectorView*) view		// Inspector views can call this to indicate they should be expanded/shrunk
						toState: (BOOL) expanded;

// Status
@property (atomic, getter=isHidden, readonly) BOOL hidden;		// Returns YES if the window is not currently onscreen for some reason
@property (atomic, getter=isInform7ProjectActive, readonly) bool inform7ProjectActive;

@end
