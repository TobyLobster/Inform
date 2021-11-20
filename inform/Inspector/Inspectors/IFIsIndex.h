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

extern NSString* const IFIsIndexInspector;

///
/// Dynamic or XML (depending on preferences) index inspector
///
@interface IFIsIndex : IFInspector<NSOutlineViewDataSource>

/// Retrieves the shared index inspector
+ (IFIsIndex*) sharedIFIsIndex;

/// Updates the index from a specific window controller (to have an index, it must be a ProjectController)
- (void) updateIndexFrom: (NSWindowController*) window;

@end
