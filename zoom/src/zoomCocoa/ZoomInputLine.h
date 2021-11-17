//
//  ZoomInputLine.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Jun 26 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <ZoomView/ZoomCursor.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ZoomInputLineDelegate;

@interface ZoomInputLine : NSObject

- (id) initWithCursor: (ZoomCursor*) cursor
		   attributes: (NSDictionary<NSAttributedStringKey, id>*) attr;

- (void) drawAtPoint: (NSPoint) point;
@property (readonly) NSSize size;
- (NSRect) rectForPoint: (NSPoint) point;

- (void) keyDown: (NSEvent*) evt;

@property (readonly, copy) NSString *inputLine;

@property (weak) id<ZoomInputLineDelegate> delegate;

@property (readonly, copy, nullable) NSString *lastHistoryItem;
@property (readonly, copy, nullable) NSString *nextHistoryItem;

- (void) updateCursor;

@end

@protocol ZoomInputLineDelegate <NSObject>
@optional

- (void) inputLineHasChanged: (ZoomInputLine*) sender;
- (void) endOfLineReached: (ZoomInputLine*) sender;

@property (nonatomic, readonly, copy, nullable) NSString *lastHistoryItem;
@property (nonatomic, readonly, copy, nullable) NSString *nextHistoryItem;

@end

NS_ASSUME_NONNULL_END
