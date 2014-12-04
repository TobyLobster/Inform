//
//  GlkStyle.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 29/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <GlkView/glk.h>

extern NSString* GlkStyleAttributeName;									// Styles store themselves in the attributes to facilitate reformating after a change to a preference object

//
// Description of a Glk style, and functions for turning a Glk style into a cocoa style
//
// (Maybe I should split this into a Mutable/Immutable pair)
//

@class GlkPreferences;

@interface GlkStyle : NSObject<NSCopying> {
	// Style attributes
	float indentation;
	float paraIndent;
	NSTextAlignment alignment;
	float size;
	int weight;
	BOOL oblique;
	BOOL proportional;
	NSColor* textColour;
	NSColor* backColour;
	BOOL reversed;
	
	// Caching the attributes
	int prefChangeCount;												// Change count for the preferences last time we cached the style dictionary
	GlkPreferences*	lastPreferences;									// The last preference object this style was applied to
	float lastScaleFactor;												// The scale factor the attributes were created at
	NSDictionary* lastAttributes;										// The attributes generated last time we needed to
}

// Creating a style
+ (GlkStyle*) style;													// 'Normal' style

// The hints
- (void) setIndentation: (float) indentation;							// Measured in points
- (void) setParaIndentation: (float) paraIndent;						// Measured in points
- (void) setJustification: (NSTextAlignment) alignment;					// Glk doesn't allow us to support 'Natural' alignment
- (void) setSize: (float) size;											// Relative, in points
- (void) setWeight: (int) weight;										// -1 = lighter, 1 = bolder
- (void) setOblique: (BOOL) oblique;									// YES if an italic/oblique version of the font should be used (italics are used for preference)
- (void) setProportional: (BOOL) proportional;							// NO if fixed-pitch
- (void) setTextColour: (NSColor*) textColor;							// Foreground text colour
- (void) setBackColour: (NSColor*) backColor;							// Background text colour
- (void) setReversed: (BOOL) reversed;									// YES If text/back are reversed

- (float)			indentation;
- (float)			paraIndentation;
- (NSTextAlignment)	justification;
- (float)			size;
- (int)				weight;
- (BOOL)			oblique;
- (BOOL)			proportional;
- (NSColor*)		textColour;
- (NSColor*)		backColour;
- (BOOL)			reversed;

// Dealing with glk style hints
- (void) setHint: (glui32) hint
		 toValue: (glsi32) value;
- (void) setHint: (glui32) hint
	toMatchStyle: (GlkStyle*) style;

// Utility functions
- (BOOL) canBeDistinguishedFrom: (GlkStyle*) style;						// Returns YES if this style will look different to the given style

// Turning styles into dictionaries for attributed strings
- (NSDictionary*) attributesWithPreferences: (GlkPreferences*) prefs
								scaleFactor: (float) scaleFactor;		// Attributes suitable to use with an attributed string while displaying
- (NSDictionary*) attributesWithPreferences: (GlkPreferences*) prefs;	// Attributes suitable to use with an attributed string while displaying

@end

#import <GlkView/GlkPreferences.h>
