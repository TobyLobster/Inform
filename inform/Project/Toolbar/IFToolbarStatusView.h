//
//  IFToolbarStatusView.h
//  Inform
//
//  Created by Toby Nelson, 2014.
//

#import <Cocoa/Cocoa.h>

@class IFToolbarManager;
@class IFToolbarProgressIndicator;

@interface IFToolbarStatusView : NSView

@property (atomic) BOOL isExtensionProject;

-(void) showMessage: (NSString*) title;

-(void) startStory;
-(void) stopStory;

-(void) canCancel: (BOOL) canCancel;
-(void) startProgress;
-(void) setProgressMaxValue: (CGFloat) maxValue;
-(void) updateProgress: (CGFloat) progress;
-(void) setProgressIndeterminate: (BOOL) indeterminate;
-(void) stopProgress;

@property (weak, atomic) IFToolbarManager *delegate;
-(void) updateToolbar;

@end
