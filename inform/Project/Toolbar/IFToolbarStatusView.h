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
-(void) setProgressMaxValue: (float) maxValue;
-(void) updateProgress: (float) progress;
-(void) setProgressIndeterminate: (BOOL) indeterminate;
-(void) stopProgress;

-(void) setDelegate: (IFToolbarManager*) delegate;
-(void) updateToolbar;

@end
