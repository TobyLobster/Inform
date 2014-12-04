//
//  GlkPreferences.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 29/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "GlkPreferences.h"

#include "glk.h"

NSString* GlkPreferencesHaveChangedNotification = @"GlkPreferencesHaveChangedNotification";

@implementation GlkPreferences

// = Initialisation =

+ (GlkPreferences*) sharedPreferences {
	static GlkPreferences* sharedPrefs = nil;
	
	if (!sharedPrefs) {
		sharedPrefs = [[GlkPreferences alloc] init];
	}
	
	return sharedPrefs;
}

- (id) init {
	self = [super init];
	
	if (self) {
		textMargin = 10.0;
		useScreenFonts = YES;
		scrollbackLength = 100.0;

		NSFontManager* fontManager = [NSFontManager sharedFontManager];
		
		// Default typography settings
		kerning = YES;
		ligatures = YES;
		
		// Default fonts are Gill Sans 12 and Courier 12
		proportionalFont = [[fontManager fontWithFamily: @"Gill Sans"
                                                traits: NSUnboldFontMask
                                                weight: 5
                                                  size: 12] copy];
		fixedFont = [[fontManager fontWithFamily: @"Courier"
                                         traits: NSUnboldFontMask
                                         weight: 5
                                           size: 12] copy];
		
		// Choose alternative fonts if our defaults are not available
		if (proportionalFont == nil) proportionalFont = [NSFont systemFontOfSize: 12];
		if (fixedFont == nil) fixedFont = [NSFont fontWithName: @"Monaco"
														  size: 12];
		if (fixedFont == nil) fixedFont = [NSFont systemFontOfSize: 12];
		
		// Default styles
		styles = [[NSMutableDictionary alloc] init];
		
		GlkStyle* normal = [GlkStyle style];
		GlkStyle* emphasized = [GlkStyle style];
		GlkStyle* preformatted = [GlkStyle style];
		GlkStyle* header = [GlkStyle style];
		GlkStyle* subheader = [GlkStyle style];
		GlkStyle* alert = [GlkStyle style];
		GlkStyle* note = [GlkStyle style];
		GlkStyle* blockquote = [GlkStyle style];
		GlkStyle* input = [GlkStyle style];
		GlkStyle* user1 = [GlkStyle style];
		GlkStyle* user2 = [GlkStyle style];
		
		[subheader setWeight: 1];
		[alert setWeight: 1];
		[note setWeight: -1];
		[blockquote setWeight: 1];
		[input setWeight: 1];
		
		[emphasized setOblique: YES];
		[alert setOblique: YES];
		
		[alert setSize: 1];
		[header setSize: 4];
		[subheader setSize: 1];
		
		[header setJustification: NSCenterTextAlignment];
		
		[preformatted setProportional: NO];
		
		[blockquote setIndentation: 10];
		
		// Store the styles
		[self setStyle: normal
			   forHint: style_Normal];
		[self setStyle: emphasized
			   forHint: style_Emphasized];
		[self setStyle: preformatted
			   forHint: style_Preformatted];
		[self setStyle: header
			   forHint: style_Header];
		[self setStyle: subheader
			   forHint: style_Subheader];
		[self setStyle: alert
			   forHint: style_Alert];
		[self setStyle: note
			   forHint: style_Note];
		[self setStyle: blockquote
			   forHint: style_BlockQuote];
		[self setStyle: input
			   forHint: style_Input];
		[self setStyle: user1
			   forHint: style_User1];
		[self setStyle: user2
			   forHint: style_User2];
	}
	
	return self;
}

- (void) dealloc {
	[styles release];
	[proportionalFont release];
	[fixedFont release];
	
	[super dealloc];
}

// = Changes =

- (int) changeCount {
	return changeCount;
}

- (void) preferencesHaveChanged {
	if (!changeNotified) {
		[[NSRunLoop currentRunLoop] performSelector: @selector(notifyPreferenceChange)
											 target: self
										   argument: nil
											  order: 64
											  modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
		changeNotified = YES;
	}
}

- (void) notifyPreferenceChange {
	changeCount++;
	[[NSNotificationCenter defaultCenter] postNotificationName: GlkPreferencesHaveChangedNotification
														object: self];
}

// = Preferences and the user defaults =

- (void) setPreferencesFromDefaults: (NSDictionary*) defaults {
	// Not implemented yet
}

- (NSDictionary*) preferenceDefaults {
	// Not implemented yet
	return nil;
}

// = Font preferences =

- (void) setProportionalFont: (NSFont*) propFont {
	[proportionalFont release];
	proportionalFont = [propFont copy];
	
	[self preferencesHaveChanged];
}

- (void) setFixedFont: (NSFont*) newFixedFont {
	[fixedFont release];
	fixedFont = [newFixedFont copy];
	
	[self preferencesHaveChanged];
}

- (NSFont*) proportionalFont {
	return proportionalFont;
}

- (NSFont*) fixedFont {
	return fixedFont;
}

- (void) setFontSize: (float) fontSize {
	NSFontManager* mgr = [NSFontManager sharedFontManager];
	
	NSFont* newProp = [mgr convertFont: proportionalFont
								toSize: fontSize];
	NSFont* newFixed = [mgr convertFont: fixedFont
								 toSize: fontSize];
	
	[self setProportionalFont: newProp];
	[self setFixedFont: newFixed];
}

// = Style preferences =

- (void) setStyles: (NSDictionary*) newStyles {
	[styles release]; styles = nil;
	styles = [[NSMutableDictionary alloc] initWithDictionary: newStyles
												   copyItems: YES];
	
	[self preferencesHaveChanged];
}

- (void) setStyle: (GlkStyle*) style
		  forHint: (unsigned) glkHint {
	[styles setObject: [[style copy] autorelease]
			   forKey: [NSNumber numberWithUnsignedInt: glkHint]];
	
	[self preferencesHaveChanged];
}

- (NSDictionary*) styles {
	return styles;
}

// = Typography preferences =

- (float) textMargin {
	return textMargin;
}

- (void) setTextMargin: (float) margin {
	textMargin = margin;
	[self preferencesHaveChanged];
}

- (BOOL) useScreenFonts {
	return useScreenFonts;
}

- (BOOL) useHyphenation {
	return useHyphenation;
}

- (BOOL) useLigatures {
	return ligatures;
}

- (BOOL) useKerning {
	return kerning;
}

- (void) setUseScreenFonts: (BOOL) value {
	useScreenFonts = value;
	[self preferencesHaveChanged];
}

- (void) setUseHyphenation: (BOOL) value {
	useHyphenation = value;
	[self preferencesHaveChanged];
}

- (void) setUseLigatures: (BOOL) value {
	ligatures = value;
	[self preferencesHaveChanged];
}

- (void) setUseKerning: (BOOL) value {
	kerning = value;
	[self preferencesHaveChanged];
}

// = Misc preferences =

- (float) scrollbackLength {
	return scrollbackLength;
}

- (void) setScrollbackLength: (float) length {
	scrollbackLength = length;
	[self preferencesHaveChanged];
}

// = NSCopying =

- (id) copyWithZone: (NSZone*) zone {
	GlkPreferences* copy = [[GlkPreferences alloc] init];
	
	[copy setProportionalFont: proportionalFont];
	[copy setFixedFont: fixedFont];
	[copy setStyles: styles];
	[copy setTextMargin: textMargin];
	
	[copy setUseScreenFonts: useScreenFonts];
	[copy setUseHyphenation: useHyphenation];
	
	[copy setScrollbackLength: scrollbackLength];
	
	return copy;
}

@end
