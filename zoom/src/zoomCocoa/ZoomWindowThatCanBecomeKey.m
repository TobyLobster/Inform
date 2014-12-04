//
//  ZoomWindowThatCanBecomeKey.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 19/10/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "ZoomWindowThatCanBecomeKey.h"


@implementation ZoomWindowThatCanBecomeKey

- (BOOL) canBecomeKeyWindow {
	// Yargh, why isn't this the default behaviour?
	// Apparently this is still broken, but in a way that shouldn't matter for our purposes: see CocoaDev
	return YES;
}

@end
