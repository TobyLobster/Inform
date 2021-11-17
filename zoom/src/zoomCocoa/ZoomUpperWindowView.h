//
//  ZoomUpperWindowView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Oct 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <ZoomView/ZoomView.h>
#import <ZoomView/ZoomCursor.h>
#import <ZoomView/ZoomInputLine.h>

@class ZoomView;
@interface ZoomUpperWindowView : NSView <ZoomInputLineDelegate, ZoomCursorDelegate, NSAccessibilityStaticText> {
    __weak ZoomView* zoomView;	
	ZoomCursor* cursor;
	
	ZoomInputLine* inputLine;
	NSPoint inputLinePos;
}
- (instancetype)initWithFrame:(NSRect)frame zoomView:(ZoomView*) view;
@property (readonly) NSPoint cursorPos;
- (void) updateCursor;
- (void) setFlashCursor: (BOOL) flash;

- (void) activateInputLine;

- (void) windowDidBecomeKey: (NSNotification*) noti;
- (void) windowDidResignKey: (NSNotification*) noti;

@end
