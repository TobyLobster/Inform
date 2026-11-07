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

@property (nonatomic, strong)          IFSkeinItem *       item;
@property (nonatomic)                  CGFloat             commandWidth;   // Width of the command
@property (nonatomic)                  CGFloat             subtreeWidth;   // Combined visible width of all the subtree from this item down
@property (nonatomic, readonly)        CGFloat             visibleWidth;   // Visible lozenge width
@property (nonatomic)                  NSRect              boundingRect;
@property (nonatomic, weak, nullable)  IFSkeinLayoutItem * parent;         // nil for the root
@property (nonatomic, copy, nullable)  NSArray<IFSkeinLayoutItem*> * children;   // nil until the layout sets them
@property (nonatomic)                  int                 level;
@property (nonatomic)                  BOOL                onSelectedLine;
@property (nonatomic)                  BOOL                recentlyPlayed;
@property (nonatomic, readonly)        CGFloat             centreX;
@property (nonatomic, readonly)        NSRect              lozengeRect;
@property (nonatomic, readonly)        NSRect              localSpaceLozengeRect;
@property (nonatomic, readonly)        NSRect              textRect;

- (void) moveRightBy: (CGFloat) deltaX
         recursively: (BOOL) recursively;

@property (nonatomic, readonly, strong, nullable)IFSkeinLayoutItem *selectedLineChild;
@property (nonatomic, readonly, strong, nullable)IFSkeinLayoutItem *leafSelectedLineItem;

@property (nonatomic, readonly) NSUInteger drawStateHash;

@end

NS_ASSUME_NONNULL_END
