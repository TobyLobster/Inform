//
//  IFSkeinLayoutItem.m
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import "IFSkeinLayoutItem.h"
#import "IFSkeinConstants.h"
#import "IFSkeinView.h"
#import "IFSkeinItemView.h"
#import "IFSkeinItem.h"

@implementation IFSkeinLayoutItem {
    IFSkeinItem*    item;
    BOOL            onSelectedLine;
    BOOL            recentlyPlayed;
    CGFloat         subtreeWidth;
    int             level;
    int             depth;
}

@synthesize parent;
@synthesize children;
@synthesize commandWidth;
@synthesize boundingRect;
@synthesize item;
@synthesize subtreeWidth;
@synthesize level;
@synthesize depth;
@synthesize onSelectedLine;
@synthesize recentlyPlayed;

#pragma mark -  Initialisation

- (instancetype) init {
	return [self initWithItem: nil
                 subtreeWidth: 0
						level: 0];
}

- (instancetype) initWithItem: (IFSkeinItem*) newItem
                 subtreeWidth: (CGFloat) newSubtreeWidth
                        level: (int) newLevel {
	self = [super init];
	
	if (self) {
		item = newItem;
		subtreeWidth = newSubtreeWidth;
		level = newLevel;
		depth = 0;
        commandWidth = [IFSkeinItemView commandSize: self].width;
	}
	
	return self;
}

#pragma mark -  Getting properties

- (CGFloat) visibleWidth {
	return 20.0 + self.commandWidth;
}

#pragma mark -  Setting properties

- (void) setChildren: (NSArray*) newChildren {
	children = [newChildren copy];
	
	int maxDepth = -1;
    for( IFSkeinLayoutItem* child in children ) {
		maxDepth = MAX(maxDepth, [child depth]);
	}

	depth = maxDepth+1;
}

- (void) moveRightBy: (CGFloat) deltaX
         recursively: (BOOL) recursively {
    // Update bounding rect
    NSRect newBounds = self.boundingRect;
    newBounds.origin.x = floor(newBounds.origin.x + deltaX);
    self.boundingRect = newBounds;

    // Move children by the same amount
    if( recursively ) {
        for( IFSkeinLayoutItem* item2 in self.children ) {
            [item2 moveRightBy: deltaX recursively: YES];
        }
    }
}

- (NSRect) lozengeRect {
    NSRect itemRect = self.boundingRect;

    // Adjust bounding rectangle inwards to give the lozenge rectangle
    itemRect.origin.x += kSkeinItemImageLeftBorder;
    itemRect.origin.y += itemRect.size.height - kSkeinItemImageHeight + kSkeinItemImageTopBorder;
    itemRect.size.width  -= kSkeinItemImageLeftBorder + kSkeinItemImageRightBorder + kSkeinItemFrameWidthExtension;
    itemRect.size.height -= kSkeinItemImageTopBorder + kSkeinItemImageBottomBorder;
    return itemRect;
}

- (NSRect) localSpaceLozengeRect {
    NSRect rect = self.lozengeRect;
    // lozengeRect is in the IFSkeinView coordinate space, which is measured from the top-left (isFlipped=YES).
    // We convert the lozengeRect to our local (IFSkeinItemView) space, which is measured from the bottom-left (isFlipped=NO).
    return NSMakeRect( rect.origin.x - boundingRect.origin.x,
                       boundingRect.size.height - (rect.origin.y - boundingRect.origin.y) - rect.size.height,
                       rect.size.width,
                       rect.size.height);
}


- (NSRect) textRect {
    NSRect itemRect = self.lozengeRect;

    CGFloat width = self.commandWidth;

    // Adjust the lozenge width to just include the text area
    itemRect.origin.x += 15.0;
    itemRect.size.width = width;

    return itemRect;
}

- (CGFloat) centreX {
    return NSMidX(self.lozengeRect);
}

-(IFSkeinLayoutItem*) selectedLineChild {
    for( IFSkeinLayoutItem* child in self.children ) {
        if( child.onSelectedLine ) {
            return child;
        }
    }
    return nil;
}

- (IFSkeinLayoutItem*) leafSelectedLineItem {
    // Find leaf node
    IFSkeinLayoutItem* leafItem = self;
    while(leafItem.onSelectedLine) {
        IFSkeinLayoutItem* childItem = leafItem.selectedLineChild;
        if( childItem == nil ) {
            return leafItem;
        }
        leafItem = childItem;
    }
    return nil;
}

/// Calculate a hash based on the current state. We only redraw when the stateHash changes.
-(NSUInteger) drawStateHash {
    NSUInteger hash = item.command.hash;
    hash ^= recentlyPlayed      ? 1 : 0;
    hash ^= onSelectedLine      ? 2 : 0;
    hash ^= item.hasBadge       ? 4 : 0;
    hash ^= item.isTestSubItem  ? 8 : 0;
    hash ^= ((unsigned long) (10 * [IFSkeinView fontSize])) << 4;

    return hash;
}

@end
