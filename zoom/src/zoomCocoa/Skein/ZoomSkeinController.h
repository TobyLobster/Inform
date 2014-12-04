//
//  ZoomSkeinController.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sun Jul 04 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

#import "ZoomSkein.h"
#import "ZoomSkeinView.h"

@interface ZoomSkeinController : NSWindowController {
	IBOutlet ZoomSkeinView* skeinView;
}

+ (ZoomSkeinController*) sharedSkeinController;

- (void) setSkein: (ZoomSkein*) skein;
- (ZoomSkein*) skein;

@end
