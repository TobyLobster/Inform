//
//  GlkTypesetter.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 10/09/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#ifndef __GLKVIEW_GLKTYPESETTER_H__
#define __GLKVIEW_GLKTYPESETTER_H__

#import <GlkView/GlkViewDefinitions.h>
#if defined(COCOAGLK_IPHONE)
# import <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

@class GlkCustomTextSection;
@class GlkMarginSection;

///
/// Protocol that can be implemented by custom line sections (which want to know about their final typesetting information)
///
@protocol GlkCustomLineSection <NSObject>

/// This object has been typeset at the specified position
- (void) placeBaselineAt: (NSPoint) point
				forGlyph: (NSInteger) glyph;

@end

///
/// Protocol implemented by things that wish to be informed about the locations of custom glyphs
///
/// (This is by way of a hack to avoid having to implement a NSLayoutManager subclass that can draw the custom glyphs
/// itself)
///
@protocol GlkCustomTextLayout <NSObject>

- (void) invalidateCustomGlyphs: (NSRange) range;
- (void) addCustomGlyph: (NSInteger) location
				section: (GlkCustomTextSection*) section;

@end

///
/// Possible alignments for a section within a line fragment
///
typedef NS_ENUM(int, GlkSectionAlignment) {
	/// Line up this section with the baseline
	GlkAlignBaseline,
	/// Line up this section with top of the line fragment (not including leading)
	GlkAlignTop,
	/// Line up this section with the center of the line fragment
	GlkAlignCenter,
	/// Line up this section with the bottom of the line fragment (not including leading)
	GlkAlignBottom
};

///
/// Representation of a section of a line fragment
///
@interface GlkLineSection: NSObject {
	/// The bounds for this line section: 0,0 indicates the start of the line fragment, 0,0 indicates the far left of the current fragment, at the baseline
	NSRect bounds;
	/// The X-advancement for this line section
	CGFloat advancement;
	/// The X-offset for this line section
	CGFloat offset;
	/// The glyph range for this line section
	NSRange glyphRange;
	/// The alignment for this line section
	GlkSectionAlignment alignment;

	/// A line section delegate object
	__unsafe_unretained id<GlkCustomLineSection> delegate;
	/// Whether or not this is an elastic line section (used in full-justification)
	BOOL elastic;
}

/// The bounds for this line section: 0,0 indicates the start of the line fragment, 0,0 indicates the far left of the current fragment, at the baseline
@property GlkRect bounds;
/// The X-advancement for this line section
@property CGFloat advancement;
/// The X-offset for this line section
@property CGFloat offset;
/// The glyph range for this line section
@property NSRange glyphRange;
/// The alignment for this line section
@property GlkSectionAlignment alignment;

/// A line section delegate object
@property (assign) id<GlkCustomLineSection> delegate;
/// Whether or not this is an elastic line section (used in full-justification)
@property (getter=isElastic) BOOL elastic;

@end

///
/// NSTypesetter subclass that can do all the funky things that Glk requires to support images
///
@interface GlkTypesetter : NSTypesetter {
	// What we're laying out
	/// The text storage object that we're laying out [NOT RETAINED]
	__unsafe_unretained NSAttributedString* storage;
	/// The layout manager that we're dealing with [NOT RETAINED]
	__unsafe_unretained NSLayoutManager* layout;
	/// The list of all of the text containers in the current [NOT RETAINED]
	__unsafe_unretained NSArray* containers;
	/// The text container that we're fitting text into [NOT RETAINED]
	__unsafe_unretained NSTextContainer* container;
	
	/// The line fragment padding to use
	CGFloat inset;
	/// The last glyph laid out
	NSUInteger lastSetGlyph;
	
	// The glyph cache
	/// The range of the cached glyphs
	NSRange cached;
	/// Size of the cache
	NSUInteger cacheLength;
	
	/// The identifier for each glyph that we're laying out
	CGGlyph* cacheGlyphs;
	/// The character index into the source string for each glyph
	NSUInteger* cacheCharIndexes;
	/// The properties for each glyph
	NSGlyphProperty* cacheProperties;
	/// The bidirectional level for each glyph
	unsigned char* cacheBidi;
	
	/// The X-advancements for each glyph that we're laying out
	CGFloat* cacheAdvancements;
	/// The ascenders for each glyph that we're laying out
	CGFloat* cacheAscenders;
	/// The descenders for each glyph that we're laying out
	CGFloat* cacheDescenders;
	/// The line heights for each glyph that we're laying out
	CGFloat* cacheLineHeight;
	/// The bounds for each glyph that we're laying out
	GlkRect* cacheBounds;
	/// The attributes for each glyph that we're laying out [RETAINED]
	NSDictionary*__strong* cacheAttributes;
	/// The font attribute for each glyph that we're laying out [NOT RETAINED]
	NSFont*__unsafe_unretained* cacheFonts;
	
	// Left and right margin sections
	/// Left margin items (by line fragment initial glyph)
	NSMutableArray* leftMargins;
	/// Right margin items (by line fragment initial glyph)
	NSMutableArray* rightMargins;
	/// Left margin active before this line fragment started
	GlkMarginSection* activeLeftMargin;
	/// Right margin active before this line fragment started
	GlkMarginSection* activeRightMargin;
	
	/// First glyph on the current line fragment
	NSInteger lineFragmentInitialGlyph;
	/// Left margin added (so far) in this fragment
	CGFloat thisLeftMargin;
	/// Right margin added (so far) in this fragment
	CGFloat thisRightMargin;
	CGFloat thisLeftMaxY;
	CGFloat thisRightMaxY;
	
	// The current paragraph
	/// The character range for the current paragraph
	NSRange paragraph;
	/// The NSParagraphStyle for the current paragraph [NOT RETAINED]
	__unsafe_unretained NSParagraphStyle* paraStyle;
	
	// Line sections
	/// The used rect of the current text container
	NSRect usedRect;
	/// The size of the current text container
	NSSize size;
	/// Number of line sections
	NSInteger numLineSections;
	/// The line sections themselves
	NSMutableArray<GlkLineSection*> *sections;
	/// Offset to apply to the baseline due to custom alignment
	CGFloat customOffset;
	/// If YES, then the bounding box is not sufficient to calculate the baseline offset to use
	BOOL customBaseline;
	
	/// The overall line fragment bounds
	NSRect fragmentBounds;
	/// The line fragment rectangle according to the text container
	NSRect proposedRect;
	/// The remaining rectangle, according to the text container
	NSRect remaining;

	// The delegate
	/// The delegate [NOT RETAINED]
	__weak id<GlkCustomTextLayout> delegate;
}

// Laying out line sections
/// Ensures that the specified range of glyphs are in the cache
- (BOOL) cacheGlyphsIncluding: (NSInteger) minGlyphIndex;
/// Starts a new line fragment
- (void) beginLineFragment;
/// Finishes the current line fragment and adds it to the layout manager
- (BOOL) endLineFragment: (BOOL) lastFragment
				 newline: (BOOL) newline;

/// Adds a new line section
- (void) addLineSection: (NSRect) bounds
			advancement: (CGFloat) advancement
				 offset: (CGFloat) offset
			 glyphRange: (NSRange) glyphRange
			  alignment: (GlkSectionAlignment) alignment
			   delegate: (id<GlkCustomLineSection>) delegate
				elastic: (BOOL) elastic;

// Margins
/// Adds a certain width to the left margin on the current line
/// (for flowing images)
- (void) addToLeftMargin: (CGFloat) width
				  height: (CGFloat) height;
/// Adds a certain width to the right margin on the current line
/// (for flowing images)
- (void) addToRightMargin: (CGFloat) width
				   height: (CGFloat) height;

/// Get the current offset into the left margin
@property (readonly) CGFloat currentLeftMarginOffset;
/// Get the current offset into the right margin
@property (readonly) CGFloat currentRightMarginOffset;
/// Remaining space for margin objects
@property (readonly) CGFloat remainingMargin;

/// Amount required to clear the left margin
@property (readonly) CGFloat currentLeftMarginHeight;
/// Amount required to clear the right margin
@property (readonly) CGFloat currentRightMarginHeight;

// Laying out glyphs
/// Lays out a single line fragment from the specified glyph
- (NSInteger) layoutLineFromGlyph: (NSInteger) glyph;

// Setting the delegate
/// Sets the delegate (the delegate is NOT RETAINED)
@property (weak) id<GlkCustomTextLayout> delegate;

// Clearing the cache
/// Forces any cached glyphs to be cleared (eg when a textstorage object changes)
- (void) flushCache;

@end

#endif
