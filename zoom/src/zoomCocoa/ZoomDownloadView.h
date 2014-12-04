//
//  ZoomDownloadView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 13/10/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ZoomDownloadView : NSView {
	NSImage* downloadImage;						// The background image
	NSProgressIndicator* progress;				// The progress indicator
}

- (NSProgressIndicator*) progress;				// The download progress indicator

@end
