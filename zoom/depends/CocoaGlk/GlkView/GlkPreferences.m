//
//  GlkPreferences.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 29/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "GlkPreferences.h"
#import "GlkStyle.h"

#include "glk.h"

NSString* const GlkPreferencesHaveChangedNotification = @"GlkPreferencesHaveChangedNotification";

@implementation GlkPreferences

#pragma mark - Initialisation

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
		if (proportionalFont == nil) proportionalFont = [GlkFont systemFontOfSize: 12];
		if (fixedFont == nil) fixedFont = [GlkFont fontWithName: @"Monaco"
														   size: 12];
		if (fixedFont == nil) fixedFont = [GlkFont systemFontOfSize: 12];
		
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
		
		[header setJustification: NSTextAlignmentCenter];
		
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

#pragma mark - Changes

@synthesize changeCount;

- (void) preferencesHaveChanged {
	if (!changeNotified) {
		[[NSRunLoop currentRunLoop] performSelector: @selector(notifyPreferenceChange)
											 target: self
										   argument: nil
											  order: 64
											  modes: @[NSDefaultRunLoopMode]];
		changeNotified = YES;
	}
}

- (void) notifyPreferenceChange {
	changeCount++;
	[[NSNotificationCenter defaultCenter] postNotificationName: GlkPreferencesHaveChangedNotification
														object: self];
}

#pragma mark - Preferences and the user defaults

- (void) setPreferencesFromDefaults: (NSDictionary*) defaults {
	// TODO: Not implemented yet
}

- (NSDictionary*) preferenceDefaults {
	// TODO: Not implemented yet
	return nil;
}

#pragma mark - Font preferences

- (void) setProportionalFont: (NSFont*) propFont {
	proportionalFont = [propFont copy];
	
	[self preferencesHaveChanged];
}

- (void) setFixedFont: (NSFont*) newFixedFont {
	fixedFont = [newFixedFont copy];
	
	[self preferencesHaveChanged];
}

@synthesize proportionalFont;
@synthesize fixedFont;

- (void) setFontSize: (CGFloat) fontSize {
	NSFontManager* mgr = [NSFontManager sharedFontManager];
	
	NSFont* newProp = [mgr convertFont: proportionalFont
								toSize: fontSize];
	NSFont* newFixed = [mgr convertFont: fixedFont
								 toSize: fontSize];
	
	[self setProportionalFont: newProp];
	[self setFixedFont: newFixed];
}

#pragma mark - Style preferences

- (void) setStyles: (NSDictionary*) newStyles {
	styles = [[NSMutableDictionary alloc] initWithDictionary: newStyles
												   copyItems: YES];
	
	[self preferencesHaveChanged];
}

- (void) setStyle: (GlkStyle*) style
		  forHint: (unsigned) glkHint {
	[styles setObject: [style copy]
			   forKey: @(glkHint)];
	
	[self preferencesHaveChanged];
}

- (NSDictionary*) styles {
	return styles;
}

#pragma mark - Typography preferences

@synthesize textMargin;

- (void) setTextMargin: (CGFloat) margin {
	textMargin = margin;
	[self preferencesHaveChanged];
}

@synthesize useScreenFonts;
@synthesize useHyphenation;
@synthesize useLigatures = ligatures;
@synthesize useKerning = kerning;

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

#pragma mark - Misc preferences

@synthesize scrollbackLength;

- (void) setScrollbackLength: (CGFloat) length {
	scrollbackLength = length;
	[self preferencesHaveChanged];
}

#pragma mark - NSCopying

- (id) copyWithZone: (NSZone*) zone {
	GlkPreferences* copy = [[GlkPreferences allocWithZone: zone] init];
	
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
