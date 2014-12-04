//
//  ZoomClearView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 28/10/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "ZoomClearView.h"


@implementation ZoomClearView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
    }
    return self;
}

- (void)drawRect:(NSRect)rect {
	NSRect bounds = [self bounds];
	
	[[NSColor clearColor] set];
	NSRectFill(bounds);
}

- (BOOL) isOpaque {
	return NO;
}

@end
