//
//  ZoomWindowThatIsKey.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 14/10/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "ZoomWindowThatIsKey.h"


@implementation ZoomWindowThatIsKey

- (BOOL) isKeyWindow {
	return [[self parentWindow] isKeyWindow];
}

- (BOOL) isMainWindow {
	return [[self parentWindow] isMainWindow];
}

@end
