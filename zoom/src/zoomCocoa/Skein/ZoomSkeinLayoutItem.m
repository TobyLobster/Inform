//
//  ZoomSkeinLayoutItem.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 08/01/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "ZoomSkeinLayoutItem.h"


@implementation ZoomSkeinLayoutItem

#pragma mark - Initialisation

- (id) init {
	return [self initWithItem: nil
						width: 0
					fullWidth: 0
						level: 0];
}

- (id) initWithItem: (ZoomSkeinItem*) newItem
			  width: (CGFloat) newWidth
		  fullWidth: (CGFloat) newFullWidth
			  level: (int) newLevel {
	self = [super init];
	
	if (self) {
		item = newItem;
		width = newWidth;
		fullWidth = newFullWidth;
		level = newLevel;
		depth = 0;
	}
	
	return self;
}

#pragma mark - Getting properties

@synthesize item;
@synthesize width;
@synthesize fullWidth;
@synthesize position;
@synthesize children;
@synthesize level;
@synthesize onSkeinLine;
@synthesize depth;
@synthesize recentlyPlayed;

#pragma mark - Setting properties

- (void) setChildren: (NSArray*) newChildren {
	children = newChildren;
	
	NSInteger maxDepth = -1;
	
	for (ZoomSkeinLayoutItem* child in children) {
		if ([child depth] > maxDepth) maxDepth = [child depth];
	}
	
	depth = maxDepth+1;
}

- (void) findItemsOnLevel: (int) findLevel
				   result: (NSMutableArray*) result {
	if (findLevel < level) return;
	
	if (findLevel == level) {
		[result addObject: self];
		return;
	} else if (findLevel == level-1) {
		if (children) [result addObjectsFromArray: children];
		return;
	} else if (children) {
		for (ZoomSkeinLayoutItem* child in children) {
			[child findItemsOnLevel: findLevel
							 result: result];
		}
	}
}

- (NSArray*) itemsOnLevel: (int) findLevel {
	NSMutableArray* result = [NSMutableArray array];
	
	[self findItemsOnLevel: findLevel
					result: result];
	
	return [result copy];
}

@end
