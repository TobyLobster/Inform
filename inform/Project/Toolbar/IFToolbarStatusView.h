//
//  IFToolbarStatusView.h
//  Inform
//
//  Created by Toby Nelson, 2014.
//

#import <Cocoa/Cocoa.h>

@class IFToolbarManager;
@class IFToolbarProgressIndicator;

@interface IFToolbarStatusView : NSView {
    NSString*                   title;
    float                       progress;
    float                       total;
    IFToolbarProgressIndicator* progressIndicator;
    BOOL                        isInProgress;
    BOOL                        isStoryActive;
    BOOL                        canCancel;

    NSTextField*                titleText;
    NSTextField*                storyText;
    NSButton*                   cancelButton;
    NSImage*                    informImage;

    // 'Welcome' objects
    NSTextField*                welcomeTitle;
    NSTextField*                welcomeBuild;
    NSImageView*                welcomeImageView;
    
    IFToolbarManager*           delegate;
}

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
