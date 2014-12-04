//
//  ZoomScrollView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Oct 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

#import "ZoomView.h"
#import "ZoomUpperWindowView.h"

@class ZoomView;
@class ZoomUpperWindowView;
@interface ZoomScrollView : NSScrollView {
    ZoomView*            zoomView;
    ZoomUpperWindowView* upperView;
        
    NSBox* upperDivider;
	
	float scaleFactor;
	
	NSSize lastFixedSize;
	NSSize lastTileSize;
	int lastUpperSize;
	
	BOOL useDivider;
}

- (id) initWithFrame: (NSRect) frame
            zoomView: (ZoomView*) zView;

- (void) setScaleFactor: (float) factor;
- (void) updateUpperWindows;
- (ZoomUpperWindowView*) upperWindowView;

- (BOOL) setUseUpperDivider: (BOOL) useDivider;

@end
