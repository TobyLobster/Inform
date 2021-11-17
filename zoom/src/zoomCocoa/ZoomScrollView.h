//
//  ZoomScrollView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Oct 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

#import <ZoomView/ZoomView.h>
#import <ZoomView/ZoomUpperWindowView.h>

@class ZoomView;
@class ZoomUpperWindowView;
@interface ZoomScrollView : NSScrollView {
    __weak ZoomView*            zoomView;
    ZoomUpperWindowView* upperView;
        
    NSBox* upperDivider;
	
	CGFloat scaleFactor;
	
	NSSize lastFixedSize;
	NSSize lastTileSize;
	int lastUpperSize;
	
	BOOL useDivider;
}

- (id) initWithFrame: (NSRect) frame
            zoomView: (ZoomView*) zView;

@property (nonatomic) CGFloat scaleFactor;
- (void) updateUpperWindows;
@property (readonly, strong) ZoomUpperWindowView *upperWindowView;

- (BOOL) setUseUpperDivider: (BOOL) useDivider;

@end
