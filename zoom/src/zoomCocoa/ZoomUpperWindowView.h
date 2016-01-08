//
//  ZoomUpperWindowView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Oct 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "ZoomView.h"
#import "ZoomCursor.h"
#import "ZoomInputLine.h"

@class ZoomView;
@interface ZoomUpperWindowView : NSView {
    ZoomView* zoomView;	
	ZoomCursor* cursor;
	
	ZoomInputLine* inputLine;
	NSPoint inputLinePos;
}

- (instancetype)initWithFrame:(NSRect)frame
                     zoomView:(ZoomView*) view;

@property (NS_NONATOMIC_IOSONLY, readonly) NSPoint cursorPos;
- (void) updateCursor;
- (void) setFlashCursor: (BOOL) flash;

- (void) activateInputLine;

- (void) windowDidBecomeKey: (NSNotification*) not;
- (void) windowDidResignKey: (NSNotification*) not;

@end
