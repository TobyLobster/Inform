//
//  IFSourceFileView.h
//  Inform
//
//  Created by Andrew Hunter on Mon Feb 16 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

// Variation on NSTextView that supports line highlighting

// Highlight array contains entries of type NSArray
//   Each entry contains (line, style) as NSNumbers

@interface IFSourceFileView : NSTextView {
	BOOL tornAtTop;																// YES if we should draw a 'tear' at the top of the view
	BOOL tornAtBottom;															// YES if we should draw a 'tear' at the bottom of the view
	NSRect lastUsedRect;														// The last known 'used' rect (used to determine whether or not to update the bottom tear)
}

// Drawing 'tears' at the top and bottom

- (void) setTornAtTop: (BOOL) tornAtTop;										// Sets whether or not a 'tear' should appear at the top of the view
- (void) setTornAtBottom: (BOOL) tornAtBottom;									// Sets whether or not a 'tear' should appear at the bottom of the view
-(bool) setMouseCursorWithPosition:(NSPoint) mousePoint;

@end

@interface NSObject(IFSourceFileViewDelegate)

- (void) sourceFileShowPreviousSection: (id) sender;							// User clicked on the top tear
- (void) sourceFileShowNextSection: (id) sender;								// User clicked on the bottom tear

@end