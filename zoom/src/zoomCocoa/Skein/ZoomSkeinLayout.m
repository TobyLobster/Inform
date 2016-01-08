//
//  ZoomSkeinLayout.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Jul 21 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <objc/objc-runtime.h>

#import "ZoomSkeinLayout.h"

// Constants
static const float itemPadding = 26.0;

static NSDictionary* itemTextAttributes = nil;
static NSDictionary* labelTextAttributes = nil;

// Bug in weak linking? Can't use NSShadowAttributeName... Hmph
static NSString* ZoomNSShadowAttributeName = @"NSShadow";

// Images
static NSImage* unplayed, *selected, *active, *unchanged, *changed, *annotation, *commentaryBadge;

static NSImage* unchangedDark, *activeDark;

@implementation ZoomSkeinLayout

// = Factory methods =

+ (NSImage*) imageNamed: (NSString*) name {
	NSImage* img = [NSImage imageNamed: name];
	
	if (img == nil) {
		// Try to load from the framework instead
		NSBundle* ourBundle = [NSBundle bundleForClass: [self class]];
		NSString* filename = [ourBundle pathForResource: name
												 ofType: @"png"];
		
		if (filename) {
			img = [[[NSImage alloc] initWithContentsOfFile: filename] autorelease];
		}
	}
	
	[img setFlipped: YES];
	return img;
}

+ (NSImage*) darkenImage: (NSImage*) image {
	NSRect imgRect;
	
	imgRect.origin = NSMakePoint(0,0);
	imgRect.size = [image size];

	NSImage* highlighted = [[NSImage alloc] initWithSize: imgRect.size];
	
	[highlighted lockFocus];
	
	// Background
	[[NSColor colorWithDeviceRed: 0.0
						   green: 0.0
							blue: 0.0
						   alpha: 0.18] set];
	NSRectFill(imgRect);
	
	// The item
	[image drawAtPoint: NSMakePoint(0,0)
			  fromRect: imgRect
			 operation: NSCompositeDestinationAtop
			  fraction: 1.0];
	
	[highlighted unlockFocus];
	
	// Release
	return [highlighted autorelease];
}

+ (void) initialize {
	NSShadow* labelShadow = nil;
	
	if (objc_lookUpClass("NSShadow") != nil) {
		labelShadow = [[objc_lookUpClass("NSShadow") alloc] init];
		[labelShadow setShadowOffset: NSMakeSize(0.4, -1)];
		[labelShadow setShadowBlurRadius: 1.5];
		[labelShadow setShadowColor: [NSColor colorWithCalibratedWhite:0.0 alpha:0.7]];
	}
	
	unplayed   = [[[self class] imageNamed: @"Skein-unplayed"] retain];
	selected   = [[[self class] imageNamed: @"Skein-selected"] retain];
	active     = [[[self class] imageNamed: @"Skein-active"] retain];
	unchanged  = [[[self class] imageNamed: @"Skein-unchanged"] retain];
	changed    = [[[self class] imageNamed: @"Skein-changed"] retain];
	annotation = [[[self class] imageNamed: @"Skein-annotation"] retain];
	commentaryBadge = [[[self class] imageNamed: @"SkeinDiffersBadge"] retain];
	
	unchangedDark = [[[self class] darkenImage: unchanged] retain];
	activeDark = [[[self class] darkenImage: active] retain];

	itemTextAttributes = [@{NSFontAttributeName: [NSFont systemFontOfSize: 10],
		NSForegroundColorAttributeName: [NSColor blackColor]} retain];

    if (labelShadow)
    {
        labelTextAttributes = [@{NSFontAttributeName: [NSFont systemFontOfSize: 13],
            NSForegroundColorAttributeName: [NSColor blackColor],
            ZoomNSShadowAttributeName: labelShadow} retain];
    }
    else
    {
        labelTextAttributes = [@{NSFontAttributeName: [NSFont systemFontOfSize: 13],
                                 NSForegroundColorAttributeName: [NSColor blackColor]} retain];
    }
	
	if (labelShadow) [labelShadow release];
}

+ (void) drawImage: (NSImage*) img
		   atPoint: (NSPoint) pos
		 withWidth: (float) width {
	pos.x = floorf(pos.x);
	pos.y = floorf(pos.y);
	width = floorf(width);
	
	// Images must be 90x30
	if (width <= 0.0) width = 1.0;
	
	// Draw the middle bit
	NSRect bitToDraw = NSMakeRect(pos.x, pos.y, 50, 30);
	NSRect bitToDrawFrom = NSMakeRect(20, 0, 50, 30);
	float p;
	
	for (p=width; p>=0.0; p-=50.0) {
		if (p < 50.0) {
			bitToDrawFrom.size.width = bitToDraw.size.width = p;
		}
		
		bitToDraw.origin.x = pos.x + p - bitToDraw.size.width;
		
		[img drawInRect: bitToDraw
			   fromRect: bitToDrawFrom
			  operation: NSCompositeSourceOver
			   fraction: 1.0];	
	}
	
	// Draw the edge bits
	[img drawInRect: NSMakeRect(pos.x-15, pos.y, 15, 30)
		   fromRect: NSMakeRect(0,0,15,30)
		  operation: NSCompositeSourceOver
		   fraction: 1.0];	
	[img drawInRect: NSMakeRect(pos.x+width, pos.y, 15, 30)
		   fromRect: NSMakeRect(75,0,15,30)
		  operation: NSCompositeSourceOver
		   fraction: 1.0];	
}

// = Initialisation =

- (instancetype) init {
	return [self initWithRootItem: nil];
}

- (instancetype) initWithRootItem: (ZoomSkeinItem*) item {
	self = [super init];
	
	if (self) {
		rootItem = [item retain];

		itemWidth = 120.0; // Pixels
		itemHeight = 96.0;
		packingStyle = IFSkeinPackBestFit;
	}
	
	return self;
}

- (void) dealloc {
	if (rootItem) [rootItem release];
	
	if (itemForItem) [itemForItem release];
	
	[tree release];
	[levels release];
	
	if (highlightedSet) [highlightedSet release];
	if (highlightedLineItem) [highlightedLineItem release];
	
	[super dealloc];
}

// = Setting skein data =

- (void) setItemWidth: (float) newItemWidth {
	if (newItemWidth < 82.0) newItemWidth = 82.0;
	itemWidth = newItemWidth;
}

- (void) setItemHeight: (float) newItemHeight {
	itemHeight = newItemHeight;
}

- (void) setRootItem: (ZoomSkeinItem*) item {
	if (rootItem) [rootItem release];
	rootItem = [item retain];
}

- (ZoomSkeinItem*) rootItem {
	return rootItem;
}

- (void) setActiveItem: (ZoomSkeinItem*) item {
	if (activeItem) {
		// If the new active item is not a child of the previous item, then unset the 'recently played' flag
		if (![[activeItem children] containsObject: item]) {
			ZoomSkeinItem* skeinItem = activeItem;
			while (skeinItem != nil) {
				ZoomSkeinLayoutItem* layoutItem = itemForItem[[NSValue valueWithPointer: skeinItem]];
				[layoutItem setRecentlyPlayed: NO];
				skeinItem = [skeinItem parent];
			}
		}
		
		[activeItem release];
	}
	activeItem = [item retain];
	
	// Mark everything upwards of the active item as played
	ZoomSkeinItem* skeinItem = activeItem;
	while (skeinItem != nil) {
		ZoomSkeinLayoutItem* layoutItem = itemForItem[[NSValue valueWithPointer: skeinItem]];
		[layoutItem setRecentlyPlayed: YES];
		skeinItem = [skeinItem parent];
	}
}

- (ZoomSkeinItem*) activeItem {
	return activeItem;
}

- (void) setSelectedItem: (ZoomSkeinItem*) item {
	if (selectedItem) [selectedItem release];
	selectedItem = [item retain];
}

- (ZoomSkeinItem*) selectedItem {
	return selectedItem;
}

- (void) updateHighlightDetails {
	// Update the set of items that use the 'transcript line' style
	
	// Clear the items that are currently marked as highlighted
	if (highlightedSet != nil) {
		NSEnumerator* oldHighlightEnum = [itemForItem objectEnumerator];
		ZoomSkeinLayoutItem* layoutItem;
		
		while (layoutItem = [oldHighlightEnum nextObject])  {
			[layoutItem setOnSkeinLine: NO];
		}
	}
	
	// This set is a set of NSValue pointers to zoomSkeinItems. It's used while drawing.
	[highlightedSet release];
	highlightedSet = [[NSMutableSet alloc] init];
	
	// Iterate up from the highlighted item
	ZoomSkeinItem* currentItem = highlightedLineItem;
	
	while (currentItem != nil) {
		// Store this item
		ZoomSkeinLayoutItem* itemUpwards = itemForItem[[NSValue valueWithPointer: currentItem]];
		[itemUpwards setOnSkeinLine: YES];
		
		// Up the tree
		currentItem = [currentItem parent];
	}
	
	// Iterate down from the highlighted item, so long as there is only one child item
	currentItem = highlightedLineItem;
	
	while ([[currentItem children] count] == 1) {
		// Move down the tree
		currentItem = [[currentItem children] allObjects][0];
		
		// Store this item
		ZoomSkeinLayoutItem* itemUpwards = itemForItem[[NSValue valueWithPointer: currentItem]];
		[itemUpwards setOnSkeinLine: YES];
		[itemUpwards setRecentlyPlayed: NO];
		// [[itemForItem objectForKey: [NSValue valueWithPointer: currentItem]] setOnSkeinLine: YES];
	}
}

- (void) highlightSkeinLine: (ZoomSkeinItem*) itemOnLine {
	// Do nothing if there's nothing to do
	if (itemOnLine == highlightedLineItem) return;
	
	[highlightedLineItem release];
	highlightedLineItem = [itemOnLine retain];
	
	[self updateHighlightDetails];
}

// = Performing layout =

- (ZoomSkeinLayoutItem*) layoutSkeinItemLoose: (ZoomSkeinItem*) item
									withLevel: (int) level {
	if (item == nil) return nil;
	
	NSEnumerator* childEnum = [[item children] objectEnumerator];
	ZoomSkeinItem* child;
	float position = 0.0;
	float lastWidth = 0.0;
	ZoomSkeinLayoutItem* childItem;
	
	NSMutableArray* children = [NSMutableArray array];
	
	while (child = [childEnum nextObject]) {
		// Layout the child item
		childItem = [self layoutSkeinItemLoose: child
									 withLevel: level+1];
		
		// Position it (first iteration: we center later)
		position += lastWidth/2.0; // Add in halves: we're dealing with object centers
		
		lastWidth = [childItem fullWidth];
		position += lastWidth/2.0;
		
		[childItem setPosition: position];
		
		// Add to the list of children for this item
		[children addObject: childItem];
	}
	
	// Update position to be the total width
	position += lastWidth/2.0;
	
	// Should only happen if there are no children
	if (position == 0.0) position = itemWidth;
	
	// Center the children	
	float center = position / 2.0;
	
	childEnum = [children objectEnumerator];
	while (childItem = [childEnum nextObject]) {
		[childItem setPosition: [childItem position] - center];
	}
	
	// Adjust the width to fit the text, if required
	float commandWidth = [item commandSize].width;
	float annotationWidth = [item annotationSize].width;
    float combinedWidth = MAX(commandWidth, annotationWidth);
	
	if (position < (combinedWidth + itemPadding)) position = combinedWidth + itemPadding;
	
	// Return the result
	ZoomSkeinLayoutItem* result = [[ZoomSkeinLayoutItem alloc] initWithItem: item
                                                               commandWidth: commandWidth
                                                            annotationWidth: annotationWidth
																  fullWidth: position
																	  level: level];
	
	[result setChildren: children];
	
	// Index this item
	itemForItem[[NSValue valueWithPointer: item]] = result;
	
	// Add to the 'levels' array, which contains which items to draw at which levels
	while (level >= [levels count]) {
		[levels addObject: [NSMutableArray array]];
	}
	
	[levels[level] addObject: result];
	return [result autorelease];
}

- (void) fixPositions: (ZoomSkeinLayoutItem*) item
		   withOffset: (float) offset {
	// After running through layoutSkeinItem, all positions are relative to the 'parent' item
	// This routine fixes this
	
	// Move this item by the offset (fixing it with an absolute position)
	float oldPos = [item position];
	float newPos = oldPos + offset;
	[item setPosition: newPos];
	
	// Fix the children to have absolute positions
	NSEnumerator* childEnum = [[item children] objectEnumerator];
	ZoomSkeinLayoutItem* child;
	
	while (child = [childEnum nextObject]) {
		[self fixPositions: child
				withOffset: newPos];
	}
	
	float leftPos = newPos - ([item fullWidth]/2.0);
	if ((-leftPos) > globalOffset)
		globalOffset = -leftPos;
	if (newPos > globalWidth)
		globalWidth = newPos;
}

- (void) layoutSkeinLoose {	
	if (rootItem == nil) return;
	
	if (itemForItem) [itemForItem release];
	itemForItem = [[NSMutableDictionary alloc] init];
	
	// Perform initial layout of the items
    [tree release];
    [levels release];
	levels = [[NSMutableArray alloc] init];
	
	tree = [[self layoutSkeinItemLoose: rootItem
							 withLevel: 0] retain];
	
	if (tree != nil) {
		// Transform the 'relative' positions of all items into 'absolute' positions
		globalOffset = 0; globalWidth = 0;
		[self fixPositions: tree
				withOffset: 0];
	}
	
	if (highlightedLineItem) [self updateHighlightDetails];
}

// = Getting layout data =

- (int) levels {
	return (int) [levels count];
}

- (NSArray*) itemsOnLevel: (int) level {
	if (level < 0 || level >= [levels count]) return nil;
	
	NSMutableArray* res = [NSMutableArray array];
	NSEnumerator* levelEnum = [levels[level] objectEnumerator];
	ZoomSkeinLayoutItem* item;
	
	while (item = [levelEnum nextObject])  {
		[res addObject: [item item]];
	}
	
	return res;
}

- (NSArray*) dataForLevel: (int) level {
	if (level < 0 || level >= [levels count]) return nil;
	return levels[level];
}

// = Raw item data =

- (ZoomSkeinLayoutItem*) dataForItem: (ZoomSkeinItem*) item {
	return itemForItem[[NSValue valueWithPointer: item]]; // Yeah, yeah. Items are distinguished by command, not location in the tree
}

- (float) xposForItem: (ZoomSkeinItem*) item {
	return [[self dataForItem: item] position] + globalOffset;
}

- (int) levelForItem: (ZoomSkeinItem*) item {
	return [[self dataForItem: item] level];
}

- (float) widthForItem: (ZoomSkeinItem*) item {
	return [[self dataForItem: item] combinedWidth];
}

- (float) fullWidthForItem: (ZoomSkeinItem*) item {
	return [[self dataForItem: item] fullWidth];
}

// = Item positioning data =

- (NSRect) activeAreaForData: (ZoomSkeinLayoutItem*) item {
	NSRect itemRect;
    float borderX = 15.0f;

    float ypos = ((float)[item level]) * itemHeight + (itemHeight/2.0);
	float position = [item position];
	float width = [item commandWidth] + borderX * 2.0f;

	// Basic rect
	itemRect.origin.x = position + globalOffset - (width/2.0);
	itemRect.origin.y = ypos - 8;
	itemRect.size.width = width;
	itemRect.size.height = 24.0;

	// ... adjusted for the buttons
    float minItemWidth = 32.0 + 40.0;
	if (itemRect.size.width < minItemWidth) {
		itemRect.origin.x = position + globalOffset - minItemWidth/2.0;
		itemRect.size.width = minItemWidth;
	}

	return itemRect;
}

- (NSRect) textAreaForData: (ZoomSkeinLayoutItem*) item {
	NSRect itemRect;
	float ypos = ((float)[item level]) * itemHeight + (itemHeight/2.0);
	float position = [item position];
	float width = [item commandWidth];

	// Basic rect
	itemRect.origin.x = position + globalOffset - (width/2.0);
	itemRect.origin.y = ypos + 1;
	itemRect.size.width = width;
    NSLayoutManager* lm = [[[NSLayoutManager alloc] init] autorelease];
	itemRect.size.height = [lm defaultLineHeightForFont: [NSFont systemFontOfSize: 10]];
	
	// Move it down by a few pixels if this is a selected item
	if ([item item] == selectedItem) {
		itemRect.origin.y += 2;
	}
	
	return itemRect;
}

- (NSRect) activeAreaForItem: (ZoomSkeinItem*) itemData {
	return [self activeAreaForData: [self dataForItem: itemData]];
}

- (NSRect) textAreaForItem: (ZoomSkeinItem*) itemData {
	return [self textAreaForData: [self dataForItem: itemData]];
}

- (ZoomSkeinItem*) itemAtPoint: (NSPoint) point {
	// Searches for the item that is under the given point
	
	// Recall that items are drawn at:
	//		float ypos = ((float)level)*itemHeight + (itemHeight / 2.0);
	//      The 'lozenge' extends -8 upwards, and has a height of 30 pixels
	//		There needs to be some space for icon controls
	//		Levels start at 0
	//		Labels appear above the item (in the control space: so you can't directly click on a label)
	
	// Check for level
	int level = floorf(point.y/itemHeight);
	
	if (level < 0 || level >= [levels count]) return nil;
	
	// Position in level
	float levelPos = ((float)level)*itemHeight + (itemHeight / 2.0);
	float levelOffset = point.y - levelPos;
	
	// Must correspond to the lozenge
	//if (levelOffset < -8) return nil;
	//if (levelOffset >= 22) return nil;
	if (levelOffset < -18) return nil;
	if (levelOffset >= 34) return nil;
	
	// Find which item is selected (if any)
	
	// Recall that item positions are centered. Widths are calculated
	NSEnumerator* levelEnum = [levels[level] objectEnumerator];
	ZoomSkeinLayoutItem* item;
	
	while (item = [levelEnum nextObject]) {
		float thisItemWidth = [item commandWidth];
		float itemPos = [item position] + globalOffset;
		
		// There's a +40 border either side of the item
		thisItemWidth += 40.0;
		
		// Buttons require a minimum width
		if (thisItemWidth < 72.0) {
			thisItemWidth = 72.0;
		}
		
		// Item is centered
		thisItemWidth /= 2.0;
		
		if (point.x > (itemPos - thisItemWidth) && point.x < (itemPos + thisItemWidth)) {
			// This is the item
			return [item item];
		}
	}
	
	// Nothing found
	return nil;
}

- (NSSize) size {	
	if (tree) {
		NSSize res;
		
		res.width = [tree fullWidth] + 40.0f;
		res.height = ((float)[levels count] + 1) * itemHeight;
		
		return res;
	} else {
		return NSMakeSize(0,0);
	}
}

-(void) drawLinksToChildren:(ZoomSkeinLayoutItem*) item atX:(float)xpos atY:(float) ypos atSize:(NSSize) size
{
    // Draw links to the children
    [[NSColor blackColor] set];
    NSEnumerator* childEnumerator = [[item children] objectEnumerator];

    float startYPos = floorf(ypos + size.height / 2.0f);
    float endYPos = floorf(ypos + itemHeight);

    NSColor* tempChildLink = [NSColor grayColor];
    NSColor* permChildLink = [NSColor colorWithDeviceRed:0.4f green:0.3f blue:0.3f alpha:1.0f];

    ZoomSkeinLayoutItem* child;
    while (child = [childEnumerator nextObject]) {
        float childXPos = [child position] + globalOffset;
        BOOL highlightLine = [child onSkeinLine];

        // Construct the line we're going to draw
        NSBezierPath* line = [[NSBezierPath alloc] init];
        // Thicken the line if this is on the highlighted line
        if (highlightLine) {
            [line setLineWidth: 4.0f];
        } else {
            [line setLineWidth: 2.0f];
        }
        [line moveToPoint: NSMakePoint(floorf(xpos), startYPos)];
        [line lineToPoint: NSMakePoint(floorf(childXPos), endYPos)];

        // Set the appropriate colour and dash pattern
        if ([[child item] temporary]) {
            CGFloat dashPattern[2];

            [tempChildLink set];

            dashPattern[0] = 4.0;
            dashPattern[1] = 3.0;
            [line setLineDash: dashPattern
                        count: 2
                        phase: 0.0];
        } else {
            [permChildLink set];
        }
        
        // Draw the line
        [line stroke];
        [line release];
    }
}

-(void) drawLayoutItem:(ZoomSkeinLayoutItem*) item atX:(float)xpos atY:(float) ypos atSize:(NSSize) size
{
    ZoomSkeinItem* skeinItem = [item item];

    // Draw the annotation, if present
    float thisItemWidth = 0.0f;
    float labelWidth = 0.0f;
    NSUInteger annotationLength = [[skeinItem annotation] length];
    if (annotationLength > 0) {
        thisItemWidth = [self widthForItem: skeinItem];
        labelWidth = [skeinItem annotationSize].width;

        [[self class] drawImage: annotation
                        atPoint: NSMakePoint(xpos - thisItemWidth/2.0, ypos-22)
                      withWidth: thisItemWidth];

        [skeinItem drawAnnotationAtPosition: NSMakePoint(xpos - (labelWidth/2), ypos - 18)];
    }

    // Draw the background
    NSImage* background;
    float bgWidth = floorf(size.width);

    BOOL darken = [[skeinItem commentary] length] == 0;

    background = unchanged;
    if (darken) background = unchangedDark;
    if ([item recentlyPlayed] && !darken) background = active;
    if ([item recentlyPlayed] && darken) background = activeDark;

    [[self class] drawImage: background
                    atPoint: NSMakePoint(floorf(xpos - bgWidth/2.0), floorf(ypos-8 + (background==selected?2.0:0.0)))
                  withWidth: bgWidth];

    // Draw the item
    [skeinItem drawCommandAtPosition: NSMakePoint(floorf(xpos - (size.width/2)), ypos + (background==selected?2.0:0.0))];

    // Draw the 'commentary changed' badge if necessary
    if ([skeinItem commentaryComparison] == ZoomSkeinDifferent) {
        NSRect fromRect;

        fromRect.origin = NSMakePoint(0,0);
        fromRect.size = [commentaryBadge size];

        [commentaryBadge drawAtPoint: NSMakePoint(floorf(xpos + bgWidth/2.0 + 4), ypos + 6)
                            fromRect: fromRect
                           operation: NSCompositeSourceOver
                            fraction: 1.0];
    }
}

-(void) drawActiveAreaItem:(ZoomSkeinLayoutItem*) item
{
    NSRect rect = [self activeAreaForItem: [item item]];
    [[NSColor colorWithCalibratedRed:0.0f green:0.0f blue:0.0f alpha:0.5f] setFill];
    [NSBezierPath fillRect: rect];
}


// = Drawing the layout =

- (void) drawInRect: (NSRect) rect {
	// Fill in the background
	[[NSColor whiteColor] set];
	NSRectFill(rect);

	// Actually draw the skein
	int startLevel = floorf(NSMinY(rect) / itemHeight)-1;
	int endLevel = ceilf(NSMaxY(rect) / itemHeight);
	int level;

    for( int drawPass = 0; drawPass < 2; drawPass++ )
    {
        for (level = startLevel; level < endLevel; level++) {
            if (level < 0) continue;
            if (level >= [self levels]) break;
            
            // Iterate through the items on this level...
            NSEnumerator* levelEnum = [[self dataForLevel: level] objectEnumerator];
            ZoomSkeinLayoutItem* item;
            
            float ypos = floorf(((float)level)*itemHeight + (itemHeight / 2.0));
            
            while (item = [levelEnum nextObject]) {
                ZoomSkeinItem* skeinItem = [item item];
                float xpos = [item position] + globalOffset;
                NSSize size = [skeinItem commandSize];

                if( drawPass == 0 )
                {
                    [self drawLinksToChildren:item atX:xpos atY:ypos atSize: size];
                }
                else if( drawPass == 1 )
                {
                    [self drawLayoutItem:item atX:xpos atY:ypos atSize: size];
                }
                else
                {
                    [self drawActiveAreaItem:item];
                }
            }
        }
    }
}

- (void) drawItem: (ZoomSkeinItem*) skeinItem
		  atPoint: (NSPoint) point {
	// Draw the background
	NSImage* background = unchanged;
	float bgWidth = [self widthForItem: skeinItem];
	
	if (![skeinItem played]) background = unplayed;
	if ([skeinItem changed]) background = changed;
	// if (skeinItem == activeItem) background = active;
	if ([skeinItem parent] == activeItem) background = active;
	// if (skeinItem == [self selectedItem]) background = selected;
	
	// Temporarily unflip the background image before drawing
	// (Doing this means this call will not work in flipped views. Well, it will, but it will look dreadful)
	[background setFlipped: NO];
	[[self class] drawImage: background
					atPoint: NSMakePoint(point.x + 20, point.y + (background==selected?2.0:0.0))
				  withWidth: bgWidth];
	[background setFlipped: YES];
	
	// Draw the item
	[skeinItem drawCommandAtPosition: NSMakePoint(point.x+20, point.y+8 + (background==selected?2.0:0.0))];
}

- (NSImage*) imageForItem: (ZoomSkeinItem*) item {
	NSRect imgRect;
	
	imgRect.origin = NSMakePoint(0,0);
	imgRect.size = NSMakeSize([self widthForItem: item] + 40.0, 30.0);
	
	NSImage* img = [[[NSImage alloc] initWithSize: imgRect.size] autorelease];
	
	[img lockFocus];
	[[NSColor clearColor] set];
	NSRectFill(imgRect);
	[self drawItem: item
		   atPoint: NSMakePoint(0,0)];	
	[img unlockFocus];
	
	return img;
}

- (NSImage*) image {
	NSImage* res = [[[NSImage alloc] initWithSize: [self size]] autorelease];
	
	[res lockFocus];
	
	NSAffineTransform* flip = [NSAffineTransform transform];
	
	// Almost works, except the text is upside down.
	[flip scaleXBy: 1.0
			   yBy: -1.0];
	[flip translateXBy: 0.0
				   yBy: -[self size].height];
	[flip set];
	
	NSRect imgRect;
	imgRect.origin = NSMakePoint(0,0);
	imgRect.size = [self size];
	
	[self drawInRect: imgRect];
		
	[res unlockFocus];
	
	return res;
}

// = Alternative packing style(s) =

- (void) setPackingStyle: (int) newPackingStyle {
	packingStyle = newPackingStyle;
}

- (void) layoutSkein {
	switch (packingStyle) {
		case IFSkeinPackLoose:
		default:
			[self layoutSkeinLoose];
			break;
			
		case IFSkeinPackTight:
			[self layoutSkeinTight];
			break;
            
        case IFSkeinPackBestFit:
            [self layoutSkeinBestFit];
            break;
	}
}

- (void) layoutSkeinTight {
	// 'Tight' packing style will always use horizontal space if it's available.
	if (rootItem == nil) return;
	
	if (itemForItem) [itemForItem release];
	itemForItem = [[NSMutableDictionary alloc] init];
	
	// Perform initial layout of the items
    [tree release];
    [levels release];

	levels = [[NSMutableArray alloc] init];
	tree = [[self layoutSkeinItemTight: rootItem
							 withLevel: 0] retain];
	
	if (tree != nil) {
		// Transform the 'relative' positions of all items into 'absolute' positions
		globalOffset = 0; globalWidth = 0;
		[self fixPositions: tree
				withOffset: 0];
	}
	
	if (highlightedLineItem) [self updateHighlightDetails];
}

#define MaxTightDepth 8

- (ZoomSkeinLayoutItem*) layoutSkeinItemTight: (ZoomSkeinItem*) item
									withLevel: (int) level {
	// Counterpart to layoutSkeinItemLoose that is slightly more intelligent about re-using vertical space
	if (item == nil) return nil;
	
	NSEnumerator* childEnum = [[item children] objectEnumerator];
	ZoomSkeinItem* child;
	ZoomSkeinLayoutItem* lastItem = nil;
	float position = 0.0;
	float lastWidth = 0.0;
	ZoomSkeinLayoutItem* childItem;
	
	NSMutableArray* children = [NSMutableArray array];
	
	while (child = [childEnum nextObject]) {
		// Layout the child item
		childItem = [self layoutSkeinItemTight: child
									 withLevel: level+1];
		
		// Pick an effective item width
		float effectiveWidthLeft = lastWidth;
		float effectiveWidthRight = [childItem fullWidth];
		
		if (lastItem) {
			int leftDepth = [lastItem depth];
			int rightDepth = [childItem depth];
			
			if (leftDepth < rightDepth && leftDepth < MaxTightDepth) {
				
			} else if (rightDepth < leftDepth && rightDepth < MaxTightDepth) {
				
			}
		}
		
		// Position it (first iteration: we center later)
		position += effectiveWidthLeft/2.0; // Add in halves: we're dealing with object centers
		
		lastWidth = effectiveWidthRight;
		position += lastWidth/2.0;
		
		[childItem setPosition: position];
		
		// Add to the list of children for this item
		[children addObject: childItem];
		lastItem = childItem;
	}
	
	// Update position to be the total width
	position += lastWidth/2.0;
	
	// Should only happen if there are no children
	if (position == 0.0) position = itemWidth;
	
	// Center the children	
	float center = position / 2.0;
	
	childEnum = [children objectEnumerator];
	while (childItem = [childEnum nextObject]) {
		[childItem setPosition: [childItem position] - center];
	}
	
	// Adjust the width to fit the text, if required
	float commandWidth = [item commandSize].width;
	float annotationWidth = [item annotationSize].width;
    float combinedWidth = MAX(commandWidth, annotationWidth);

	if (position < (combinedWidth + itemPadding)) position = combinedWidth + itemPadding;
	
	// Return the result
	ZoomSkeinLayoutItem* result = [[ZoomSkeinLayoutItem alloc] initWithItem: item
                                                               commandWidth: commandWidth
                                                            annotationWidth: annotationWidth
																  fullWidth: position
																	  level: level];
	
	[result setChildren: children];
	
	// Index this item
	itemForItem[[NSValue valueWithPointer: item]] = result;
	
	// Add to the 'levels' array, which contains which items to draw at which levels
	while (level >= [levels count]) {
		[levels addObject: [NSMutableArray array]];
	}
	
	[levels[level] addObject: result];

	return [result autorelease];
}

- (void) layoutSkeinBestFit {
	// 'Best Fit' packing style
	if (rootItem == nil) return;
	
	[itemForItem release];
	itemForItem = [[NSMutableDictionary alloc] init];
	
	// Perform initial layout of the items
    [tree release];
    [levels release];
	levels = [[NSMutableArray alloc] init];
    tree = nil;

	levelWidths = [[NSMutableArray alloc] init];
    
	tree = [[self layoutSkeinCreateLayoutTree: rootItem
                                    withLevel: 0] retain];

    [self layoutSkeinItemAlignLeft: tree
                         withLevel: 0];
    
    [self layoutSkeinItemBestFit: tree];
    
    [self layoutSkeinCalculateFullWidth: tree withLevel: 0];
    
    [levelWidths release];
    levelWidths = nil;

	if (highlightedLineItem) [self updateHighlightDetails];
}

-(float) currentLevelWidth:(int) level {
    // Make sure we have enough levels
    while( [levelWidths count] <= level ) {
        [levelWidths addObject:@0.0f];
    }
    return [levelWidths[level] floatValue];
}

- (ZoomSkeinLayoutItem*) layoutSkeinCreateLayoutTree: (ZoomSkeinItem*) item
                                           withLevel: (int) level {
	if (item == nil) {
        return nil;
    }

	NSMutableArray* children = [NSMutableArray array];

    // Create layout tree, recursively
	for( ZoomSkeinItem* child in [item children] ) {
        ZoomSkeinLayoutItem* childItem = [self layoutSkeinCreateLayoutTree: child
                                                                 withLevel: level+1];
		[children addObject: childItem];
    }

	// Calculate the width to fit the text
	float commandWidth    = [item commandSize].width;
	float annotationWidth = [item annotationSize].width;
    //float combinedWidth   = MAX(commandWidth, annotationWidth);

	ZoomSkeinLayoutItem* result = [[ZoomSkeinLayoutItem alloc] initWithItem: item
                                                               commandWidth: commandWidth
                                                            annotationWidth: annotationWidth
																  fullWidth: 1.0f
																	  level: level];
	[result setChildren: children];

	// Index this item
	itemForItem[[NSValue valueWithPointer: item]] = result;
	
	// Add to the 'levels' array, which contains the items to draw at each level
	while (level >= [levels count]) {
		[levels addObject: [NSMutableArray array]];
	}
	
	[levels[level] addObject: result];

    return [result autorelease];
}

- (void) layoutSkeinItemAlignLeft: (ZoomSkeinLayoutItem*) item
                        withLevel: (int) level {
	if (item == nil) {
        return;
    }

    // Align items to the left edge (DFS)
	for( ZoomSkeinLayoutItem* child in [item children] ) {
        [self layoutSkeinItemAlignLeft: child
                             withLevel: level+1];
    }

    float currentLevelWidth = [self currentLevelWidth: level];
    [item setPosition: 40.0f + currentLevelWidth + [item combinedWidth]/2];

    currentLevelWidth += [item combinedWidth] + itemPadding;

    levelWidths[level] = @(currentLevelWidth);
}

- (void) moveRemainingItemsRightAfter: (ZoomSkeinLayoutItem*) item
                              onLevel: (int) levelIndex
                                   by: (float) deltaX
                          recursively: (BOOL) recursively {
    // Move remaining items at this level right
    BOOL found = NO;
    NSMutableArray* level = levelArray[levelIndex];
    for( ZoomSkeinLayoutItem* item2 in level ) {
        if( item2 == item ) {
            found = YES;
        }
        if( found ) {
            [item2 moveRightBy: deltaX
                   recursively: recursively];
        }
    }
}

- (void) layoutSkeinItemBestFit: (ZoomSkeinLayoutItem*) item {
	if (item == nil) {
        return;
    }

    NSMutableArray *queue   = [[NSMutableArray alloc] initWithObjects: item, nil];
    levelArray              = [[NSMutableArray alloc] initWithObjects: [NSMutableArray arrayWithObject: item], nil];

    // Create a queue - each item, from the top to the bottom, left to right (BFS)
    while ([queue count] > 0) {
        ZoomSkeinLayoutItem * itemQ = queue[0];

        for ( ZoomSkeinLayoutItem *childItem in [itemQ children] ) {
            // Add to queue
            [queue addObject: childItem];
            
            // Add to levels
            while( [levelArray count] <= [childItem level] ) {
                [levelArray addObject: [NSMutableArray array]];
            }
            [levelArray[[childItem level]] addObject: childItem];
        }
        [queue removeObjectAtIndex: 0];
    }

    // Visit each level, from the bottom to the top, left to right
    for( NSArray* level in [levelArray reverseObjectEnumerator] ) {
        for( ZoomSkeinLayoutItem* item in level ) {

            // If we are a parent
            if( [[item children] count] > 0 ) {
                float parentx = [item position];
                
                // Find centre of all children
                float minx = MAXFLOAT;
                float maxx = -MAXFLOAT;
                for( ZoomSkeinLayoutItem* item2 in [item children] ) {
                    minx = MIN(minx, [item2 position]);
                    maxx = MAX(maxx, [item2 position]);
                }
                float centrex = (minx + maxx)/2;
                float deltaX;
                
                if( parentx < centrex ) {
                    // Move parent right to centre under children
                    deltaX = centrex - parentx;
                    
                    // Move remaining items at this level right
                    [self moveRemainingItemsRightAfter: item
                                               onLevel: [item level]
                                                    by: deltaX
                                           recursively: NO];
                } else if( parentx > centrex ) {
                    deltaX = parentx - centrex;

                    // Move the first child right to align under parent, and all remaining
                    // items on that level, and any of their children by the same amount
                    [self moveRemainingItemsRightAfter: [item children][0]
                                               onLevel: [item level] + 1
                                                    by: deltaX
                                           recursively: YES];
                }
            }
        }
    }

    [queue release];
    [levelArray release];
    levelArray = nil;
}

- (float) layoutSkeinCalculateFullWidth: (ZoomSkeinLayoutItem*) item
                              withLevel: (int) level {
	if (item == nil) {
        return 0.0f;
    }
    
    // DFS
    float furthestRightX = 0.0f;
	for( ZoomSkeinLayoutItem* child in [item children] ) {
        float childFurthestRightX = [self layoutSkeinCalculateFullWidth: child
                                                              withLevel: level+1];
        furthestRightX = MAX(furthestRightX, childFurthestRightX);
    }
    
    furthestRightX = MAX([item position] + [item combinedWidth]/2, ceilf(furthestRightX));
    [item setFullWidth: furthestRightX];
    return furthestRightX;
}

@end
