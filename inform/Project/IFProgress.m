//
//  IFProgress.m
//  Inform
//
//  Created by Andrew Hunter on 28/11/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import "IFProgress.h"

@implementation IFProgress

// = Initialisation =

- (id) initWithPriority: (int) aPriority
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

- (void) dealloc {
	if (message) [message release];
	
	[super dealloc];
}

// = Setting the current progress =

- (void) setPercentage: (float) newPercentage {
	percentage = newPercentage;
	
	if (delegate && [delegate respondsToSelector: @selector(progressIndicator:percentage:)]) {
		[delegate progressIndicator: self
						 percentage: newPercentage];
	}
}

- (void) setMessage: (NSString*) newMessage {
	if (message) [message release];
	message = [newMessage copy];
	
	if (delegate && [delegate respondsToSelector: @selector(progressIndicator:message:)]) {
		[delegate progressIndicator: self
							message: message];
	}
}

- (void) startStory {
    storyActive = YES;
	if (delegate && [delegate respondsToSelector: @selector(progressIndicatorStartStory:)]) {
		[delegate progressIndicatorStartStory: self];
	}
}

- (void) stopStory {
    storyActive = NO;
	if (delegate && [delegate respondsToSelector: @selector(progressIndicatorStopStory:)]) {
		[delegate progressIndicatorStopStory: self];
	}
}

- (void) startProgress {
    inProgress = YES;
    percentage = 0.0f;
	if (delegate && [delegate respondsToSelector: @selector(progressIndicatorStartProgress:)]) {
		[delegate progressIndicatorStartProgress: self];
	}
}

- (void) stopProgress {
    inProgress = NO;
    percentage = 0.0f;
	if (delegate && [delegate respondsToSelector: @selector(progressIndicatorStopProgress:)]) {
		[delegate progressIndicatorStopProgress: self];
	}
}

- (float) percentage {
	return percentage;
}

- (NSString*) message {
	return message;
}

- (BOOL) storyActive {
    return storyActive;
}

// = Setting the delegate =

- (void) setDelegate: (id) newDelegate {
	delegate = newDelegate;
}


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

- (BOOL) isCancelled {
    return cancelled;
}

- (BOOL) isInProgress {
    return inProgress;
}

- (int) priority {
    return priority;
}

- (BOOL) showsProgressBar {
    return showsProgressBar;
}

- (BOOL)      canCancel {
    return canCancel;
}
@end
