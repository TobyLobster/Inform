//
//  ZoomSkeinLayoutItem.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 08/01/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

//
// A 'laid-out' skein item
//
// Originally I used an NSDictionary to represent this. Unfortunately, Cocoa spends a huge amount of time
// creating, allocating and deallocating these. Thus, I replaced it with a dedicated object.
//
// The performance increase is especially noticable with well-populated skeins
//

#import "ZoomSkeinItem.h"

@interface ZoomSkeinLayoutItem : NSObject {
	ZoomSkeinItem* item;
	BOOL		   onSkeinLine;
	BOOL		   recentlyPlayed;
	float          width;
	float		   fullWidth;
	float		   position;
	NSArray*	   children;
	int			   level;
	int			   depth;
}

// Initialisation

- (id) initWithItem: (ZoomSkeinItem*) item
			  width: (float) width
		  fullWidth: (float) fullWidth
			  level: (int) level;

// Setting/getting properties

- (ZoomSkeinItem*) item;
- (float)		   width;
- (float)		   fullWidth;
- (float)		   position;
- (NSArray*)	   children;
- (int)			   level;
- (BOOL)		   onSkeinLine;
- (BOOL)		   recentlyPlayed;
- (int)			   depth;

- (void) setItem: (ZoomSkeinItem*) newItem;
- (void) setWidth: (float) newWidth;
- (void) setFullWidth: (float) newFullWidth;
- (void) setPosition: (float) newPosition;
- (void) setChildren: (NSArray*) newChildren;
- (void) setLevel: (int) newLevel;
- (void) setOnSkeinLine: (BOOL) onSkeinLine;
- (void) setRecentlyPlayed: (BOOL) recentlyPlayed;

- (NSArray*) itemsOnLevel: (int) level;
- (void) moveRightBy: (float) deltaX
         recursively: (BOOL) recursively;

@end
