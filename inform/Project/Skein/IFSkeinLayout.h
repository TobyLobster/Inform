//
//  IFSkeinLayout.h
//  Inform
//
//  Created by Toby Nelson
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class IFSkeinItem;
@class IFSkeinLayoutItem;

@interface IFSkeinLayout : NSObject

// Initialisation
- (instancetype) initWithRootItem: (nullable IFSkeinItem*) rootItem NS_DESIGNATED_INITIALIZER;

// Setting skein data
@property (atomic, strong, nullable) IFSkeinItem *        rootItem;
@property (atomic, strong, nullable) IFSkeinItem *        activeItem;
@property (atomic, strong, nullable) IFSkeinItem *        selectedItem;

// Layout equivalents
@property (atomic, strong, nullable) IFSkeinLayoutItem *  rootLayoutItem;       // nil until the skein is laid out
@property (atomic, strong, nullable) IFSkeinLayoutItem *  activeLayoutItem;
@property (atomic, strong, nullable) IFSkeinLayoutItem *  selectedLayoutItem;

@property (atomic, readonly)         NSPoint              reportPosition;

// Performing the layout
- (void) layoutSkein;

// Getting layout data
@property (atomic, readonly) int      levels;
@property (atomic, readonly) NSSize   size;

- (nullable IFSkeinItem*) itemAtPoint: (NSPoint) point;

- (NSRange) rangeOfLevelsBetweenMinViewY: (CGFloat) minY
                             andMaxViewY: (CGFloat) maxY;

- (void) updateLayoutWithReportDetails: (NSArray<NSNumber*>*) array;

@end

NS_ASSUME_NONNULL_END
