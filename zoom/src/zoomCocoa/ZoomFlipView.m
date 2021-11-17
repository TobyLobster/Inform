//
//  ZoomFlipView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 23/09/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import "ZoomFlipView.h"

@implementation ZoomFlipView

#pragma mark - Initialisation

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
		animationTime = 0.2;
    }
    return self;
}

- (void) dealloc {
	[self finishAnimation];
}

- (void) setupLayersForView: (NSView*) view {
	// Build the root layer
	if ([[self propertyDictionary] objectForKey: @"RootLayer"] == nil) {
		CALayer* rootLayer;
		[[self propertyDictionary] setObject: rootLayer = [CALayer layer]
									  forKey: @"RootLayer"];
		rootLayer.layoutManager = self;
		rootLayer.backgroundColor = [NSColor textBackgroundColor].CGColor;
		[rootLayer removeAllAnimations];
	}
	
	// Set up the layers for this view
	CALayer* viewLayer = [view layer];
	if (viewLayer== nil) {
		viewLayer = [CALayer layer];
		viewLayer.backgroundColor = [NSColor textBackgroundColor].CGColor;
		
		[view setLayer: viewLayer];
	}
	[viewLayer removeAllAnimations];
	
	[viewLayer setFrame: [[self layer] bounds]];
	viewLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
	
	if (![view wantsLayer]) {
		[view setWantsLayer: YES];
	}
	if (![self wantsLayer]) {
		[self setLayer: [[self propertyDictionary] objectForKey: @"RootLayer"]];
		[self setWantsLayer: YES];
	}
}

#pragma mark - Caching views

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

- (NSMutableDictionary*) propertyDictionary {
	if (props == nil) {
		props = [[NSMutableDictionary alloc] init];
	}
	
	return props;
}

#pragma mark - Animating

- (void) finishAnimation {
	if (originalView) {
		NSView* finalView =[[self propertyDictionary] objectForKey: @"FinalView"];
		if (finalView == nil) return;
		
		// Self destruct
		[originalView removeFromSuperview];
		
		// Move to the final view
		[[originalView layer] removeFromSuperlayer];
		
		originalView = finalView;
		[finalView setFrame: [self bounds]];
		
		// Set the properties for the new view
		[[self propertyDictionary] setObject: finalView
									  forKey: @"StartView"];
		[[self propertyDictionary] setObject: [finalView layer]
									  forKey: @"InitialLayer"];
		[[self propertyDictionary] removeObjectForKey: @"FinalLayer"];
		[[self propertyDictionary] removeObjectForKey: @"FinalView"];
	}
}

- (void) prepareToAnimateView: (NSView*) view {
	[self finishAnimation];
	
	if (view == nil) return;
	
	if ([[view superview] isKindOfClass: [self class]] && [[view layer] superlayer] != nil) {
		return;
	}
	
	[[self propertyDictionary] setObject: view
								  forKey: @"StartView"];
	
	// Setup the layers
	[self setupLayersForView: view];
	
	// Gather some information
	originalView = view;
	originalSuperview = [view superview];
	originalFrame = [view frame];
	
	// Move the view into this view
	[self setFrame: originalFrame];
	
	[view removeFromSuperviewWithoutNeedingDisplay];
	[view setFrame: [self bounds]];
	
	[self addSubview: view];
	//[[self layer] addSublayer: [view layer]];
	[[self propertyDictionary] setObject: [view layer]
								  forKey: @"InitialLayer"];
	
	// Move this view to where the original view was
	[self setAutoresizingMask: [view autoresizingMask]];
	[self removeFromSuperview];
	[self setFrame: originalFrame];
	[originalSuperview addSubview: self];
}

@synthesize animationTime;

- (void) animateTo: (NSView*) view
			 style: (ZoomViewAnimationStyle) style {
	if (view == nil || view == originalView) {
		return;
	}
	
	// If we're trying to re-animate a view that already has an animation, then continue to use that view
	if ([[view superview] isKindOfClass: [self class]] && [[view layer] superlayer] != nil) {
		[(ZoomFlipView*)[view superview] animateTo: view
											 style: style];
		return;
	}
	
	[[self propertyDictionary] setObject: view
								  forKey: @"FinalView"];
	
	// Setup the layers for the specified view
	[self setupLayersForView: originalView];
	[self setupLayersForView: view];
	
	// Move the view into this view
	
	[view removeFromSuperview];
	[view setFrame: [self bounds]];
	
	[self addSubview: view];
	//[[self layer] addSublayer: [view layer]];
	[[self propertyDictionary] setObject: [view layer]
								  forKey: @"FinalLayer"];
	[[self propertyDictionary] setObject: [originalView layer]
								  forKey: @"InitialLayer"];
	
	// Set the delegate and layout manager for this object
	[self layer].delegate = self;
	[self layer].layoutManager = nil;
	
	// Run the animation
	[self setAnimationStyle: style];
	
	// Prepare to run the animation
	CABasicAnimation* initialAnim	= [CABasicAnimation animation];
	CABasicAnimation* finalAnim		= [CABasicAnimation animation];
	NSRect bounds = [self bounds];
	
	// Set up the animations depending on the requested style
	initialAnim.keyPath		= @"bounds";
	initialAnim.fromValue	= @(bounds);
	initialAnim.toValue		= @(NSMakeRect(bounds.origin.x + bounds.size.width, bounds.origin.y, bounds.size.width, bounds.size.height));
	
	finalAnim.keyPath		= @"bounds";
	finalAnim.fromValue		= @(NSMakeRect(bounds.origin.x - bounds.size.width, bounds.origin.y, bounds.size.width, bounds.size.height));
	finalAnim.toValue		= @(bounds);
	
	// Set the common values
	initialAnim.timingFunction  = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut];
	initialAnim.duration		= [self animationTime] * 8;
	initialAnim.repeatCount		= 1;
	initialAnim.delegate		= self;
	
	finalAnim.timingFunction	= [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut];
	finalAnim.duration			= [self animationTime] * 8;
	finalAnim.repeatCount		= 1;
	//finalAnim.delegate			= self;
	
	// Animate the two views
	[[originalView layer] addAnimation: initialAnim
								forKey: nil];
	[[view layer] addAnimation: finalAnim
						forKey: nil];
}

- (CGFloat) percentDone {
	NSTimeInterval timePassed = -[whenStarted timeIntervalSinceNow];
	CGFloat done = ((CGFloat)timePassed)/((CGFloat)animationTime);
	
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

#pragma mark - Drawing


- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)flag {
	if (flag) [self finishAnimation];
}

#pragma mark - Animation properties

- (void) setAnimationStyle: (ZoomViewAnimationStyle) style {
	[[self propertyDictionary] setObject: @(style)
								  forKey: @"AnimationStyle"];
}

- (ZoomViewAnimationStyle) animationStyle {
	return [(NSNumber*)[[self propertyDictionary] objectForKey: @"AnimationStyle"] integerValue];
}

#pragma mark - Performing layout

- (void)layoutSublayersOfLayer:(CALayer *)layer {
	// TODO: if we ever make proper use of this, then this could be useful
	return;
}

@end
