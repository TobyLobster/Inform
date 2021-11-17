//
//  ZoomResourceDrop.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Jul 28 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>


@protocol ZoomResourceDropDelegate;

@interface ZoomResourceDrop : NSView <NSDraggingDestination> {
	NSString* droppedFilename;
	NSData*   droppedData;
	
	int willOrganise;
	BOOL enabled;
}

// Flags
@property BOOL willOrganise;

@property (nonatomic, getter=isEnabled) BOOL enabled;

@property (copy) NSString *droppedFilename;

/// Delegate
@property (weak) IBOutlet id<ZoomResourceDropDelegate> delegate;

@end

// Delegate methods
@protocol ZoomResourceDropDelegate <NSObject>
@optional

- (void) resourceDropFilenameChanged: (ZoomResourceDrop*) drop;
- (void) resourceDropDataChanged: (ZoomResourceDrop*) drop;

@end
