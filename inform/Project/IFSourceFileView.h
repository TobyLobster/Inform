//
//  IFSourceFileView.h
//  Inform
//
//  Created by Andrew Hunter on Mon Feb 16 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>


// Highlight array contains entries of type NSArray
//   Each entry contains (line, style) as NSNumbers

/// Variation on NSTextView that supports line highlighting
@interface IFSourceFileView : NSTextView

// Drawing 'tears' at the top and bottom

/// Sets whether or not a 'tear' should appear at the top of the view
- (void) setTornAtTop: (BOOL) tornAtTop;
/// Sets whether or not a 'tear' should appear at the bottom of the view
- (void) setTornAtBottom: (BOOL) tornAtBottom;
-(bool) setMouseCursorWithPosition:(NSPoint) mousePoint;

@end

@interface NSObject(IFSourceFileViewDelegate)

/// User clicked on the top tear
- (void) sourceFileShowPreviousSection: (id) sender;
/// User clicked on the bottom tear
- (void) sourceFileShowNextSection: (id) sender;

@end
