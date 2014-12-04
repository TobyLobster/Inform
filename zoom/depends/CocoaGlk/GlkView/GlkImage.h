//
//  GlkImage.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 08/08/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <GlkView/GlkCustomTextSection.h>

// Attribute that can be applied to control glyphs to indicate that they should cause formatting of a specific Glk image
extern NSString* GlkImageAttribute;

//
// Representation of an image in a text container
//
@interface GlkImage : GlkCustomTextSection {
	NSImage* image;								// The NSImage associated with this image
	NSSize size;								// The size to draw this image with
	unsigned alignment;							// The Glk alignment of this image
	unsigned characterPosition;					// The character position of this image in the text stream
	
	NSRect bounds;								// The bounds of this image in the text container
	BOOL calculatedBounds;						// Whether or not the bounds for this image have been calculated yet

	float marginOffset;							// If this is a margin image, the offset that it should be drawn at
	float scaleFactor;							// Scale factor for margin objects
}

// Initialisation
- (id) initWithImage: (NSImage*) image
		   alignment: (unsigned) alignment
				size: (NSSize) size
			position: (unsigned) characterPosition;

// Information
- (NSImage*) image;								// The NSImage associated with this image
- (NSSize) size;								// The size to draw this image with
- (unsigned) alignment;							// The Glk alignment of this image
- (unsigned) characterPosition;					// The character position of this image in the text stream

- (void) setBounds: (NSRect) bounds;			// Sets the bounds of this image, marks it as calculated
- (NSRect) bounds;								// Retrieves the bounds of this image
- (BOOL) calculatedBounds;						// Returns YES if the bounds are calculated
- (void) markAsUncalculated;					// Marks this image as uncalculated

@end
