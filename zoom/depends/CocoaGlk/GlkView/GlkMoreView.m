//
//  GlkMoreView.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 09/10/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import "GlkMoreView.h"


@implementation GlkMoreView

+ (GlkSuperImage*) image {
#if defined(COCOAGLK_IPHONE)
	return [UIImage imageNamed:@"MorePrompt" inBundle:[NSBundle bundleForClass:[GlkMoreView class]] compatibleWithTraitCollection:nil];
#else
	return [[NSBundle bundleForClass: [self class]] imageForResource:@"MorePrompt"];
#endif
}

- (id) init {
#if defined(COCOAGLK_IPHONE)
	UIImage *img = [GlkMoreView image];
	
	CGRect frame;
	
	frame.origin = CGPointZero;
	frame.size = img.size;
#else
	NSRect frame;
	
	NSImageRep* rep = [[[GlkMoreView image] representations] objectAtIndex: 0];
	
	frame.origin = NSMakePoint(0,0);
	
	frame.size.width = [rep pixelsWide];
	frame.size.height = [rep pixelsHigh];
#endif
	
	return [self initWithFrame: frame];
}

- (id)initWithFrame:(GlkRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		moreImage = [GlkMoreView image];
#if !defined(COCOAGLK_IPHONE)
		[moreImage setCacheMode: NSImageCacheNever];
#endif
    }
    return self;
}

- (void)drawRect:(GlkRect)rect {
#if defined(COCOAGLK_IPHONE)
	[moreImage drawInRect: self.bounds];
#else
	NSRect imageRect;
	
	imageRect.origin = NSMakePoint(0,0);
	imageRect.size = [moreImage size];
	
	[moreImage drawInRect: [self bounds]
				 fromRect: imageRect
				operation: NSCompositingOperationSourceOver
				 fraction: 1.0];
#endif
}

- (BOOL) isOpaque {
	return NO;
}

@end
