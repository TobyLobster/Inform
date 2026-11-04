//
//  IFSkeinLayout.m
//  Inform
//
//  Created by Toby Nelson 2015
//

#import "IFSkeinLayout.h"
#import "IFSkeinItem.h"
#import "IFSkeinItemView.h"
#import "IFSkeinLayoutItem.h"
#import "IFSkeinConstants.h"

@implementation IFSkeinLayout {
    // The layout
    IFSkeinLayoutItem*      treeRoot;
    NSMutableArray*         levels;
    NSMutableArray*         levelWidths;
    NSMutableArray*         levelYs;
    NSMutableArray *        levelArray;

    CGFloat                 shiftRightForReportOffsetX;
}

@synthesize rootItem            = _rootItem;
@synthesize activeItem          = _activeItem;
@synthesize selectedItem        = _selectedItem;
@synthesize rootLayoutItem      = _rootLayoutItem;
@synthesize activeLayoutItem    = _activeLayoutItem;
@synthesize selectedLayoutItem  = _selectedLayoutItem;

#pragma mark - Initialisation

- (instancetype) init {
	return [self initWithRootItem: nil];
}

- (instancetype) initWithRootItem: (IFSkeinItem*) item {
	self = [super init];

	if (self) {
		_rootItem        = item;
        _reportPosition  = NSMakePoint(0.0f, 0.0f);
        shiftRightForReportOffsetX = 0.0f;
	}

	return self;
}

#pragma mark - Setting skein data

-(void) setRecentlyPlayedItems {
    // Mark everything upwards of the active item as played
    IFSkeinLayoutItem* layoutItem = _activeLayoutItem;
    while (layoutItem != nil) {
        [layoutItem setRecentlyPlayed: YES];
        layoutItem = layoutItem.parent;
    }
}

-(void) clearOnSelectedLine:(IFSkeinLayoutItem *) root {
    root.onSelectedLine = NO;
    for( IFSkeinLayoutItem* child in root.children ) {
        [self clearOnSelectedLine: child];
    }
}

- (void) setSelectedLineItems {
	// Update the set of items that use the 'transcript line' style

	// Clear the items that are currently marked as highlighted
    [self clearOnSelectedLine: treeRoot];

	// Iterate up from the highlighted item
	IFSkeinLayoutItem* layoutItem = _selectedLayoutItem;
	
	while (layoutItem != nil) {
		// Store this item
		[layoutItem setOnSelectedLine: YES];

		// Up the tree
		layoutItem = layoutItem.parent;
	}

	// Iterate down from the highlighted item, so long as there is only one child item
	layoutItem = _selectedLayoutItem;

	while (layoutItem.children.count > 0) {
		// Move down the tree
		layoutItem = layoutItem.children[0];
		
		// Store this item
        layoutItem.onSelectedLine = YES;
	}
}

#pragma mark - Getting layout data

- (int) levels {
	return (int) levels.count;
}

#pragma mark - Item positioning data

- (int) levelAtViewPosY: (CGFloat) viewPosY {
    viewPosY -= kSkeinTopBorder;

    for( int level = 0; level < levels.count; level++ ) {
        if( viewPosY < [levelYs[level+1] doubleValue] ) {
            return level;
        }
    }
    return (int) levels.count;
}

- (NSRange) rangeOfLevelsBetweenMinViewY: (CGFloat) minY
                             andMaxViewY: (CGFloat) maxY {
    // Which levels (rows) do we need to look through?
    int startLevel = [self levelAtViewPosY:minY] - 1;
    int endLevel = [self levelAtViewPosY:maxY];

    // Bound the start and end levels
    startLevel = MAX(0, startLevel);
    endLevel   = MIN(endLevel, self.levels-1);

    // Sanity check
    if( endLevel < startLevel ) {
        NSAssert(false, @"rangeOfLevelsBetweenMinViewY:andMaxViewY: bad range of levels");
        endLevel = startLevel;
    }

    return NSMakeRange(startLevel, endLevel-startLevel);
}


- (IFSkeinItem*) itemAtPoint: (NSPoint) point {
	// Searches for the item that is under the given point

	// Check for level
	int level = [self levelAtViewPosY: point.y];
	if (level < 0 || level >= levels.count) return nil;

    for( IFSkeinLayoutItem* layoutItem in levels[level] ) {
        if( NSPointInRect( point, layoutItem.lozengeRect) ) {
			return layoutItem.item;
		}
	}

	// Nothing found
	return nil;
}

- (NSSize) size {	
	if (treeRoot) {
		NSSize res;

		res.width = treeRoot.subtreeWidth + shiftRightForReportOffsetX + kSkeinRightBorder;
        CGFloat treeHeight = 0.0f;
        if( levels.count > 0 ) {
            treeHeight = [levelYs[levels.count] doubleValue];
        }
        res.height = treeHeight + kSkeinTopBorder + kSkeinBottomBorder;

		return res;
	} else {
		return NSMakeSize(0,0);
	}
}

#pragma mark - Packing

- (void) layoutSkein {
    // 'Best Fit' packing style
	levels       = [[NSMutableArray alloc] init];
	levelWidths  = [[NSMutableArray alloc] init];
    levelYs      = nil;
    _activeLayoutItem = nil;
    _selectedLayoutItem = nil;
    _rootLayoutItem = nil;

    // Create the tree of layout nodes
	treeRoot = [self layoutSkeinCreateLayoutTree: _rootItem
                                       withLevel: 0];

    // Mark everything upwards of the active item as recently played, and set the highlighted line
    [self setRecentlyPlayedItems];
    [self setSelectedLineItems];

    // Align all layout items to the left
    [self layoutSkeinItemAlignLeft: treeRoot
                         withLevel: 0];

    // Run the best fit algorithm
    [self layoutSkeinItemBestFit: treeRoot];

    // Work out the subtree width of each node
    [self layoutSkeinCalculateSubtreeWidth: treeRoot];

    // Clear out levelWidths, since it is only used while laying out
    levelWidths = nil;
}

-(CGFloat) currentLevelWidth:(int) level {
    // Make sure we have enough levels
    while( levelWidths.count <= level ) {
        [levelWidths addObject:@0.0f];
    }
    return [levelWidths[level] floatValue];
}

- (IFSkeinLayoutItem*) layoutSkeinCreateLayoutTree: (IFSkeinItem*) item
                                         withLevel: (int) level {
	if (item == nil) {
        return nil;
    }

    IFSkeinLayoutItem* result = [[IFSkeinLayoutItem alloc] initWithItem: item
                                                           subtreeWidth: 1.0f
                                                                  level: level];
    result.commandWidth = [IFSkeinItemView commandSize: result].width;
    result.parent = nil;

    if( item == _activeItem ) {
        _activeLayoutItem = result;
    }
    if( item == _selectedItem ) {
        _selectedLayoutItem = result;
    }
    if( item == _rootItem ) {
        _rootLayoutItem = result;
    }

	NSMutableArray* children = [[NSMutableArray alloc] init];

    // Create layout tree, recursively
	for( IFSkeinItem* child in item.children ) {
        IFSkeinLayoutItem* childItem = [self layoutSkeinCreateLayoutTree: child
                                                               withLevel: level+1];
        childItem.parent = result;
		[children addObject: childItem];
    }
    result.children = children;

	// Add to the 'levels' array, which contains the items to draw at each level
	while (level >= levels.count) {
		[levels addObject: [NSMutableArray array]];
	}
	[levels[level] addObject: result];

    return result;
}

- (void) layoutSkeinItemAlignLeft: (IFSkeinLayoutItem*) layoutItem
                        withLevel: (int) level {
	if (layoutItem == nil) {
        return;
    }

    // Align items to the left edge (DFS)
	for( IFSkeinLayoutItem* child in layoutItem.children ) {
        [self layoutSkeinItemAlignLeft: child
                             withLevel: level+1];
    }

    CGFloat currentLevelWidth = [self currentLevelWidth: level];

    // Set initial rectangle
    NSRect itemRect;
    itemRect.origin.x   = floor(kSkeinLeftBorder - kSkeinItemImageLeftBorder + currentLevelWidth);
    itemRect.origin.y   = floor((CGFloat)layoutItem.level * kSkeinMinLevelHeight + kSkeinTopBorder);

    itemRect.size.width  = kSkeinItemImageCommandLeftBorder + layoutItem.commandWidth + kSkeinItemImageCommandRightBorder + kSkeinItemFrameWidthExtension;
    itemRect.size.height = kSkeinItemFrameHeight;

    itemRect = NSIntegralRect(itemRect);

    layoutItem.boundingRect = itemRect;

    currentLevelWidth += layoutItem.visibleWidth + kSkeinItemPadding;

    levelWidths[level] = @(currentLevelWidth);
}

- (void) moveRemainingItemsRightAfter: (IFSkeinLayoutItem*) item
                              onLevel: (int) levelIndex
                                   by: (CGFloat) deltaX
                          recursively: (BOOL) recursively {
    // Move remaining items at this level right
    BOOL found = NO;
    NSMutableArray* level = levelArray[levelIndex];
    for( IFSkeinLayoutItem* item2 in level ) {
        if( item2 == item ) {
            found = YES;
        }
        if( found ) {
            [item2 moveRightBy: deltaX
                   recursively: recursively];
        }
    }
}

- (void) layoutSkeinItemBestFit: (IFSkeinLayoutItem*) startItem {
	if (startItem == nil) {
        return;
    }

    NSMutableArray *queue   = [[NSMutableArray alloc] initWithObjects: startItem, nil];
    levelArray              = [[NSMutableArray alloc] initWithObjects: [NSMutableArray arrayWithObject: startItem], nil];

    // Create a queue - each item, from the top to the bottom, left to right (BFS)
    while (queue.count > 0) {
        IFSkeinLayoutItem * itemQ = queue[0];

        for ( IFSkeinLayoutItem *childItem in itemQ.children ) {
            // Add to queue
            [queue addObject: childItem];
            
            // Add to levels
            while( levelArray.count <= childItem.level ) {
                [levelArray addObject: [NSMutableArray array]];
            }
            [levelArray[childItem.level] addObject: childItem];
        }
        [queue removeObjectAtIndex: 0];
    }

    // Visit each level, from the bottom to the top, left to right
    for( NSArray* level in [levelArray reverseObjectEnumerator] ) {
        for( IFSkeinLayoutItem* layoutItem in level ) {
            if(!layoutItem.onSelectedLine) {
                // We are not on the selected line
                // If we are a parent, centre the parent between it's children
                if( layoutItem.children.count > 0 ) {
                    CGFloat parentx = layoutItem.centreX;
                    
                    // Find centre of all children
                    CGFloat minx = CGFLOAT_MAX;
                    CGFloat maxx = -CGFLOAT_MAX;
                    for( IFSkeinLayoutItem* item2 in layoutItem.children ) {
                        minx = MIN(minx, NSMidX(item2.lozengeRect));
                        maxx = MAX(maxx, NSMidX(item2.lozengeRect));
                    }
                    CGFloat centreChildrenX = (minx + maxx)/2;
                    CGFloat deltaX;
                    
                    if( parentx < centreChildrenX ) {
                        // Move parent right to centre under children
                        deltaX = centreChildrenX - parentx;
                        
                        // Move remaining items at this level right
                        [self moveRemainingItemsRightAfter: layoutItem
                                                   onLevel: layoutItem.level
                                                        by: deltaX
                                               recursively: NO];
                    } else if( parentx > centreChildrenX ) {
                        deltaX = parentx - centreChildrenX;

                        // Move the first child right to align under parent, and all remaining
                        // items on that level, and any of their children by the same amount
                        [self moveRemainingItemsRightAfter: layoutItem.children[0]
                                                   onLevel: layoutItem.level + 1
                                                        by: deltaX
                                               recursively: YES];
                    }
                }
            }
            else {
                // We are on the selected line. Arrange in a straight line.
                CGFloat parentx = layoutItem.centreX;

                // Find child's centre point
                IFSkeinLayoutItem* selectedLineChild = layoutItem.selectedLineChild;
                if( selectedLineChild ) {
                    CGFloat centreChildrenX = selectedLineChild.centreX;
                    CGFloat deltaX;

                    if( parentx < centreChildrenX ) {
                        // Move parent right to centre under children
                        deltaX = centreChildrenX - parentx;

                        // Move remaining items at this level right
                        [self moveRemainingItemsRightAfter: layoutItem
                                                   onLevel: layoutItem.level
                                                        by: deltaX
                                               recursively: NO];
                    } else if( parentx > centreChildrenX ) {
                        deltaX = parentx - centreChildrenX;

                        // Move the first child right to align under parent, and all remaining
                        // items on that level, and any of their children by the same amount
                        [self moveRemainingItemsRightAfter: layoutItem.children[0]
                                                   onLevel: layoutItem.level + 1
                                                        by: deltaX
                                               recursively: YES];
                    }
                }
            }
        }
    }

    queue = nil;

    // We are done with the level arrays now... only used while laying out.
    levelArray = nil;
}

- (CGFloat) layoutSkeinCalculateSubtreeWidth: (IFSkeinLayoutItem*) layoutItem {
	if (layoutItem == nil) {
        return 0.0f;
    }
    
    // DFS
    CGFloat furthestRightX = 0.0f;
	for( IFSkeinLayoutItem* child in layoutItem.children ) {
        CGFloat childFurthestRightX = [self layoutSkeinCalculateSubtreeWidth: child];
        furthestRightX = MAX(furthestRightX, childFurthestRightX);
    }
    
    furthestRightX = MAX(NSMaxX(layoutItem.lozengeRect), furthestRightX);
    layoutItem.subtreeWidth = furthestRightX;
    return furthestRightX;
}

-(IFSkeinLayoutItem*) itemClosestBeyondX:(CGFloat) minX root:(IFSkeinLayoutItem*) layoutItem {
    IFSkeinLayoutItem* result = nil;
    CGFloat bestX = CGFLOAT_MAX;

    CGFloat x = NSMinX(layoutItem.boundingRect);
    if( x > minX ) {
        bestX = x;
        result = layoutItem;
    }

    for(IFSkeinLayoutItem* child in layoutItem.children ) {
        IFSkeinLayoutItem* childResult = [self itemClosestBeyondX: minX root: child];
        if( childResult ) {
            CGFloat childX = NSMinX(childResult.boundingRect);
            if( childX < bestX ) {
                result = childResult;
                bestX = childX;
            }
        }
    }

    return result;
}


-(void) expandTreeVertically:(IFSkeinLayoutItem*) root {
    // Adjust Y position only
    root.boundingRect = NSMakeRect(root.boundingRect.origin.x,
                                   kSkeinTopBorder + [levelYs[root.level] floatValue],
                                   root.boundingRect.size.width,
                                   root.boundingRect.size.height);
    for( IFSkeinLayoutItem* child in root.children ) {
        [self expandTreeVertically: child];
    }
}


- (void) updateLayoutWithReportDetails: (NSArray*) array {

    // Set the level Y positions based on the report details
    levelYs = [[NSMutableArray alloc] init];
    [levelYs addObject:@(0.0f)];

    CGFloat totalHeight = 0.0f;
    for( int i = 0; i < levels.count; i++ ) {
        CGFloat levelHeight = kSkeinMinLevelHeight;
        if( i < array.count ) {
            levelHeight = [array[i] doubleValue];
        }
        totalHeight += levelHeight;
        [levelYs addObject:@(totalHeight)];
    }

    // We move the tree that exists to the right of the selected line further right to make room for the report

    // Find the right position for the report frame
    if( treeRoot.onSelectedLine ) {
        IFSkeinLayoutItem* selectedLineItem = treeRoot;

        _reportPosition.x = 0.0f;
        _reportPosition.y = kSkeinTopBorder + kSkeinItemImageTopBorder + kSkeinItemImageHeight * 0.5f - kSkeinReportInsideTopBorder - kSkeinReportOffsetY;

        // Traverse down the selected line to find the ideal x position for the report
        while(( selectedLineItem != nil ) && (selectedLineItem.onSelectedLine)) {
            _reportPosition.x = MAX(_reportPosition.x,
                                   floor(NSMaxX(selectedLineItem.lozengeRect) + kSkeinReportLeftBorder));

            // Move on to next level down
            selectedLineItem = selectedLineItem.selectedLineChild;
        }

        // Traverse the tree, looking for the item furthest left on the right hand side of the selected line
        CGFloat selectedLineX = treeRoot.centreX;
        IFSkeinLayoutItem* bestItem = [self itemClosestBeyondX: selectedLineX root: treeRoot];
        shiftRightForReportOffsetX = 0.0f;
        if( bestItem != nil ) {
            CGFloat closestBeyondX = NSMinX(bestItem.boundingRect);
            shiftRightForReportOffsetX = _reportPosition.x - closestBeyondX;
        }
        shiftRightForReportOffsetX += kSkeinReportWidth + kSkeinReportRightBorder - kSkeinItemImageLeftBorder;

        // Traverse down the selected line
        selectedLineItem = treeRoot;
        while(( selectedLineItem != nil ) && (selectedLineItem.onSelectedLine)) {
            BOOL foundSelectedLine = NO;
            for( IFSkeinLayoutItem* child in selectedLineItem.children ) {
                // Find any child to the right of the selected line...
                if( child.onSelectedLine ) {
                    foundSelectedLine = YES;
                }
                else if( foundSelectedLine ) {
                    // ...and move it to the right
                    [child moveRightBy: shiftRightForReportOffsetX
                           recursively: YES];
                }
            }

            // Move on to next level down
            selectedLineItem = selectedLineItem.selectedLineChild;
        }
    }

    // Expand the tree vertically
    [self expandTreeVertically: treeRoot];
}

@end
