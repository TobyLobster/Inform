//
//  IFSkeinLayoutItem.h
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class IFSkeinItem;

//
// A skein item's layout
//
@interface IFSkeinLayoutItem : NSObject

// Initialisation

- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithItem: (IFSkeinItem*) item
                 subtreeWidth: (CGFloat) subtreeWidth
                        level: (int) level NS_DESIGNATED_INITIALIZER;

// Setting/getting properties

@property (atomic, strong)             IFSkeinItem *       item;
@property (atomic)                     CGFloat             commandWidth;   // Width of the command
@property (atomic)                     CGFloat             subtreeWidth;   // Combined visible width of all the subtree from this item down
@property (atomic, readonly)           CGFloat             visibleWidth;   // Visible lozenge width
@property (atomic)                     NSRect              boundingRect;
@property (atomic, weak, nullable)     IFSkeinLayoutItem * parent;         // nil for the root
@property (nonatomic, copy, nullable)  NSArray<IFSkeinLayoutItem*> * children;   // nil until the layout sets them
@property (atomic)                     int                 level;
@property (atomic)                     BOOL                onSelectedLine;
@property (atomic)                     BOOL                recentlyPlayed;
@property (atomic, readonly)           int                 depth;
@property (atomic, readonly)           CGFloat             centreX;
@property (atomic, readonly)           NSRect              lozengeRect;
@property (atomic, readonly)           NSRect              localSpaceLozengeRect;
@property (atomic, readonly)           NSRect              textRect;

- (void) moveRightBy: (CGFloat) deltaX
         recursively: (BOOL) recursively;

@property (NS_NONATOMIC_IOSONLY, readonly, strong, nullable) IFSkeinLayoutItem *selectedLineChild;
@property (NS_NONATOMIC_IOSONLY, readonly, strong, nullable) IFSkeinLayoutItem *leafSelectedLineItem;

@property (NS_NONATOMIC_IOSONLY, readonly) NSUInteger drawStateHash;

@end

NS_ASSUME_NONNULL_END
