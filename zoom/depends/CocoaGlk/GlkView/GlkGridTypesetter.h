//
//  GlkGridTypesetter.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 18/12/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#ifndef __GLKVIEW_GLKGRIDTYPESETTER_H__
#define __GLKVIEW_GLKGRIDTYPESETTER_H__

#import <GlkView/GlkViewDefinitions.h>
#if defined(COCOAGLK_IPHONE)
# import <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

#import <GlkView/GlkTypesetter.h>

///
/// Variant of GlkTypesetter that typesets things laid out into a character grid. Using this class,
/// each character will be typeset into a specified cell size.
///
/// Try to ensure that the cellSize closely matches the font size; performance and appearance may
/// suffer if this is not the case. This class supports a considerably more limited range of
/// layout options to the standard typesetter.
///
@interface GlkGridTypesetter : GlkTypesetter {
	/// Width of the grid, in characters
	int gridWidth;
	/// Height of the grid, in characters
	int gridHeight;
	/// Size of a grid cell
	NSSize cellSize;
}

// Setting up the grid
/// Sets the number of characters for the grid width and height
- (void) setGridWidth: (int) gridWidth
			   height: (int) gridHeight;
/// Sets the size of an individual cell in the grid
- (void) setCellSize: (NSSize) cellSize;

@end

#endif
