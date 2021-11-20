//
//  IFIsTitleView.h
//  Inform
//
//  Created by Andrew Hunter on Mon May 03 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>


///
/// View that displays the inspector title and the the graduated background.
///
@interface IFIsTitleView : NSView

/// Recommended height of a title view
+ (CGFloat) titleHeight;
/// Sets the title string to display
- (void) setTitle: (NSString*) title;

@end
