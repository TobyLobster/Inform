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

///
/// The window controller for the window that contains the inspectors
///
@interface IFInspectorWindow : NSWindowController<NSWindowDelegate>

// The shared instance
/// The application-wide inspector controller
+ (IFInspectorWindow*) sharedInspectorWindow;
@property (class, readonly, strong) IFInspectorWindow *sharedInspectorWindow;

// Dealing with inspector views
/// Adds a new inspector to this window
- (void) addInspector: (IFInspector*) newInspector;

/// Sets whether or not a particular inspector should be displayed (expanded)
- (void) setInspectorState: (BOOL) shown
					forKey: (NSString*) key;
/// Returns \c YES if a particular inspector is displayed (expanded)
- (BOOL) inspectorStateForKey: (NSString*) key;

/// Shows a specific inspector
- (void) showInspector: (IFInspector*) inspector;
/// Shows an inspector with a specific key
- (void) showInspectorWithKey: (NSString*) key;
/// Hides a specific inspector
- (void) hideInspector: (IFInspector*) inspector;
/// Hides an inspector with a specific key
- (void) hideInspectorWithKey: (NSString*) key;

// Dealing with updates
/// Updates the layout of the inspectors (ie, rearranges shown/hidden inspectors, resizes the window, etc)
- (void) updateInspectors;
/// Returns the 'active' window, which is usually the same as Cocoa's main window
@property (atomic, readonly, strong) NSWindow *activeWindow;

/// Inspector views can call this to indicate they should be expanded/shrunk
- (void) inspectorViewDidChange: (IFInspectorView*) view
						toState: (BOOL) expanded;

// Status
/// Returns \c YES if the window is not currently onscreen for some reason
@property (atomic, getter=isHidden, readonly) BOOL hidden;
@property (atomic, getter=isInform7ProjectActive, readonly) bool inform7ProjectActive;

@end
