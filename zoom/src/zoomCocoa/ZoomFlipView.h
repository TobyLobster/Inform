//
//  ZoomFlipView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 23/09/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

typedef NS_ENUM(NSInteger, ZoomViewAnimationStyle) {
	ZoomAnimateLeft,
	ZoomAnimateRight,
	ZoomAnimateFade,
	
	ZoomCubeDown,
	ZoomCubeUp
};

///
/// NSView subclass that allows us to flip between several views using Core Animation.
///
@interface ZoomFlipView : NSView <CALayerDelegate, CALayoutManager, CAAnimationDelegate> {
	// Animation settings
	NSTimeInterval animationTime;
	ZoomViewAnimationStyle animationStyle;
	
	// Leopard property dictionary
	NSMutableDictionary* props;
	
	// Information used while animating
	NSRect originalFrame;
	NSView* originalView;
	NSView* originalSuperview;
	NSDate* whenStarted;	
}

// Animating
/// The animation time
@property NSTimeInterval animationTime;
/// Prepares to animate, using the specified view as a template
- (void) prepareToAnimateView: (NSView*) view;
/// Begins animating the specified view so that transitions from the state set in prepareToAnimateView to the new state
- (void) animateTo: (NSView*) view
			 style: (ZoomViewAnimationStyle) style;
/// Abandons any running animation
- (void) finishAnimation;
/// Property dictionary used for the leopard extensions
- (NSMutableDictionary*) propertyDictionary;

@end

@interface NSObject(ZoomViewAnimation)

/// Optional method implemented by views that is a request from the animation view to remove any applicable tracking rectangles
- (void) removeTrackingRects;
/// Optional method implemented by views that is a request from the animation view to add any tracking rectangles back again
- (void) setTrackingRects;

@end
