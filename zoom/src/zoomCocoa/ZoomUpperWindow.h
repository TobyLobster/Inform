//
//  ZoomUpperWindow.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Oct 09 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZoomView.h"

@class ZoomView;
@interface ZoomUpperWindow : NSObject<ZUpperWindow, NSCoding> {
    ZoomView* theView;

    int startLine, endLine;

    NSMutableArray* lines;
    int xpos, ypos;

    NSColor* backgroundColour;
	ZStyle* inputStyle;
}

- (id) initWithZoomView: (ZoomView*) view;

- (int) length;
- (NSArray*) lines;
- (NSColor*) backgroundColour;
- (void)     cutLines;

- (void) reformatLines;

- (void) setZoomView: (ZoomView*) view;

@end
