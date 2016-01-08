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
	float		   fullWidth;
	float		   position;
	NSArray*	   children;
	int			   level;
	int			   depth;
}

// Initialisation

- (instancetype) initWithItem: (ZoomSkeinItem*) item
                 commandWidth: (float) newCommandWidth
              annotationWidth: (float) newAnnotationWidth
                    fullWidth: (float) fullWidth
                        level: (int) level NS_DESIGNATED_INITIALIZER;

// Setting/getting properties

@property (NS_NONATOMIC_IOSONLY, strong) ZoomSkeinItem *item;
@property (NS_NONATOMIC_IOSONLY) float commandWidth;
@property (NS_NONATOMIC_IOSONLY) float annotationWidth;
@property (NS_NONATOMIC_IOSONLY) float fullWidth;
@property (NS_NONATOMIC_IOSONLY) float position;
@property (NS_NONATOMIC_IOSONLY, copy) NSArray *children;
@property (NS_NONATOMIC_IOSONLY) int level;
@property (NS_NONATOMIC_IOSONLY) BOOL onSkeinLine;
@property (NS_NONATOMIC_IOSONLY) BOOL recentlyPlayed;
@property (NS_NONATOMIC_IOSONLY, readonly) int depth;


- (NSArray*) itemsOnLevel: (int) level;
- (void) moveRightBy: (float) deltaX
         recursively: (BOOL) recursively;
- (float) combinedWidth;

@end
