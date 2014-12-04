//
//  ZoomHQImageView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 14/01/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import "ZoomHQImageView.h"


@implementation ZoomHQImageView

- (void)drawRect:(NSRect)rect {
	// Set the graphics context image rendering quality
	[[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
	
	// The rest is up to the image view (or would be, if it didn't promptly turn this off again)
	// [super drawRect: rect];
	
	NSRect bounds = [self bounds];
	NSSize imageSize = [[self image] size];
	NSRect imageBounds = [self bounds];
	float scaleFactor1 = (imageBounds.size.height-6)/imageSize.height;
	float scaleFactor2 = (imageBounds.size.width-6)/imageSize.width;
	
	float scaleFactor = scaleFactor1 < scaleFactor2?scaleFactor1:scaleFactor2;
	
	imageBounds.size.width = imageSize.width * scaleFactor;
	imageBounds.size.height = imageSize.height * scaleFactor;
	
	imageBounds.origin.x += (bounds.size.width-imageBounds.size.width)/2;
	imageBounds.origin.y += (bounds.size.height-imageBounds.size.height);
	
	[[self image] drawInRect: imageBounds
					fromRect: NSMakeRect(0,0,imageSize.width,imageSize.height)
				   operation: NSCompositeSourceOver
					fraction: 1.0];
}

- (void) mouseDown: (NSEvent*) event {
	if ([event clickCount] == 2 && [self target] != nil) {
		[self sendAction: [self action]
					  to: [self target]];
	}
}

@end
