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

NS_SWIFT_UI_ACTOR
@interface IFSkeinLayout : NSObject

// Initialisation
/// A layout with no root item
- (instancetype) init;
- (instancetype) initWithRootItem: (nullable IFSkeinItem*) rootItem NS_DESIGNATED_INITIALIZER;

// Setting skein data
@property (nonatomic, strong, nullable) IFSkeinItem *               rootItem;
@property (nonatomic, strong, nullable) IFSkeinItem *               activeItem;
@property (nonatomic, strong, nullable) IFSkeinItem *               selectedItem;

// Layout equivalents
@property (nonatomic, readonly, strong, nullable) IFSkeinLayoutItem * rootLayoutItem;       // nil until the skein is laid out
@property (nonatomic, readonly, strong, nullable) IFSkeinLayoutItem * selectedLayoutItem;

@property (nonatomic, readonly)                   NSPoint             reportPosition;

// Performing the layout
- (void) layoutSkein;

// Getting layout data
@property (nonatomic, readonly) NSSize size;

- (nullable IFSkeinItem*) itemAtPoint: (NSPoint) point;

- (void) updateLayoutWithReportDetails: (NSArray<NSNumber*>*) array;

@end

NS_ASSUME_NONNULL_END
