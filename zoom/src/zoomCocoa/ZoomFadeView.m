//
//  ZoomFadeView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 23/09/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import "ZoomFadeView.h"


@implementation ZoomFadeView

static NSImage* fade = nil;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		if (fade == nil) {
			fade = [[NSImage imageNamed: @"top-shading"] retain];
		}
    }
    return self;
}

- (void)drawRect:(NSRect)rect {
	[[NSColor colorWithPatternImage: fade] set];
	[[NSGraphicsContext currentContext] setPatternPhase: [self convertPoint: NSMakePoint(0,0)
																	 toView: nil]];

	NSRectFill(rect);
}

@end
