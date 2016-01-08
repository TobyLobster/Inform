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

@interface GlkPreferences : NSObject<NSCopying>

// The shared preferences object (these are automagically stored in the user defaults)
+ (GlkPreferences*) sharedPreferences;

// Preferences and the user defaults
- (void) setPreferencesFromDefaults: (NSDictionary*) defaults;		// Used to load the preferences from a defaults file
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSDictionary *preferenceDefaults;								// These preferences in a format suitable for the user defaults file

// The preferences themselves

// Font preferences					// The font used for proportional text							// The font used for fixed-pitch text

@property (NS_NONATOMIC_IOSONLY, copy) NSFont *proportionalFont;
@property (NS_NONATOMIC_IOSONLY, copy) NSFont *fixedFont;

- (void) setFontSize: (float) fontSize;								// Replaces the current fonts with ones of the given size

// Typography preferences
@property (NS_NONATOMIC_IOSONLY) float textMargin;												// The padding to use in text windows
@property (NS_NONATOMIC_IOSONLY) BOOL useScreenFonts;											// Whether or not to use screen fonts
@property (NS_NONATOMIC_IOSONLY) BOOL useHyphenation;											// Whether or not to use hyphenation
@property (NS_NONATOMIC_IOSONLY) BOOL useLigatures;												// Whether or not to display ligatures
@property (NS_NONATOMIC_IOSONLY) BOOL useKerning;												// Whether or not to use kerning								// Replaces the current padding that we should use

// Style preferences							// Dictionary mapping NSNumbers with Glk styles to GlkStyle objects
- (void) setStyle: (GlkStyle*) style								// Sets a style for a specific Glk hint
		  forHint: (unsigned) glkHint;

@property (NS_NONATOMIC_IOSONLY, copy) NSDictionary *styles;											// The style dictionary

// Misc preferences
@property (NS_NONATOMIC_IOSONLY) float scrollbackLength;											// The amount of scrollback to support in text windows (0-100)
						// Sets the amount of scrollback to retain

// Changes
@property (NS_NONATOMIC_IOSONLY, readonly) int changeCount;												// Number of changes that have occured on this preference object

@end

#import <GlkView/GlkStyle.h>
