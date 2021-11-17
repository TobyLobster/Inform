//
//  GlkStyle.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 29/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#ifndef __GLKVIEW_GLKSTYLE_H__
#define __GLKVIEW_GLKSTYLE_H__

#import <Foundation/Foundation.h>
#import <GlkView/GlkViewDefinitions.h>
#if defined(COCOAGLK_IPHONE)
# import <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif
#import <GlkView/glk.h>

/// Styles store themselves in the attributes to facilitate reformating after a change to a preference object
extern NSAttributedStringKey const GlkStyleAttributeName;


@class GlkPreferences;

///
/// Description of a Glk style, and functions for turning a Glk style into a cocoa style
///
/// (Maybe I should split this into a Mutable/Immutable pair)
///
@interface GlkStyle : NSObject<NSCopying> {
	// Style attributes
	CGFloat indentation;
	CGFloat paraIndent;
	NSTextAlignment alignment;
	CGFloat size;
	int weight;
	BOOL oblique;
	BOOL proportional;
	GlkColor* textColour;
	GlkColor* backColour;
	BOOL reversed;
	
	// Caching the attributes
	/// Change count for the preferences last time we cached the style dictionary
	NSInteger prefChangeCount;
	/// The last preference object this style was applied to
	__weak GlkPreferences*	lastPreferences;
	/// The scale factor the attributes were created at
	CGFloat lastScaleFactor;
	/// The attributes generated last time we needed to
	NSDictionary* lastAttributes;
}

// Creating a style
/// 'Normal' style
+ (instancetype) style;

/// 'Normal' style
- (instancetype)init;

// The hints
/// Measured in points
@property (nonatomic) CGFloat indentation;
/// Measured in points
@property (nonatomic) CGFloat paraIndentation;
/// Glk doesn't allow us to support 'Natural' alignment
@property (nonatomic) NSTextAlignment justification;
/// Relative, in points
@property (nonatomic) CGFloat size;
/// -1 = lighter, 1 = bolder
@property (nonatomic) int weight;
/// \c YES if an italic/oblique version of the font should be used (italics are used for preference)
@property (nonatomic) BOOL oblique;
/// \c NO if fixed-pitch
@property (nonatomic) BOOL proportional;
/// Foreground text colour
@property (nonatomic, copy) NSColor *textColour;
/// Background text colour
@property (nonatomic, copy) NSColor *backColour;
/// \c YES If text/back are reversed
@property (nonatomic, getter=isReversed) BOOL reversed;

// Dealing with glk style hints
- (void) setHint: (glui32) hint
		 toValue: (glsi32) value;
- (void) setHint: (glui32) hint
	toMatchStyle: (GlkStyle*) style;

// Utility functions
/// Returns \c YES if this style will look different to the given style
- (BOOL) canBeDistinguishedFrom: (GlkStyle*) style;

// Turning styles into dictionaries for attributed strings
/// Attributes suitable to use with an attributed string while displaying
- (NSDictionary<NSAttributedStringKey,id>*) attributesWithPreferences: (GlkPreferences*) prefs
														  scaleFactor: (CGFloat) scaleFactor;
/// Attributes suitable to use with an attributed string while displaying
- (NSDictionary<NSAttributedStringKey,id>*) attributesWithPreferences: (GlkPreferences*) prefs;

@end

#endif
