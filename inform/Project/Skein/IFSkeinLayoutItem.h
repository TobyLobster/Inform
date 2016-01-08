//
//  IFSkeinLayoutItem.h
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <Cocoa/Cocoa.h>

@class IFSkeinItem;

//
// A skein item's layout
//
@interface IFSkeinLayoutItem : NSObject

// Initialisation

- (instancetype) initWithItem: (IFSkeinItem*) item
                 subtreeWidth: (float) subtreeWidth
                        level: (int) level NS_DESIGNATED_INITIALIZER;

// Setting/getting properties

@property (atomic, strong)    IFSkeinItem *       item;
@property (atomic)            float               commandWidth;   // Width of the command
@property (atomic)            float               subtreeWidth;   // Combined visible width of all the subtree from this item down
@property (atomic, readonly)  float               visibleWidth;   // Visible lozenge width
@property (atomic)            NSRect              boundingRect;
@property (atomic, strong)    IFSkeinLayoutItem * parent;
@property (atomic, copy)      NSArray *           children;
@property (atomic)            int                 level;
@property (atomic)            BOOL                onSelectedLine;
@property (atomic)            BOOL                recentlyPlayed;
@property (atomic, readonly)  int                 depth;
@property (atomic, readonly)  float               centreX;
@property (atomic, readonly)  NSRect              lozengeRect;
@property (atomic, readonly)  NSRect              localSpaceLozengeRect;
@property (atomic, readonly)  NSRect              textRect;

- (void) moveRightBy: (float) deltaX
         recursively: (BOOL) recursively;

-(IFSkeinLayoutItem*) selectedLineChild;
- (IFSkeinLayoutItem*) leafSelectedLineItem;

-(unsigned long) drawStateHash;

@end
