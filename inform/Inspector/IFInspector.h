//
//  IFInspector.h
//  Inform
//
//  Created by Andrew Hunter on Thu Apr 29 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

@class IFInspectorWindow;

//
// Definition of an individual inspector: inspectors should subclass this and hook up the 
// 'inspectorView' outlet in their nibs.
//
@interface IFInspector : NSObject {
	IBOutlet NSView* inspectorView;								// The view that contains the inspector
	
	NSString* title;											// The title of this inspector
	
	IFInspectorWindow* inspectorWin;							// The window controller that contains this inspector
}

// Setting the view to use
- (void) setInspectorView: (NSView*) view;						// Sets the inspector view
- (NSView*) inspectorView;										// Retrieves the inspector view

// Notifications from the inspector controller
- (void) inspectWindow: (NSWindow*) newWindow;					// Called when the key window changes. Subclasses should override this to reflect the new window.

// Inspector details
- (void) setTitle: (NSString*) title;							// Sets the title for this inspector.
- (NSString*) title;											// Retrieves the title for this inspector.

- (void) setExpanded: (BOOL) expanded;							// Sets whether or not the inspector is expanded (shown). Non-expanded inspectors are concertinaed down.
- (BOOL) expanded;												// YES if the inspector is expanded (visible)

- (BOOL) available;												// Should be overridden by subclasses. Returns YES if the inspector is available in the current context. Normally this is dependant on the type of window being inspected.

// (Should be overridden by subclasses). The unique key for this inspector.
- (NSString*) key;												// The key string for this inspector. Must be overridden by subclasses, must be unique.

// The controller
- (void) setInspectorWindow: (IFInspectorWindow*) window;		// Sets the window controller that will own this inspector

@end

// (IFInspectorWindow #imports us, and has priority)
#import "IFInspectorWindow.h"
