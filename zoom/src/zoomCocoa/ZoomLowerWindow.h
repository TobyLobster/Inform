//
//  ZoomLowerWindow.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Oct 08 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZoomProtocol.h"
#import "ZoomView.h"

@interface ZoomLowerWindow : NSObject<ZLowerWindow, NSCoding> {
    ZoomView* zoomView;
	
	ZStyle* backgroundStyle;
	ZStyle* inputStyle;
}

- (instancetype) initWithZoomView: (ZoomView*) zoomView NS_DESIGNATED_INITIALIZER;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) ZStyle *backgroundStyle;

- (void) setZoomView: (ZoomView*) view;

@end
