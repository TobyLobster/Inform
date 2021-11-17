//
//  ZoomTextView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Oct 09 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ZoomView/ZoomUpperWindow.h>

@class ZoomUpperWindow;
@interface ZoomTextView : NSTextView {
    NSMutableArray<NSArray*>* pastedLines; // Array of arrays ([NSValue<rect>, NSAttributedString])
	
	BOOL dragged;
	CGFloat pastedScaleFactor;
}

- (void) pasteUpperWindowLinesFromZoomWindow: (ZoomUpperWindow*) win;
- (void) clearPastedLines;

@property CGFloat pastedLineScaleFactor;
- (void) offsetPastedLines: (CGFloat) offset;

@end
