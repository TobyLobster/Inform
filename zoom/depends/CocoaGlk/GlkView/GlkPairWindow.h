//
//  GlkPairWindow.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 19/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#ifndef __GLKVIEW_GLKPAIRWINDOW_H__
#define __GLKVIEW_GLKPAIRWINDOW_H__

#import <GlkView/GlkViewDefinitions.h>
#if defined(COCOAGLK_IPHONE)
# import <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

#import <GlkView/GlkWindow.h>

///
/// Representation of a Glk pair window
///
@interface GlkPairWindow : GlkWindow {
	// = GLK settings
	
	// The two windows that make up the pair
	/// The key window is used to determine the size of this window (when fixed)
	GlkWindow* key;
	/// Left window is the 'original' window when splitting
	GlkWindow* left;
	/// Right window is the 'new' window when splitting
	GlkWindow* right;
	
	/// The size of the window
	unsigned size;
	
	// Arrangement options
	/// Proportional arrangement if \c NO
	BOOL fixed;
	/// Vertical arrangement if \c NO
	BOOL horizontal;
	/// \c NO if left is above/left of right, \c YES otherwise
	BOOL above;
	
	// = Custom settings
	/// Width of the border
	CGFloat borderWidth;
	/// \c YES if the border should only be drawn around windows that have requested input
	BOOL inputBorder;
	
	/// True if something has changed to require the windows to be layed out again
	BOOL needsLayout;
	/// The border sliver
	NSRect borderSliver;
}

// Setting the windows that make up this pair
- (void) setKeyWindow: (GlkWindow*) newKey;
- (void) setLeftWindow: (GlkWindow*) newLeft;
- (void) setRightWindow: (GlkWindow*) newRight;

@property (nonatomic, retain) GlkWindow *keyWindow;
@property (nonatomic, readonly, assign) GlkWindow *nonKeyWindow;
@property (nonatomic, retain) GlkWindow *leftWindow;
@property (nonatomic, retain) GlkWindow *rightWindow;

// Size and arrangement
@property (nonatomic) unsigned size;
/// Proportional arrangement if \c NO
@property (nonatomic) BOOL fixed;
/// Vertical arrangement if \c NO
@property (nonatomic) BOOL horizontal;
/// \c NO if left is above/left of right, \c YES otherwise
@property BOOL above;

// Custom settings
/// Width of the divider between windows (not drawn if < 2)
@property (nonatomic) CGFloat borderWidth;
/// Set to \c YES to only draw the border if input is requested
@property (nonatomic) BOOL inputBorder;

@end

#endif
