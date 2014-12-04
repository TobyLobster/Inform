//
//  ZoomLFlipView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 27/10/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "ZoomLFlipView.h"

#define NORECURSION									// Define to specify that no recursive animation should be allowed

@implementation ZoomFlipView(ZoomLeopardFlipView)

+ (id) flipViewClass {
	static id classId = nil;
	if (!classId) {
		classId = [objc_lookUpClass("ZoomFlipView") retain];
	}
	return classId;
}

- (void) setupLayersForView: (NSView*) view {
	// Build the root layer
	if ([[self propertyDictionary] objectForKey: @"RootLayer"] == nil) {
		CALayer* rootLayer;
		[[self propertyDictionary] setObject: rootLayer = [CALayer layer]
									  forKey: @"RootLayer"];
		rootLayer.layoutManager = self;
		rootLayer.backgroundColor = [NSColor whiteColor];
		[rootLayer removeAllAnimations];
	}

	// Set up the layers for this view
	CALayer* viewLayer = [view layer];
	if (viewLayer== nil) {
		static CGFloat white[4] = { 1.0, 1.0, 1.0, 1.0 };
		viewLayer = [CALayer layer];
		viewLayer.backgroundColor = [NSColor whiteColor];		

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

- (void) leopardPrepareViewForAnimation: (NSView*) view {
	if (view == nil) return;
	
	if ([[view superview] isKindOfClass: [self class]] && [[view layer] superlayer] != nil) {
		return;
	}
	
	[[self propertyDictionary] setObject: view
								  forKey: @"StartView"];
	
	// Setup the layers
	[self setupLayersForView: view];

	// Gather some information
	[originalView autorelease];
	[originalSuperview release];
	originalView = [view retain];
	originalSuperview = [[view superview] retain];
	originalFrame = [view frame];
	
	// Move the view into this view
	[[view retain] autorelease];
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

- (void) leopardAnimateTo: (NSView*) view
					style: (ZoomViewAnimationStyle) style {
	if (view == nil || view == originalView) {
		return;
	}
	
	// If we're trying to re-animate a view that already has an animation, then continue to use that view
	if ([[view superview] isKindOfClass: [self class]] && [[view layer] superlayer] != nil) {
		[(ZoomFlipView*)[view superview] leopardAnimateTo: view
													style: style];
		return;
	}	
	
	[[self propertyDictionary] setObject: view
								  forKey: @"FinalView"];

	// Setup the layers for the specified view
	[self setupLayersForView: originalView];
	[self setupLayersForView: view];

	// Move the view into this view
	[[view retain] autorelease];
	
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
	initialAnim.fromValue	= [NSValue valueWithRect: bounds];
	initialAnim.toValue		= [NSValue valueWithRect: NSMakeRect(bounds.origin.x + bounds.size.width, bounds.origin.y, bounds.size.width, bounds.size.height)];

	finalAnim.keyPath		= @"bounds";
	finalAnim.fromValue		= [NSValue valueWithRect: NSMakeRect(bounds.origin.x - bounds.size.width, bounds.origin.y, bounds.size.width, bounds.size.height)];
	finalAnim.toValue		= [NSValue valueWithRect: bounds];
	
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

- (void) leopardFinishAnimation {
	if (originalView) {
		NSView* finalView =[[self propertyDictionary] objectForKey: @"FinalView"];
		if (finalView == nil) return;
		
		// Ensure nothing gets freed prematurely
		[[self retain] autorelease];
		[[originalView retain] autorelease];
		[[finalView retain] autorelease];

		// Self destruct
		[originalView removeFromSuperview];
		
		// Move to the final view		
		[[originalView layer] removeFromSuperlayer];
		
		[originalView autorelease];
		originalView = [finalView retain];
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

- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)flag {
	if (flag) [self finishAnimation];
}

// = Animation properties =

- (void) setAnimationStyle: (ZoomViewAnimationStyle) style {
	[[self propertyDictionary] setObject: [NSNumber numberWithInt: style]
								  forKey: @"AnimationStyle"];
}

- (ZoomViewAnimationStyle) animationStyle {
	return [(NSNumber*)[[self propertyDictionary] objectForKey: @"AnimationStyle"] intValue];
}

// = Performing layout =

- (void)layoutSublayersOfLayer:(CALayer *)layer {
	// TODO: if we ever make proper use of this, then this could be useful
	return;
}

@end
