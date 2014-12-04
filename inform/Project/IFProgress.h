//
//  IFProgress.h
//  Inform
//
//  Created by Andrew Hunter on 28/11/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

static const int IFProgressPriorityCompiler   = 40;
static const int IFProgressPriorityRunGame    = 30;
static const int IFProgressPriorityExtensions = 20;
static const int IFProgressPrioritySyntax     = 10;

//
// A progress indicator object
//
@interface IFProgress : NSObject {
    // Constants
    int  priority;
    BOOL showsProgressBar;
    BOOL canCancel;
    
    // Current state
	float percentage;
	NSString* message;
    BOOL storyActive;
    BOOL inProgress;

    BOOL cancelled;
    SEL  cancelActionSelector;
    id   cancelActionObject;

    // Delegate
	id delegate;
}

- (id) init __attribute__((unavailable));
- (id) initWithPriority: (int) aPriority
       showsProgressBar: (BOOL) showsProgressBar
              canCancel: (BOOL) canCancel;

// Set/get the current progress
- (void)	  setPercentage: (float) newPercentage;
- (void)	  setMessage: (NSString*) newMessage;
- (void)	  startStory;
- (void)	  stopStory;
- (void)      startProgress;
- (void)      stopProgress;

- (float)	  percentage;
- (NSString*) message;
- (BOOL)      storyActive;
- (BOOL)      isInProgress;

// Constants
- (int)       priority;
- (BOOL)      showsProgressBar;
- (BOOL)      canCancel;

// Setting the delegate
- (void) setDelegate: (id) delegate;
- (void) cancelProgress;
- (BOOL) isCancelled;
- (void) setCancelAction: (SEL) selector forObject:(id) object;

@end

//
// Progress indicator delegate methods
//
@interface NSObject(IFProgressDelegate)

- (void) progressIndicator: (IFProgress*) indicator
				percentage: (float) newPercentage;
- (void) progressIndicator: (IFProgress*) indicator
				   message: (NSString*) newMessage;
- (void) progressIndicatorStartStory: (IFProgress*) indicator;
- (void) progressIndicatorStopStory: (IFProgress*) indicator;
- (void) progressIndicatorStartProgress: (IFProgress*) indicator;
- (void) progressIndicatorStopProgress: (IFProgress*) indicator;

@end
