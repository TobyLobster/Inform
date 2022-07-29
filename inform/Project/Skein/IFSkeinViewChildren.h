//
//  IFSkeinViewChildren.h
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <AppKit/AppKit.h>
#import "IFSkeinReportView.h"

@class IFSkeinItem;
@class IFSkeinView;
@class IFSkeinLayout;
@class IFSkeinItemView;

@interface IFSkeinViewChildren : NSObject<IFSkeinReportBlessDelegate>

-(instancetype) initWithSkeinView:(IFSkeinView*) theSkeinView;
- (void) updateChildrenWithLayout: (IFSkeinLayout*) layout
                          animate: (BOOL) animate;

// Update and return report details

- (void)     updateReportDetails;
- (NSArray*) reportDetails;

- (NSRect)   rectForItem:(IFSkeinItem*) item;
- (IFSkeinLayoutItem*) layoutItemForItem: (IFSkeinItem*) item;
- (IFSkeinItemView*) itemViewForItem: (IFSkeinItem*) item;

// Handle font size change
-(void) fontSizePreferenceChanged;

@end
