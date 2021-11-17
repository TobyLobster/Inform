//
//  GlkTypesetter.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 10/09/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

// TODO: (?) monitor the text storage object for changes, and flush the glyph cache as appropriate
// TODO: deal with more than one container
// TODO: support different line breaking modes
// TODO: bidirectional support
// TODO: tabstop support
// TODO: hyphenation
// TODO: release stuff in the attribute caches
// TODO: underlining
// TODO: NSKernAttributeName
// TODO: NSBaselineOffsetAttributeName
// TODO: text attachments
// TODO: (?) recognise all newline characters (U+085 in particular), and the DOS combos
// TODO: dealloc method
// TODO: if we can't layout even a single glyph in a line, we just abort layout at that point
// TODO: squish custom sections that won't find on a line
// TODO: zombie bug? (eg, shrink down view so that glyphs won't fit on a line, though seems to happen at other points too)
// TODO: NSFont boundsForGlyph seems to be returning utter garbage in many cases
// TODO: crash if we shrink the view below the size of the left/right margin
// TODO: Deal with images that occupy a margin and that are shorter than the image that's currently there better
// TODO: Migrate to CoreText?

#include <tgmath.h>
#import <GlkView/GlkImage.h>
#import "glk.h"

#import <GlkView/GlkTypesetter.h>
#import <GlkView/GlkCustomTextSection.h>

@implementation GlkLineSection
@synthesize advancement;
@synthesize alignment;
@synthesize bounds;
@synthesize delegate;
@synthesize offset;
@synthesize glyphRange;
@synthesize elastic;
@end

// Internal classes
@interface GlkMarginSection : NSObject {
	NSInteger fragmentGlyph;
	CGFloat width;
	CGFloat maxY;
}

- (id) initWithFragmentGlyph: (NSInteger) glyph
					   width: (CGFloat) width
						maxY: (CGFloat) maxY;

@property (readonly) NSInteger glyph;
@property (readonly) CGFloat width;
@property (readonly) CGFloat maxY;

@end

@implementation GlkMarginSection

- (id) initWithFragmentGlyph: (NSInteger) glyph
					   width: (CGFloat) newWidth
						maxY: (CGFloat) newMaxY {
	self = [super init];
	
	if (self) {
		fragmentGlyph = glyph;
		width = newWidth;
		maxY = newMaxY;
	}
	
	return self;
}

@synthesize glyph=fragmentGlyph;
@synthesize width;
@synthesize maxY;

@end

// Behaviour #defines

#define GlyphLookahead 512								// Number of glyphs to 'look ahead' when working out character positioning, etc
#define GlyphMinRemoval 256								// Minimum number of glyphs to remove from the cache all at once
#undef  Debug											// Define to put this in debugging mode
#undef  MoreDebug										// More debugging information
#undef  EvenMoreDebug									// Even more debugging information
#undef  CheckForOverflow								// Check for overflow when laying out the lines

// OS X version #defines

#undef MeasureMultiGlyphs								// Use the 10.4 routines in NSFont to measure multiple glyphs at once

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
# define MeasureMultiGlyphs
#endif

#undef MeasureMultiGlyphs

// Static variables

static NSCharacterSet* newlineSet = nil;
static NSCharacterSet* whitespaceSet = nil;

static NSParagraphStyle* defaultParaStyle = nil;

#ifdef Debug
static NSString* buggyAttribute = @"BUG IF WE TRY TO ACCESS THIS";
#endif

@implementation GlkTypesetter

- (instancetype)init
{
	if (self = [super init]) {
		sections = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void) dealloc {
	// Release any attributes that we still have cached
	NSDictionary* lastAttribute = nil;
	
	int x;
	for (x=0; x<cached.length; x++) {
		if (cacheAttributes[x] != lastAttribute) {
			lastAttribute = cacheAttributes[x];
			[lastAttribute release];
		}
	}
	
	// Free up the various caches
	if (cacheGlyphs) free(cacheGlyphs);
	if (cacheCharIndexes) free(cacheCharIndexes);
	if (cacheProperties) free(cacheProperties);
	if (cacheBidi) free(cacheBidi);
	if (cacheAdvancements) free(cacheAdvancements);
	if (cacheAscenders) free(cacheAscenders);
	if (cacheDescenders) free(cacheDescenders);
	if (cacheLineHeight) free(cacheLineHeight);
	if (cacheBounds) free(cacheBounds);
	if (cacheAttributes) free(cacheAttributes);
	if (cacheFonts) free(cacheFonts);
	
	[sections release];
	delegate = nil;
	
	[super dealloc];
}

//
// Unfortunately, it appears that NSATSTypesetter is not customisable enough for the things I need to do to
// create a proper Glk display. Therefore, this is some pretty deep black magic: a from-scratch NSTypesetter
// subclass.
//
// Apple's documentation on this is somewhat sketchy, so this is probably going to be a little flakey in places.
//

#pragma mark - Getting glyph information

- (void) flushCache {
	// Flushes out glyphs from the cache
	int x;
	
	// Release the dictionary entries
	NSDictionary* lastEntry = nil;
	for (x=0; x<cached.length; x++) {
#ifdef Debug
		if ((NSString*)cacheAttributes[x] == buggyAttribute) {
			NSLog(@"Oops: tried to flush an attribute that has already been freed! (%i/%i)", x, x+cached.location);
			continue;
		}
#endif
		
		if (cacheAttributes[x] != lastEntry) {
			lastEntry = cacheAttributes[x];
			[lastEntry release];
		}
		
		cacheAttributes[x] = nil;
	}
	
	// Clear the cache
	cached.location = cached.length = 0;
	paragraph.location = -1;
	paragraph.length = 0;
}

- (void) measureGlyphs: (CGGlyph*) glyphs
				 count: (NSInteger) count
				  font: (NSFont*) font
		  advancements: (CGFloat*) advancements
				bounds: (NSRect*) bounds {
#ifdef Debug
	if (count <= 0) {
		NSLog(@"No glyphs to measure!");
		return;
	}
#endif
	
	// Measures the specified range of glyphs in the given font
	int x;
	
	// Ordered array of the glyphs to measure (avoids measuring the same glyph twice)
	int numGlyphs = 0;
	int numAllocated = 128;
	CGGlyph* glyphsToMeasure = malloc(sizeof(CGGlyph)*numAllocated);
	
	// Get an ordered array containing the unique glyphs that we need to measure as a part of this call
	for (x=0; x<count; x++) {
		CGGlyph glyph = glyphs[x];
		
		int top = numGlyphs - 1;
		int bottom = 0;
		
		while (top >= bottom) {
			int middle = (top+bottom)>>1;
			
			if (glyphsToMeasure[middle] > glyph) top = middle - 1;
			else if (glyphsToMeasure[middle] < glyph) bottom = middle + 1;
			else {
				top = bottom = middle;
				break;
			}
		}
		
		// Bottom now indicates the first glyph that is greater than this glyph
		if (bottom < numGlyphs && glyphsToMeasure[bottom] == glyph) continue;
		
		// Insert this glyph into the list of glyphs to measure
		if (numGlyphs >= numAllocated) {
			numAllocated += 128;
			glyphsToMeasure = realloc(glyphsToMeasure, sizeof(CGGlyph)*numAllocated);
		}
		
		if (bottom != numGlyphs)
			memmove(glyphsToMeasure + bottom + 1, glyphsToMeasure + bottom, sizeof(CGGlyph)*(numGlyphs-bottom));
		numGlyphs++;
		
		glyphsToMeasure[bottom] = glyph;
	}
	
#ifdef Debug
	NSLog(@"Glyph measurement badness %.2f (%i varieties)", (CGFloat)numGlyphs/(CGFloat)count, numGlyphs);
#endif
	
	// Measure each glyph in the glyph array
	NSSize advance[numGlyphs+1];
	NSRect bounding[numGlyphs+1];
	
#ifndef MeasureMultiGlyphs
	// Compatible mode: measure one glyph at a time
	for (x=0; x<numGlyphs; x++) {
		CGGlyph glyph = glyphsToMeasure[x];
		
		NSSize glyphAdvance = [font advancementForCGGlyph: glyph];
		NSRect glyphBounds = [font boundingRectForCGGlyph: glyph];
		
		advance[x] = glyphAdvance;
		bounding[x] = glyphBounds;
	}
#else
	// 10.4+ mode: measure many glyphs at once
	[font getAdvancements: advance
				forGlyphs: glyphsToMeasure
					count: numGlyphs];
	[font getBoundingRects: bounding
				 forGlyphs: glyphsToMeasure
					 count: numGlyphs];
#endif
	
	// Put the results into the advancements and bounds arrays
	for (x=0; x<count; x++) {
		CGGlyph glyph = glyphs[x];
		
		// Binary search for this glyph
		int top = numGlyphs-1;
		int bottom = 0;
		
		while (top >= bottom) {
			int middle = (top+bottom)>>1;
			
			if (glyphsToMeasure[middle] > glyph) top = middle - 1;
			else if (glyphsToMeasure[middle] < glyph) bottom = middle + 1;
			else {
				advancements[x] = advance[middle].width;
				bounds[x] = bounding[x];
				break;
			}
		}
		
#ifdef Debug
		if (top < bottom) {
			NSLog(@"Failed to find a cached glyph (%i)!", glyph);
			
#ifdef EvenMoreDebug
			int y;
			for (y=0; y<numGlyphs; y++) {
				NSLog(@"Got glyph %i", glyphsToMeasure[y]);
			}
#endif
		}
#endif
	}
	
	// Tidy up
	free(glyphsToMeasure);
}

- (BOOL) cacheGlyphsIncluding: (NSInteger) minGlyphIndex {
	NSInteger x;
	
	// Use the layout manager and the text storage object to get the widths and attributes of the glyphs
	if (cached.location > minGlyphIndex) {
		// TODO: insert glyphs before this point?
		[self flushCache];
	}
	
	if (cached.location + cached.length > minGlyphIndex) {
		// This glyph is already cached
		return YES;
	}
	
	// Work out the range of glyph locations to get positional information for
	NSRange cacheRange;
	
	if (cached.length == 0) {
		cacheRange.location = minGlyphIndex;
		cacheRange.length = GlyphLookahead;
	} else {
		cacheRange.location = cached.length + cached.location;
		cacheRange.length = (minGlyphIndex+1)-cached.location;
	}
	
	if (cacheRange.length < GlyphLookahead) cacheRange.length = GlyphLookahead;
	
	// The cache range must lie within the number of glyphs in the layout manager
	NSUInteger numGlyphs = [layout numberOfGlyphs];
	if (cacheRange.length + cacheRange.location > numGlyphs) {
		cacheRange.length = numGlyphs - cacheRange.location;
	}
	
	if (cacheRange.length <= 0) {
		return NO;
	}
	
	// Get the glyphs and character indexes from the layout manager
	CGGlyph glyphs[cacheRange.length+1];
	NSUInteger charIndexes[cacheRange.length+1];
	NSGlyphProperty properties[cacheRange.length+1];
	unsigned char bidi[cacheRange.length+1];					// NOT YET USED
	
	cacheRange.length = [layout getGlyphsInRange: cacheRange
										  glyphs: glyphs
									  properties: properties
								characterIndexes: charIndexes
									  bidiLevels: bidi];
	
	if (cacheRange.length == 0) return NO;
	
	// Get the attributes from the storage
	NSDictionary* attributes[cacheRange.length];
	NSFont* fonts[cacheRange.length];
	CGFloat ascenders[cacheRange.length];
	CGFloat descenders[cacheRange.length];
	CGFloat lineHeight[cacheRange.length];
	
	NSDictionary* currentAttributes = nil;
	NSDictionary* lastAttributes = nil;
	NSFont* currentFont = nil;
	CGFloat currentAscender = 0;
	CGFloat currentDescender = 0;
	CGFloat currentHeight = 0;
	NSRange attributeRange = NSMakeRange(-1, 0);
	
	if (cached.length > 0)
		lastAttributes = cacheAttributes[cached.length-1];
	
	for (x=0; x<cacheRange.length; x++) {
		// Get the next set of attributes, if necessary
		if (charIndexes[x] < attributeRange.location || charIndexes[x] >= attributeRange.location + attributeRange.length) {
			currentAttributes = [storage attributesAtIndex: charIndexes[x]
											effectiveRange: &attributeRange];
			if (currentAttributes != lastAttributes)
				[currentAttributes retain];
			lastAttributes = currentAttributes;
			
			currentFont = [layout substituteFontForFont: (NSFont*) [currentAttributes objectForKey: NSFontAttributeName]];
			currentAscender = [currentFont ascender];
			currentDescender = [currentFont descender];
			currentHeight = [[self layoutManager] defaultLineHeightForFont: currentFont];
		}
		
		// Set the current attributes
		attributes[x] = currentAttributes;
		fonts[x] = currentFont;
		ascenders[x] = currentAscender;
		descenders[x] = currentDescender;
		lineHeight[x] = currentHeight;
	}
	
	// Get the advancement and bounds information from the NSFont class
	NSRect bounds[cacheRange.length];
	CGFloat advancements[cacheRange.length];
	
	for (x=0; x<cacheRange.length;) {
		// Work out the span of the current font
		NSFont* font = fonts[x];
		NSInteger length = 0;
		NSInteger start = x;
		for (; x<cacheRange.length && fonts[x] == font; x++, length++);
		
		// Measure this set of glyphs
		[self measureGlyphs: glyphs + start
					  count: length
					   font: font
			   advancements: advancements + start
					 bounds: bounds + start];
		
#ifdef EvenMoreDebug
		int y;
		NSLog(@"-- Measured --");
		for (y=start; y<x; y++) {
			NSLog(@"%g", advancements[y]);
		}
		if (start > 0) {
			NSLog(@"Previous: %g", advancements[start-1]);
		}
#endif
	}

#ifdef EvenMoreDebug
	int y;
	NSLog(@"-- Advancements --");
	for (y=0; y<cacheRange.length; y++) {
		NSLog(@"%g", advancements[y]);
	}
#endif
	
	// Copy the results to the cache
	NSUInteger cacheIndex;
	
	if (cached.length == 0) {
#ifdef Debug
		NSLog(@"Resetting cache (is 0 length)");
#endif
		cached.location = cacheRange.location;
		cached.length = cacheRange.length;
		cacheIndex = 0;
	} else {
		cacheIndex = cacheRange.location - cached.location;
		cached.length = (cacheRange.location + cacheRange.length)-cached.location;
	}
	
	// Reallocate as necessary
	if (cached.length >= cacheLength) {
		cacheLength = cached.length + GlyphLookahead;

		cacheGlyphs = realloc(cacheGlyphs, sizeof(CGGlyph)*cacheLength);
		cacheCharIndexes = realloc(cacheCharIndexes, sizeof(NSUInteger)*cacheLength);
		cacheProperties = realloc(cacheProperties, sizeof(NSGlyphProperty)*cacheLength);
		cacheBidi = realloc(cacheBidi, sizeof(unsigned char)*cacheLength);
		
		cacheAdvancements = realloc(cacheAdvancements, sizeof(CGFloat)*cacheLength);
		cacheAscenders = realloc(cacheAscenders, sizeof(CGFloat)*cacheLength);
		cacheDescenders = realloc(cacheDescenders, sizeof(CGFloat)*cacheLength);
		cacheLineHeight = realloc(cacheLineHeight, sizeof(CGFloat)*cacheLength);
		cacheBounds = realloc(cacheBounds, sizeof(NSRect)*cacheLength);
		cacheAttributes = realloc(cacheAttributes, sizeof(NSDictionary*)*cacheLength);
		cacheFonts = realloc(cacheFonts, sizeof(NSFont*)*cacheLength);
	}
	
	// Copy the various bits and pieces
	memcpy(cacheGlyphs + cacheIndex, glyphs, cacheRange.length*sizeof(CGGlyph));
	memcpy(cacheCharIndexes + cacheIndex, charIndexes, cacheRange.length*sizeof(NSUInteger));
	memcpy(cacheProperties + cacheIndex, properties, cacheRange.length*sizeof(NSGlyphProperty));
	memcpy(cacheBidi + cacheIndex, bidi, cacheRange.length*sizeof(unsigned char));

	memcpy(cacheAdvancements + cacheIndex, advancements, cacheRange.length*sizeof(CGFloat));
	memcpy(cacheAscenders + cacheIndex, ascenders, cacheRange.length*sizeof(CGFloat));
	memcpy(cacheDescenders + cacheIndex, descenders, cacheRange.length*sizeof(CGFloat));
	memcpy(cacheLineHeight + cacheIndex, lineHeight, cacheRange.length*sizeof(CGFloat));
	memcpy(cacheBounds + cacheIndex, bounds, cacheRange.length*sizeof(NSRect));
	memcpy(cacheAttributes + cacheIndex, attributes, cacheRange.length*sizeof(NSDictionary*));
	memcpy(cacheFonts + cacheIndex, fonts, cacheRange.length*sizeof(NSFont*));

	// Result depends on whether or not we actually measured the specified glyph
	return cacheRange.location + cacheRange.length > minGlyphIndex;
}

- (void) removeGlyphsFromCache: (NSInteger) newMinGlyphIndex {
	// Removes glyphs from the cache that are no longer going to be used
	int x;
	NSUInteger glyphsToRemove = newMinGlyphIndex - cached.location;
	
#ifdef Debug
	if (glyphsToRemove < 0) {
		NSLog(@"Oops: tried to remove glyphs that were already gone!");
		return;
	}
#endif

	if (glyphsToRemove < GlyphMinRemoval) {
		// Not enough glyphs already in the cache to justify starting to remove some more
		return;
	}
	
	if (glyphsToRemove > cached.length) {
		NSLog(@"Oops: tried to remove more glyphs than exist!");
		[self flushCache];
		return;
	}
	
	// Release any dictionary entries for the glyphs that we're removing
	for (x=0; x<glyphsToRemove; x++) {
		NSDictionary* thisEntry = cacheAttributes[x];
		NSDictionary* nextEntry = nil;

#ifdef DEBUG
		if (thisEntry == buggyAttribute) {
			NSLog(@"Oops: Tried to free a cached character twice (%i/%i)", x, x+cached.location);
			continue;
		}
#endif
				
		if (x+1 < cached.length) nextEntry = cacheAttributes[x+1];
		
		// Only release the last mention in the cache of a particular run of attributes
		if (nextEntry != thisEntry) [thisEntry release];
		cacheAttributes[x] = nil;
	}
	
	// Move the caches around
	NSUInteger numRemaining = cached.length - glyphsToRemove;
	memmove(cacheGlyphs, cacheGlyphs + glyphsToRemove, sizeof(CGGlyph)*numRemaining);
	memmove(cacheCharIndexes, cacheCharIndexes + glyphsToRemove, sizeof(NSUInteger)*numRemaining);
	memmove(cacheProperties, cacheProperties + glyphsToRemove, sizeof(NSGlyphProperty)*numRemaining);
	memmove(cacheBidi, cacheBidi + glyphsToRemove, sizeof(unsigned char)*numRemaining);

	memmove(cacheAdvancements, cacheAdvancements + glyphsToRemove, sizeof(CGFloat)*numRemaining);
	memmove(cacheAscenders, cacheAscenders + glyphsToRemove, sizeof(CGFloat)*numRemaining);
	memmove(cacheDescenders, cacheDescenders + glyphsToRemove, sizeof(CGFloat)*numRemaining);
	memmove(cacheLineHeight, cacheLineHeight + glyphsToRemove, sizeof(CGFloat)*numRemaining);
	memmove(cacheBounds, cacheBounds + glyphsToRemove, sizeof(NSRect)*numRemaining);
	memmove(cacheAttributes, cacheAttributes + glyphsToRemove, sizeof(NSDictionary*)*numRemaining);
	memmove(cacheFonts, cacheFonts + glyphsToRemove, sizeof(NSFont*)*numRemaining);
	
#ifdef Debug
	for (x=numRemaining; x<cached.length; x++) {
		cacheAttributes[x] = (NSDictionary*)buggyAttribute;
	}
#endif
	
	// Reset the cache location
	cached.location += glyphsToRemove;
	cached.length = numRemaining;
}

#pragma mark - Margins

- (NSInteger) marginNearest: (NSInteger) glyph
			  inMarginArray: (NSArray<GlkMarginSection*>*) margin {
	// Finds the index of the margin nearest the specified glyph
	NSInteger top = [margin count] - 1;
	NSInteger bottom = 0;
	
	while (top >= bottom) {
		NSInteger middle = (top + bottom)>>1;
		
		GlkMarginSection* thisSection = [margin objectAtIndex: middle];
		NSInteger thisGlyph = [thisSection glyph];
		
		if (thisGlyph > glyph) top = middle - 1;
		else if (thisGlyph < glyph) bottom = middle + 1;
		else return middle;
	}
	
	// Top is the first margin with a glyph less than the specified position
	return top;
}

- (void) removeMarginsFrom: (NSInteger) glyph
						to: (NSInteger) finalGlyph
				   inArray: (NSMutableArray*) margin {
	// Finds the index of the margin nearest the lower glyph
	NSInteger count = [margin count];
	NSInteger top = count - 1;
	NSInteger bottom = 0;
	
	while (top >= bottom) {
		NSInteger middle = (top + bottom)>>1;
		
		GlkMarginSection* thisSection = [margin objectAtIndex: middle];
		NSInteger thisGlyph = [thisSection glyph];
		
		if (thisGlyph > glyph) top = middle - 1;
		else if (thisGlyph < glyph) bottom = middle + 1;
		else {
			bottom = middle;
			break;
		}
	}
	
	// bottom is the first section within the specified range: work out how many items to remove
	NSInteger numToRemove = 0;
	while (bottom < count) {
		GlkMarginSection* candidate = [margin objectAtIndex: bottom];
		NSInteger candidateGlyph = [candidate glyph];
		
		if (candidateGlyph >= finalGlyph) break;
		
		numToRemove++;
		count--;
	}
	
	if (numToRemove > 0) {
		[margin removeObjectsInRange: NSMakeRange(bottom, numToRemove)];
	}
}

- (void) addToLeftMargin: (CGFloat) width
				  height: (CGFloat) height {
	thisLeftMargin += width;
	if (height + NSMaxY(usedRect) > thisLeftMaxY) {
		thisLeftMaxY = height + NSMaxY(usedRect);
	}
}

- (void) addToRightMargin: (CGFloat) width
				   height: (CGFloat) height {
	thisRightMargin += width;
	if (height + NSMaxY(usedRect) > thisRightMaxY) {
		thisRightMaxY = height + NSMaxY(usedRect);
	}
}

- (CGFloat) currentLeftMarginOffset {
	return thisLeftMargin + inset + (activeLeftMargin?[activeLeftMargin width]:0);
}

- (CGFloat) currentRightMarginOffset {
	return thisRightMargin + inset + (activeRightMargin?[activeRightMargin width]:0);	
}

- (CGFloat) remainingMargin {
	return usedRect.size.width - (activeLeftMargin?[activeLeftMargin width]:0) - (activeRightMargin?[activeRightMargin width]:0) - thisLeftMargin - thisRightMargin - inset*2;
}

- (CGFloat) currentLeftMarginHeight {
	CGFloat result = activeLeftMargin?[activeLeftMargin maxY]:0;
	if (thisLeftMaxY > result) result = thisLeftMaxY;
	return result - NSMaxY(usedRect);
}

- (CGFloat) currentRightMarginHeight {
	CGFloat result = activeRightMargin?[activeRightMargin maxY]:0;
	if (thisRightMaxY > result) result = thisRightMaxY;
	return result - NSMaxY(usedRect);
}

#pragma mark - Laying out line sections

- (void) beginLineFragment {
	// Starts a new line fragment
	[sections removeAllObjects];
	
	usedRect = [layout usedRectForTextContainer: container];
	customBaseline = NO;
	customOffset = 0;
	
	// Clear the left/right margins if necessary
	if (activeLeftMargin && NSMaxY(usedRect) > [activeLeftMargin maxY]) activeLeftMargin = nil;
	if (activeRightMargin && NSMaxY(usedRect) > [activeRightMargin maxY]) activeRightMargin = nil;
	
	thisLeftMargin = thisRightMargin = thisLeftMaxY = thisRightMaxY = 0;
}

/// Fixes the bounds of the current set of line fragments according to the various alignments that are present
- (void) fixBounds {
	// Work out the baseline offset and unaligned bounds for this line fragment
	CGFloat baselineOffset = -fragmentBounds.origin.y;
	customOffset = 0;
	
	// Use only the items aligned to the baseline to work out the 'real' baseline.
	baselineOffset = 0;
	fragmentBounds = NSMakeRect(0,0,0,0);
	for (GlkLineSection *section in sections) {
		if (section.alignment == GlkAlignBaseline) {
			if (section.bounds.origin.y < baselineOffset) {
				baselineOffset = section.bounds.origin.y;
			}
			
			fragmentBounds = NSUnionRect(fragmentBounds, section.bounds);
		}
	}
	
	baselineOffset = -baselineOffset;
	
	// Now work out the effect of the custom aligned sections on the bounds and the baseline
	if (customBaseline) {
		for (GlkLineSection *section in sections) {
			switch (section.alignment) {
				case GlkAlignBaseline:
					break;
				
				case GlkAlignTop:
				{
					NSRect bounds = section.bounds;
					bounds.origin.y -= NSMaxY(bounds);

					if (-bounds.origin.y-baselineOffset > customOffset) customOffset = -bounds.origin.y-baselineOffset;

					fragmentBounds = NSUnionRect(fragmentBounds, bounds);
					break;
				}
					
				case GlkAlignBottom:
				{
					NSRect bounds = section.bounds;
					bounds.origin.y = -baselineOffset;

					fragmentBounds = NSUnionRect(fragmentBounds, bounds);
					break;
				}
					
				case GlkAlignCenter:
				{
					NSRect bounds = section.bounds;
					bounds.origin.y = -(baselineOffset + bounds.size.height)/2;
					
					if (-bounds.origin.y-baselineOffset > customOffset) customOffset = -bounds.origin.y-baselineOffset;
					
					fragmentBounds = NSUnionRect(fragmentBounds, bounds);
					break;
				}
			}
		}
	}
}

/// Finishes the current line fragment and adds it to the layout manager
- (BOOL) endLineFragment: (BOOL) hitTheLastGlyph
				 newline: (BOOL) newline {
	if (sections.count <= 0) return YES;
	
	// Get the bounds of the line fragment, and adjust it for its final position
	NSRect bounds = proposedRect;
	
	// Add leading to the line
	if (paraStyle != nil) bounds.size.height += [paraStyle lineSpacing];

	NSRect used = bounds;
	
	// Work out the glyph range for this line fragment
	NSUInteger firstGlyph = sections.firstObject.glyphRange.location;
	NSUInteger lastGlyph = sections.lastObject.glyphRange.location + sections.lastObject.glyphRange.length;
	NSRange glyphRange = NSMakeRange(firstGlyph, lastGlyph-firstGlyph);
	
	// Work out the baseline offset for this line fragment
	CGFloat baselineOffset = -fragmentBounds.origin.y;
	
	if (customBaseline) {
		// Use only the items aligned to the baseline to work out the 'real' baseline.
		baselineOffset = 0;
		for (GlkLineSection *section in sections) {
			if (section.alignment == GlkAlignBaseline) {
				if (section.bounds.origin.y < baselineOffset) {
					baselineOffset = section.bounds.origin.y;
				}
			}
		}
		
		baselineOffset = -baselineOffset;
	}
	
	if (hitTheLastGlyph) {
		used.size.width = NSMaxX(fragmentBounds)-used.origin.x + inset;
	}
	
	// Start laying out this line fragment
	NSRect integralBounds = NSIntegralRect(bounds);
	
	if (NSMaxY(integralBounds) > [container containerSize].height) {
		return NO;
	}
	
	[layout setTextContainer: container
			   forGlyphRange: glyphRange];
	[layout setLineFragmentRect: integralBounds
				  forGlyphRange: glyphRange
					   usedRect: NSIntegralRect(used)];
	
	baselineOffset = floor(baselineOffset + 0.5);
	
	// Position the glyphs within the line sections
	CGFloat maxX = 0.0;
	for (GlkLineSection *section in sections) {
		if (section.glyphRange.length <= 0) continue;
		
		NSPoint loc;
		loc.x = section.offset;
		
		maxX = loc.x + section.advancement;
		
		switch (section.alignment) {
			case GlkAlignBaseline:
			default:
				loc.y = baselineOffset + customOffset;
				break;
				
			case GlkAlignTop:
				loc.y = baselineOffset+customOffset - section.bounds.size.height + NSMaxY(section.bounds);
				break;
				
			case GlkAlignBottom:
				loc.y = customOffset - NSMaxY(section.bounds);
				break;
				
			case GlkAlignCenter:
				loc.y = customOffset - (-baselineOffset + section.bounds.size.height)/2 - NSMaxY(section.bounds);
				break;
		}
		
		// Call the delegate
		if (section.delegate) {
			[section.delegate placeBaselineAt: loc
									 forGlyph: section.glyphRange.location];
		}
		
		// Set the location for this range of glyphs
		[layout setLocation: loc
	   forStartOfGlyphRange: section.glyphRange];
		
		// Set any NSControlGlyphs to invisible
		NSInteger lastGlyph = section.glyphRange.location + section.glyphRange.length - cached.location;
		for (NSInteger y=section.glyphRange.location-cached.location; y<lastGlyph; y++) {
			if ((cacheProperties[y] & (NSGlyphPropertyNull | NSGlyphPropertyControlCharacter)) != 0) {
				[layout setNotShownAttribute: YES
							 forGlyphAtIndex: y+cached.location];
			}
		}
		
#ifdef CheckForOverflow
		CGFloat offset = sections[x].offset;
		for (y=sections[x].glyphRange.location; y < sections[x].glyphRange.location+sections[x].glyphRange.length; y++) {
			offset += cacheAdvancements[y-cached.location];
		}
		if (offset > NSMaxX(proposedRect)-inset) {
			NSLog(@"Section %i overflows the line fragment rectangle", x);
		}
#endif
	}
	
	// Add the 'extra' spacing around the final fragment
	if (hitTheLastGlyph == YES) {
		NSRect remainingSpace = bounds;
		
		if (!newline) {
			//remainingSpace.origin.y = fragmentBounds.origin.y;
			//remainingSpace.size.height = fragmentBounds.size.height;
			remainingSpace.origin.x = maxX-inset;
			remainingSpace.size.width = bounds.size.width - (maxX-inset*2);
		} else {
			remainingSpace.origin.y = NSMaxY(bounds);
			remainingSpace.origin.x = inset;
			remainingSpace.size.width = bounds.size.width-inset*2;
		}
		
#if 0
		[layout setExtraLineFragmentRect: NSIntegralRect(remainingSpace)
								usedRect: remainingSpace
						   textContainer: container];
#endif
	}
	
	// Done
	
#ifdef MoreDebug
	NSLog(@"Laid out %i sections (glyphs %i-%i)", numLineSections, glyphRange.location, glyphRange.location+glyphRange.length);
#endif
		
	return YES;
}

- (void) addLineSection: (GlkRect) bounds
			advancement: (CGFloat) advancement
				 offset: (CGFloat) offset
			 glyphRange: (NSRange) glyphRange
			  alignment: (GlkSectionAlignment) alignment
			   delegate: (id<GlkCustomLineSection>) sectionDelegate
				elastic: (BOOL) elastic {
#ifdef CheckForOverflow
	if (numLineSections > 0 && glyphRange.location != sections[numLineSections-1].glyphRange.location + sections[numLineSections-1].glyphRange.length) {
		NSLog(@"Non-contiguous line sections");
	}
#endif
	
	// Adds a new line section
	GlkLineSection *newSec = [[GlkLineSection alloc] init];
	newSec.bounds = bounds;
	newSec.advancement = advancement;
	newSec.offset = offset;
	newSec.glyphRange = glyphRange;
	newSec.alignment = alignment;
	newSec.delegate = sectionDelegate;
	newSec.elastic = elastic;

	[sections addObject:newSec];
	
	if (alignment != GlkAlignBaseline) customBaseline = YES;
	
	if (sections.count == 1) {
		fragmentBounds = bounds;
	} else {
		fragmentBounds = NSUnionRect(fragmentBounds, bounds);
	}
}

#pragma mark - Dealing with paragraphs

- (BOOL) updateParagraphFromGlyph: (NSInteger) glyph {
	// Update the paragraph style from the specified glyph
	if (paragraph.location <= glyph && paragraph.location+paragraph.length > glyph)
		return paragraph.location == glyph;
	
	// Find the next paragraph break
	if (![self cacheGlyphsIncluding: glyph]) {
		return NO;
	}
	
	if (newlineSet == nil) {
		newlineSet = [[NSCharacterSet characterSetWithCharactersInString: @"\n\r"] retain];
	}
	
	NSUInteger thisChar = cacheCharIndexes[glyph-cached.location];
	NSRange nextBreak = [[storage string] rangeOfCharacterFromSet: newlineSet
													  options: NSLiteralSearch
														range: NSMakeRange(thisChar, [[storage string] length] - thisChar)];
	
	if (nextBreak.location == NSNotFound) {
		nextBreak.location = [[storage string] length];
	} else {
		nextBreak.location++;
	}
	
	// Work out the range this represents (in terms of glyphs)
	NSRange charRange = NSMakeRange(thisChar, nextBreak.location-thisChar);
	paragraph = [layout glyphRangeForCharacterRange: charRange
							   actualCharacterRange: &charRange];
	
	// Get the style for this paragraph
	paraStyle = [cacheAttributes[glyph-cached.location] objectForKey: NSParagraphStyleAttributeName];
	
	if (paraStyle == nil) {
		if (defaultParaStyle == nil) {
			defaultParaStyle = [[NSParagraphStyle defaultParagraphStyle] retain];
		}
		paraStyle = defaultParaStyle;
	}
	
	return YES;
}

#pragma mark - Laying out glyphs

- (void) justifyCurrentLineFragment: (NSTextAlignment) alignment
							 inRect: (GlkRect) proposed
						 leftIndent: (CGFloat) leftMargin
						rightIndent: (CGFloat) rightMargin
							newline: (BOOL) newline {
	// Work out the total width of this section
	CGFloat totalWidth = 0;
	
	for (GlkLineSection *section in sections) {
		totalWidth += section.advancement;
	}
	
	if (newline && alignment == NSTextAlignmentJustified) {
		alignment = NSTextAlignmentNatural;
	}
	
	switch (alignment) {
		case NSTextAlignmentLeft:
		case NSTextAlignmentNatural:
			// Nothing to do
			break;
			
		case NSTextAlignmentCenter:
		{
			CGFloat offset = (proposed.size.width - totalWidth - inset*2 - leftMargin - rightMargin - thisLeftMargin - (activeLeftMargin?[activeLeftMargin width]:0)) / 2;
			offset += proposed.origin.x + inset + leftMargin + thisLeftMargin + (activeLeftMargin?[activeLeftMargin width]:0);
			
			for (GlkLineSection *section in sections) {
				section.offset = offset;
				offset += section.advancement;
			}
			break;
		}
			
		case NSTextAlignmentRight:
		{
			CGFloat offset = (proposed.size.width - totalWidth - inset - rightMargin - thisLeftMargin - (activeLeftMargin?[activeLeftMargin width]:0));
			offset += proposed.origin.x + thisLeftMargin + (activeLeftMargin?[activeLeftMargin width]:0);
			
			for (GlkLineSection *section in sections) {
				section.offset = offset;
				offset += section.advancement;
			}
			break;
		}
			
		case NSTextAlignmentJustified:
		{
			int elasticCount = 0;
			
			// Count the number of elastic sections
			for (GlkLineSection *section in sections) {
				if (section.elastic) elasticCount++;
			}
			
			// Give up if there are no elastic sections (TODO: fully-justify all characters?)
			if (elasticCount <= 0) break;
			
			// Work out the additional advancement for each line section
			CGFloat adjustment = (proposed.size.width - totalWidth - inset*2 - leftMargin - rightMargin - thisLeftMargin - (activeLeftMargin?[activeLeftMargin width]:0))/(CGFloat)elasticCount;
			CGFloat offset = inset + leftMargin + thisLeftMargin + (activeLeftMargin?[activeLeftMargin width]:0);

			// Adjust the size of each section appropriately
			for (GlkLineSection *section in sections) {
				section.offset = floor(offset);
				offset += section.advancement;
				
				if (section.elastic) {
					offset += adjustment;
				}
			}
			
			break;
		}
	}
}

- (NSInteger) layoutLineFromGlyph: (NSInteger) glyph {
	// Lays out a single line fragment from the specified glyph
	if (![self cacheGlyphsIncluding: glyph]) return glyph;
	glyph -= cached.location;
	
	[self beginLineFragment];

	// Initial layout: lay out glyphs until the bounding box overflows the text container
	NSRect totalBounds = NSMakeRect(0,0,0,0);
	BOOL newline = NO;
	BOOL newParagraph = [self updateParagraphFromGlyph: glyph+cached.location];
	BOOL splitOnElastic = [paraStyle alignment]==NSTextAlignmentJustified;
	BOOL elastic = NO;
	
	CGFloat leftIndent = newParagraph?[paraStyle firstLineHeadIndent]:[paraStyle headIndent];
	CGFloat rightIndent = [paraStyle tailIndent];
	CGFloat offset = inset + leftIndent + (activeLeftMargin?[activeLeftMargin width]:0);
	
	BOOL hitTheLastGlyph = NO;
	NSInteger lastInvalidated = glyph;

	while (NSMaxX(totalBounds) < size.width && glyph < cached.length && !newline) {
		// Build up a line section for this set of glyphs
		NSDictionary* attributes = cacheAttributes[glyph];
		
		NSRect sectionBounds = NSMakeRect(offset, -cacheAscenders[glyph], 0.1, cacheLineHeight[glyph]);

		CGFloat initialOffset = offset;
		NSInteger initialGlyph = glyph;
		BOOL newsection = NO;
		BOOL customSection = NO;
		
		while (cacheAttributes[glyph] == attributes && NSMaxX(sectionBounds) < size.width && !newsection) {
			if ((cacheProperties[glyph] & NSGlyphPropertyControlCharacter) == NSGlyphPropertyControlCharacter) {
				// Perform control glyph layout
				unichar controlChar = [[storage string] characterAtIndex: cacheCharIndexes[glyph]];
				
				if (controlChar == '\n' || controlChar == '\r') {
					// Add a newline here
					newline = YES;
					newsection = YES;
				}
				
				// If this glyph has an associated custom text section, then get that to perform layout
				GlkCustomTextSection* custom = [attributes objectForKey: GlkCustomSectionAttributeName];
				if (custom) {
					NSRange glyphRange = NSMakeRange(glyph+cached.location, 1);
					BOOL addOffset = [custom formatSectionAtOffset: offset
													  inTypesetter: self
													 forGlyphRange: glyphRange];
					if (addOffset) {
						offset = sections.lastObject.offset + sections.lastObject.advancement;
						newsection = YES;
						customSection = YES;
					}
					
					// Tell the delegate about the new glyph
					if (delegate) {
						[delegate invalidateCustomGlyphs: NSMakeRange(lastInvalidated+cached.location, glyph-lastInvalidated+1)];
						[delegate addCustomGlyph: glyphRange.location
										 section: custom];
						lastInvalidated = glyph+1;
					}
				}
			} else if (cacheGlyphs[glyph] == NSNullGlyph) {
				// Ignore null glyphs
			} else {
				// Include this glyph in the set of glyphs
				NSRect bounds = NSMakeRect(offset, -cacheAscenders[glyph],
										   cacheAdvancements[glyph], cacheLineHeight[glyph]);
				
				sectionBounds = NSUnionRect(sectionBounds, bounds);
				offset += cacheAdvancements[glyph];
			}
			
			// Next glyph
			glyph++;
			
			if (glyph >= cached.length) {
#ifdef Debug
				int lastLocation = cached.location;
#endif
				
				if (![self cacheGlyphsIncluding: glyph+cached.location]) {
					hitTheLastGlyph = YES;
					break;
				}
				
#ifdef Debug
				if (cached.location != lastLocation) {
					NSLog(@"Oops: cache location moved in the middle of a line");
					break;
				}
#endif
			}
			
			// Stop here if we just added an elastic glyph
			if (splitOnElastic && (cacheProperties[glyph-1] & NSGlyphPropertyElastic) == NSGlyphPropertyElastic) {
				elastic = YES;
				break;
			}
		}
		
		// Store this line section
		if (!customSection) {
			NSRange glyphRange = NSMakeRange(initialGlyph + cached.location, glyph-initialGlyph);
			
			if (delegate && glyph > lastInvalidated) {
				NSRange invalidateRange = NSMakeRange(lastInvalidated + cached.location, glyph-lastInvalidated);
				[delegate invalidateCustomGlyphs: invalidateRange];
			}
			
			[self addLineSection: sectionBounds
					 advancement: offset-initialOffset
						  offset: initialOffset
					  glyphRange: glyphRange
					   alignment: GlkAlignBaseline
						delegate: nil
						 elastic: elastic];
		}
		
		// Merge with the total bounds
		totalBounds = NSUnionRect(totalBounds, sectionBounds);
	}
	
	// Secondary layout: remove characters as necessary to split this line properly
	CGFloat topPadding = 0;
	CGFloat bottomPadding = 0;
	if (newParagraph && paraStyle) {
		// This line is at the start of a new paragraph: add the paragraph spacing
		topPadding += [paraStyle paragraphSpacingBefore];
	}
	
	if (newline && paraStyle) {
		// This line is at the end of a paragraph: add the paragraph spacing
		bottomPadding += [paraStyle paragraphSpacing];
	}
	
	// If we've got a left margin for this section, then offset everything appropriately
	if (thisLeftMargin > 0) {
		for (GlkLineSection *section in sections) {
			section.offset += thisLeftMargin;
			NSRect preBounds = section.bounds;
			preBounds.origin.x += thisLeftMargin;
			section.bounds = preBounds;
		}
	}
	
	// Send the proposed rectangle to the text container for adjustment
	if (customBaseline) [self fixBounds];
	proposedRect = fragmentBounds;
	proposedRect.origin.y = NSMaxY(usedRect);
	proposedRect.origin.x = 0;
	proposedRect.size.height += topPadding + bottomPadding;
	proposedRect.size.width = size.width;
	
	proposedRect.size.width -= thisRightMargin + (activeRightMargin?[activeRightMargin width]:0);
	
	proposedRect = [container lineFragmentRectForProposedRect: proposedRect
											   sweepDirection: NSLineSweepRight
											movementDirection: NSLineMovesDown
												remainingRect: &remaining];
	
	if (proposedRect.size.height == 0 && sections.count > 0) {
		// If the proposed rect is 0-height, then do no further layout
		return sections[0].glyphRange.location;
	}
	
	// Find the first glyph that is within the proposed rectangle
	if (sections.count > 0) {
		// Find the character to split on, if we've overflowed the end of the box
		NSInteger splitSection = sections.count-1;
		NSInteger splitGlyph = sections[splitSection].glyphRange.location+sections[splitSection].glyphRange.length;
		
		// Version that searches backwards for the first glyph within the proposed rectangle (borken?)
		CGFloat splitPos = NSMaxX(sections[splitSection].bounds);

		for (;;) {
			// Move back a glyph
			splitGlyph--;
			if (splitGlyph < 0) {
				splitGlyph = 0;
				break;
			}
			
			if (splitGlyph < sections[splitSection].glyphRange.location) {
				splitSection--;
				if (splitSection < 0) break;
				
				splitPos = NSMaxX(sections[splitSection].bounds);
			}
			
			CGFloat maxPos;
			
			if (sections[splitSection].delegate != nil) {
				// For delegated sections, just skip the whole thing
				splitPos = sections[splitSection].offset;
				maxPos = splitPos + sections[splitSection].advancement;
				
				splitGlyph = sections[splitSection].glyphRange.location;
			} else if ((cacheProperties[splitGlyph-cached.location] &
						(NSGlyphPropertyControlCharacter | NSGlyphPropertyNull | NSGlyphPropertyElastic))
					   != 0) {
				// Other control and null glyphs have no real meaning (treat them as 0 width for the purposes of splitting)
				splitPos -= cacheAdvancements[splitGlyph-cached.location];
				maxPos = splitPos;
			} else {
				// For everthing else, move back single characters at a time
				splitPos -= cacheAdvancements[splitGlyph-cached.location];
				maxPos = splitPos + cacheAdvancements[splitGlyph-cached.location]; // + NSMaxX(cacheBounds[splitGlyph-cached.location]);
				// TODO? bounds seem messed up
			}
			
			if (maxPos < NSMaxX(proposedRect)-inset-rightIndent) {
				// This is the first glyph within the proposed rectangle
#ifdef MoreDebug
				NSLog(@"Split glyph: %i (max position %g out of %g, starting at %g [%g])", splitGlyph, maxPos, NSMaxX(proposedRect)-inset, splitPos, inset);
#endif
				break;
			}
		}
				
		// Move backwards from the split character to find a 'proper' character to split at
		if (splitSection>=0
			&& (splitSection+1 < sections.count
				|| sections[splitSection].glyphRange.location+sections[splitSection].glyphRange.length > splitGlyph+1)) {
			// Basic method: search backwards in the string for a whitespace character
			NSRange lineRange = NSMakeRange(cacheCharIndexes[sections[0].glyphRange.location-cached.location],
											cacheCharIndexes[splitGlyph+1-cached.location]);
			lineRange.length -= lineRange.location;
			
			if (whitespaceSet == nil) whitespaceSet = [[NSCharacterSet whitespaceCharacterSet] retain];
			
			NSRange whitespaceChar = [[storage string] rangeOfCharacterFromSet: whitespaceSet
																	   options: NSLiteralSearch|NSBackwardsSearch
																		 range: lineRange];
			
			if (whitespaceChar.location != NSNotFound) {
				NSRange tmp;
				splitGlyph = [layout glyphRangeForCharacterRange: NSMakeRange(whitespaceChar.location, 1)
											actualCharacterRange: &tmp].location;
			}
		}
		
		// TODO (?): hyphenation
		
		// Change the line sections so that we are splitting after splitGlyph
		while (splitSection>=0 && sections[splitSection].glyphRange.location > splitGlyph) splitSection--;
		if (splitSection < 0 || splitGlyph < sections[0].glyphRange.location) {
			splitSection = 0;
			splitGlyph = sections[0].glyphRange.location;
		}
		BOOL boundsChanged = sections.count != splitSection+1 || splitGlyph <= sections[splitSection].glyphRange.location;

		while (sections.count > splitSection+1) {
			[sections removeLastObject];
		}
		{
			NSRange preRange = sections[splitSection].glyphRange;
			preRange.length = (splitGlyph+1)-sections[splitSection].glyphRange.location;
			sections[splitSection].glyphRange = preRange;
		}
		
		if (boundsChanged || YES)
		{
			// Correct the advancement (required for justification to work)
			NSInteger advanceGlyph;
			NSInteger firstInSection = sections[splitSection].glyphRange.location-cached.location;
			NSInteger lastInSection = firstInSection + sections[splitSection].glyphRange.length;
			CGFloat newAdvance = 0;
			
			for (advanceGlyph=firstInSection; advanceGlyph<lastInSection; advanceGlyph++) {
				newAdvance += cacheAdvancements[advanceGlyph];
			}
			sections[splitSection].advancement = newAdvance;
			
			// Correct the bounding rectangle (it might be smaller now)
			[self fixBounds];
			
			proposedRect.size.height = fragmentBounds.size.height + topPadding+bottomPadding;
		}
		
		// Set the final glph, adjusted for the split
		glyph = splitGlyph+1 - cached.location;
	}
	
	// Justify this line
	[self justifyCurrentLineFragment: [paraStyle alignment]
							  inRect: proposedRect
						  leftIndent: leftIndent
						 rightIndent: rightIndent
							 newline: newline||(hitTheLastGlyph && glyph == cached.length)];
	
	// If we hit the last glyph, perform some additional formatting
	if (hitTheLastGlyph && glyph == cached.length) {
	} else {
		// We might have cached the last glyph, but this line doesn't end on it
		hitTheLastGlyph = NO;
	}

	// Finish laying out this line fragment
	fragmentBounds.origin.y -= topPadding;
	fragmentBounds.size.height += topPadding+bottomPadding;
	if (![self endLineFragment: hitTheLastGlyph
					   newline: newline]
		&& sections.count > 0) {
		// Failed to lay anything out!
		return sections[0].glyphRange.location;
	}
	
	// Update the usedRect for future methods
	usedRect.size.height = NSMaxY(remaining)-usedRect.origin.y;
	
	// If we hit the last glyph, tell the delegate to invalidate everything ahead of this point
	if (hitTheLastGlyph && delegate) {
		[delegate invalidateCustomGlyphs: NSMakeRange(glyph+cached.location, 2000000000-lastInvalidated+cached.location)];
	}
	
	// Update the margin bounds
	[self removeMarginsFrom: lineFragmentInitialGlyph
						 to: glyph+cached.location
					inArray: leftMargins];
	[self removeMarginsFrom: lineFragmentInitialGlyph
						 to: glyph+cached.location
					inArray: rightMargins];
	
	if (thisLeftMargin > 0) {
		if (leftMargins == nil) leftMargins = [[NSMutableArray alloc] init];
		
		NSInteger nearestLeft = [self marginNearest: lineFragmentInitialGlyph
									  inMarginArray: leftMargins];
		if (activeLeftMargin && [activeLeftMargin maxY] > thisRightMaxY) thisRightMaxY = [activeLeftMargin maxY];
		GlkMarginSection* newMargin = [[GlkMarginSection alloc] initWithFragmentGlyph: lineFragmentInitialGlyph
																				width: (activeLeftMargin?[activeLeftMargin width]:0) + thisLeftMargin
																				 maxY: thisLeftMaxY];
		[leftMargins insertObject: newMargin
						  atIndex: nearestLeft+1];
		[newMargin release];
	}
	
	if (thisRightMargin > 0) {
		if (rightMargins == nil) rightMargins = [[NSMutableArray alloc] init];

		NSInteger nearestRight = [self marginNearest: lineFragmentInitialGlyph
									   inMarginArray: rightMargins];
		if (activeRightMargin && [activeRightMargin maxY] > thisRightMaxY) thisRightMaxY = [activeRightMargin maxY];
		GlkMarginSection* newMargin = [[GlkMarginSection alloc] initWithFragmentGlyph: lineFragmentInitialGlyph
																				width: (activeRightMargin?[activeRightMargin width]:0) + thisRightMargin
																				 maxY: thisRightMaxY];
		[rightMargins insertObject: newMargin
						  atIndex: nearestRight+1];
		[newMargin release];
	}
	
	// Return the result
	return glyph + cached.location;
}

#pragma mark - NSTypesetter overrides

- (void) prepareForLayoutInLayoutManager: (NSLayoutManager*) layoutMgr
					startingAtGlyphIndex: (NSUInteger) startGlyphIndex {
	// Setup: get the things that we're gong to layout
	NSAttributedString* newStorage	= [layoutMgr attributedString];
	NSLayoutManager* newLayout		= layoutMgr;
	NSArray* newContainers			= [layoutMgr textContainers];
	
	if (newStorage != storage || newLayout != layout || newContainers != containers || lastSetGlyph != startGlyphIndex) {
#ifdef Debug
		NSLog(@"Storage/layout manager/text containers have changed: flushing");
#endif
		[self flushCache];
	}
	
	// Set the objects
	layout		= newLayout;
	storage		= newStorage;
	containers	= newContainers;
	container	= nil;
	
	// Set the text container
	if ([containers count] > 0) {
		// Lay out in a real container
		container	= [containers objectAtIndex: 0];
		inset		= [container lineFragmentPadding];
		
		size		= [container containerSize];
	} else {
		// Lay out in a fake container
		container	= nil;
		inset		= 0;
		
		size		= NSMakeSize(100, 100);
	}
}

- (void) layoutGlyphsInLayoutManager: (NSLayoutManager*) layoutMgr
				startingAtGlyphIndex: (NSUInteger) startGlyphIndex
			maxNumberOfLineFragments: (NSUInteger) maxNumLines
					  nextGlyphIndex: (NSUInteger*) nextGlyph {
	// Deal with the case where there are no text containers to perform layout in
#if 0
	if ([containers count] <= 0) {
		// Just say we've laid everything out, seeing as it's got nowhere to go
		if (nextGlyph) {
			*nextGlyph = [layout numberOfGlyphs];
		}
		
		return;
	}
#endif

	// Setup
	[self prepareForLayoutInLayoutManager: layoutMgr
					 startingAtGlyphIndex: startGlyphIndex];
	
	// Perform the layout
	NSInteger glyph = startGlyphIndex;
	for (NSInteger x=0; x<maxNumLines; x++) {
		// Set up line margin information
		lineFragmentInitialGlyph = glyph;
		NSInteger activeLeft = [self marginNearest: glyph-1
									 inMarginArray: leftMargins];
		NSInteger activeRight = [self marginNearest: glyph-1
									  inMarginArray: rightMargins];
		
		activeLeftMargin = activeRightMargin = nil;
		if (activeLeft >= 0) activeLeftMargin = [leftMargins objectAtIndex: activeLeft];
		if (activeRight >= 0) activeRightMargin = [rightMargins objectAtIndex: activeRight];
		
		// Lay out the next line fragment
		NSInteger nextGlyph = [self layoutLineFromGlyph: glyph];
		
		//[self removeGlyphsFromCache: nextGlyph];
		if (nextGlyph == glyph)
			[self flushCache];
		else
			[self removeGlyphsFromCache: nextGlyph];
		
		glyph = nextGlyph;
	}
	
	lastSetGlyph = glyph;
	if (nextGlyph)
		*nextGlyph = glyph;
	
	// TODO: if we've got the last glyph, tell the delegate to invalidate everything ahead of that point
}

- (NSRange) paragraphGlyphRange {
	if ([super respondsToSelector: @selector(paragraphGlyphRange)]) {
		return [super paragraphGlyphRange];
	} else {
		return NSMakeRange(0,0);
	}
}

- (void) beginParagraph {
	[super beginParagraph];
}

- (void) endParagraph {
	[super endParagraph];
}

- (void)beginLineWithGlyphAtIndex:(NSUInteger)glyphIndex {
	[super beginLineWithGlyphAtIndex: glyphIndex];
}

- (void)endLineWithGlyphRange:(NSRange)lineGlyphRange {
	[super endLineWithGlyphRange: lineGlyphRange];
}

- (NSUInteger)layoutParagraphAtPoint:(GlkPoint *)lineFragmentOrigi {
	// Get the glyph range that we're laying out
	NSRange glyphRange = [self paragraphGlyphRange];
	NSInteger glyph = glyphRange.location;
	
	// Prepare for layout
	[self prepareForLayoutInLayoutManager: [self layoutManager]					// Compiler warning is OK as layoutParagraphAtPoint: is only supported on 10.4 or later
					 startingAtGlyphIndex: glyph];
	[self cacheGlyphsIncluding: glyphRange.location];
	
	// Work out the glyph range of the current paragraph
	if (newlineSet == nil) {
		newlineSet = [[NSCharacterSet characterSetWithCharactersInString: @"\n\r"] retain];
	}
	
	NSUInteger thisChar = cacheCharIndexes[glyph-cached.location];
	NSRange nextBreak = [[storage string] rangeOfCharacterFromSet: newlineSet
                                                          options: NSLiteralSearch
                                                            range: NSMakeRange(thisChar, [[storage string] length] - thisChar)];
	
	if (nextBreak.location == NSNotFound) {
		nextBreak.location = [[storage string] length];
	} else {
		nextBreak.location++;
	}
	
	// Work out the range this represents (in terms of glyphs)
	NSRange charRange = NSMakeRange(thisChar, nextBreak.location-thisChar);
	NSRange paragraphRange = [layout glyphRangeForCharacterRange: charRange
									   actualCharacterRange: &charRange];
	
	// Begin a new paragraph
	[self beginParagraph];
	
	while (glyph < paragraphRange.location + paragraphRange.length) {
		// Set up line margin information
		lineFragmentInitialGlyph = glyph;
		NSInteger activeLeft = [self marginNearest: glyph-1
									 inMarginArray: leftMargins];
		NSInteger activeRight = [self marginNearest: glyph-1
									  inMarginArray: rightMargins];
		
		activeLeftMargin = activeRightMargin = nil;
		if (activeLeft >= 0) activeLeftMargin = [leftMargins objectAtIndex: activeLeft];
		if (activeRight >= 0) activeRightMargin = [rightMargins objectAtIndex: activeRight];

		// Lay out this line
		[self beginLineWithGlyphAtIndex: glyph];
		NSInteger nextGlyph = [self layoutLineFromGlyph: glyph];
		[self endLineWithGlyphRange: NSMakeRange(glyph, nextGlyph-glyph)];
		
		// Move on
		if (glyph == nextGlyph) {
			[self flushCache];
			return lastSetGlyph=glyph;
			break;
		} else {
			[self removeGlyphsFromCache: nextGlyph];
		}
		glyph = nextGlyph;
	}
	
	[self endParagraph];
	return lastSetGlyph=glyph;
}

#pragma mark - Setting the delegate

@synthesize delegate;

@end
