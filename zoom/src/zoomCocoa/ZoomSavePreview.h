//
//  ZoomSavePreview.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Mar 27 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

#import "ZoomUpperWindow.h"

@interface ZoomSavePreview : NSView {
	NSString* filename;
	ZoomUpperWindow* preview;
	NSArray* previewLines;
	
	BOOL highlighted;
}

- (id) initWithPreview: (ZoomUpperWindow*) prev
			  filename: (NSString*) filename;
- (id) initWithPreviewStrings: (NSArray*) prev
					 filename: (NSString*) filename;
- (void) setHighlighted: (BOOL) value;
- (NSString*) filename;

@end
