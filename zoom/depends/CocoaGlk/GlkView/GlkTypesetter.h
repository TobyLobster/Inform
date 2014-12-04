//
//  GlkTypesetter.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 10/09/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class GlkCustomTextSection;
@class GlkMarginSection;

///
/// Protocol that can be implemented by custom line sections (which want to know about their final typesetting information)
///
@protocol GlkCustomLineSection

- (void) placeBaselineAt: (NSPoint) point					// This object has been typeset at the specified position
				forGlyph: (int) glyph;

@end

///
/// Protocol implemented by things that wish to be informed about the locations of custom glyphs
///
/// (This is by way of a hack to avoid having to implement a NSLayoutManager subclass that can draw the custom glyphs
/// itself)
///
@protocol GlkCustomTextLayout

- (void) invalidateCustomGlyphs: (NSRange) range;
- (void) addCustomGlyph: (int) location
				section: (GlkCustomTextSection*) section;

@end

///
/// Possible alignments for a section within a line fragment
///
typedef enum GlkSectionAlignment GlkSectionAlignment;
enum GlkSectionAlignment {
	GlkAlignBaseline,							// Line up this section with the baseline
	GlkAlignTop,								// Line up this section with top of the line fragment (not including leading)
	GlkAlignCenter,								// Line up this section with the center of the line fragment
	GlkAlignBottom								// Line up this section with the bottom of the line fragment (not including leading)
};

///
/// Representation of a section of a line fragment
///
typedef struct GlkLineSection {
	NSRect bounds;								// The bounds for this line section: 0,0 indicates the start of the line fragment, 0,0 indicates the far left of the current fragment, at the baseline
	float advancement;							// The X-advancement for this line section
	float offset;								// The X-offset for this line section
	NSRange glyphRange;							// The glyph range for this line section
	GlkSectionAlignment alignment;				// The alignment for this line section

	id<GlkCustomLineSection> delegate;			// A line section delegate object
	BOOL elastic;								// Whether or not this is an elastic line section (used in full-justification)
} GlkLineSection;

///
/// NSTypesetter subclass that can do all the funky things that Glk requires to support images
///
@interface GlkTypesetter : NSTypesetter {
	// What we're laying out
	NSAttributedString* storage;				// The text storage object that we're laying out [NOT RETAINED]
	NSLayoutManager* layout;					// The layout manager that we're dealing with [NOT RETAINED]
	NSArray* containers;						// The list of all of the text containers in the current [NOT RETAINED]
	NSTextContainer* container;					// The text container that we're fitting text into [NOT RETAINED]
	
	float inset;								// The line fragment padding to use
	int lastSetGlyph;							// The last glyph laid out
	
	// The glyph cache
	NSRange cached;								// The range of the cached glyphs
	int cacheLength;							// Size of the cache
	
	NSGlyph* cacheGlyphs;						// The identifier for each glyph that we're laying out
	unsigned* cacheCharIndexes;					// The character index into the source string for each glyph
	NSGlyphInscription* cacheInscriptions;		// The inscriptions for each glyph
	BOOL* cacheElastic;							// The elastic bits for each glyph
	unsigned char* cacheBidi;					// The bidirectional level for each glyph
	
	float* cacheAdvancements;					// The X-advancements for each glyph that we're laying out
	float* cacheAscenders;						// The ascenders for each glyph that we're laying out
	float* cacheDescenders;						// The descenders for each glyph that we're laying out
	float* cacheLineHeight;						// The line heights for each glyph that we're laying out
	NSRect* cacheBounds;						// The bounds for each glyph that we're laying out
	NSDictionary** cacheAttributes;				// The attributes for each glyph that we're laying out [RETAINED]
	NSFont** cacheFonts;						// The font attribute for each glyph that we're laying out [NOT RETAINED]
	
	// Left and right margin sections
	NSMutableArray* leftMargins;				// Left margin items (by line fragment initial glyph)
	NSMutableArray* rightMargins;				// Right margin items (by line fragment initial glyph)
	GlkMarginSection* activeLeftMargin;			// Left margin active before this line fragment started
	GlkMarginSection* activeRightMargin;		// Right margin active before this line fragment started
	
	int lineFragmentInitialGlyph;				// First glyph on the current line fragment
	float thisLeftMargin;						// Left margin added (so far) in this fragment
	float thisRightMargin;						// Right margin added (so far) in this fragment
	float thisLeftMaxY;
	float thisRightMaxY;
	
	// The current paragraph
	NSRange paragraph;							// The character range for the current paragraph
	NSParagraphStyle* paraStyle;				// The NSParagraphStyle for the current paragraph [NOT RETAINED]
	
	// Line sections
	NSRect usedRect;							// The used rect of the current text container
	NSSize size;								// The size of the current text container
	int numLineSections;						// Number of line sections
	GlkLineSection* sections;					// The line sections themselves
	float customOffset;							// Offset to apply to the baseline due to custom alignment
	BOOL customBaseline;						// If YES, then the bounding box is not sufficient to calculate the baseline offset to use
	
	NSRect fragmentBounds;						// The overall line fragment bounds
	NSRect proposedRect;						// The line fragment rectangle according to the text container
	NSRect remaining;							// The remaining rectangle, according to the text container

	// The delegate
	NSObject<GlkCustomTextLayout>* delegate;	// The delegate [NOT RETAINED]
}

// Laying out line sections
- (BOOL) cacheGlyphsIncluding: (int) minGlyphIndex;			// Ensures that the specified range of glyphs are in the cache
- (void) beginLineFragment;									// Starts a new line fragment
- (BOOL) endLineFragment: (BOOL) lastFragment				// Finishes the current line fragment and adds it to the layout manager
				 newline: (BOOL) newline;

- (void) addLineSection: (NSRect) bounds					// Adds a new line section
			advancement: (float) advancement
				 offset: (float) offset
			 glyphRange: (NSRange) glyphRange
			  alignment: (GlkSectionAlignment) alignment
			   delegate: (id<GlkCustomLineSection>) delegate
				elastic: (BOOL) elastic;

// Margins
- (void) addToLeftMargin: (float) width						// Adds a certain width to the left margin on the current line
				  height: (float) height;					// (for flowing images)
- (void) addToRightMargin: (float) width					// Adds a certain width to the right margin on the current line
				   height: (float) height;					// (for flowing images)

- (float) currentLeftMarginOffset;							// Get the current offset into the left margin
- (float) currentRightMarginOffset;							// Get the current offset into the right margin
- (float) remainingMargin;									// Remaining space for margin objects

- (float) currentLeftMarginHeight;							// Amount required to clear the left margin
- (float) currentRightMarginHeight;							// Amount required to clear the right margin

// Laying out glyphs
- (int) layoutLineFromGlyph: (int) glyph;					// Lays out a single line fragment from the specified glyph

// Setting the delegate
- (void) setDelegate: (NSObject<GlkCustomTextLayout>*) delegate;	// Sets the delegate (the delegate is NOT RETAINED)

// Clearing the cache
- (void) flushCache;										// Forces any cached glyphs to be cleared (eg when a textstorage object changes)

@end

#import <GlkView/GlkCustomTextSection.h>
