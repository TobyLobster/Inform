//
//  ZoomSkeinController.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sun Jul 04 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomSkeinController.h"

@implementation ZoomSkeinController

+ (ZoomSkeinController*) sharedSkeinController {
	static ZoomSkeinController* cont = nil;
	
	if (!cont) {
		cont = [[[self class] alloc] init];
	}
	
	return cont;
}

- (id) init {
	self = [self initWithWindowNibName: @"Skein"];
	
	if (self) {
	}
	
	return self;
}

- (void) awakeFromNib {
	[(NSPanel*)[self window] setBecomesKeyOnlyIfNeeded: YES];
	[skeinView setDelegate: self];
}

- (void) setSkein: (ZoomSkein*) skein {
	if (skeinView == nil) {
		[self loadWindow];
	}
	
	[skeinView setSkein: skein];
}

- (ZoomSkein*) skein {
	return [skeinView skein];
}

- (void) restartGame {
	id controller  = [[NSApp mainWindow] windowController];
	if ([controller respondsToSelector: @selector(restartGame)]) {
		[controller restartGame];
	}
}

- (void) playToPoint: (ZoomSkeinItem*) point
		   fromPoint: (ZoomSkeinItem*) fromPoint {
	id controller  = [[NSApp mainWindow] windowController];
	if ([controller respondsToSelector: @selector(playToPoint:fromPoint:)]) {
		[controller playToPoint: point
					  fromPoint: fromPoint];
	}
}

@end
