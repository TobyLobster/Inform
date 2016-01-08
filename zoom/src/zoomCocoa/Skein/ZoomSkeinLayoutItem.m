//
//  ZoomSkeinLayoutItem.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 08/01/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "ZoomSkeinLayoutItem.h"

static const float minItemWidth = 50.0f;

@implementation ZoomSkeinLayoutItem

// = Initialisation =

- (instancetype) init {
	return [self initWithItem: nil
                 commandWidth: 0.0f
              annotationWidth: 0.0f
					fullWidth: 0
						level: 0];
}

- (instancetype) initWithItem: (ZoomSkeinItem*) newItem
                 commandWidth: (float) newCommandWidth
              annotationWidth: (float) newAnnotationWidth
                    fullWidth: (float) newFullWidth
                        level: (int) newLevel {
	self = [super init];
	
	if (self) {
		item = [newItem retain];
        _annotationWidth = newAnnotationWidth;
        _commandWidth = newCommandWidth;
		fullWidth = newFullWidth;
		level = newLevel;
		depth = 0;
	}
	
	return self;
}

- (void) dealloc {
	if (item) [item release];
	if (children) [children release];
	
	[super dealloc];
}

// = Getting properties =

- (ZoomSkeinItem*) item {
	return item;
}

- (float) combinedWidth {
	return MAX(MAX(minItemWidth, self.commandWidth), self.annotationWidth);
}

- (float) fullWidth {
	return fullWidth;
}

- (float) position {
	return position;
}

- (NSArray*) children {
	return children;
}

- (int)	level {
	return level;
}

- (BOOL) onSkeinLine {
	return onSkeinLine;
}

- (int) depth {
	return depth;
}

- (BOOL) recentlyPlayed {
	return recentlyPlayed;
}

// = Setting properties =

- (void) setItem: (ZoomSkeinItem*) newItem {
	if (item) [item release];
	item = [newItem retain];
}

- (void) setFullWidth: (float) newFullWidth {
	fullWidth = newFullWidth;
}

- (void) setPosition: (float) newPosition {
	position = newPosition;
}

- (void) setChildren: (NSArray*) newChildren {
	if (children) [children release];
	children = [newChildren retain];
	
	int maxDepth = -1;
	NSEnumerator* childEnum = [children objectEnumerator];
	ZoomSkeinLayoutItem* child;
	
	while (child = [childEnum nextObject]) {
		if ([child depth] > maxDepth) maxDepth = [child depth];
	}
	
	depth = maxDepth+1;
}

- (void) setLevel: (int) newLevel {
	level = newLevel;
}

- (void) setOnSkeinLine: (BOOL) online {
	onSkeinLine = online;
}

- (void) setRecentlyPlayed: (BOOL) played {
	recentlyPlayed = played;
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
		NSEnumerator* childEnum = [children objectEnumerator];
		ZoomSkeinLayoutItem* child;
		
		while (child = [childEnum nextObject]) {
			[child findItemsOnLevel: findLevel
							 result: result];
		}
	}
}

- (NSArray*) itemsOnLevel: (int) findLevel {
	NSMutableArray* result = [NSMutableArray array];
	
	[self findItemsOnLevel: findLevel
					result: result];
	
	return result;
}

- (void) moveRightBy: (float) deltaX
         recursively: (BOOL) recursively {
    [self setPosition: [self position] + deltaX];
    
    if( recursively ) {
        for( ZoomSkeinLayoutItem* item2 in [self children] ) {
            [item2 moveRightBy: deltaX recursively: YES];
        }
    }
}

@end
