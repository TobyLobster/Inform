//
//  IFToolbarStatusView.h
//  Inform
//
//  Created by Toby Nelson, 2014.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class IFToolbarManager;

@interface IFToolbarStatusView : NSView

-(void) showMessage: (NSString*) title;

-(void) startStory;
-(void) stopStory;

-(void) canCancel: (BOOL) canCancel;
-(void) startProgress;
-(void) setProgressMaxValue: (CGFloat) maxValue;
-(void) updateProgress: (CGFloat) progress;
-(void) setProgressIndeterminate: (BOOL) indeterminate;
-(void) stopProgress;

@property (weak, atomic, nullable) IFToolbarManager *delegate;
-(void) updateToolbar;

@end

NS_ASSUME_NONNULL_END
