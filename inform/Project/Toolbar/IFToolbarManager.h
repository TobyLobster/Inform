//
//  IFToolbarManager.h
//  Inform
//
//  Created by Toby Nelson in 2014.
//

#import "IFProjectController.h"
#import "IFToolbarStatusView.h"

@interface IFToolbarManager : NSObject<NSToolbarDelegate> {
    // The toolbar
    NSToolbar* toolbar;
    NSView* toolbarView;
    IFProjectController* projectController;
    IFToolbarStatusView* toolbarStatusView;

	// Progress indicators
	NSMutableArray* progressObjects;
}

- (id) initWithProjectController:(IFProjectController*) pc;
- (void) updateSettings;
- (void) setToolbar;
- (void) validateVisibleItems;
- (void) windowDidResize: (NSNotification*) notification;

// Status Messages
- (void) showMessage: (NSString*) message;
-(NSString*) toolbarIdentifier;

// Progress
- (void) updateProgress;
- (void) addProgressIndicator: (IFProgress*) indicator;
- (void) removeProgressIndicator: (IFProgress*) indicator;
- (void) progressIndicator: (IFProgress*) indicator
				percentage: (float) newPercentage;
- (void) progressIndicator: (IFProgress*) indicator
				   message: (NSString*) newMessage;
- (void) progressIndicatorStartStory: (IFProgress*) indicator;
- (void) progressIndicatorStopStory: (IFProgress*) indicator;
- (void) progressIndicatorStartProgress: (IFProgress*) indicator;
- (void) progressIndicatorStopProgress: (IFProgress*) indicator;
-(void) cancelProgress;

@end
