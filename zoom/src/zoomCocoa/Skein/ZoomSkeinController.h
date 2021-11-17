//
//  ZoomSkeinController.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sun Jul 04 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

#import <ZoomView/ZoomSkein.h>
#import <ZoomView/ZoomSkeinView.h>

@interface ZoomSkeinController : NSWindowController <ZoomSkeinViewDelegate> {
	IBOutlet ZoomSkeinView* skeinView;
}

@property (class, readonly, strong) ZoomSkeinController *sharedSkeinController;

@property (nonatomic, strong) ZoomSkein *skein;

@end
