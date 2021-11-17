//
//  glk_image.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 16/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <GlkView/GlkViewDefinitions.h>
#if defined(COCOAGLK_IPHONE)
# import <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

#include "glk.h"
#import "cocoaglk.h"
#import "glk_client.h"
#include "gi_blorb.h"

static BOOL imageSourceSet = NO;

//
// Tells the session object where to get its image from
//
void cocoaglk_set_image_source(id<GlkImageSource> imageSource) {
	imageSourceSet = YES;
	if (imageSource != nil) {
		[cocoaglk_session setImageSource: imageSource];
	}
}

//
// This draws the given image resource in the given window. The position of
// the image is given by val1 and val2, but their meaning varies depending
// on what kind of window you are drawing in. See section 7.2, "Graphics
// in Graphics Windows" and section 7.3, "Graphics in Text Buffer Windows".
//
// This function returns a flag indicating whether the drawing operation
// succeeded. [[A FALSE result can occur for many reasons. The image data
//	might be corrupted; the library may not have enough memory to operate;
//	there may be no image with the given identifier; the window might not
//	support image display; and so on.]]
//
// The CocoaGlk implementation always returns true; however, the image is
// not guaranteed to be drawn if the image resource does not exist. This is
// to save a round-trip asking the windowing process if it knows how to draw
// a particular image or not.
//
glui32 glk_image_draw(winid_t win, glui32 image, glsi32 val1, glsi32 val2) {
	if (!imageSourceSet) cocoaglk_set_image_source([[[GlkBlorbImageSource alloc] init] autorelease]);
	
	glui32 res = 0;
	
	// Sanity check
	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_image_draw called with an invalid winid");
	}
	
	if (win->wintype != wintype_Graphics && win->wintype != wintype_TextBuffer) {
		cocoaglk_error("glk_image_draw called on a window which is not either a graphics or text buffer window");
	}
	
	// Draw the image
	if (win->wintype == wintype_Graphics) {
		res = 1;
		
		[cocoaglk_buffer drawImageWithIdentifier: image
						  inWindowWithIdentifier: win->identifier
									  atPosition: GlkMakePoint(val1, val2)];
	} else {
		[cocoaglk_buffer drawImageWithIdentifier: image
						  inWindowWithIdentifier: win->identifier
									   alignment: val1];
	}
	
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_image_draw(%p, %u, %i, %i) = %i", win, image, val1, val2, res);
#endif

	return res;
}

glui32 glk_image_draw_scaled(winid_t win, glui32 image, 
							 glsi32 val1, glsi32 val2, glui32 width, glui32 height) {
	if (!imageSourceSet) cocoaglk_set_image_source([[[GlkBlorbImageSource alloc] init] autorelease]);

	glui32 res = 0;
	
	// Sanity check
	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_image_draw_scaled called with an invalid winid");
	}
	
	if (win->wintype != wintype_Graphics && win->wintype != wintype_TextBuffer) {
		cocoaglk_error("glk_image_draw_scaled called on a window which is not either a graphics or text buffer window");
	}
	
	// Draw the image
	if (win->wintype == wintype_Graphics) {
		res = 1;
		
		[cocoaglk_buffer drawImageWithIdentifier: image
						  inWindowWithIdentifier: win->identifier
										  inRect: GlkMakeRect(val1, val2, width, height)];
	} else {
		NSLog(@"TRACE: glk_image_draw_scaled(%p, %u, %i, %i, %u, %u) = %i", win, image, val1, val2, width, height, res);		
	}
	
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_image_draw_scaled(%p, %u, %i, %i, %u, %u) = %i", win, image, val1, val2, width, height, res);
#endif
	
	return res;
}

glui32 glk_image_get_info(glui32 image, glui32 *width, glui32 *height) {
	if (!imageSourceSet) cocoaglk_set_image_source([[[GlkBlorbImageSource alloc] init] autorelease]);
	
	// This caches the image sizes, to avoid repeatedly calling the server process
	static NSMutableDictionary<NSNumber*, NSValue*>* imageSizeDictionary = nil;	
	if (!imageSizeDictionary) {
		imageSizeDictionary = [[NSMutableDictionary alloc] init];
	}
	
	glui32 res = 0;
	
	// Use the cache for preference
	NSNumber* imageKey = @(image);
	NSValue* imageSizeValue = imageSizeDictionary[imageKey];
	GlkCocoaSize imageSize;
	
	if (imageSizeValue != nil) {
		// Use the cached version of the size
#ifdef COCOAGLK_IPHONE
		imageSize = [imageSizeValue CGSizeValue];
#else
		imageSize = [imageSizeValue sizeValue];
#endif
	} else {
		// Retrieve the size of the image from the server
		imageSize = [cocoaglk_session sizeForImageResource: image];
		
		NSValue *sizeVal = @(imageSize);
		
		imageSizeDictionary[imageKey] = sizeVal;
	}
	
	if (imageSize.width < 0) {
		// Image was not found
		res = 0;
	} else {
		// Image was found - return the results
		res = 1;
		
		if (width) *width = imageSize.width;
		if (height) *height = imageSize.height;
	}
	
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_image_get_info(%u, %p=%u, %p=%u) = %i", image, width, width?*width:0, height, height?*height:0, res);
#endif
	
	return res;
}

void glk_window_flow_break(winid_t win) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_window_flow_break(%p)", win);
#endif
	
	// Sanity check
	if (win == NULL) {
		cocoaglk_warning("glk_window_flow_break called with a NULL winid");
		return;
	}
	
	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_window_flow_break called with an invalid winid");
	}
	
	// Buffer the flow break
	[cocoaglk_buffer breakFlowInWindowWithIdentifier: win->identifier];
}

void glk_window_erase_rect(winid_t win, 
						   glsi32 left, glsi32 top, glui32 width, glui32 height) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_window_erase_rect(%p, %i, %i, %u, %u)", win, left, top, width, height);
#endif	
	
	// Sanity check
	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_window_erase_rect called with an invalid winid");
		return;
	}
	
	if (win->wintype != wintype_Graphics) {
		cocoaglk_error("glk_window_erase_rect called on a window which is not a graphics window");
		return;
	}
	
	// Pass the call off to fill_rect
	glk_window_fill_rect(win, win->background, left, top, width, height);
}

void glk_window_fill_rect(winid_t win, glui32 color, 
						  glsi32 left, glsi32 top, glui32 width, glui32 height) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_window_fill_rect(%p, %i, %i, %u, %u)", win, left, top, width, height);
#endif	
	
	// Sanity check
	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_window_erase_rect called with an invalid winid");
		return;
	}
	
	if (win->wintype != wintype_Graphics) {
		cocoaglk_error("glk_window_erase_rect called on a window which is not a graphics window");
		return;
	}
	
#if !defined(COCOAGLK_IPHONE)
	// Create an NSColor from the color value
	NSColor* fillColour = [NSColor colorWithSRGBRed: ((CGFloat)(color&0xff0000))/16711680.0
											  green: ((CGFloat)(color&0xff00))/65280.0
											   blue: ((CGFloat)(color&0xff))/255.0
											  alpha: 1.0];
#else
	// Create a UIColor from the color value
	UIColor* fillColour = [UIColor colorWithRed: ((CGFloat)(color&0xff0000))/16711680.0
										  green: ((CGFloat)(color&0xff00))/65280.0
										   blue: ((CGFloat)(color&0xff))/255.0
										  alpha: 1.0];
#endif
	
	// Tell the buffer to erase this window eventually
	[cocoaglk_buffer fillAreaInWindowWithIdentifier: win->identifier
										 withColour: fillColour
										  rectangle: GlkMakeRect(left, top, width, height)];
}

//
// This sets the window's background color. It does *not* change what is
// currently displayed; it only affects subsequent clears and resizes. The
// initial background color of each window is white.
//
// Colors are encoded in a 32-bit value: the top 8 bits must be zero,
// the next 8 bits are the red value, the next 8 bits are the green value,
// and the bottom 8 bits are the blue value. Color values range from 0 to
// 255. [[So 0x00000000 is black, 0x00FFFFFF is white, and 0x00FF0000 is
//	bright red.]]
//
void glk_window_set_background_color(winid_t win, glui32 color) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_window_set_background_color(%p, %u)", win, color);
#endif
	
	// Sanity check
	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_window_set_background_color called with an invalid winid");
		return;
	}
	
	if (win->wintype != wintype_Graphics) {
		cocoaglk_error("glk_window_set_background_color called on a window which is not a graphics window");
		return;
	}
	
	// Set the background colour
	win->background = color;
}

//
// Implementation of the blorb image source
//
@implementation GlkBlorbImageSource

- (id) init {
	self = [super init];
	
	if (self) {
		if (giblorb_get_resource_map() == NULL) {
			[self release];
			return nil;
		}
	}
	
	return self;
}

- (bycopy NSData*) dataForImageResource: (glui32) image {
	// Attempt to load the image from the blorb resources
	giblorb_result_t res;
	giblorb_err_t    erm;
	
	erm = giblorb_load_resource(giblorb_get_resource_map(), giblorb_method_Memory, &res, giblorb_ID_Pict, image);
	
	if (erm != giblorb_err_None) return nil;
	
	// Create the image data
	NSData* imgData = [NSData dataWithBytes: res.data.ptr
									 length: res.length];
	
	// Discard the image loaded from memory
	giblorb_unload_chunk(giblorb_get_resource_map(), res.chunknum);
	
	// Return the result
	return imgData;
}

@end
