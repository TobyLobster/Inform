//
//  IFClickThroughScrollView.m
//  Inform-xc2
//
//  Created by Andrew Hunter on 06/01/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import "IFClickThroughScrollView.h"


@implementation IFClickThroughScrollView

- (void) mouseDown: (NSEvent*) event {
	// Pass the event through to the contained view
	[[self documentView] mouseDown: event];
	
	// Continue as normal
	[super mouseDown: event];
}

@end
