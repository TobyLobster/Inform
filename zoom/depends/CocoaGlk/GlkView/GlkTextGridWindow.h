//
//  GlkTextGridWindow.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 20/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#ifndef __GLKVIEW_GLKTEXTGRIDWINDOW_H__
#define __GLKVIEW_GLKTEXTGRIDWINDOW_H__

#import <GlkView/GlkViewDefinitions.h>
#if defined(COCOAGLK_IPHONE)
# import <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

#import <GlkView/GlkWindow.h>
#import <GlkView/GlkTextWindow.h>

@interface GlkTextGridWindow : GlkTextWindow<NSTextStorageDelegate,NSTextViewDelegate> {
	/// The amount of line input that we have accepted so far
	NSInteger lineInputLength;
	
	/// Current character width/height
	int width,height;
	/// Current cursor position. Top left is 0,0.
	int xpos,ypos;
	
	/// The next input line to display
	NSString* nextInputLine;
}

@end

#endif
