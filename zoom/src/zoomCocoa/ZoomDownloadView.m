//
//  ZoomDownloadView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 13/10/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "ZoomDownloadView.h"


@implementation ZoomDownloadView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		// Set up the image
		downloadImage = [[NSImage imageNamed: @"IFDB-downloading"] retain];
		
		// Set up the progress indicator
		progress = [[NSProgressIndicator alloc] initWithFrame: NSMakeRect(NSMinX(frame)+37, NSMinY(frame) + 24, frame.size.width-74, 16)];
		[progress setAutoresizingMask: NSViewWidthSizable|NSViewMaxYMargin];
		[progress setUsesThreadedAnimation: NO];
		
		[self addSubview: progress];
    }
    return self;
}

- (void) dealloc {
	[downloadImage release];
	
	[super dealloc];
}

- (void)drawRect:(NSRect)rect {
	NSSize imageSize = [downloadImage size];
	NSRect bounds = [self bounds];
	
	[[NSColor clearColor] set];
	NSRectFill(bounds);
	
	NSRect downloadRect;
	downloadRect.origin.x = NSMinX(bounds) + (bounds.size.width - imageSize.width) / 2;
	downloadRect.origin.y = NSMinY(bounds) + (bounds.size.height - imageSize.height) / 2;
	downloadRect.size = imageSize;
	[downloadImage drawInRect: downloadRect
					 fromRect: NSMakeRect(0,0, imageSize.width,imageSize.height)
					operation: NSCompositeSourceOver
					 fraction: 1.0];
}

- (BOOL) isOpaque {
	return NO;
}

- (NSProgressIndicator*) progress {
	return progress;
}

@end
