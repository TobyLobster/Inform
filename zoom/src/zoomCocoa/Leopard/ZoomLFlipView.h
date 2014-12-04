//
//  ZoomLFlipView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 27/10/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZoomFlipView.h"

///
/// A ZoomFlipView category that lets us use Core Animation instead of the standard flip view when
/// performing animations.
/// 
@interface ZoomFlipView(ZoomLeopardFlipView)

- (void) leopardPrepareViewForAnimation: (NSView*) view;					// Prepares the specified view for animation
- (void) leopardAnimateTo: (NSView*) view									// Causes an animation to occur
					style: (ZoomViewAnimationStyle) style;
- (void) leopardFinishAnimation;											// Causes the animation to stop

@end
