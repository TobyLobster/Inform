//
//  ZoomWhiteView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 23/09/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import "ZoomWhiteView.h"


@implementation ZoomWhiteView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
    }
    return self;
}

- (void)drawRect:(NSRect)rect {
	[[NSColor whiteColor] set];
	NSRectFill(rect);
}

@end
