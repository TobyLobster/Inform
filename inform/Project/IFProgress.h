//
//  IFProgress.h
//  Inform
//
//  Created by Andrew Hunter on 28/11/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

static const int IFProgressPriorityTestAll    = 50;
static const int IFProgressPriorityCompiler   = 40;
static const int IFProgressPriorityRunGame    = 30;
static const int IFProgressPriorityExtensions = 20;
static const int IFProgressPrioritySyntax     = 10;

//
// A progress indicator object
//
@interface IFProgress : NSObject

- (instancetype) init __attribute__((unavailable));
- (instancetype) initWithPriority: (int) aPriority
       showsProgressBar: (BOOL) showsProgressBar
              canCancel: (BOOL) canCancel NS_DESIGNATED_INITIALIZER;

// Set/get the current progress
- (void)	  startStory;
- (void)	  stopStory;
- (void)      startProgress;
- (void)      stopProgress;

@property (atomic) float percentage;
@property (atomic, copy) NSString *message;
@property (atomic, readonly) BOOL storyActive;
@property (atomic, getter=isInProgress, readonly) BOOL inProgress;

// Constants
@property (atomic, readonly) int priority;
@property (atomic, readonly) BOOL showsProgressBar;
@property (atomic, readonly) BOOL canCancel;

// Setting the delegate
- (void) setDelegate: (id) delegate;
- (void) cancelProgress;
@property (atomic, getter=isCancelled, readonly) BOOL cancelled;
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
