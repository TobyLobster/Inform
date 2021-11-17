//
//  GlkGridTypesetter.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 18/12/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#include <tgmath.h>
#import "GlkGridTypesetter.h"


@implementation GlkGridTypesetter

#pragma mark - Setting up the grid

- (void) invalidateAllLayout {
	// Invalidates any layout performed in this text grid so far
}

- (void) setGridWidth: (int) newWidth
			   height: (int) newHeight {
	gridWidth = newWidth;
	gridHeight = newHeight;
	
	[self invalidateAllLayout];
}

- (void) setCellSize: (GlkCocoaSize) newSize {
	cellSize = newSize;
	
	[self invalidateAllLayout];
}
	
#pragma mark - Performing layout

- (NSInteger) layoutLineFromGlyph: (NSInteger) glyph {
	// Lays out a line fragment from the specified glyph
	if (![self cacheGlyphsIncluding: glyph]) return glyph;
	glyph -= cached.location;
	
	[self beginLineFragment];
	
	// Work out where in the grid we are currently located
	NSUInteger charIndex = cacheCharIndexes[glyph];
	NSInteger x = charIndex % gridWidth;
	NSInteger y = charIndex / gridWidth;
	GlkPoint gridPos = GlkMakePoint(cellSize.width*x+inset, cellSize.height*y);
	
	CGFloat charPos = gridPos.x;
	CGFloat initialCharPos = charPos;
	
	// Perform layout for as many characters as possible
	NSInteger firstGlyph = glyph;
	NSUInteger lastChar = cacheCharIndexes[glyph];
	CGFloat charWidth = 0;
	NSInteger lastBoundaryGlyph = glyph;
	BOOL hitTheLastGlyph = NO;
	
	GlkRect sectionBounds =  GlkMakeRect(charPos, -cacheAscenders[glyph],
										 cacheAdvancements[glyph], cacheLineHeight[glyph]);
	
	while (x < gridWidth && glyph < cached.length) {
		NSUInteger thisChar = cacheCharIndexes[glyph];
		
		if (thisChar != lastChar) {
			// We're advancing to the next character
			x++;
			charPos += charWidth;
			gridPos.x += cellSize.width;
			
			// Reset character measurements
			charWidth = 0;
			lastBoundaryGlyph = glyph;
		}
		
		// Correct for any inaccuracies in the width of the characters
		if (floor(charPos) != floor(gridPos.x) && thisChar != lastChar) {
			// Put all the characters so far in one line section
			[self addLineSection: sectionBounds
					 advancement: gridPos.x-initialCharPos
						  offset: initialCharPos
					  glyphRange: NSMakeRange(firstGlyph+cached.location, glyph-firstGlyph)
					   alignment: GlkAlignBaseline
						delegate: nil
						 elastic: NO];
			
			// Start the next section
			initialCharPos = charPos = gridPos.x;
			sectionBounds =  GlkMakeRect(charPos, -cacheAscenders[glyph],
										cacheAdvancements[glyph], cacheLineHeight[glyph]);
			firstGlyph = glyph;
		}
		
		// Remember this character
		lastChar = thisChar;
		
		// Measure this glyph
		NSRect glyphBounds = NSMakeRect(charPos + charWidth, floor(-cacheAscenders[glyph]),
										cacheAdvancements[glyph], cacheLineHeight[glyph]);
		charWidth += cacheAdvancements[glyph];
		sectionBounds = NSUnionRect(sectionBounds, glyphBounds);
		
		// Advance to the next glyph
		glyph++;
		if (glyph >= cached.length) {
			if (![self cacheGlyphsIncluding: glyph+cached.location]) {
				// We're advancing to the next character
				x++;
				charPos += charWidth;
				gridPos.x += cellSize.width;
				
				// Reset character measurements
				charWidth = 0;
				lastBoundaryGlyph = glyph;
				
				// This is the final glyph
				hitTheLastGlyph = YES;
				break;
			}
		}
	}
	
	// Rewind to the last glyph on a character boundary
	glyph = lastBoundaryGlyph;
	
	// Store this line section
	[self addLineSection: sectionBounds
			 advancement: gridPos.x-initialCharPos
				  offset: initialCharPos
			  glyphRange: NSMakeRange(firstGlyph+cached.location, glyph-firstGlyph)
			   alignment: GlkAlignBaseline
				delegate: nil
				 elastic: NO];
	
	// Send the proposed rectangle to the text container for adjustment
	fragmentBounds.size.height = cellSize.height;

	proposedRect = fragmentBounds;
	proposedRect.origin.y = y*cellSize.height;
	proposedRect.origin.x = 0;
	proposedRect.size.height = cellSize.height;
	proposedRect.size.width = size.width;
	
	proposedRect = [container lineFragmentRectForProposedRect: proposedRect
											   sweepDirection: NSLineSweepRight
											movementDirection: NSLineMovesDown
												remainingRect: &remaining];
	
	if (proposedRect.size.height == 0 && sections.count > 0) {
		// If the proposed rect is 0-height, then do no further layout
		return sections[0].glyphRange.location;
	}	
	
	// Finish this line fragment
	if (![self endLineFragment: hitTheLastGlyph
					   newline: x == gridWidth]
		&& sections.count > 0) {
		// Failed to lay anything out!
		return sections[0].glyphRange.location;
	}
	
	// Update the usedRect for future methods
	usedRect.size.height = NSMaxY(remaining)-usedRect.origin.y;
	
	return glyph + cached.location;
}

@end
