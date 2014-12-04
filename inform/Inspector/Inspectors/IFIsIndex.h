//
//  IFIsIndex.h
//  Inform
//
//  Created by Andrew Hunter on Fri May 07 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>

#import "IFInspector.h"

extern NSString* IFIsIndexInspector;

//
// Dynamic or XML (depending on preferences) index inspector
//
@interface IFIsIndex : IFInspector<NSOutlineViewDataSource> {
	IBOutlet NSOutlineView* indexList;						// The outline view that will contain the index
	
	BOOL canDisplay;										// YES if there's an index to display
	NSWindow* activeWindow;									// Currently active window
	
	NSMutableArray* itemCache;								// Cache of items retrieved from the index (used because the index can update before the display)
}

+ (IFIsIndex*) sharedIFIsIndex;								// Retrieves the shared index inspector

- (void) updateIndexFrom: (NSWindowController*) window;		// Updates the index from a specific window controller (to have an index, it must be a ProjectController)

@end
