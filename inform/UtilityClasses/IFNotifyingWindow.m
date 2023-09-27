//
//  IFNotifyingWindow.m
//  Inform
//
//  Created by Andrew Hunter on 06/01/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFNotifyingWindow.h"
#import "IFFindController.h"
#import "IFProjectController.h"

@protocol IFFirstResponder <NSObject>
- (void) changeFirstResponder: (NSResponder*) first;
@end

@implementation IFNotifyingWindow

- (BOOL) makeFirstResponder: (NSResponder*) aResponder {
	// Cocoa doesn't provide any way for us to track which window is the first responder: this
    // should hopefully correct that oversight
	BOOL res = [super makeFirstResponder: aResponder];

	if (res == YES) {
		// For convenience's sake, we assume that the delegate implements our changeFirstResponder: method
		// (this is bad practice in general, but saves a lot of hassle in this case as we aren't planning
		// to reuse this class)
		[(id<IFFirstResponder>)self.delegate changeFirstResponder: aResponder];
	}

	[[IFFindController sharedFindController] updateFromFirstResponder];
	return res;
}

@end
