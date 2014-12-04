//
//  GlkArrangeEvent.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 22/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "GlkArrangeEvent.h"

#include "glk.h"

@implementation GlkArrangeEvent

// = Initialisation =

- (id) initWithGlkWindow: (GlkWindow*) window {
	self = [super initWithType: evtype_Arrange
			  windowIdentifier: [window identifier]];
	
	if (self) {
		// Nothing to do
	}
	
	return self;
}

@end
