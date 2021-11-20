//
//  IFInspector.h
//  Inform
//
//  Created by Andrew Hunter on Thu Apr 29 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class IFInspectorWindow;

///
/// Definition of an individual inspector: inspectors should subclass this and hook up the
/// 'inspectorView' outlet in their nibs.
///
@interface IFInspector : NSObject

@property (atomic, strong, nullable) IBOutlet NSView *inspectorView;

// Notifications from the inspector controller
/// Called when the key window changes. Subclasses should override this to reflect the new window.
- (void) inspectWindow: (NSWindow*) newWindow;

// Inspector details
/// The title for this inspector.
@property (atomic, copy, null_resettable) NSString *title;
/// \c YES if the inspector is expanded (visible)
@property (atomic) BOOL expanded;
/// Should be overridden by subclasses. Returns \c YES if the inspector is available in the current context. Normally this is dependant on the type of window being inspected.
@property (atomic, readonly) BOOL available;
/// The unique key string for this inspector. Must be overridden by subclasses, must be unique.
@property (atomic, readonly, copy) NSString *key;

// The controller
/// Sets the window controller that will own this inspector
- (void) setInspectorWindow: (IFInspectorWindow*) window;

@end

NS_ASSUME_NONNULL_END
