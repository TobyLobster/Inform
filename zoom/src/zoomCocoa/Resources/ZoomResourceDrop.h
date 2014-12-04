//
//  ZoomResourceDrop.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Jul 28 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface ZoomResourceDrop : NSView {
	NSString* droppedFilename;
	NSData*   droppedData;
	
	int willOrganise;
	BOOL enabled;
	
	IBOutlet id delegate;
}

// Flags
- (void) setWillOrganise: (BOOL) willOrganise;
- (BOOL) willOrganise;

- (void) setEnabled: (BOOL) enabled;
- (BOOL) enabled;

- (void) setDroppedFilename: (NSString*) filename;
- (NSString*) droppedFilename;

// Delegate
- (void) setDelegate: (id) delegate;

@end

// Delegate methods
@interface NSObject(ZoomResourceDropDelegate)

- (void) resourceDropFilenameChanged: (ZoomResourceDrop*) drop;
- (void) resourceDropDataChanged: (ZoomResourceDrop*) drop;

@end
