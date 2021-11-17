//
//  GlkPreferences.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 29/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#ifndef __GLKVIEW_GLKPREFERENCES_H__
#define __GLKVIEW_GLKPREFERENCES_H__

#import <GlkView/GlkViewDefinitions.h>
#if defined(COCOAGLK_IPHONE)
# import <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

/// Notification sent whenever the preferences are changed (not necessarily sent immediately)
extern NSNotificationName const GlkPreferencesHaveChangedNotification;

@class GlkStyle;

///
/// General preferences used for a Glk view
///
@interface GlkPreferences : NSObject<NSCopying> {
	// The fonts
	GlkFont* proportionalFont;
	GlkFont* fixedFont;
	
	// The standard styles
	NSMutableDictionary<NSNumber*,GlkStyle*>* styles;
	
	// Typography
	CGFloat textMargin;
	BOOL useScreenFonts;
	BOOL useHyphenation;
	BOOL kerning;
	BOOL ligatures;
	
	// Misc bits
	CGFloat scrollbackLength;
	
	/// YES if the last change is being notified
	BOOL changeNotified;
	/// Number of changes
	int  changeCount;
}

/// The shared preferences object (these are automagically stored in the user defaults)
@property (class, readonly, retain) GlkPreferences *sharedPreferences;

// Preferences and the user defaults
/// Used to load the preferences from a defaults file
- (void) setPreferencesFromDefaults: (NSDictionary<NSString*,id>*) defaults;
/// These preferences in a format suitable for the user defaults file
@property (readonly, copy) NSDictionary<NSString*,id> *preferenceDefaults;

// The preferences themselves

// Font preferences
/// The font used for proportional text
@property (nonatomic, copy) NSFont *proportionalFont;
/// The font used for fixed-pitch text
@property (nonatomic, copy) NSFont *fixedFont;

/// Replaces the current fonts with ones of the given size
- (void) setFontSize: (CGFloat) fontSize;

// Typography preferences
/// The padding to use in text windows
@property (nonatomic) CGFloat textMargin;
/// Whether or not to use screen fonts
@property (nonatomic) BOOL useScreenFonts;
/// Whether or not to use hyphenation
@property (nonatomic) BOOL useHyphenation;
/// Whether or not to display ligatures
@property (nonatomic) BOOL useLigatures;
/// Whether or not to use kerning
@property (nonatomic) BOOL useKerning;
/// Replaces the current padding that we should use
- (void) setTextMargin: (CGFloat) margin;

// Style preferences
/// Dictionary mapping \c NSNumbers with Glk styles to \c GlkStyle objects
- (void) setStyles: (NSDictionary<NSNumber*,GlkStyle*>*) styles;
/// Sets a style for a specific Glk hint
- (void) setStyle: (GlkStyle*) style
		  forHint: (unsigned) glkHint;

/// The style dictionary
@property (nonatomic, copy) NSDictionary<NSNumber*,GlkStyle*> *styles;
// Misc preferences
/// The amount of scrollback to support in text windows (0-100)
@property (nonatomic) CGFloat scrollbackLength;

// Changes
/// Number of changes that have occured on this preference object
@property (readonly) int changeCount;

@end

#endif
