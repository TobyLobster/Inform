//
//  ZoomPixmapWindow.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Jun 25 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#include <tgmath.h>
#import "ZoomPixmapWindow.h"
#import "ZoomView.h"


@implementation ZoomPixmapWindow

// Initialisation
- (id) initWithZoomView: (ZoomView*) view {
	self = [super init];
	
	if (self) {
		pixmap = [[NSImage alloc] initWithSize: NSMakeSize(640, 400)];
		zView = view;
		[zView.window setContentSize: NSMakeSize(640, 400)];
		
		inputStyle = nil;
	}
	
	return self;
}

#pragma mark - Getting the pixmap

- (NSSize) size {
	return [pixmap size];
}

@synthesize pixmap;

#pragma mark - Standard window commands

- (oneway void) clearWithStyle: (in bycopy ZStyle*) style {
	[pixmap lockFocus];
	
    NSColor* backgroundColour = style.reversed?[zView foregroundColourForStyle: style]:[zView backgroundColourForStyle: style];
	[backgroundColour set];
	NSRectFill(NSMakeRect(0, 0, [pixmap size].width, [pixmap size].height));
			   
	[pixmap unlockFocus];
}

- (oneway void) setFocus {
}

- (NSSize) sizeOfFont: (NSFont*) font {
    // Hack: require a layout manager for OS X 10.6, but we don't have the entire text system to fall back on
    NSLayoutManager* layoutManager = [[NSLayoutManager alloc] init];
    
    // Width is one 'em'
	CGFloat width = [@"M" sizeWithAttributes: @{NSFontAttributeName: font}].width;
    
    // Height is decided by the layout manager
    CGFloat height = [layoutManager defaultLineHeightForFont: font];
    
    return NSMakeSize(width, height);
}

- (oneway void) writeString: (in bycopy NSString*) string
				  withStyle: (in bycopy ZStyle*) style {
	[pixmap lockFocus];
	
	NSLog(@"Warning: should not call standard ZWindow writeString on a pixmap window");
	
	[pixmap unlockFocus];
}

// Pixmap window commands
- (void) setSize: (in NSSize) windowSize {
	if (windowSize.width < 0) {
		windowSize.width = [zView bounds].size.width;
	}
	if (windowSize.height < 0) {
		windowSize.height = [zView bounds].size.height;
	}
	
	[pixmap setSize: windowSize];
}

- (void) plotRect: (in NSRect) rect
		withStyle: (in bycopy ZStyle*) style {
	[pixmap lockFocusFlipped:YES];
	
    NSColor* foregroundColour = [zView foregroundColourForStyle: style];
	[foregroundColour set];
	NSRectFill(rect);
	
	[pixmap unlockFocus];
	[zView setNeedsDisplay: YES];
}

- (void) plotText: (in bycopy NSString*) text
		  atPoint: (in NSPoint) point
		withStyle: (in bycopy ZStyle*) style {
	[pixmap lockFocusFlipped:YES];
		
	NSMutableDictionary* attr = [[zView attributesForStyle: style] mutableCopy];
	
	// Draw the background
	CGFloat height = [self sizeOfFont: [attr objectForKey: NSFontAttributeName]].height;
	CGFloat descender = [[attr objectForKey: NSFontAttributeName] descender];
	NSSize size = [text sizeWithAttributes: attr];
	
	point.y -= ceil(height)+1.0;
	
	size.height = height;
	NSRect backgroundRect;
	backgroundRect.origin = point;
	backgroundRect.size = size;
	backgroundRect.origin.y -= descender;
	
	backgroundRect.origin.x = floor(backgroundRect.origin.x);
	backgroundRect.origin.y = floor(backgroundRect.origin.y);
	backgroundRect.size.width = ceil(backgroundRect.size.width);
	backgroundRect.size.height = ceil(backgroundRect.size.height) + 1.0;
	
	[(NSColor*)[attr objectForKey: NSBackgroundColorAttributeName] set];
	NSRectFill(backgroundRect);
	
	// Draw the text
	[attr removeObjectForKey: NSBackgroundColorAttributeName];
	[text drawAtPoint: point
	   withAttributes: attr];
	
	[pixmap unlockFocus];
	[zView setNeedsDisplay: YES];
	[zView orOutputText: text];
}

- (void) scrollRegion: (in NSRect) region
			  toPoint: (in NSPoint) where {
	[pixmap lockFocusFlipped:YES];
	
	// Used to use NSCopyBits but Apple randomly broke it sometime in Snow Leopard. The docs lied anyway.
	// This is much slower :-(
	NSBitmapImageRep*	copiedBits	= [[NSBitmapImageRep alloc] initWithFocusedViewRect: region];
	NSImage*			copiedImage	= [[NSImage alloc] init];
	[copiedImage addRepresentation: copiedBits];
	[copiedImage drawInRect: NSMakeRect(where.x, where.y, region.size.width, region.size.height)
				   fromRect: NSZeroRect
				  operation: NSCompositingOperationSourceOver
				   fraction: 1.0
			 respectFlipped: YES
					  hints: nil];
	
	
	// Uh, docs say we should use NSNullObject here, but it's not defined. Making a guess at its value (sigh)
	// This would be less of a problem in a view, because we can get the view's own graphics state. But you
	// can't get the graphics state for an image (in general).
	// NSCopyBits(0, region, where);
	[pixmap unlockFocus];
}

#pragma mark - Measuring

- (void) getInfoForStyle: (in bycopy ZStyle*) style
				   width: (out CGFloat*) width
				  height: (out CGFloat*) height
				  ascent: (out CGFloat*) ascent
				 descent: (out CGFloat*) descent {
	ZFontStyle fontnum =
        (style.bold?ZFontStyleBold:0)|
        (style.underline?ZFontStyleUnderline:0)|
        (style.fixed?ZFontStyleFixed:0)|
        (style.symbolic?ZFontStyleSymbolic:0);

	NSFont* font = [zView fontFromStyle: fontnum];
    NSSize fontSize = [self sizeOfFont: font];
	
	*width = fontSize.width;
	*ascent = [font ascender];
	*descent = [font descender];
	*height = fontSize.height+1;
}

- (bycopy NSDictionary*) attributesForStyle: (in bycopy ZStyle*) style {
	return [zView attributesForStyle: style];
}

- (NSSize) measureString: (in bycopy NSString*) string
			   withStyle: (in bycopy ZStyle*) style {
	NSDictionary* attr = [zView attributesForStyle: style];
	
	return [string sizeWithAttributes: attr];
}

- (bycopy NSColor*) colourAtPixel: (NSPoint) point {
	[pixmap lockFocusFlipped:YES];
	
	if (point.x <= 0) point.x = 1;
	if (point.y <= 0) point.y = 1;
	
	NSColor* res = NSReadPixel(point);
	
	[pixmap unlockFocus];
	
	return [res copy];
}

#pragma mark - Input

- (void) setInputPosition: (NSPoint) point
				withStyle: (in bycopy ZStyle*) style {
	inputPos = point;
	inputStyle = [style copy];
}

@synthesize inputPos;
@synthesize inputStyle;

- (void) plotImageWithNumber: (in int) number
					 atPoint: (in NSPoint) point {
	NSImage* img = [[zView resources] imageWithNumber: number];

	NSRect destRect;
	destRect.origin = point;
	destRect.size = [[zView resources] sizeForImageWithNumber: number
												forPixmapSize: [pixmap size]];
	
	[pixmap lockFocusFlipped:YES];
	[img drawInRect: destRect
		   fromRect: NSZeroRect
		  operation: NSCompositingOperationSourceOver
		   fraction: 1.0
	 respectFlipped: YES
			  hints: nil];
	[pixmap unlockFocus];
	
	[zView setNeedsDisplay: YES];
}

#pragma mark - NSCoding
#define PIXMAPCODINGKEY @"PixMap"
#define INPUTPOSCODINGKEY @"InputPos"
#define INPUTSTYLECODINGKEY @"InPutStyle"


- (void) encodeWithCoder: (NSCoder*) encoder {
	if (encoder.allowsKeyedCoding) {
		[encoder encodeObject: pixmap forKey: PIXMAPCODINGKEY];
		[encoder encodePoint: inputPos forKey: INPUTPOSCODINGKEY];
		[encoder encodeObject: inputStyle forKey: INPUTSTYLECODINGKEY];
	} else {
		[encoder encodeObject: pixmap];
		
		[encoder encodePoint: inputPos];
		[encoder encodeObject: inputStyle];
	}
}

- (id)initWithCoder:(NSCoder *)decoder {
	self = [super init];
	
    if (self) {
		if (decoder.allowsKeyedCoding) {
			pixmap = [decoder decodeObjectOfClass: [NSImage class] forKey: PIXMAPCODINGKEY];
			inputPos = [decoder decodePointForKey: INPUTPOSCODINGKEY];
			inputStyle = [decoder decodeObjectOfClass: [ZStyle class] forKey: INPUTSTYLECODINGKEY];
		} else {
			pixmap = [decoder decodeObject];
			inputPos = [decoder decodePoint];
			inputStyle = [decoder decodeObject];
		}
    }
	
    return self;
}

+ (BOOL)supportsSecureCoding
{
	return YES;
}

@synthesize zoomView=zView;

#pragma mark - Input styles

- (oneway void) setInputStyle: (in bycopy ZStyle*) newInputStyle {
	// Do nothing
}

@end
