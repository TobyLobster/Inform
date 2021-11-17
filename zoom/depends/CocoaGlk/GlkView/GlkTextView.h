//
//  GlkTextView.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 01/04/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#ifndef __GLKVIEW_GLKTEXTVIEW_H__
#define __GLKVIEW_GLKTEXTVIEW_H__

#import <GlkView/GlkViewDefinitions.h>
#if defined(COCOAGLK_IPHONE)
# import <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif
#import <GlkView/GlkTypesetter.h>

///
/// Class that implements our custom extensions to the text view (mainly character input and image drawing)
///
@interface GlkTextView : NSTextView<GlkCustomTextLayout>

// Character input
/// Any characters sent to this window that can be handled by Glk will be passed to the superview
- (void) requestCharacterInput;
/// Cancels the previous
- (void) cancelCharacterInput;

@end

#endif
