//
//  ZoomInputLine.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Jun 26 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZoomCursor.h"

@interface ZoomInputLine : NSObject {
	ZoomCursor* cursor;
	
	NSObject* delegate;
	
	NSMutableString* lineString;
	NSMutableDictionary* attributes;
	int				 insertionPos;
}

- (id) initWithCursor: (ZoomCursor*) cursor
		   attributes: (NSDictionary*) attr;

- (void) drawAtPoint: (NSPoint) point;
- (NSSize) size;
- (NSRect) rectForPoint: (NSPoint) point;

- (void) keyDown: (NSEvent*) evt;

- (NSString*) inputLine;

- (void) setDelegate: (id) delegate;
- (id)   delegate;

- (NSString*) lastHistoryItem;
- (NSString*) nextHistoryItem;

- (void) updateCursor;

@end

@interface NSObject(ZoomInputLineDelegate)

- (void) inputLineHasChanged: (ZoomInputLine*) sender;
- (void) endOfLineReached: (ZoomInputLine*) sender;

- (NSString*) lastHistoryItem;
- (NSString*) nextHistoryItem;

@end
