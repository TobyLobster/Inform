//
//  Z6Display.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#include <tgmath.h>
#import "ZoomProtocol.h"
#import "ZoomZMachine.h"
#import "ZoomServer.h"

#include "file.h"
#include "display.h"
#include "v6display.h"

#undef  MEASURE_REMOTELY		// Set to force measuring of font sizes, etc, on the Zoom process rather than this one. Will be slower

struct BlorbImage* zoomImageCache = NULL;
int zoomImageCacheSize = 0;

#pragma mark - V6 display

// Initialisation

int display_init_pixmap(int width, int height) {
	[(id<ZPixmapWindow>)[mainMachine windowNumber: 0] setSize: NSMakeSize(width, height)];
	zPixmapDisplay = YES;
	
	return 1;
}

void display_has_restarted(void) {
	[[mainMachine display] zMachineHasRestarted];
}

static int set_style(int style) {
    // Copy the old style
    ZStyle* newStyle = [zDisplayCurrentStyle copy];
	
    int oldStyle =
        (newStyle.reversed?1:0)|
        (newStyle.bold?2:0)|
        (newStyle.underline?4:0)|
        (newStyle.fixed?8:0)|
        (newStyle.symbolic?16:0);
    
    // Not using this any more
    if (zDisplayCurrentStyle) zDisplayCurrentStyle = nil;
	
    BOOL flag = (style<0)?NO:YES;
    if (style < 0) style = -style;
	
    // Set the flags
    if (style == 0) {
        [newStyle setBold: NO];
        [newStyle setUnderline: NO];
        [newStyle setFixed: NO];
        [newStyle setSymbolic: NO];
        [newStyle setReversed: NO];
		
        zDisplayCurrentStyle = newStyle;
        return oldStyle;
    }
	
    if (style&1)  [newStyle setReversed: flag];
    if (style&2)  [newStyle setBold: flag];
    if (style&4)  [newStyle setUnderline: flag];
    if (style&8)  [newStyle setFixed: flag];
    if (style&16) [newStyle setSymbolic: flag];
	
    // Set as the current style
    zDisplayCurrentStyle = newStyle;
	
    return oldStyle;
}

// Drawing

extern void  display_plot_rect(int x, int y,
							   int width, int height) { 
	[[mainMachine buffer] plotRect: NSMakeRect(x, y, width, height)
						 withStyle: zDisplayCurrentStyle
						  inWindow: (id<ZPixmapWindow>)[mainMachine windowNumber: 0]];
	
#ifdef DEBUG
	NSLog(@"display_plot_rect(%i, %i, %i, %i)", x, y, width, height);
#endif
}

void  display_plot_gtext(const int* buf, int len,
						 int style, int x, int y) {	
	set_style(style);
    NSString* str = [[NSString alloc] initWithData: [NSData dataWithBytes: buf
                                                                   length: len * sizeof(int)]
                                          encoding: NSUTF32LittleEndianStringEncoding];
    
    if (!str) {
    // Convert buf to an NSString
    int length;
    unichar* bufU = NULL;
	
    for (length=0; length < len; length++) {
        bufU = realloc(bufU, sizeof(unichar)*((length>>4)+1)<<4);
        bufU[length] = buf[length];
    }
	
    if (length == 0) return;
	
	// Plot the text
        str = [[NSString alloc] initWithCharactersNoCopy: bufU
                                                  length: length
                                            freeWhenDone: YES];
    }
	
	[[mainMachine buffer] plotText: str
						   atPoint: NSMakePoint(x, y)
						 withStyle: zDisplayCurrentStyle
						  inWindow: (id<ZPixmapWindow>)[mainMachine windowNumber: 0]];

#ifdef DEBUG
	NSLog(@"display_plot_gtext(%@, %i, %i, %i, %i)", str, len, style, x, y);
#endif
}

void display_pixmap_cols(int fore, int back) { 
#ifdef DEBUG
	NSLog(@"ZDisplay: display_pixmap_cols(%i, %i)", fore, back);
#endif

	display_set_colour(fore, back);
}

void display_scroll_region(int x, int y,
						   int width, int height,
						   int xoff, int yoff) {
	if (xoff == 0 && yoff == 0) return;
	if (width == 0 || height == 0) return;
	
	[[mainMachine buffer] scrollRegion: NSMakeRect(x, y, width, height)
							   toPoint: NSMakePoint(x+xoff, y+yoff)
							  inWindow: (id<ZPixmapWindow>)[mainMachine windowNumber: 0]];
}

// Measuring

static int lastStyle = -12763;
static CGFloat lastWidth = -1;
static CGFloat lastHeight = -1;
static CGFloat lastAscent = -1;
static CGFloat lastDescent = -1;

static void measureStyle(int style) {
	if (style == lastStyle) return;

	set_style(style);
	[(id<ZPixmapWindow>)[mainMachine windowNumber: 0] getInfoForStyle: zDisplayCurrentStyle
																width: &lastWidth
															   height: &lastHeight
															   ascent: &lastAscent
															  descent: &lastDescent];
	lastStyle = style;
}

static NSDictionary<NSAttributedStringKey, id>* styleAttributes(ZStyle* style) {
	static ZStyle* attributeStyle = nil;
	static NSDictionary<NSAttributedStringKey, id>* lastAttributes = nil;
	
	if (attributeStyle != nil &&
		[attributeStyle isEqual: style]) {
		return lastAttributes;
	}
	
    lastAttributes = nil;
    attributeStyle = nil;
	
	attributeStyle = [style copy];
	lastAttributes = [(id<ZPixmapWindow>)[mainMachine windowNumber: 0] attributesForStyle: style];
	
	return lastAttributes;
}

float display_measure_text(const int* buf, int len, int style) { 
	set_style(style);
	
    NSString* str = [[NSString alloc] initWithData: [NSData dataWithBytes: buf
                                                                   length: len * sizeof(int)]
                                          encoding: NSUTF32LittleEndianStringEncoding];
    if (!str) {
    // Convert buf to an NSString
    int length;
    unichar* bufU = NULL;
	
    for (length=0; length < len; length++) {
        bufU = realloc(bufU, sizeof(unichar)*((length>>4)+1)<<4);
        bufU[length] = buf[length];
    }
	
    if (length == 0) return 0;
	
        str = [[NSString alloc] initWithCharactersNoCopy: bufU
                                                  length: length
                                            freeWhenDone: YES];
    }
	// Measure the string
	
#ifdef MEASURE_REMOTELY
	NSSize sz = [(id<ZPixmapWindow>)[mainMachine windowNumber: 0] measureString: str
																	  withStyle: zDisplayCurrentStyle];
#else
	NSSize sz = [str sizeWithAttributes: styleAttributes(zDisplayCurrentStyle)];
#endif
	
#ifdef DEBUG
	NSLog(@"display_measure_text(%@, %i, %i) = %g", str, len, style, sz.width);
#endif
	
	return sz.width;
}

float display_get_font_width(int style) { 
	measureStyle(style);
	
#ifdef DEBUG
	NSLog(@"display_get_font_width = %g", lastWidth);
#endif
	return lastWidth;
}

float display_get_font_height(int style) {
	measureStyle(style);

#ifdef DEBUG
	NSLog(@"display_get_font_height = %g", lastHeight);
#endif
	
	return ceil(lastHeight)+1.0;
}

float display_get_font_ascent(int style) {
	measureStyle(style);
	
#ifdef DEBUG
	NSLog(@"display_get_font_ascent = %g", lastAscent);
#endif
	
	return ceil(lastAscent);
}

float display_get_font_descent(int style) { 
	measureStyle(style);
	
#ifdef DEBUG
	NSLog(@"display_get_font_descent = %g", -lastDescent);
#endif
	
	return ceil(-lastDescent);
}

int display_get_pix_colour(int x, int y) {
	[mainMachine flushBuffers];
	
	NSColor* pixColour = [(id<ZPixmapWindow>)[mainMachine windowNumber: 0] colourAtPixel: NSMakePoint(x, y)];
	
	int redComponent = floor([pixColour redComponent] * 31.0);
	int greenComponent = floor([pixColour greenComponent] * 31.0);
	int blueComponent = floor([pixColour blueComponent] * 31.0);
	
	return ((redComponent)|(greenComponent<<5)|(blueComponent<<10)) + 16;
}

#pragma mark - Input

void display_set_input_pos(int style, int x, int y, int width) { 
	set_style(style);
	
	[(id<ZPixmapWindow>)[mainMachine windowNumber: 0] setInputPosition: NSMakePoint(x, y)
															 withStyle: zDisplayCurrentStyle];
}

void display_wait_for_more(void) {
	[mainMachine flushBuffers];
	
	[[mainMachine display] displayMore: YES];
	display_readchar(0);
	[[mainMachine display] displayMore: NO];
}

#pragma mark - Mouse

extern void  display_read_mouse      (void) {
//	if ([mainMachine respondsToSelector:@selector(readMouse)]) {
//		NSPoint mousePoint = [mainMachine readMouse];
//	} else {
		NSLog(@"Function not implemented: %s %s:%i", __FUNCTION__, __FILE__, __LINE__);
//	}
}

int display_get_pix_mouse_b (void) { 
	return 1;
}

int display_get_pix_mouse_x (void) { 
	return [mainMachine mousePosX];
}

int display_get_pix_mouse_y (void) { 
	return [mainMachine mousePosY];
}

extern void  display_set_mouse_win   (int x, int y, int width, int height) { NSLog(@"Function not implemented: %s %s:%i", __FUNCTION__, __FILE__, __LINE__); }

void display_flush(void) {
	[mainMachine flushBuffers];
}

#pragma mark - Images

void display_plot_image(BlorbImage* img, int x, int y) {
	[[mainMachine buffer] plotImage: img->number
							atPoint: NSMakePoint(x, y)
						   inWindow: (id<ZPixmapWindow>)[mainMachine windowNumber: 0]];
}

#pragma mark - Blorb

// We re-implement blorb here, mainly because images really should be on the other side of the connection
// (plus, I want to use NSImages, avoid libpng, etc)
// Ayup, we duplicate quite a lot of code here :-/

int blorb_is_blorbfile(ZFile* file) {
	if (file == NULL) return 1;
	return 0;
}

BlorbFile* blorb_loadfile(ZFile* file) {
	if (file == NULL) {
		// Get file details from the remote process
		BlorbFile* newFile = malloc(sizeof(BlorbFile));
		
		return newFile;
	}
	
	return NULL;
}

void blorb_closefile(BlorbFile* file) {
	free(file);
}

BlorbImage* blorb_findimage(BlorbFile* blorb, int num) {
	// Get the image storage
	BlorbImage* res = NULL;
	
	if (num < 0 || num > 32768) return NULL; // Limits on the number of images
	
	if (num >= zoomImageCacheSize) {
		int x;
		
		zoomImageCache = realloc(zoomImageCache, sizeof(struct BlorbImage)*(num+1));
		
		for (x=zoomImageCacheSize; x<=num; x++) {
			zoomImageCache[x].in_use = 0;
		}
		
		zoomImageCacheSize = num;
	}
	
	// Use the cached image if possible
	res = zoomImageCache + num;
	if (res->in_use) {
		if (res->file_offset < 0) 
			return NULL;
		else
			return res;
	}

	// Get information on this image from the remote system
	id<ZDisplay> disp = [mainMachine display];
	
	if (![disp containsImageWithNumber: num]) {
		// Image not available: mark it as so
		res->file_offset = -1;
		res->in_use = 0;
		return NULL;
	}
	
	NSSize imageSize = [disp sizeOfImageWithNumber: num];
	
	// Set up the image block
	res->file_offset = 0;
	res->file_len = 0;
	res->number = num;
	res->loaded = (image_data*)res; // HACK! See below
	res->in_use = 1;
	
	res->width = ceil(imageSize.width);
	res->height = ceil(imageSize.height);
	
	res->std_n = 1; res->std_d = 1;
	res->min_n = 1; res->min_d = 1;
	res->max_n = 1; res->max_d = 1;
	res->usage_count = 1;
	res->is_adaptive = 0;
	
	// *HACK*
	// res->loaded must contain a value in order for the system to recognise that there exists an actual image
	// there (ie for @draw_picture to work). This causes no harm, as the actual image_* API is not used at all
	// in the Cocoa version, so any value at all other than NULL will do.
	
	return res;
}

BlorbSound* blorb_findsound(BlorbFile* blorb, int num) {
	return NULL;
}

