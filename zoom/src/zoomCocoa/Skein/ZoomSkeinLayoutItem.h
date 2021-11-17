//
//  ZoomSkeinLayoutItem.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 08/01/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ZoomView/ZoomSkeinItem.h>

NS_ASSUME_NONNULL_BEGIN

//! A 'laid-out' skein item
//!
//! Originally I used an NSDictionary to represent this. Unfortunately, Cocoa spends a huge amount of time
//! creating, allocating and deallocating these. Thus, I replaced it with a dedicated object.
//!
//! The performance increase is especially noticable with well-populated skeins
@interface ZoomSkeinLayoutItem : NSObject

// Initialisation

- (instancetype) init;
- (instancetype) initWithItem: (nullable ZoomSkeinItem*) item
						width: (CGFloat) width
					fullWidth: (CGFloat) fullWidth
						level: (int) level NS_DESIGNATED_INITIALIZER;

// Setting/getting properties

@property (strong, nullable) ZoomSkeinItem *item;
@property CGFloat width;
@property CGFloat fullWidth;
@property CGFloat position;
@property (nonatomic, strong) NSArray<ZoomSkeinLayoutItem*> *children;
@property int level;
@property BOOL onSkeinLine;
@property BOOL recentlyPlayed;
@property (readonly) NSInteger depth;

- (NSArray<ZoomSkeinLayoutItem*>*) itemsOnLevel: (int) level;

@end

NS_ASSUME_NONNULL_END
