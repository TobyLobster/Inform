//
//  IFIsFlippedView.m
//  Inform
//
//  Created by Andrew Hunter on Mon May 03 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "IFIsFlippedView.h"


@implementation IFIsFlippedView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
    }
    return self;
}

- (void)drawRect:(NSRect)rect {
	[[NSColor windowBackgroundColor] set];
	NSRectFill(rect);
}

- (BOOL) isFlipped {
	return YES;
}

- (BOOL) isOpaque {
	return YES;
}

@end
