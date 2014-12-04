//
//  ZoomFlipView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 23/09/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import "ZoomFlipView.h"
#import "ZoomLFlipView.h"

@implementation ZoomFlipView

// = Initialisation =

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
		animationTime = 0.2;
#ifdef FlipUseCoreAnimation
		useCoreAnimation = YES;
#else
		useCoreAnimation = NO;
#endif
    }
    return self;
}

- (void) dealloc {
	[self finishAnimation];
	
	[startImage release];
	[endImage release];
	[whenStarted release];
	[props autorelease];
	
	[super dealloc];
}

// = Caching views =

+ (void) detrackView: (NSView*) view {
	if ([view respondsToSelector: @selector(removeTrackingRects)]) {
		[view removeTrackingRects];
	}
}

+ (void) trackView: (NSView*) view {
	if ([view respondsToSelector: @selector(setTrackingRects)]) {
		[view setTrackingRects];
	}
}

+ (NSImage*) cacheView: (NSView*) view {
	// TODO: instead of putting the view on the cached window, could directly call drawRect: on the
	// view and its subviews, with the display focus locked to the image instead of the 'real' window.
	
	// Create the cached representation of the view
	NSRect viewFrame = [view frame];
	NSCachedImageRep* cacheRep = [[NSCachedImageRep alloc] initWithSize: viewFrame.size
																  depth: [[NSScreen deepestScreen] depth]
															   separate: YES
																  alpha: YES];
	
	// Move the view to the cached rep's window
	NSView* oldParent = [view superview];
	[ZoomFlipView detrackView: view];
	[view removeFromSuperviewWithoutNeedingDisplay];
	
	if ([[cacheRep window] contentView] == nil) {
		[[cacheRep window] setContentView: [[[NSView alloc] init] autorelease]];
	}
	[[cacheRep window] setBackgroundColor: [NSColor clearColor]];
	
	[view setFrame: [cacheRep rect]];
	[[[cacheRep window] contentView] addSubview: view];
	[view setNeedsDisplay: YES];
	
	// Draw the view (initialising the image)
	[[[cacheRep window] contentView] display];
	
	// Move the view back to where it belongs
	[ZoomFlipView detrackView: view];
	[view removeFromSuperviewWithoutNeedingDisplay];
	[view setFrame: viewFrame];
	[oldParent addSubview: view];
	
	[ZoomFlipView trackView: view];
	
	// Construct the final image
	NSImage* result = [[NSImage alloc] initWithSize: viewFrame.size];
	
	NSArray* representations = [[[result representations] copy] autorelease];
	NSEnumerator* repEnum = [representations objectEnumerator];
	NSImageRep* rep;
	while (rep = [repEnum nextObject]) {
		[result removeRepresentation: rep];
	}
	
	[result addRepresentation: [cacheRep autorelease]];
	return [result autorelease];
}

- (void) cacheStartView: (NSView*) view {
	[startImage release];
	startImage = [[[self class] cacheView: view] retain];
}

- (NSMutableDictionary*) propertyDictionary {
	if (props == nil) {
		props = [[NSMutableDictionary alloc] init];
	}
	
	return props;
}

// = Animating =

- (void) finishAnimation {
	if (useCoreAnimation && [self respondsToSelector: @selector(leopardFinishAnimation)]) {
		[self leopardFinishAnimation];
	} else {
		if (animationTimer) [self autorelease];
		[animationTimer invalidate]; [animationTimer release]; animationTimer = nil;
		
		if (originalView != nil) {
			[[self retain] autorelease];

			[self removeFromSuperview];
			
			NSRect frame = originalFrame;
			frame.size = [originalView frame].size;
			
			[originalView setFrame: frame];
			[originalSuperview addSubview: originalView];
			[originalView setNeedsDisplay: YES];
			[pixelBuffer release]; pixelBuffer = nil;
			[ZoomFlipView trackView: originalView];
			
			[originalView release]; originalView = nil;
			[originalSuperview release]; originalSuperview = nil;
		}		
	}
}

- (void) prepareToAnimateView: (NSView*) view {
	[self finishAnimation];
	
	if (useCoreAnimation && [self respondsToSelector: @selector(leopardPrepareViewForAnimation:)]) {
		[self leopardPrepareViewForAnimation: view];
	} else {
		// Cache the initial view
		[self cacheStartView: view];
		
		// Replace the specified view with the animating view (ie, this view)
		[originalView autorelease];
		[originalSuperview release];
		originalView = [view retain];
		originalSuperview = [[view superview] retain];
		originalFrame = [view frame];
		
		[ZoomFlipView detrackView: originalView];
		[originalView removeFromSuperviewWithoutNeedingDisplay];
		[self setFrame: originalFrame];
		[originalSuperview addSubview: self];
		[self setNeedsDisplay: YES];
		
		[self setAutoresizingMask: [originalView autoresizingMask]];		
	}
}

- (void) setAnimationTime: (NSTimeInterval) newAnimationTime {
	animationTime = newAnimationTime;
}

- (NSTimeInterval) animationTime {
	return animationTime;
}

- (void) animateTo: (NSView*) view
			 style: (ZoomViewAnimationStyle) style {
	if (useCoreAnimation && [self respondsToSelector: @selector(leopardAnimateTo:style:)]) {
		[self leopardAnimateTo: view
						 style: style];
	} else {
		[whenStarted release];
		whenStarted = [[NSDate date] retain];
		
		// Create the final image
		[endImage release];
		endImage = [[[self class] cacheView: view] retain];
		
		
		// Construct the pixel buffer for this animation
	#if 0
		switch (style) {
			case ZoomCubeUp:
			case ZoomCubeDown:
				NSRect bounds = [self bounds];
				
				pixelBuffer = [[NSOpenGLPixelBuffer alloc] initWithTextureTarget: GL_TEXTURE_RECTANGLE_EXT
														   textureInternalFormat: GL_RGBA
														   textureMaxMipMapLevel: 0
																	  pixelsWide: bounds.size.width
																	  pixelsHigh: bounds.size.height];
		}
	#endif
		
		// Replace the specified view with the animating view (ie, this view)
		[originalView autorelease];
		originalView = [view retain];
		originalFrame = [view frame];
		
		[ZoomFlipView detrackView: originalView];
		[self setFrame: originalFrame];
		[originalSuperview addSubview: self];
		[self setNeedsDisplay: YES];
		
		// Start running the animation
		[self retain];
		animationStyle = style;
		animationTimer = [[NSTimer timerWithTimeInterval: 0.01
												  target: self
												selector: @selector(animationTick)
												userInfo: nil
												 repeats: YES] retain];
		
		[[NSRunLoop currentRunLoop] addTimer: animationTimer
									 forMode: NSDefaultRunLoopMode];
		[[NSRunLoop currentRunLoop] addTimer: animationTimer
									 forMode: NSEventTrackingRunLoopMode];
	}
}

- (float) percentDone {
	NSTimeInterval timePassed = -[whenStarted timeIntervalSinceNow];
	float done = ((float)timePassed)/((float)animationTime);
	
	if (done < 0) done = 0;
	if (done > 1) done = 1.0;
	
	done = -2.0*done*done*done + 3.0*done*done;
	
	return done;
}

- (void) animationTick {
	if ([self percentDone] >= 1.0)
		[self finishAnimation];
	else
		[self setNeedsDisplay: YES];
}

// = Drawing =

- (void)drawRect:(NSRect)rect {
	if (useCoreAnimation && [self respondsToSelector: @selector(leopardAnimateTo:style:)]) {
		return;
	}
		
	float percentDone = [self percentDone];
	float percentNotDone = 1.0-percentDone;
	
	NSRect bounds = [self bounds];
	NSSize startSize = [startImage size];
	NSSize endSize = [endImage size];
	NSRect startFrom, startTo;
	NSRect endFrom, endTo;
	
	switch (animationStyle) {
		case ZoomAnimateLeft:
			// Work out where to place the images
			startFrom.origin = NSMakePoint(startSize.width*percentDone, 0);
			startFrom.size = NSMakeSize(startSize.width*percentNotDone, startSize.height);
			startTo.origin = NSMakePoint(0, NSMaxY(bounds)-startSize.height);
			startTo.size = startFrom.size;
			
			endFrom.origin = NSMakePoint(0, 0);
			endFrom.size = NSMakeSize(endSize.width*percentDone, endSize.height);
			endTo.origin = NSMakePoint(startSize.width*percentNotDone, NSMaxY(bounds)-endSize.height);
			endTo.size = endFrom.size;
			
			// Draw them
			[startImage drawInRect: startTo
						  fromRect: startFrom
						 operation: NSCompositeSourceOver
						  fraction: 1.0];
			[endImage drawInRect: endTo
						fromRect: endFrom
					   operation: NSCompositeSourceOver
						fraction: 1.0];
			break;
			
		case ZoomAnimateRight:
			// Work out where to place the images
			startFrom.origin = NSMakePoint(0, 0);
			startFrom.size = NSMakeSize(startSize.width*percentNotDone, startSize.height);
			startTo.origin = NSMakePoint(startSize.width*percentDone, NSMaxY(bounds)-startSize.height);
			startTo.size = startFrom.size;
			
			endFrom.origin = NSMakePoint(endSize.width*percentNotDone, 0);
			endFrom.size = NSMakeSize(endSize.width*percentDone, endSize.height);
			endTo.origin = NSMakePoint(0, NSMaxY(bounds)-endSize.height);
			endTo.size = endFrom.size;
			
			// Draw them
			[startImage drawInRect: startTo
						  fromRect: startFrom
						 operation: NSCompositeSourceOver
						  fraction: 1.0];
			[endImage drawInRect: endTo
						fromRect: endFrom
					   operation: NSCompositeSourceOver
						fraction: 1.0];
			break;
			
		case ZoomAnimateFade:
			// Draw the images
			startFrom.origin = NSMakePoint(0, 0);
			startFrom.size = startSize;
			startTo.origin = NSMakePoint(0,0);
			startTo.size = startFrom.size;
			
			endFrom.origin = NSMakePoint(0, 0);
			endFrom.size = endSize;
			endTo.origin = NSMakePoint(0, 0);
			endTo.size = endFrom.size;

			[startImage drawInRect: startTo
						  fromRect: startFrom
						 operation: NSCompositeSourceOver
						  fraction: 1.0];
			[endImage drawInRect: endTo
						fromRect: endFrom
					   operation: NSCompositeSourceOver
						fraction: percentDone];			
			break;
	}
}

@end
