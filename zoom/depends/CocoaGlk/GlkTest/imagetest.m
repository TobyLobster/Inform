//
// Glk executable that tests some of the more esoteric image functions of Glk.
//
// You'll need a file called 'GlkTest.png' in the Pictures directory in your users directory to use this
// program. (This also demonstrates how to take your image resources from places other than blorb)
//

#include <GlkView/glk.h>
#import "GlkClient/cocoaglk.h"

#if defined(COCOAGLK_IPHONE)
# import <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

#import <GlkView/GlkImageSourceProtocol.h>

@interface GlkImageTestSource : NSObject<GlkImageSource> {
}

@end

@implementation GlkImageTestSource

#if !defined(COCOAGLK_IPHONE)

- (bycopy NSData*) dataForImageResource: (glui32) image {
	static NSImage* ourImage = nil;
	
	if (!ourImage) {
		ourImage = [[NSImage alloc] initWithContentsOfFile: [@"~/Pictures/GlkTest.png" stringByExpandingTildeInPath]];
	}
	
	return [ourImage TIFFRepresentation];
}

#else

- (NSData*) dataForImageResource: (glui32) image {
	// IMPLEMENT ME
	return nil;
}

#endif

@end

static winid_t mainwin1 = NULL;

void write_image_test(void) {
	char* someText = "It is a most extraordinary thing, but I never read a patent medicine advertisement without being impelled to the conclusion that I am suffering from the particular disease therein dealt with in its most virulent form.  The diagnosis seems in every case to correspond exactly with all the sensations that I have ever felt.\n\n";
	char* someMoreText = "I remember going to the British Museum one day to read up the treatment for some slight ailment of which I had a touch - hay fever, I fancy it was.  I got down the book, and read all I came to read; and then, in an unthinking moment, I idly turned the leaves, and began to indolently study diseases, generally.  I forget which was the first distemper I plunged into - some fearful, devastating scourge, I know - and, before I had glanced half down the list of \"premonitory symptoms,\" it was borne in upon me that I had fairly got it.\n\n";
	
#if 1
	glk_set_style(style_User1);
	glk_image_draw(mainwin1, 0, imagealign_InlineCenter, 0);
	glk_put_string("\n");
	glk_image_draw(mainwin1, 0, imagealign_InlineCenter, 0);
	glk_put_string("\n");
	
	glk_put_string("\nUser1\n");

	glk_put_string("\n->");
	glk_image_draw(mainwin1, 0, imagealign_InlineCenter, 0);
	glk_put_string("<-\n");
	glk_set_style(style_Normal);
	
	glk_image_draw(mainwin1, 0, imagealign_MarginLeft, 0);
	glk_put_string(someText);
	glk_put_string(someMoreText);
	
	glk_window_flow_break(mainwin1);
	
	glk_image_draw(mainwin1, 0, imagealign_MarginRight, 0);
	glk_put_string(someText);
	
	glk_window_flow_break(mainwin1);

	glk_put_string(someMoreText);	

	glk_image_draw(mainwin1, 0, imagealign_MarginRight, 0);
	glk_image_draw(mainwin1, 0, imagealign_MarginLeft, 0);
	glk_put_string(someText);
	
	glk_window_flow_break(mainwin1);
	
	glk_put_string(someMoreText);
	
	glk_window_flow_break(mainwin1);
	
	glk_put_string("InlineDown ->");
	glk_image_draw(mainwin1, 0, imagealign_InlineDown, 0);
	glk_put_string("<-\n");
	
	glk_put_string("InlineUp ->");
	glk_image_draw(mainwin1, 0, imagealign_InlineUp, 0);
	glk_put_string("<-\n");
	
	glk_put_string("InlineCenter ->");
	glk_image_draw(mainwin1, 0, imagealign_InlineCenter, 0);
	glk_put_string("<-\n");
	glk_put_string(someMoreText);
#endif
	
	glk_put_string("InlineDown ->");
	glk_image_draw(mainwin1, 0, imagealign_InlineDown, 0);
	glk_put_string("<- ");
	
	glk_put_string("InlineUp ->");
	glk_image_draw(mainwin1, 0, imagealign_InlineUp, 0);
	glk_put_string("<- ");
	
	glk_put_string("InlineCenter ->");
	glk_image_draw(mainwin1, 0, imagealign_InlineCenter, 0);
	glk_put_string("<-\n");
	glk_put_string(someMoreText);
}

void glk_main(void) {
	event_t evt;
	BOOL finished;
	
	glui32 imageWidth, imageHeight;

	// Register our image provider
	cocoaglk_set_image_source([[GlkImageTestSource alloc] init]);
	
	// Open a graphics window
	glk_stylehint_set(wintype_TextBuffer, style_Normal, stylehint_BackColor, 0xddffff);
    mainwin1 = glk_window_open(0, 0, 0, wintype_Graphics, 1);
	
	// Request mouse and character events
	glk_request_char_event(mainwin1);
	glk_request_mouse_event(mainwin1);
	
	// Draw our image in the top-left corner
	glk_image_get_info(0, &imageWidth, &imageHeight);
	glk_image_draw(mainwin1, 0, 20, 20);
	
	// Process events until the user presses a key
	finished = YES;
	while (!finished) {
		glk_select(&evt);
		
		switch (evt.type) {
			case evtype_Redraw:
				// Redraw the image as required
				glk_window_erase_rect(mainwin1, 20, 20, imageWidth, imageHeight);
				glk_image_draw(mainwin1, 0, 20, 20);
				break;
				
			case evtype_CharInput:
				glk_cancel_char_event(mainwin1);
				glk_cancel_mouse_event(mainwin1);
				finished = YES;
				break;

			case evtype_MouseInput:
				glk_image_draw(mainwin1, 0, evt.val1 - (imageWidth>>1), evt.val2 - (imageHeight>>1));
				glk_request_mouse_event(mainwin1);				
				break;
		}
	}
	
	// Close the graphics window
	glk_window_close(mainwin1, NULL);
	
	glk_stylehint_set(wintype_TextBuffer, style_Normal, stylehint_Size, 1);
	glk_stylehint_set(wintype_TextBuffer, style_Emphasized, stylehint_Size, 10);
	glk_stylehint_set(wintype_TextBuffer, style_Normal, stylehint_BackColor, 0xddddff);
	glk_stylehint_set(wintype_TextBuffer, style_Normal, stylehint_Justification, stylehint_just_LeftRight);
	
	glk_stylehint_set(wintype_TextBuffer, style_Header, stylehint_Oblique, 1);
	glk_stylehint_set(wintype_TextBuffer, style_Header, stylehint_Size, 4);
	glk_stylehint_set(wintype_TextBuffer, style_Header, stylehint_Weight, 1);
	glk_stylehint_set(wintype_TextBuffer, style_Header, stylehint_BackColor, 0xddddff);
	glk_stylehint_set(wintype_TextBuffer, style_Header, stylehint_Justification, stylehint_just_Centered);

	glk_stylehint_set(wintype_TextBuffer, style_User1, stylehint_Justification, stylehint_just_Centered);
	
	// Open a text buffer window
	mainwin1 = glk_window_open(0,0,0, wintype_TextBuffer, 1);
	
	// Write some stuff (and images) to it
	glk_set_window(mainwin1);
#if 0
	int x;
	for (x=0; x<10; x++) {
		glk_set_style(style_Header);
		glk_put_string("CocoaGlk imaging test ");
		glk_set_style(style_Normal);
		glk_put_string("This is a long string that might lay out correctly. Or might not. ");
	}
	glk_put_string("\n\n");
	
	for (x=0; x<10; x++) {
		glk_set_style(style_Header);
		glk_put_string("CocoaGlk imaging test ");
		glk_set_style(style_Normal);
		glk_put_string("x");
		int y;
		for (y=0; y<x*4; y++) {
			glk_put_string(".");
		}
		glk_put_string("x");
	}
	glk_put_string("\n\n");
	
	for (x=0; x<10; x++) {
		glk_set_style(style_Header);
		glk_put_string("CocoaGlk imaging test ");
		glk_set_style(style_Normal);
		glk_put_string("x");
		int y;
		for (y=0; y<x*4; y++) {
			glk_put_string(" ");
		}
		glk_put_string("x");
	}
	glk_put_string("\n\n");
#endif

	glk_set_style(style_Header);
	//glk_put_string("CocoaGlk imaging test\n");
	glk_set_style(style_Normal);
	//glk_put_string("\n");
	
	write_image_test();
	
	glk_request_char_event(mainwin1);
	
	// Process events until the user presses a key
	finished = NO;
	while (!finished) {
		glk_select(&evt);

		switch (evt.type) {				
			case evtype_CharInput:
				write_image_test();
				glk_request_char_event(mainwin1);				
				break;
		}
	}
}
