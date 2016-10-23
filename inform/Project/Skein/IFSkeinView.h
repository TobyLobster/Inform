//
//  IFSkeinView.h
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <AppKit/AppKit.h>
#import <QuartzCore/CAAnimation.h>

@class IFSkein;
@class IFSkeinItem;
@class IFSkeinLayout;


@protocol IFSkeinViewDelegate

// Playing the game
- (void) stopGame;
- (void) playToPoint: (IFSkeinItem*) point
           fromPoint: (IFSkeinItem*) currentPoint;

@end



@interface IFSkeinView : NSView<NSTextViewDelegate, CAAnimationDelegate>

@property (atomic, strong)            IFSkein *           skein;
@property (atomic, strong, readonly)  IFSkeinLayout*      layoutTree;
@property (atomic, strong)            IFSkeinItem *       selectedItem;

@property (atomic, assign) NSObject<IFSkeinViewDelegate>* delegate;

- (void) layoutSkeinWithAnimation:(BOOL) animate;

- (void) selectItem: (IFSkeinItem*) item;
- (BOOL) selectItemWithNodeId: (unsigned long) skeinItemNodeId;
-(void) scrollViewToItem: (IFSkeinItem*) scrollToItem;

- (void) editItem: (IFSkeinItem*) skeinItem;

- (void) playToPoint: (IFSkeinItem*) item;
- (IFSkeinItem*) itemAtPoint:(NSPoint) point;
- (NSMenu *) menuForItem: (IFSkeinItem*) item;

- (void) setItemBlessed:(IFSkeinItem*) item bless:(BOOL) bless;
- (BOOL) hasMenu:(IFSkeinItem*) item;

- (void) saveTranscript: (id) sender;

// Font size handling
+ (float) fontSize;
- (void) fontSizePreferenceChanged: (NSNotification*) not;

- (BOOL) isAnyItemPurple;
- (BOOL) isAnyItemGrey;
- (BOOL) isAnyItemBlue;
- (BOOL) isReportVisible;
- (BOOL) isTickVisible;
- (BOOL) isCrossVisible;
- (BOOL) isBadgedItemVisible;
- (int) itemsVisible;

@end
