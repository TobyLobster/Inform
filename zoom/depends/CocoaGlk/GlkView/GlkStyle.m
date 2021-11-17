//
//  GlkStyle.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 29/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#include <tgmath.h>
#import "GlkStyle.h"
#import "GlkPreferences.h"
#include <CoreText/CoreText.h>

NSString* const GlkStyleAttributeName = @"GlkStyleAttribute";

@implementation GlkStyle

#pragma mark - Initialisation

- (id) init {
	self = [super init];
	
	if (self) {
		// Default attributes
		indentation = 0;
		paraIndent = 0;
		alignment = NSTextAlignmentLeft;
		size = 0;
		weight = 0;
		oblique = NO;
		proportional = YES;
		textColour = [GlkColor blackColor];
		backColour = [GlkColor whiteColor];
		reversed = NO;
		
		// The cache
		prefChangeCount = 0;
		lastPreferences = nil;
		lastAttributes = nil;
	}
	
	return self;
}

#pragma mark - Creating a style

+ (GlkStyle*) style {
	return [[[self class] alloc] init];
}

#pragma mark - The hints

- (void) styleChanged {
	lastPreferences = nil;
	lastAttributes = nil;
}

- (void) setIndentation: (CGFloat) newIndentation {
	indentation = newIndentation;
	[self styleChanged];
}

- (void) setParaIndentation: (CGFloat) newParaIndent {
	paraIndent = newParaIndent;
	[self styleChanged];
}

- (void) setJustification: (NSTextAlignment) newAlignment {
	alignment = newAlignment;
	[self styleChanged];
}

- (void) setSize: (CGFloat) newSize {
	size = newSize;
	[self styleChanged];
}

- (void) setWeight: (int) newWeight {
	weight = newWeight;
	[self styleChanged];	
}

- (void) setOblique: (BOOL) newOblique {
	oblique = newOblique;
	[self styleChanged];
}

- (void) setProportional: (BOOL) newProportional {
	proportional = newProportional;
	[self styleChanged];
}

- (void) setTextColour: (GlkColor*) newTextColour {
	if (newTextColour == textColour) return;
	
	textColour = [newTextColour copy];
	
	[self styleChanged];
}

- (void) setBackColour: (GlkColor*) newBackColour {
	if (newBackColour == backColour) return;
	
	backColour = [newBackColour copy];
	
	[self styleChanged];
}

- (void) setReversed: (BOOL) newReversed {
	reversed = newReversed;
	[self styleChanged];
}

@synthesize indentation;
@synthesize paraIndentation = paraIndent;
@synthesize justification = alignment;
@synthesize size;
@synthesize weight;
@synthesize oblique;
@synthesize proportional;
@synthesize textColour;
@synthesize backColour;
@synthesize reversed;

#pragma mark - Utility functions

- (BOOL) isEqualTo: (NSObject*) obj {
	if (obj == self) return YES;
	
	if (![obj isKindOfClass: [self class]]) {
		return NO;
	} else {
		// IMPLEMENT ME
		return NO;
	}
}

- (BOOL) canBeDistinguishedFrom: (GlkStyle*) style {
	return ![self isEqualTo: style];
}

#pragma mark - Turning styles into dictionaries for attributed strings

- (NSDictionary*) addSelfToAttributes: (NSDictionary*) dict {
	// We have to do things this way to avoid creating a reference loop (which would leak memory)
	NSMutableDictionary* mutDict = [dict mutableCopy];
	
	[mutDict setObject: self
				forKey: GlkStyleAttributeName];
	
	return mutDict;
}

- (NSDictionary*) attributesWithPreferences: (GlkPreferences*) prefs {
	return [self attributesWithPreferences: prefs
							   scaleFactor: 1.0f]; 
}

- (NSDictionary*) attributesWithPreferences: (GlkPreferences*) prefs
								scaleFactor: (CGFloat) scaleFactor {
#if defined(COCOAGLK_IPHONE)
	// Use the cached version of the attributes if they're around
	if (lastAttributes && lastPreferences == prefs && lastScaleFactor == scaleFactor) {
		if ([lastPreferences changeCount] == prefChangeCount) {
			return [self addSelfToAttributes: lastAttributes];
		}
		
		[lastAttributes release]; lastAttributes = nil;
	}
	
	// Various bits of the style
	NSDictionary* res = nil;
	
	UIFont* font;
	GlkColor* foreCol;
	GlkColor* backCol;
	NSMutableParagraphStyle* paraStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	
	// Select the appropriate font
	if (proportional) {
		font = [prefs proportionalFont];
	} else {
		font = [prefs fixedFont];
	}
	UIFontDescriptor *descriptor = font.fontDescriptor;
	
	// Adjust the font size
	if (size != 0 || scaleFactor != 1.0f) {
		CGFloat newSize = [font pointSize] + size;
		if (newSize < 6) newSize = 6;
		newSize *= scaleFactor;
		
		descriptor = [descriptor fontDescriptorByAddingAttributes:@{UIFontDescriptorSizeAttribute: @(newSize)}];
	}
	
	UIFontDescriptorSymbolicTraits symbolicTraits = descriptor.symbolicTraits;
	// Clear the traits to change
	symbolicTraits &= ~(UIFontDescriptorTraitItalic);
	// Adjust the font weight
	if (weight < 0) {
		symbolicTraits &= ~(UIFontDescriptorTraitBold);
	}
	
	if (weight > 0) {
		symbolicTraits |= UIFontDescriptorTraitBold;
	}
	
	// Italic/oblique
	if (oblique) {
		symbolicTraits |= UIFontDescriptorTraitItalic;
	}
	UIFontDescriptor *descriptor1 = [descriptor fontDescriptorWithSymbolicTraits:symbolicTraits];
	if (descriptor1) {
		descriptor = descriptor1;
	}
	font = [UIFont fontWithDescriptor:descriptor size:0];

	
	// Colours
	foreCol = textColour;
	backCol = backColour;
	
	if (reversed) {
		foreCol = backColour;
		backCol = textColour;
	}
	
	// Paragraph style
	[paraStyle setAlignment: alignment];
	[paraStyle setFirstLineHeadIndent: indentation + paraIndent];
	[paraStyle setHeadIndent: indentation];
	[paraStyle setTailIndent: indentation];
	
	// Create the style dictionary
	res = [NSDictionary dictionaryWithObjectsAndKeys:
		   [[paraStyle copy] autorelease], NSParagraphStyleAttributeName,
		   font, NSFontAttributeName,
		   foreCol, NSForegroundColorAttributeName,
		   backCol, NSBackgroundColorAttributeName,
		   @([prefs useLigatures]), NSLigatureAttributeName,
		   nil];
	
	// Finish up
	[paraStyle release];
	
	if (res) {
		// Cache this style
		[lastAttributes release];
		lastAttributes = [res copy];
		prefChangeCount = [prefs changeCount];
		lastPreferences = prefs;
	}
	
	// Return the result
	return [self addSelfToAttributes: res];
#else
	// Use the cached version of the attributes if they're around
	if (lastAttributes && lastPreferences == prefs && lastScaleFactor == scaleFactor) {
		if ([lastPreferences changeCount] == prefChangeCount) {
			return [self addSelfToAttributes: lastAttributes];
		}
		
		lastAttributes = nil;
	}
	
	NSFontManager* mgr = [NSFontManager sharedFontManager];
	
	// Various bits of the style
	NSDictionary* res = nil;
	
	NSFont* font;
	GlkColor* foreCol;
	GlkColor* backCol;
	NSMutableParagraphStyle* paraStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	
	// Select the appropriate font
	if (proportional) {
		font = [prefs proportionalFont];
	} else {
		font = [prefs fixedFont];
	}
	
	// Adjust the font size
	if (size != 0 || scaleFactor != 1.0) {
		CGFloat newSize = [font pointSize] + size;
		if (newSize < 6) newSize = 6;
		newSize *= scaleFactor;
 		font = [mgr convertFont: font
						 toSize: newSize];
	}
	
	// Adjust the font weight
	if (weight < 0) {
		font = [mgr convertWeight: NO
						   ofFont: font];
	}
	
	if (weight > 0) {
		font = [mgr convertWeight: YES
						   ofFont: font];
	}
	
	// Italic/oblique
	if (oblique) {
		font = [mgr convertFont: font
					toHaveTrait: NSItalicFontMask];
	}
	
	// Colours
	foreCol = textColour;
	backCol = backColour;
	
	if (reversed) {
		foreCol = backColour;
		backCol = textColour;
	}
	
	// Paragraph style
	[paraStyle setAlignment: alignment];
	[paraStyle setFirstLineHeadIndent: indentation + paraIndent];
	[paraStyle setHeadIndent: indentation];
	[paraStyle setTailIndent: indentation];
	
	// Create the style dictionary
	res = @{NSParagraphStyleAttributeName: paraStyle,
			NSFontAttributeName: font,
			NSForegroundColorAttributeName: foreCol,
			NSBackgroundColorAttributeName: backCol,
			NSLigatureAttributeName: @([prefs useLigatures] ? 1 : 0)};
		
	// Finish up
	
	if (res) {
		// Cache this style
		lastAttributes = [res copy];
		prefChangeCount = [prefs changeCount];
		lastPreferences = prefs;
	}
	
	// Return the result
	return [self addSelfToAttributes: res];
#endif
}

#pragma mark - Dealing with glk style hints
- (void) setHint: (glui32) hint
		 toValue: (glsi32) value {
	switch (hint) {
		case stylehint_BackColor:
		{
			int red   = (value&0xff0000)>>16;
			int green = (value&0xff00)>>8;
			int blue  = (value&0xff);
			
			[self setBackColour: [NSColor colorWithSRGBRed: ((CGFloat)red)/255.0
													 green: ((CGFloat)green)/255.0
													  blue: ((CGFloat)blue)/255.0
													 alpha: 1.0]];
			break;
		}
			
		case stylehint_TextColor:
		{
			int red   = (value&0xff0000)>>16;
			int green = (value&0xff00)>>8;
			int blue  = (value&0xff);
			
			[self setTextColour: [NSColor colorWithSRGBRed: ((CGFloat)red)/255.0
													 green: ((CGFloat)green)/255.0
													  blue: ((CGFloat)blue)/255.0
													 alpha: 1.0]];
			break;
		}
			
		case stylehint_Indentation:
			[self setIndentation: value*4.0];
			break;
			
		case stylehint_ParaIndentation:
			[self setParaIndentation: value*4.0];
			break;
			
		case stylehint_Justification:
		{
			NSTextAlignment align = NSTextAlignmentLeft;
			
			switch (value) {
				case stylehint_just_LeftFlush:
					align = NSTextAlignmentLeft;
					break;
				case stylehint_just_RightFlush:
					align = NSTextAlignmentRight;
					break;
				case stylehint_just_Centered:
					align = NSTextAlignmentCenter;
					break;
				case stylehint_just_LeftRight:
					align = NSTextAlignmentJustified;
					break;
			}
			
			[self setJustification: align];
			break;
		}
			
		case stylehint_Oblique:
			[self setOblique: value!=0];
			break;
			
		case stylehint_Proportional:
			[self setProportional: value!=0];
			break;
			
		case stylehint_ReverseColor:
			[self setReversed: value!=0];
			break;
			
		case stylehint_Size:
			[self setSize: value*2.0];
			break;
			
		case stylehint_Weight:
			[self setWeight: value];
			break;
			
		default:
			// Unknown hint
			break;
	}	
}

- (void) setHint: (glui32) hint
	toMatchStyle: (GlkStyle*) defaultStyle {
	switch (hint) {
		case stylehint_BackColor:
			[self setBackColour: [defaultStyle backColour]];
			break;
			
		case stylehint_TextColor:
			[self setTextColour: [defaultStyle textColour]];
			break;
			
		case stylehint_Indentation:
			[self setIndentation: [defaultStyle indentation]];
			break;
			
		case stylehint_ParaIndentation:
			[self setParaIndentation: [defaultStyle paraIndentation]];
			break;
			
		case stylehint_Justification:
			[self setJustification: [defaultStyle justification]];
			
		case stylehint_Oblique:
			[self setOblique: [defaultStyle oblique]];
			break;
			
		case stylehint_Proportional:
			[self setProportional: [defaultStyle proportional]];
			break;
			
		case stylehint_ReverseColor:
			[self setReversed: defaultStyle.reversed];
			break;
			
		case stylehint_Size:
			[self setSize: [defaultStyle size]];
			break;
			
		case stylehint_Weight:
			[self setWeight: [defaultStyle weight]];
			break;
			
		default:
			// Unknown hint
			break;
	}	
}

#pragma mark - NSCopying

- (id) copyWithZone: (NSZone*) zone {
	GlkStyle* copy = [[GlkStyle allocWithZone: zone] init];
	
	copy->indentation = indentation;
	copy->paraIndent = paraIndent;
	copy->alignment = alignment;
	copy->size = size;
	copy->weight = weight;
	copy->oblique = oblique;
	copy->proportional = proportional;
	copy->textColour = [textColour copyWithZone: zone];
	copy->backColour = [backColour copyWithZone: zone];
	copy->reversed = reversed;
	
	return copy;
}

// = NSCoding =

@end
