//
//  IFSkeinView.h
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@class IFSkein;
@class IFSkeinItem;
@class IFSkeinLayout;


NS_SWIFT_UI_ACTOR
@protocol IFSkeinViewDelegate <NSObject>

// Playing the game
- (void) stopGame;
- (void) playToPoint: (IFSkeinItem*) point
           fromPoint: (IFSkeinItem*) currentPoint;

@end



@interface IFSkeinView : NSView<NSTextViewDelegate>

@property (nonatomic, strong, nullable)  IFSkein *           skein;
@property (atomic, strong, readonly)     IFSkeinLayout*      layoutTree;
@property (atomic, strong, nullable)     IFSkeinItem *       selectedItem;

@property (atomic, weak, nullable) id<IFSkeinViewDelegate> delegate;

- (void) selectItem: (nullable IFSkeinItem*) item withAnimation:(BOOL) animate;
- (BOOL) selectItemWithNodeId: (unsigned long) skeinItemNodeId;

- (nullable IFSkeinItem*) itemAtPoint:(NSPoint) point;
- (NSMenu *) menuForItem: (IFSkeinItem*) item;

- (void) setItemBlessed:(IFSkeinItem*) item bless:(BOOL) bless;
- (BOOL) hasMenu:(IFSkeinItem*) item;

- (void) saveTranscript: (nullable id) sender;

/// Font size handling
@property (class, atomic, readonly) CGFloat fontSize;

- (void) fontSizePreferenceChanged: (NSNotification*) not;

@property (atomic, readonly, getter=isAnyItemPurple) BOOL anyItemPurple;
@property (atomic, readonly, getter=isAnyItemGrey) BOOL anyItemGrey;
@property (atomic, readonly, getter=isAnyItemBlue) BOOL anyItemBlue;
@property (atomic, readonly, getter=isReportVisible) BOOL reportVisible;
@property (atomic, readonly, getter=isTickVisible) BOOL tickVisible;
@property (atomic, readonly, getter=isCrossVisible) BOOL crossVisible;
@property (atomic, readonly, getter=isBadgedItemVisible) BOOL badgedItemVisible;
@property (nonatomic, readonly) NSInteger itemsVisible;

@end

NS_ASSUME_NONNULL_END
