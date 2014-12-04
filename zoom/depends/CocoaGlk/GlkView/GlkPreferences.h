//
//  GlkPreferences.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 29/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

//
// General preferences used for a Glk view
//

extern NSString* GlkPreferencesHaveChangedNotification;				// Notification sent whenever the preferences are changed (not necessarily sent immediately)

@class GlkStyle;

@interface GlkPreferences : NSObject<NSCopying> {
	// The fonts
	NSFont* proportionalFont;
	NSFont* fixedFont;
	
	// The standard styles
	NSMutableDictionary* styles;
	
	// Typography
	float textMargin;
	BOOL useScreenFonts;
	BOOL useHyphenation;
	BOOL kerning;
	BOOL ligatures;
	
	// Misc bits
	float scrollbackLength;
	
	BOOL changeNotified;											// YES if the last change is being notified
	int  changeCount;												// Number of changes
}

// The shared preferences object (these are automagically stored in the user defaults)
+ (GlkPreferences*) sharedPreferences;

// Preferences and the user defaults
- (void) setPreferencesFromDefaults: (NSDictionary*) defaults;		// Used to load the preferences from a defaults file
- (NSDictionary*) preferenceDefaults;								// These preferences in a format suitable for the user defaults file

// The preferences themselves

// Font preferences
- (void) setProportionalFont: (NSFont*) propFont;					// The font used for proportional text
- (void) setFixedFont: (NSFont*) fixedFont;							// The font used for fixed-pitch text

- (NSFont*) proportionalFont;
- (NSFont*) fixedFont;

- (void) setFontSize: (float) fontSize;								// Replaces the current fonts with ones of the given size

// Typography preferences
- (float) textMargin;												// The padding to use in text windows
- (BOOL) useScreenFonts;											// Whether or not to use screen fonts
- (BOOL) useHyphenation;											// Whether or not to use hyphenation
- (BOOL) useLigatures;												// Whether or not to display ligatures
- (BOOL) useKerning;												// Whether or not to use kerning
- (void) setTextMargin: (float) margin;								// Replaces the current padding that we should use
- (void) setUseScreenFonts: (BOOL) value;
- (void) setUseHyphenation: (BOOL) value;
- (void) setUseLigatures: (BOOL) value;
- (void) setUseKerning: (BOOL) value;

// Style preferences
- (void) setStyles: (NSDictionary*) styles;							// Dictionary mapping NSNumbers with Glk styles to GlkStyle objects
- (void) setStyle: (GlkStyle*) style								// Sets a style for a specific Glk hint
		  forHint: (unsigned) glkHint;

- (NSDictionary*) styles;											// The style dictionary

// Misc preferences
- (float) scrollbackLength;											// The amount of scrollback to support in text windows (0-100)

- (void) setScrollbackLength: (float) length;						// Sets the amount of scrollback to retain

// Changes
- (int) changeCount;												// Number of changes that have occured on this preference object

@end

#import <GlkView/GlkStyle.h>
