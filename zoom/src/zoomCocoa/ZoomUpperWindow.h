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
@interface ZoomUpperWindow : NSObject<ZUpperWindow, NSCoding>

- (instancetype) initWithZoomView: (ZoomView*) view NS_DESIGNATED_INITIALIZER;

@property (NS_NONATOMIC_IOSONLY, readonly) int length;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray *lines;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSColor *backgroundColour;
- (void)     cutLines;

- (void) reformatLines;

- (void) setZoomView: (ZoomView*) view;

@end
