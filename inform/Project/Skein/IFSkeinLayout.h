//
//  IFSkeinLayout.h
//  Inform
//
//  Created by Toby Nelson
//

#import <Cocoa/Cocoa.h>

@class IFSkeinItem;
@class IFSkeinLayoutItem;

@interface IFSkeinLayout : NSObject

// Initialisation
- (instancetype) initWithRootItem: (IFSkeinItem*) rootItem NS_DESIGNATED_INITIALIZER;

// Setting skein data
@property (atomic, strong)   IFSkeinItem *        rootItem;
@property (atomic, strong)   IFSkeinItem *        activeItem;
@property (atomic, strong)   IFSkeinItem *        selectedItem;

// Layout equivalents
@property (atomic, strong)   IFSkeinLayoutItem *  rootLayoutItem;
@property (atomic, strong)   IFSkeinLayoutItem *  activeLayoutItem;
@property (atomic, strong)   IFSkeinLayoutItem *  selectedLayoutItem;

@property (atomic, readonly) NSPoint              reportPosition;

// Performing the layout
- (void) layoutSkein;

// Getting layout data
@property (atomic, readonly) int      levels;
@property (atomic, readonly) NSSize   size;

- (IFSkeinItem*) itemAtPoint: (NSPoint) point;

- (NSRange) rangeOfLevelsBetweenMinViewY: (float) minY
                             andMaxViewY: (float) maxY;

- (void) updateLayoutWithReportDetails: (NSArray*) array;

@end
