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

@interface GlkStyle : NSObject<NSCopying>

// Creating a style
+ (GlkStyle*) style;													// 'Normal' style

// The hints							// Measured in points						// Measured in points					// Glk doesn't allow us to support 'Natural' alignment											// Relative, in points										// -1 = lighter, 1 = bolder									// YES if an italic/oblique version of the font should be used (italics are used for preference)							// NO if fixed-pitch							// Foreground text colour							// Background text colour									// YES If text/back are reversed

@property (NS_NONATOMIC_IOSONLY) float indentation;
@property (NS_NONATOMIC_IOSONLY) float paraIndentation;
@property (NS_NONATOMIC_IOSONLY) NSTextAlignment justification;
@property (NS_NONATOMIC_IOSONLY) float size;
@property (NS_NONATOMIC_IOSONLY) int weight;
@property (NS_NONATOMIC_IOSONLY) BOOL oblique;
@property (NS_NONATOMIC_IOSONLY) BOOL proportional;
@property (NS_NONATOMIC_IOSONLY, copy) NSColor *textColour;
@property (NS_NONATOMIC_IOSONLY, copy) NSColor *backColour;
@property (NS_NONATOMIC_IOSONLY) BOOL reversed;

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
