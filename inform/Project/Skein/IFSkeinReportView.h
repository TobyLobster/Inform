//
//  IFSkeinReportView.h
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@class IFSkein;
@class IFSkeinItem;
@class IFSkeinLayoutItem;


@protocol IFSkeinReportBlessDelegate<NSObject>

-(void) setItemBlessed:(IFSkeinItem*) item bless:(BOOL) bless;

@end

@interface IFSkeinReportView : NSView

@property (atomic, strong)           NSMutableArray<NSNumber*>* reportDetails;
@property (atomic, strong, nullable) IFSkeinLayoutItem*         rootTree;
@property (atomic, weak, nullable)   id<IFSkeinReportBlessDelegate> delegate;
@property (atomic)                   BOOL                       forceResizeDueToFontSizeChange;


-(void) updateReportDetails;
-(NSRect) rectForItem:(IFSkeinLayoutItem*) layoutItem;

// Handle font size preference changes
+(void) adjustAttributesToFontSize;

@end

NS_ASSUME_NONNULL_END
