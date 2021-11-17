//
//  ZoomLowerWindow.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Oct 08 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <ZoomView/ZoomProtocol.h>
#import <ZoomView/ZoomView.h>

@interface ZoomLowerWindow : NSObject<ZLowerWindow, NSSecureCoding> {
	ZStyle* backgroundStyle;
	ZStyle* inputStyle;
}

- (instancetype) initWithZoomView: (ZoomView*) zoomView;

@property (readonly, strong) ZStyle *backgroundStyle;

@property (weak) ZoomView *zoomView;

@end
