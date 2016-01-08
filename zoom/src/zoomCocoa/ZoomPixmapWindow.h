//
//  ZoomPixmapWindow.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Jun 25 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZoomView.h"

@interface ZoomPixmapWindow : NSObject<ZPixmapWindow, NSCoding> {
	ZoomView* zView;
	NSImage* pixmap;
	
	NSPoint inputPos;
	ZStyle* inputStyle;
}

// Initialisation
- (instancetype) initWithZoomView: (ZoomView*) view NS_DESIGNATED_INITIALIZER;
- (void) setZoomView: (ZoomView*) view;

// Getting the pixmap
@property (NS_NONATOMIC_IOSONLY, readonly) NSSize size;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSImage *pixmap;

// Input information
@property (NS_NONATOMIC_IOSONLY, readonly) NSPoint inputPos;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) ZStyle *inputStyle;

@end
