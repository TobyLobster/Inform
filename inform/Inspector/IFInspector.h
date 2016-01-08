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
@interface IFInspector : NSObject

@property (atomic, strong) NSView *inspectorView;

// Notifications from the inspector controller
- (void) inspectWindow: (NSWindow*) newWindow;      // Called when the key window changes. Subclasses should override this to reflect the new window.

// Inspector details                                // Sets the title for this inspector.
@property (atomic, copy) NSString *title;           // Retrieves the title for this inspector.
@property (atomic) BOOL expanded;                   // YES if the inspector is expanded (visible)
@property (atomic, readonly) BOOL available;        // Should be overridden by subclasses. Returns YES if the inspector is available in the current context. Normally this is dependant on the type of window being inspected.
@property (atomic, readonly, copy) NSString *key;	// The unique key string for this inspector. Must be overridden by subclasses, must be unique.

// The controller
- (void) setInspectorWindow: (IFInspectorWindow*) window;		// Sets the window controller that will own this inspector

@end
