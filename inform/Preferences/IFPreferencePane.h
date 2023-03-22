//
//  IFPreferencePane.h
//  Inform
//
//  Created by Andrew Hunter on 01/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>


///
/// Class that represents a specific preference pane in the preferences window
///
@interface IFPreferencePane : NSObject

- (instancetype) init NS_DESIGNATED_INITIALIZER;
/// Initialises and loads the given nib
- (instancetype) initWithNibName: (NSString*) nibName NS_DESIGNATED_INITIALIZER;

// Information about the preference window
/// The image that should show up in the toolbar
@property (atomic, readonly, copy) NSImage *toolbarImage;
/// The name of this pane (appears under the toolbar item)
@property (atomic, readonly, copy) NSString *preferenceName;
/// The unique identifier for this pane (subclasses don't need to override this)
@property (atomic, readonly, copy) NSToolbarItemIdentifier identifier;
/// The tooltip for this preference
@property (atomic, readonly, copy) NSString *tooltip;
/// The view that describes the UI for this preference pane
@property (atomic, readwrite, strong) IBOutlet NSView *preferenceView;

@property (atomic, readonly) CGFloat maxHeight;
@property (atomic, readonly) CGFloat minHeight;

@end
