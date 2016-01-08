//
//  IFIsArrow.m
//  Inform
//
//  Created by Andrew Hunter on Fri Apr 30 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "IFIsArrow.h"
#import "IFIsArrowCell.h"


@implementation IFIsArrow

+ (void) initialize {
	[[self class] setCellClass: [IFIsArrowCell class]];
}

- (instancetype)initWithFrame:(NSRect)frameRect {
	self = [super initWithFrame: frameRect];
	
	if (self) {
	}
	
	return self;
}

- (void) setOpen: (BOOL) open {
	[[self cell] setIntValue: open?3:1];
	[self updateCell: [self cell]];
}

- (BOOL) open {
	return [[self cell] intValue] == 3;
}

- (void) performFlip {
	[(IFIsArrowCell*)[self cell] performFlip];
}

- (BOOL) acceptsFirstMouse: (NSEvent*) evt {
	return YES;
}

- (BOOL) isOpaque {
	return NO;
}

@end
