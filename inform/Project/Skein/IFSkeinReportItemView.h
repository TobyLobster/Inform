//
//  IFSkeinReportItemView.h
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <AppKit/AppKit.h>

@class IFSkeinBlessButton;

@interface IFSkeinReportItemView : NSView

@property (atomic) NSTextView*           textView;
@property (atomic) unsigned long         uniqueId;
@property (atomic) CGFloat               textHeight;
@property (atomic) CGFloat               topBorderHeight;
@property (atomic) IFSkeinBlessButton*   blessButton;


-(void) setAttributedString: (NSAttributedString*) string
                forceChange: (BOOL) forceChange;

@end
