//
//  GlkStyle.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 29/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "GlkStyle.h"

NSString* GlkStyleAttributeName = @"GlkStyleAttribute";

@implementation GlkStyle

// = Initialisation =

- (id) init {
	self = [super init];
	
	if (self) {
		// Default attributes
		indentation = 0;
		paraIndent = 0;
		alignment = NSLeftTextAlignment;
		size = 0;
		weight = 0;
		oblique = NO;
		proportional = YES;
		textColour = [[NSColor blackColor] retain];
		backColour = [[NSColor whiteColor] retain];
		reversed = NO;
		
		// The cache
		prefChangeCount = 0;
		lastPreferences = nil;
		lastAttributes = nil;
	}
	
	return self;
}

- (void) dealloc {
	[textColour release]; textColour = nil;
	[backColour release]; backColour = nil;
	[lastAttributes release]; lastAttributes = nil;
	
	// lastPreferences is not retained, so we don't need to release it
	
	[super dealloc];
}

// = Creating a style =

+ (GlkStyle*) style {
	return [[[[self class] alloc] init] autorelease];
}

// = The hints =

- (void) styleChanged {
	lastPreferences = nil;
	[lastAttributes release]; lastAttributes = nil;
}

- (void) setIndentation: (float) newIndentation {
	indentation = newIndentation;
	[self styleChanged];
}

- (void) setParaIndentation: (float) newParaIndent {
	paraIndent = newParaIndent;
	[self styleChanged];
}

- (void) setJustification: (NSTextAlignment) newAlignment {
	alignment = newAlignment;
	[self styleChanged];
}

- (void) setSize: (float) newSize {
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

- (void) setTextColour: (NSColor*) newTextColour {
	if (newTextColour == textColour) return;
	
	[textColour autorelease]; textColour = nil;
	textColour = [newTextColour copy];
	
	[self styleChanged];
}

- (void) setBackColour: (NSColor*) newBackColour {
	if (newBackColour == backColour) return;
	
	[backColour release]; backColour = nil;
	backColour = [newBackColour copy];
	
	[self styleChanged];
}

- (void) setReversed: (BOOL) newReversed {
	reversed = newReversed;
	[self styleChanged];
}

- (float) indentation {
	return indentation;
}

- (float) paraIndentation {
	return paraIndent;
}

- (NSTextAlignment)	justification {
	return alignment;
}

- (float) size {
	return size;
}

- (int)	weight {
	return weight;
}

- (BOOL) oblique {
	return oblique;
}

- (BOOL) proportional {
	return proportional;
}

- (NSColor*) textColour {
	return textColour;
}

- (NSColor*) backColour {
	return backColour;
}

- (BOOL) reversed {
	return reversed;
}

// = Utility functions =

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

// = Turning styles into dictionaries for attributed strings =

- (NSDictionary*) addSelfToAttributes: (NSDictionary*) dict {
	// We have to do things this way to avoid creating a reference loop (which would leak memory)
	NSMutableDictionary* mutDict = [dict mutableCopy];
	
	[mutDict setObject: self
				forKey: GlkStyleAttributeName];
	
	return [mutDict autorelease];
}

- (NSDictionary*) attributesWithPreferences: (GlkPreferences*) prefs {
	return [self attributesWithPreferences: prefs
							   scaleFactor: 1.0f]; 
}

- (NSDictionary*) attributesWithPreferences: (GlkPreferences*) prefs
								scaleFactor: (float) scaleFactor {
	// Use the cached version of the attributes if they're around
	if (lastAttributes && lastPreferences == prefs && lastScaleFactor == scaleFactor) {
		if ([lastPreferences changeCount] == prefChangeCount) {
			return [self addSelfToAttributes: lastAttributes];
		}
		
		[lastAttributes release]; lastAttributes = nil;
	}
	
	NSFontManager* mgr = [NSFontManager sharedFontManager];
	
	// Various bits of the style
	NSDictionary* res = nil;
	
	NSFont* font;
	NSColor* foreCol;
	NSColor* backCol;
	NSMutableParagraphStyle* paraStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	
	// Select the appropriate font
	if (proportional) {
		font = [prefs proportionalFont];
	} else {
		font = [prefs fixedFont];
	}
	
	// Adjust the font size
	if (size != 0 || scaleFactor != 1.0f) {
		float newSize = [font pointSize] + size;
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
	res = [NSDictionary dictionaryWithObjectsAndKeys: 
		paraStyle, NSParagraphStyleAttributeName,
		font, NSFontAttributeName,
		foreCol, NSForegroundColorAttributeName,
		backCol, NSBackgroundColorAttributeName,
		[NSNumber numberWithInt: [prefs useLigatures]], NSLigatureAttributeName,
		nil];
		
	// Finish up
	[paraStyle release];
	
	if (res) {
		// Cache this style
		[lastAttributes release];
		lastAttributes = [res retain];
		prefChangeCount = [prefs changeCount];
		lastPreferences = prefs;
	}
	
	// Return the result
	return [self addSelfToAttributes: res];
}

// = Dealing with glk style hints =
- (void) setHint: (glui32) hint
		 toValue: (glsi32) value {
	switch (hint) {
		case stylehint_BackColor:
		{
			int red   = (value&0xff0000)>>16;
			int green = (value&0xff00)>>8;
			int blue  = (value&0xff);
			
			[self setBackColour: [NSColor colorWithDeviceRed: ((float)red)/255.0
													   green: ((float)green)/255.0
														blue: ((float)blue)/255.0
													   alpha: 1.0]];
			break;
		}
			
		case stylehint_TextColor:
		{
			int red   = (value&0xff0000)>>16;
			int green = (value&0xff00)>>8;
			int blue  = (value&0xff);
			
			[self setTextColour: [NSColor colorWithDeviceRed: ((float)red)/255.0
													   green: ((float)green)/255.0
														blue: ((float)blue)/255.0
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
			NSTextAlignment align = NSLeftTextAlignment;
			
			switch (value) {
				case stylehint_just_LeftFlush:
					align = NSLeftTextAlignment;
					break;
				case stylehint_just_RightFlush:
					align = NSRightTextAlignment;
					break;
				case stylehint_just_Centered:
					align = NSCenterTextAlignment;
					break;
				case stylehint_just_LeftRight:
					align = NSJustifiedTextAlignment;
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
			[self setReversed: [defaultStyle reversed]];
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

// = NSCopying =

- (id) copyWithZone: (NSZone*) zone {
	GlkStyle* copy = [[GlkStyle alloc] init];
	
	copy->indentation = indentation;
	copy->paraIndent = paraIndent;
	copy->alignment = alignment;
	copy->size = size;
	copy->weight = weight;
	copy->oblique = oblique;
	copy->proportional = proportional;
	[copy->textColour release];
	[copy->backColour release];
	copy->textColour = [textColour copyWithZone: zone];
	copy->backColour = [backColour copyWithZone: zone];
	copy->reversed = reversed;
	
	return copy;
}

// = NSCoding =

@end
