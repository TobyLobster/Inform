//
//  GlkGridTypesetter.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 18/12/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

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
	int gridWidth;										// Width of the grid, in characters
	int gridHeight;										// Height of the grid, in characters
	NSSize cellSize;									// Size of a grid cell
}

// Setting up the grid
- (void) setGridWidth: (int) gridWidth					// Sets the number of characters for the grid width and height
			   height: (int) gridHeight;
- (void) setCellSize: (NSSize) cellSize;				// Sets the size of an individual cell in the grid

@end
