//
//  IFSkeinViewChildren.h
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <AppKit/AppKit.h>
#import "IFSkeinReportView.h"

NS_ASSUME_NONNULL_BEGIN

@class IFSkeinItem;
@class IFSkeinView;
@class IFSkeinLayout;
@class IFSkeinItemView;

NS_SWIFT_UI_ACTOR
@interface IFSkeinViewChildren : NSObject<IFSkeinReportBlessDelegate>

-(instancetype) initWithSkeinView:(IFSkeinView*) theSkeinView;
- (void) updateChildrenWithLayout: (IFSkeinLayout*) layout
                          animate: (BOOL) animate;

// Update and return report details

- (void)     updateReportDetails;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray<NSNumber*> *reportDetails;

- (NSRect)   rectForItem:(IFSkeinItem*) item;
- (nullable IFSkeinLayoutItem*) layoutItemForItem: (IFSkeinItem*) item;
- (nullable IFSkeinItemView*) itemViewForItem: (IFSkeinItem*) item;

// Handle font size change
-(void) fontSizePreferenceChanged;

@end

NS_ASSUME_NONNULL_END
