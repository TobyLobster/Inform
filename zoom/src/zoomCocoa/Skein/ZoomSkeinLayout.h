//
//  ZoomSkeinLayout.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Jul 21 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZoomSkein.h"
#import "ZoomSkeinLayoutItem.h"

enum IFSkeinPackingStyle {
	IFSkeinPackLoose,
	IFSkeinPackTight,
    IFSkeinPackBestFit,
};

@interface ZoomSkeinLayout : NSObject {
	ZoomSkeinItem* rootItem;

	// Item mapping
	NSMutableDictionary* itemForItem;
	
	// The layout
	ZoomSkeinLayoutItem* tree;
	NSMutableArray* levels;
	float globalOffset, globalWidth;
    NSMutableArray* levelWidths;
    NSMutableArray *levelArray;
	
	float itemWidth;
	float itemHeight;
	int packingStyle;
	
	// Highlighted skein line
	ZoomSkeinItem* highlightedLineItem;
	NSMutableSet*  highlightedSet;
	
	// Some extra status
	ZoomSkeinItem* activeItem;
	ZoomSkeinItem* selectedItem;
}

// Initialisation
- (id) initWithRootItem: (ZoomSkeinItem*) item;

// Setting skein data
- (void) setItemWidth: (float) itemWidth;
- (void) setItemHeight: (float) itemHeight;
- (void) setPackingStyle: (int) packingStyle;

- (void) setRootItem: (ZoomSkeinItem*) item;
- (void) setActiveItem: (ZoomSkeinItem*) item;
- (void) setSelectedItem: (ZoomSkeinItem*) item;
- (void) highlightSkeinLine: (ZoomSkeinItem*) itemOnLine;

- (ZoomSkeinItem*) rootItem;
- (ZoomSkeinItem*) activeItem;
- (ZoomSkeinItem*) selectedItem;

// Performing the layout
- (void) layoutSkein;
- (void) layoutSkeinLoose;
- (void) layoutSkeinTight;

// Getting layout data
- (int) levels;
- (NSArray*) itemsOnLevel: (int) level;
- (NSArray*) dataForLevel: (int) level;

- (ZoomSkeinLayoutItem*) dataForItem: (ZoomSkeinItem*) item;

// General item data
- (float)    xposForItem:      (ZoomSkeinItem*) item;
- (int)      levelForItem:     (ZoomSkeinItem*) item;
- (float)    widthForItem:     (ZoomSkeinItem*) item;
- (float)    fullWidthForItem: (ZoomSkeinItem*) item;

// Item positioning data
- (NSSize) size;

- (NSRect) activeAreaForItem: (ZoomSkeinItem*) itemData;
- (NSRect) textAreaForItem: (ZoomSkeinItem*) itemData;
- (NSRect) activeAreaForData: (ZoomSkeinLayoutItem*) itemData;
- (NSRect) textAreaForData: (ZoomSkeinLayoutItem*) itemData;
- (ZoomSkeinItem*) itemAtPoint: (NSPoint) point;

// Drawing
- (void) drawInRect: (NSRect) rect;
- (void) drawItem: (ZoomSkeinItem*) item
		  atPoint: (NSPoint) point;
- (NSImage*) imageForItem: (ZoomSkeinItem*) item;
- (NSImage*) image;

@end
