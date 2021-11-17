//
//  glk_main.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 16/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

//
// General Glk functions and routines that don't fit anywhere else
//

#if defined(COCOAGLK_IPHONE)
# import <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

#include "glk.h"
#import "cocoaglk.h"
#import "glk_client.h"

int cocoaglk_loopIteration = 0;
void (*cocoaglk_interrupt)(void);

void glk_exit(void) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_exit()");
#endif
	
	// Flush the buffer
	cocoaglk_flushbuffer("About to exit");
	
	// Tell the UI that we're done
	[cocoaglk_session clientHasFinished];
	
	// Kill off the autorelease pool
	[cocoaglk_pool release];
	
#if !defined(COCOAGLK_IPHONE)
	exit(0);
#else
	[NSThread exit];
#endif
}

//
// Most platforms have some provision for interrupting a program --
// command-period on the Macintosh, control-C in Unix, possibly a window
// manager menu item, or other possibilities. This can happen at any time,
// including while execution is nested inside one of your own functions,
// or inside a Glk library function.
// 
// If you need to clean up critical resources, you can specify an interrupt
// handler function.
//
void glk_set_interrupt_handler(void (*func)(void)) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_set_interrupt_handler(%p)", func);
#endif

	cocoaglk_interrupt = func;
}

void glk_tick(void) {
	// Tock. No Gnurrs here.
	
	// ...
	
	// CHOMP

#if COCOAGLK_TRACE > 1
	NSLog(@"TRACE: glk_tick()", func);
#endif
	
	static int ticker = 0;
	
	if ((ticker++) > 512) {
		ticker = 0;
		if ([cocoaglk_buffer hasGotABitOnTheLargeSide]) {
			cocoaglk_loopIteration = (int)[cocoaglk_session synchronisationCount];

			cocoaglk_flushbuffer("512 tick large buffer flush");
		}
	}
}

// 
// The "gestalt" mechanism (cheerfully stolen from the Mac OS) is a system by
// which the Glk API can be upgraded without making your life impossible. New
// capabilities (graphics, sound, or so on) can be added without changing the
// basic specification. The system also allows for "optional" capabilities
// -- those which not all Glk library implementations will support -- and
//	allows you to check for their presence without trying to infer them from
//	a version number.
//
// The basic idea is that you can request information about the capabilities
// of the API, by calling the gestalt functions:

// The selector (the "sel" argument) tells which capability you
// are requesting information about; the other three arguments are
// additional information, which may or may not be meaningful. The arr
// and arrlen arguments of glk_gestalt_ext() are always optional; you may
// always pass NULL and 0, if you do not want whatever information they
// represent. glk_gestalt() is simply a shortcut for this; glk_gestalt(x,
// y) is exactly the same as glk_gestalt_ext(x, y, NULL, 0).
// 
// The critical point is that if the Glk library has never heard of the
// selector sel, it will return 0. It is *always* safe to call glk_gestalt(x,
// y) (or glk_gestalt_ext(x, y, NULL, 0)). Even if you are using an old
// library, which was compiled before the given capability was imagined,
// you can test for the capability by calling glk_gestalt(); the library
// will correctly indicate that it does not support it, by returning 0.
//
glui32 glk_gestalt(glui32 sel, glui32 val) {
	glui32 result = glk_gestalt_ext(sel, val, NULL, 0);

#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_gestalt(%u, %u) = %u", sel, val, result);
#endif
	
	return result;
}

glui32 glk_gestalt_ext(glui32 sel, glui32 val, glui32 *arr, 
					   glui32 arrlen) {
	glui32 result;
	
	switch (sel) {
		case gestalt_Version:
			result = 0x700;
			break;
			
		case gestalt_CharInput:
			result = 1;
			break;
			
		case gestalt_LineInput:
			if (val < 32 || (val >= 127 && val <= 159))
				result = 0;
			else
				result = 1;
			break;
			
		case gestalt_CharOutput:
			if (val < 32 || (val >= 127 && val <= 159) || val > 0xffff) {
				if (arr && arrlen >= 1) arr[0] = 0;
				result = gestalt_CharOutput_CannotPrint;
				if (val == 10) result = gestalt_CharOutput_ExactPrint;
			} else {
				if (arr && arrlen >= 1) arr[0] = 1;
				result = gestalt_CharOutput_ExactPrint;
			}
			break;
			
		case gestalt_MouseInput:
			if (val == wintype_TextGrid ||
				val == wintype_Graphics ||
				val == wintype_Blank) {
				result = 1;
			} else {
				result = 0;
			}
			break;
			
		case gestalt_Timer:
			result = 1;
			break;
			
		case gestalt_Graphics:
			result = 1;
			break;
			
		case gestalt_DrawImage:
			result = 1;
			break;
			
		case gestalt_Sound:
			result = 0;
			break;
			
		case gestalt_SoundVolume:
			result = 0;
			break;
			
		case gestalt_SoundNotify:
			result = 0;
			break;
			
		case gestalt_Hyperlinks:
			result = 1;
			break;
			
		case gestalt_HyperlinkInput:
			if (val == wintype_TextBuffer ||
				val == wintype_TextGrid) {
				result = 1;
			} else {
				result = 0;
			}
			break;
			
		case gestalt_SoundMusic:
			result = 0;
			break;
			
		case gestalt_GraphicsTransparency:
			result = 1;
			break;
			
		case gestalt_Unicode:
			result = 1;
			break;
			
		default:
			result = 0;
			break;
	}
	
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_gestalt_ext(%u, %u, %p, %u) = %i", sel, val, arr, arrlen, result);
#endif
	
	return result;
}

//
// These have a few advantages over the standard ANSI tolower() and toupper()
// macros. They work for the entire Latin-1 character set, including accented
// letters; they behave consistently on all platforms, since they're part
// of the Glk library; and they are safe for all characters. That is, if
// you call glk_char_to_lower() on a lower-case character, or a character
// which is not a letter, you'll get the argument back unchanged.
//
unsigned char glk_char_to_lower(unsigned char ch) {
	// Doing things this way lets us use Cocoa's built-in unicode conversion functions
	// (Which handles those nassty Latin-1 characters for us)
	NSString* str = [[NSString alloc] initWithBytes: &ch
											 length: 1
										   encoding: NSISOLatin1StringEncoding];
	NSString* lower = [str lowercaseString];
	
	unichar res = [lower characterAtIndex: 0];
	[str release];
	
	if (res < 32 || res > 255) res = ch;
	
	return res;
}

unsigned char glk_char_to_upper(unsigned char ch) {
	// Doing things this way lets us use Cocoa's built-in unicode conversion functions
	// (Which handles those nassty Latin-1 characters for us)
	NSString* str = [[NSString alloc] initWithBytes: &ch
											 length: 1
										   encoding: NSISOLatin1StringEncoding];
	NSString* lower = [str uppercaseString];
	
	unichar res = [lower characterAtIndex: 0];
	[str release];

	if (res < 32 || res > 255) res = ch;

	return res;
}
