//
//  ZoomInputLine.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Jun 26 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZoomCursor.h"

@interface ZoomInputLine : NSObject

- (instancetype) initWithCursor: (ZoomCursor*) cursor
		   attributes: (NSDictionary*) attr NS_DESIGNATED_INITIALIZER;

- (void) drawAtPoint: (NSPoint) point;
@property (NS_NONATOMIC_IOSONLY, readonly) NSSize size;
- (NSRect) rectForPoint: (NSPoint) point;

- (void) keyDown: (NSEvent*) evt;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *inputLine;

@property (NS_NONATOMIC_IOSONLY, assign) id delegate;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *lastHistoryItem;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *nextHistoryItem;

- (void) updateCursor;

@end

@interface NSObject(ZoomInputLineDelegate)

- (void) inputLineHasChanged: (ZoomInputLine*) sender;
- (void) endOfLineReached: (ZoomInputLine*) sender;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *lastHistoryItem;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *nextHistoryItem;

@end
