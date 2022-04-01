//
//  IFProgress.m
//  Inform
//
//  Created by Andrew Hunter on 28/11/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import "IFProgress.h"

@implementation IFProgress {
    // Constants
    int  priority;
    BOOL showsProgressBar;
    BOOL canCancel;

    // Current state
    CGFloat percentage;
    NSString* message;
    BOOL storyActive;
    BOOL inProgress;

    BOOL cancelled;
    SEL  cancelActionSelector;
    id   cancelActionObject;

    // Delegate
    __weak id<IFProgressDelegate> delegate;
}

#pragma mark - Initialisation

- (instancetype) initWithPriority: (int) aPriority
       showsProgressBar: (BOOL) aShowsProgressBar
              canCancel: (BOOL) aCanCancel {
	self = [super init];
	
	if (self) {
        priority = aPriority;
		percentage = 0.0f;
		message = nil;
        cancelled = NO;
        inProgress = NO;
        showsProgressBar = aShowsProgressBar;
        canCancel = aCanCancel;
		
		delegate = nil;
	}
	
	return self;
}

#pragma mark - Setting the current progress

@synthesize percentage;
- (void) setPercentage: (CGFloat) newPercentage {
	percentage = newPercentage;
	
	if ([delegate respondsToSelector: @selector(progressIndicator:percentage:)]) {
		[delegate progressIndicator: self
						 percentage: newPercentage];
	}
}

@synthesize message;
- (void) setMessage: (NSString*) newMessage {
	message = [newMessage copy];

	if ([delegate respondsToSelector: @selector(progressIndicator:message:)]) {
		[delegate progressIndicator: self
							message: message];
	}
}

- (void) startStory {
    storyActive = YES;
	if ([delegate respondsToSelector: @selector(progressIndicatorStartStory:)]) {
		[delegate progressIndicatorStartStory: self];
	}
}

- (void) stopStory {
    storyActive = NO;
	if ([delegate respondsToSelector: @selector(progressIndicatorStopStory:)]) {
		[delegate progressIndicatorStopStory: self];
	}
}

- (void) startProgress {
    inProgress = YES;
    percentage = 0.0f;
	if ([delegate respondsToSelector: @selector(progressIndicatorStartProgress:)]) {
		[delegate progressIndicatorStartProgress: self];
	}
}

- (void) stopProgress {
    inProgress = NO;
    percentage = 0.0f;
	if ([delegate respondsToSelector: @selector(progressIndicatorStopProgress:)]) {
		[delegate progressIndicatorStopProgress: self];
	}
}

@synthesize storyActive;

#pragma mark - Setting the delegate

@synthesize delegate;


// Cancelling
- (void) setCancelAction: (SEL) selector
               forObject: (id) object {
    cancelActionSelector = selector;
    cancelActionObject = object;
}

- (void) cancelProgress {
    cancelled = YES;
    if( (cancelActionSelector != nil) && (cancelActionObject != nil)) {
        if( [cancelActionObject respondsToSelector: cancelActionSelector] ) {
            [cancelActionObject performSelectorOnMainThread: cancelActionSelector
                                                 withObject: cancelActionObject
                                              waitUntilDone: YES];
        }
    }
}

@synthesize cancelled;
@synthesize inProgress;
@synthesize priority;
@synthesize showsProgressBar;
@synthesize canCancel;

@end
