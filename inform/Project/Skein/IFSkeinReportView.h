//
//  IFSkeinReportView.h
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <AppKit/AppKit.h>

@class IFSkein;
@class IFSkeinItem;
@class IFSkeinLayoutItem;


@protocol IFSkeinReportBlessDelegate<NSObject>

-(void) setItemBlessed:(IFSkeinItem*) item bless:(BOOL) bless;

@end

@interface IFSkeinReportView : NSView

@property (atomic, strong) NSMutableArray*    reportDetails;
@property (atomic, strong) IFSkeinLayoutItem* rootTree;
@property (atomic, strong) id<IFSkeinReportBlessDelegate> delegate;
@property (atomic)         BOOL               forceResizeDueToFontSizeChange;


-(void) updateReportDetails;
-(NSRect) rectForItem:(IFSkeinLayoutItem*) layoutItem;

// Handle font size preference changes
+(void) adjustAttributesToFontSize;

@end
