//
//  ZoomSkeinLayout.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Jul 21 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#include <tgmath.h>
#import <objc/objc-runtime.h>

#import "ZoomSkeinLayout.h"
#import "ZoomSkeinInternal.h"

// Define this to use the 'new' skein colouring style
#define SkeinDrawingStyleNew

// Constants
static const CGFloat itemPadding = 56.0;

// Drawing info
NSDictionary* itemTextAttributes = nil;
NSDictionary* labelTextAttributes = nil;

// Images
static NSImage* unplayed, *selected, *active, *unchanged, *changed, *annotation, *commentaryBadge;

#ifdef SkeinDrawingStyleNew
static NSImage* unchangedDark, *activeDark;
#endif

@implementation ZoomSkeinLayout {
	/// Item mapping
	NSMutableDictionary<NSValue*,ZoomSkeinLayoutItem*>* itemForItem;
	
	// The layout
	ZoomSkeinLayoutItem* tree;
	NSMutableArray<NSMutableArray<ZoomSkeinLayoutItem*>*>* levels;
	CGFloat globalOffset, globalWidth;
	
	// Highlighted skein line
	ZoomSkeinItem* highlightedLineItem;
	NSMutableSet<NSValue*>*  highlightedSet;
}

#pragma mark - Factory methods

+ (void) load {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
    NSShadow* labelShadow = [[NSShadow alloc] init];
	
    [labelShadow setShadowOffset: NSMakeSize(0.4, -1)];
    [labelShadow setShadowBlurRadius: 1.5];
    [labelShadow setShadowColor: [NSColor colorWithCalibratedWhite:0.0 alpha:0.7]];
	
		unplayed   = [[NSBundle bundleForClass: [self class]] imageForResource: @"Skein-unplayed"];
		selected   = [[NSBundle bundleForClass: [self class]] imageForResource: @"Skein-selected"];
		active     = [[NSBundle bundleForClass: [self class]] imageForResource: @"Skein-active"];
		unchanged  = [[NSBundle bundleForClass: [self class]] imageForResource: @"Skein-unchanged"];
		changed    = [[NSBundle bundleForClass: [self class]] imageForResource: @"Skein-changed"];
		annotation = [[NSBundle bundleForClass: [self class]] imageForResource: @"Skein-annotation"];
		commentaryBadge = [[NSBundle bundleForClass: [self class]] imageForResource: @"SkeinDiffersBadge"];
	
#ifdef SkeinDrawingStyleNew
		unchangedDark = [[NSBundle bundleForClass: [self class]] imageForResource: @"Skein-unchanged-dark"];
		activeDark = [[NSBundle bundleForClass: [self class]] imageForResource: @"Skein-active-dark"];
#endif
	
		itemTextAttributes = @{
			NSFontAttributeName: [NSFont systemFontOfSize: 10],
			NSForegroundColorAttributeName: [NSColor textColor],
		};
		labelTextAttributes = @{
			NSFontAttributeName: [NSFont systemFontOfSize: 13],
			NSForegroundColorAttributeName: [NSColor textColor],
			NSShadowAttributeName: labelShadow
		};
	});
}

+ (void) drawImage: (NSImage*) img
		   atPoint: (NSPoint) pos
		 withWidth: (CGFloat) width {
	pos.x = floor(pos.x);
	pos.y = floor(pos.y);
	width = floor(width);
	
	// Images must be 30 high
	if (width <= 0.0) width = 1.0;
	
	// use image slicing
	NSRect fullDrawRect = NSMakeRect(pos.x-20, pos.y, width + 20 + 20, 30);
	
	// Draw the edge bits
	[img drawInRect: fullDrawRect
		   fromRect: NSZeroRect
		  operation: NSCompositingOperationSourceOver
		   fraction: 1.0
	 respectFlipped: YES
			  hints: nil];
}

#pragma mark - Initialisation

- (id) init {
	return [self initWithRootItem: nil];
}

- (id) initWithRootItem: (ZoomSkeinItem*) item {
	self = [super init];
	
	if (self) {
		rootItem = item;

		itemWidth = 120.0; // Pixels
		itemHeight = 96.0;
		packingStyle = IFSkeinPackTight;
	}
	
	return self;
}

#pragma mark - Setting skein data

@synthesize itemWidth;
- (void) setItemWidth: (CGFloat) newItemWidth {
	if (newItemWidth < 82.0) newItemWidth = 82.0;
	itemWidth = newItemWidth;
}

@synthesize itemHeight;
@synthesize rootItem;

- (void) setActiveItem: (ZoomSkeinItem*) item {
	if (activeItem) {
		// If the new active item is not a child of the previous item, then unset the 'recently played' flag
		if (![[activeItem children] containsObject: item]) {
			ZoomSkeinItem* skeinItem = activeItem;
			while (skeinItem != nil) {
				ZoomSkeinLayoutItem* layoutItem = [itemForItem objectForKey: [NSValue valueWithNonretainedObject: skeinItem]];
				[layoutItem setRecentlyPlayed: NO];
				skeinItem = [skeinItem parent];
			}
		}
	}
	activeItem = item;
	
	// Mark everything upwards of the active item as played
	ZoomSkeinItem* skeinItem = activeItem;
	while (skeinItem != nil) {
		ZoomSkeinLayoutItem* layoutItem = [itemForItem objectForKey: [NSValue valueWithNonretainedObject: skeinItem]];
		[layoutItem setRecentlyPlayed: YES];
		skeinItem = [skeinItem parent];
	}
}

@synthesize activeItem;

@synthesize selectedItem;

- (void) updateHighlightDetails {
	// Update the set of items that use the 'transcript line' style
	
	// Clear the items that are currently marked as highlighted
	if (highlightedSet != nil) {
		NSEnumerator* oldHighlightEnum = [itemForItem objectEnumerator];
		
		for (ZoomSkeinLayoutItem* layoutItem in oldHighlightEnum)  {
			[layoutItem setOnSkeinLine: NO];
		}
	}
	
	// This set is a set of NSValue pointers to zoomSkeinItems. It's used while drawing.
	highlightedSet = [[NSMutableSet alloc] init];
	
	// Iterate up from the highlighted item
	ZoomSkeinItem* currentItem = highlightedLineItem;
	
	while (currentItem != nil) {
		// Store this item
		ZoomSkeinLayoutItem* itemUpwards = [itemForItem objectForKey: [NSValue valueWithNonretainedObject: currentItem]];
		[itemUpwards setOnSkeinLine: YES];
		
		// Up the tree
		currentItem = [currentItem parent];
	}
	
	// Iterate down from the highlighted item, so long as there is only one child item
	currentItem = highlightedLineItem;
	
	while ([[currentItem children] count] == 1) {
		// Move down the tree
		currentItem = [[[currentItem children] allObjects] objectAtIndex: 0];
		
		// Store this item
		ZoomSkeinLayoutItem* itemUpwards = [itemForItem objectForKey: [NSValue valueWithNonretainedObject: currentItem]];
		[itemUpwards setOnSkeinLine: YES];
		[itemUpwards setRecentlyPlayed: NO];
		// [[itemForItem objectForKey: [NSValue valueWithPointer: currentItem]] setOnSkeinLine: YES];
	}
}

- (void) highlightSkeinLine: (ZoomSkeinItem*) itemOnLine {
	// Do nothing if there's nothing to do
	if (itemOnLine == highlightedLineItem) return;
	
	highlightedLineItem = itemOnLine;
	
	[self updateHighlightDetails];
}

#pragma mark - Performing layout

- (ZoomSkeinLayoutItem*) layoutSkeinItemLoose: (ZoomSkeinItem*) item
									withLevel: (int) level {
	if (item == nil) return nil;
	
	CGFloat position = 0.0;
	CGFloat lastPosition = 0.0;
	CGFloat lastWidth = 0.0;
	ZoomSkeinLayoutItem* childItem;
	
	NSMutableArray* children = [NSMutableArray array];
	
	for (ZoomSkeinItem* child in [item children]) {
		// Layout the child item
		childItem = [self layoutSkeinItemLoose: child
									 withLevel: level+1];
		
		// Position it (first iteration: we center later)
		position += lastWidth/2.0; // Add in halves: we're dealing with object centers
		lastPosition = position;
		
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
	CGFloat center = position / 2.0;
	
	for (ZoomSkeinLayoutItem* childItem in children) {
		[childItem setPosition: [childItem position] - center];
	}
	
	// Adjust the width to fit the text, if required
	CGFloat ourWidth = [item commandSize].width;
	CGFloat labelWidth = [item annotationSize].width;
	
	if (labelWidth > ourWidth) ourWidth = labelWidth;
	
	if (position < (ourWidth + itemPadding)) position = ourWidth + itemPadding;
	
	// Return the result
	ZoomSkeinLayoutItem* result = [[ZoomSkeinLayoutItem alloc] initWithItem: item
																	  width: ourWidth
																  fullWidth: position
																	  level: level];
	
	[result setChildren: children];
	
	// Index this item
	[itemForItem setObject: result
					forKey: [NSValue valueWithNonretainedObject: item]];
	
	// Add to the 'levels' array, which contains which items to draw at which levels
	while (level >= [levels count]) {
		[levels addObject: [NSMutableArray array]];
	}
	
	[[levels objectAtIndex: level] addObject: result];
	
	return result;
}

- (void) fixPositions: (ZoomSkeinLayoutItem*) item
		   withOffset: (CGFloat) offset {
	// After running through layoutSkeinItem, all positions are relative to the 'parent' item
	// This routine fixes this
	
	// Move this item by the offset (fixing it with an absolute position)
	CGFloat oldPos = [item position];
	CGFloat newPos = oldPos + offset;
	[item setPosition: newPos];
	
	// Fix the children to have absolute positions
	for (ZoomSkeinLayoutItem* child in [item children]) {
		[self fixPositions: child
				withOffset: newPos];
	}
	
	CGFloat leftPos = newPos - ([item fullWidth]/2.0);
	if ((-leftPos) > globalOffset)
		globalOffset = -leftPos;
	if (newPos > globalWidth)
		globalWidth = newPos;
}

- (void) layoutSkeinLoose {	
	if (rootItem == nil) return;
	
	itemForItem = [[NSMutableDictionary alloc] init];
	
	// Perform initial layout of the items
	if (tree) {
		tree = nil;
	}
	levels = [[NSMutableArray alloc] init];
	
	tree = [self layoutSkeinItemLoose: rootItem
							withLevel: 0];
	
	if (tree != nil) {
		// Transform the 'relative' positions of all items into 'absolute' positions
		globalOffset = 0; globalWidth = 0;
		[self fixPositions: tree
				withOffset: 0];
	}
	
	if (highlightedLineItem) [self updateHighlightDetails];
}

#pragma mark - Getting layout data

- (NSInteger) levels {
	return [levels count];
}

- (NSArray*) itemsOnLevel: (NSInteger) level {
	if (level < 0 || level >= [levels count]) return nil;
	
	NSMutableArray* res = [NSMutableArray array];
	NSEnumerator* levelEnum = [[levels objectAtIndex: level] objectEnumerator];
	
	for (ZoomSkeinLayoutItem* item in levelEnum)  {
		[res addObject: [item item]];
	}
	
	return res;
}

- (NSArray*) dataForLevel: (NSInteger) level {
	if (level < 0 || level >= [levels count]) return nil;
	return [levels objectAtIndex: level];
}

#pragma mark - Raw item data

- (ZoomSkeinLayoutItem*) dataForItem: (ZoomSkeinItem*) item {
	return [itemForItem objectForKey: [NSValue valueWithNonretainedObject: item]]; // Yeah, yeah. Items are distinguished by command, not location in the tree
}

- (CGFloat) xposForItem: (ZoomSkeinItem*) item {
	return [[self dataForItem: item] position] + globalOffset;
}

- (int) levelForItem: (ZoomSkeinItem*) item {
	return [[self dataForItem: item] level];
}

- (CGFloat) widthForItem: (ZoomSkeinItem*) item {
	return [[self dataForItem: item] width];
}

- (CGFloat) fullWidthForItem: (ZoomSkeinItem*) item {
	return [[self dataForItem: item] fullWidth];
}

#pragma mark - Item positioning data

- (NSRect) activeAreaForData: (ZoomSkeinLayoutItem*) item {
	NSRect itemRect;
	CGFloat ypos = ((CGFloat)[item level]) * itemHeight + (itemHeight/2.0);
	CGFloat position = [item position];
	CGFloat width = [item width];
	
	// Basic rect
	itemRect.origin.x = position + globalOffset - (width/2.0) - 20.0;
	itemRect.origin.y = ypos - 8;
	itemRect.size.width = width + 40.0;
	itemRect.size.height = 30.0;
	
	// ... adjusted for the buttons
	if (itemRect.size.width < (32.0 + 40.0)) {
		itemRect.origin.x = position + globalOffset - (32.0+40.0)/2.0;
		itemRect.size.width = 32.0 + 40.0;
	}
	itemRect.origin.y = ypos - 18;
	itemRect.size.height = 52.0;
	
	// 'overflow' border
	itemRect = NSInsetRect(itemRect, -4.0, -4.0);	
	
	return itemRect;
}

- (NSRect) textAreaForData: (ZoomSkeinLayoutItem*) item {
	NSRect itemRect;
	CGFloat ypos = ((CGFloat)[item level]) * itemHeight + (itemHeight/2.0);
	CGFloat position = [item position];
	CGFloat width = [item width];
    
    NSLayoutManager* layoutManager = [[NSLayoutManager alloc] init];
	
	// Basic rect
	itemRect.origin.x = position + globalOffset - (width/2.0);
	itemRect.origin.y = ypos + 1;
	itemRect.size.width = width;
	itemRect.size.height = [layoutManager defaultLineHeightForFont: [NSFont systemFontOfSize: 10]];
    
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
	int level = floor(point.y/itemHeight);
	
	if (level < 0 || level >= [levels count]) return nil;
	
	// Position in level
	CGFloat levelPos = ((CGFloat)level)*itemHeight + (itemHeight / 2.0);
	CGFloat levelOffset = point.y - levelPos;
	
	// Must correspond to the lozenge
	//if (levelOffset < -8) return nil;
	//if (levelOffset >= 22) return nil;
	if (levelOffset < -18) return nil;
	if (levelOffset >= 34) return nil;
	
	// Find which item is selected (if any)
	
	// Recall that item positions are centered. Widths are calculated
	NSEnumerator* levelEnum = [[levels objectAtIndex: level] objectEnumerator];
	
	for (ZoomSkeinLayoutItem* item in levelEnum) {
		CGFloat thisItemWidth = [item width];
		CGFloat itemPos = [item position] + globalOffset;
		
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
		
		res.width = [tree fullWidth];
		res.height = ((CGFloat)[levels count]) * itemHeight;
		
		return res;
	} else {
		return NSMakeSize(0,0);
	}
}

#pragma mark - Drawing the layout

- (void) drawInRect: (NSRect) rect {
	// Fill in the background
	[[NSColor whiteColor] set];
	NSRectFill(rect);
	
	// Actually draw the skein
	int startLevel = floor(NSMinY(rect) / itemHeight)-1;
	int endLevel = ceil(NSMaxY(rect) / itemHeight);
	int level;
	
	for (level = startLevel; level < endLevel; level++) {
		if (level < 0) continue;
		if (level >= [self levels]) break;
		
		// Iterate through the items on this level...
		NSEnumerator* levelEnum = [[self dataForLevel: level] objectEnumerator];
		
		CGFloat ypos = ((CGFloat)level)*itemHeight + (itemHeight / 2.0);
		
		for (ZoomSkeinLayoutItem* item in levelEnum) {
			ZoomSkeinItem* skeinItem = [item item];
			CGFloat xpos = [item position] + globalOffset;
			NSSize size = [skeinItem commandSize];
			
			// Draw the background
			NSImage* background = unchanged;
			CGFloat bgWidth = size.width;
			//if (bgWidth < 90.0) bgWidth = 90.0;
			
#ifdef SkeinDrawingStyleNew
			BOOL darken = [[skeinItem commentary] length] == 0;
			
			background = unchanged;
			if (darken) background = unchangedDark;
			if ([item recentlyPlayed] && !darken) background = active;
			if ([item recentlyPlayed] && darken) background = activeDark;
#else
			if (![skeinItem played]) background = unplayed;
			if ([skeinItem changed]) background = changed;
			// if (skeinItem == activeItem) background = active;
			if ([skeinItem parent] == activeItem) background = active;
			// if (skeinItem == [self selectedItem]) background = selected;
#endif
			
			[[self class] drawImage: background
							atPoint: NSMakePoint(xpos - bgWidth/2.0, ypos-8 + (background==selected?2.0:0.0))
						  withWidth: bgWidth];
			
			// Draw the item
			[skeinItem drawCommandAtPosition: NSMakePoint(xpos - (size.width/2), ypos + (background==selected?2.0:0.0))];
			
			// Draw the 'commentary changed' badge if necessary
			if ([skeinItem commentaryComparison] == ZoomSkeinDifferent) {
				[commentaryBadge drawAtPoint: NSMakePoint(xpos + bgWidth/2.0 + 4, ypos + 6)
									fromRect: NSZeroRect
								   operation: NSCompositingOperationSourceOver
									fraction: 1.0];
			}
			
			// Draw links to the children
			[[NSColor blackColor] set];
			
			CGFloat startYPos = ypos + 10.0 + size.height;
			CGFloat endYPos = ypos - 10.0 + itemHeight;
			
#ifdef SkeinDrawingStyleNew
			NSColor* tempChildLink = [NSColor systemGrayColor];
#else
			NSColor* tempChildLink = [NSColor systemBlueColor];
#endif
			NSColor* permChildLink = [NSColor blackColor];
			
			for (ZoomSkeinLayoutItem* child in [item children]) {
				CGFloat childXPos = [child position] + globalOffset;
				BOOL annotated = [[child item] annotation]!=nil;
				
				BOOL highlightLine = [child onSkeinLine];
				
				// Thicken the line if this is on the highlighted line
				if (highlightLine) {
					[NSBezierPath setDefaultLineWidth: 3.0];
				}
				
				// Construct the line we're going to draw
				NSBezierPath* line = [[NSBezierPath alloc] init];
				[line moveToPoint: NSMakePoint(xpos, startYPos-8.0)];
				[line lineToPoint: NSMakePoint(xpos, startYPos)];
				[line lineToPoint: NSMakePoint(childXPos, annotated?endYPos-18:endYPos)];
				[line lineToPoint: NSMakePoint(childXPos, annotated?endYPos-14:endYPos+10.0)];
				
				// Set the appropriate colour and dash pattern
				if ([child item].temporary) {
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
								 
				// Thin it out again afterwards
				if (highlightLine) {
					[NSBezierPath setDefaultLineWidth: 1.0];
				}
			}
			
			// Draw the annotation, if present
			if ([[skeinItem annotation] length] > 0) {
				CGFloat thisItemWidth = [self widthForItem: skeinItem];
				CGFloat labelWidth = [skeinItem annotationSize].width;
				
				[[self class] drawImage: annotation
								atPoint: NSMakePoint(xpos - thisItemWidth/2.0, ypos-30)
							  withWidth: thisItemWidth];
				
				[skeinItem drawAnnotationAtPosition: NSMakePoint(xpos - (labelWidth/2), ypos - 23)];
			}
		}
	}
}

- (void) drawItem: (ZoomSkeinItem*) skeinItem
		  atPoint: (NSPoint) point {
	// Draw the background
	NSImage* background = unchanged;
	CGFloat bgWidth = [self widthForItem: skeinItem];
	
	if (![skeinItem played]) background = unplayed;
	if ([skeinItem changed]) background = changed;
	// if (skeinItem == activeItem) background = active;
	if ([skeinItem parent] == activeItem) background = active;
	// if (skeinItem == [self selectedItem]) background = selected;
	
	// Temporarily unflip the background image before drawing
	// (Doing this means this call will not work in flipped views. Well, it will, but it will look dreadful)
	[[self class] drawImage: background
					atPoint: NSMakePoint(point.x + 20, point.y + (background==selected?2.0:0.0))
				  withWidth: bgWidth];
	
	// Draw the item
	[skeinItem drawCommandAtPosition: NSMakePoint(point.x+20, point.y+8 + (background==selected?2.0:0.0))];
}

- (NSImage*) imageForItem: (ZoomSkeinItem*) item {
	NSRect imgRect;
	
	imgRect.origin = NSZeroPoint;
	imgRect.size = NSMakeSize([self widthForItem: item] + 40.0, 30.0);
	
	NSImage* img = [[NSImage alloc] initWithSize: imgRect.size];
	
	[img lockFocusFlipped:NO];
	[[NSColor clearColor] set];
	NSRectFill(imgRect);
	[self drawItem: item
		   atPoint: NSZeroPoint];
	[img unlockFocus];
	
	return img;
}

- (NSImage*) image {
	NSImage* res = [[NSImage alloc] initWithSize: [self size]];
	
	[res lockFocusFlipped:YES];
	
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

#pragma mark - Alternative packing style(s)

@synthesize packingStyle;

- (void) layoutSkein {
	switch (packingStyle) {
		case IFSkeinPackLoose:
		default:
			[self layoutSkeinLoose];
			break;
			
		case IFSkeinPackTight:
			[self layoutSkeinTight];
			break;
	}
}

- (void) layoutSkeinTight {
	// 'Tight' packing style will always use horizontal space if it's available.
	if (rootItem == nil) return;
	
	itemForItem = [[NSMutableDictionary alloc] init];
	
	// Perform initial layout of the items
	if (tree) {
		tree = nil;
	}
	levels = [[NSMutableArray alloc] init];
	
	tree = [self layoutSkeinItemTight: rootItem
							withLevel: 0];
	
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
	
	NSEnumerator<ZoomSkeinItem*>* childEnum = [[item children] objectEnumerator];
	ZoomSkeinLayoutItem* lastItem = nil;
	CGFloat position = 0.0;
	CGFloat lastWidth = 0.0;
	ZoomSkeinLayoutItem* childItem;
	
	NSMutableArray<ZoomSkeinLayoutItem*>* children = [NSMutableArray array];
	
	for (ZoomSkeinItem* child in childEnum) {
		// Layout the child item
		childItem = [self layoutSkeinItemTight: child
									 withLevel: level+1];
		
		// Pick an effective item width
		CGFloat effectiveWidthLeft = lastWidth;
		CGFloat effectiveWidthRight = [childItem fullWidth];
		
		if (lastItem) {
			NSInteger leftDepth = [lastItem depth];
			NSInteger rightDepth = [childItem depth];
			
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
	CGFloat center = position / 2.0;
	
	for (ZoomSkeinLayoutItem* childItem in children) {
		[childItem setPosition: [childItem position] - center];
	}
	
	// Adjust the width to fit the text, if required
	CGFloat ourWidth = [item commandSize].width;
	CGFloat labelWidth = [item annotationSize].width;
	
	if (labelWidth > ourWidth) ourWidth = labelWidth;
	
	if (position < (ourWidth + itemPadding)) position = ourWidth + itemPadding;
	
	// Return the result
	ZoomSkeinLayoutItem* result = [[ZoomSkeinLayoutItem alloc] initWithItem: item
																	  width: ourWidth
																  fullWidth: position
																	  level: level];
	
	[result setChildren: children];
	
	// Index this item
	[itemForItem setObject: result
					forKey: [NSValue valueWithNonretainedObject: item]];
	
	// Add to the 'levels' array, which contains which items to draw at which levels
	while (level >= [levels count]) {
		[levels addObject: [NSMutableArray array]];
	}
	
	[[levels objectAtIndex: level] addObject: result];
	
	return result;
}

@end
