//
//  ZoomiFButton.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jan 22 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface ZoomiFButton : NSImageView {
	IBOutlet NSImage* pushedImage;
	NSImage* unpushedImage;
	NSImage* disabledImage;
	
	NSTrackingRectTag theTrackingRect;
	BOOL inside;
}

- (void) setPushedImage: (NSImage*) newPushedImage;

@end
