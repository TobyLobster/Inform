//
//  IFSkeinReportItemView.h
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@class IFSkeinBlessButton;

@interface IFSkeinReportItemView : NSView

@property (atomic, readonly) NSTextView*           textView;
@property (atomic) unsigned long                   uniqueId;
@property (atomic, readonly) CGFloat               textHeight;
@property (atomic) CGFloat                         topBorderHeight;
@property (atomic, readonly) IFSkeinBlessButton*   blessButton;


-(void) setAttributedString: (NSAttributedString*) string
                forceChange: (BOOL) forceChange;

@end

NS_ASSUME_NONNULL_END
