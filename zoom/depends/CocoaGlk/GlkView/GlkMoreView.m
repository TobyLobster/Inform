//
//  GlkMoreView.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 09/10/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import "GlkMoreView.h"


@implementation GlkMoreView

+ (NSImage*) image {
	return [[[NSImage alloc] initWithContentsOfFile: [[NSBundle bundleForClass: [self class]] pathForImageResource: @"MorePrompt"]] autorelease];
}

- (id) init {
	NSRect frame;
	
	NSImageRep* rep = [[[GlkMoreView image] representations] objectAtIndex: 0];
	
	frame.origin = NSMakePoint(0,0);
	
	frame.size.width = [rep pixelsWide];
	frame.size.height = [rep pixelsHigh];
	
	return [self initWithFrame: frame];
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		moreImage = [[GlkMoreView image] retain];
		[moreImage setCacheMode: NSImageCacheNever];
    }
    return self;
}

- (void) dealloc {
	[moreImage release];
	
	[super dealloc];
}

- (void)drawRect:(NSRect)rect {
	NSRect imageRect;
	
	imageRect.origin = NSMakePoint(0,0);
	imageRect.size = [moreImage size];
	
	[moreImage drawInRect: [self bounds]
				 fromRect: imageRect
				operation: NSCompositeSourceOver
				 fraction: 1.0];
}

- (BOOL) isOpaque {
	return NO;
}

@end
