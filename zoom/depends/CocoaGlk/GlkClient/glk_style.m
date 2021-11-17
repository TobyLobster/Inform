//
//  glk_style.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 16/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "glk.h"
#import "cocoaglk.h"
#import "glk_client.h"

//
// There are no guarantees of how styles will look, but you can make
// suggestions.
//
// These functions set and clear hints about the appearance of one style for
// a particular type of window. You can also set wintype to wintype_AllTypes,
// which sets (or clears) a hint for all types of window. [[There is no
//	equivalent constant to set a hint for all styles of a single window
//	type.]]
//
// Initially, no hints are set for any window type or style. Note that
// having no hint set is not the same as setting a hint with value 0.
// 
// These functions do *not* affect *existing* windows. They affect the
// windows which you create subsequently. If you want to set hints for all
// your game windows, call glk_stylehint_set() before you start creating
// windows. If you want different hints for different windows, change the
// hints before creating each window.
//
// [[This policy makes life easier for the interpreter. It knows everything
//	about a particular window's appearance when the window is created,
//	and it doesn't have to change it while the window exists.]]
//
// Hints are hints. The interpreter may ignore them, or give the player
// a choice about whether to accept them. Also, it is never necessary
// to set hints. You don't have to suggest that style_Preformatted be
// fixed-width, or style_Emphasized be boldface or italic; they will have
// appropriate defaults. Hints are for situations when you want to *change*
// the appearance of a style from what it would ordinarily be. The most
// common case when this is appropriate is for the styles style_User1
// and style_User2.
//
void glk_stylehint_set(glui32 wintype, glui32 styl, glui32 hint, 
					   glsi32 val) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_stylehint_set(%u, %u, %u, %u)", wintype, styl, hint, val);
#endif

	// Sanity checking
	switch (wintype) {
		case wintype_Pair:
		case wintype_Blank:
			// Pair and blank windows have no style
			return;
			
		case wintype_TextGrid:
		case wintype_TextBuffer:
		case wintype_Graphics:
		case wintype_AllTypes:
			break;
		
		default:
			// Unknown window type
			cocoaglk_error("glk_stylehint_set called with an unknown window type");
			return;
	}
	
	if (styl >= style_NUMSTYLES) {
		static BOOL style_warning = NO;
		
		if (!style_warning) {
			cocoaglk_warning("Glk client is using styles outside of the normal range (this is OK in CocoaGlk but may cause problems with other Glk libraries)");
			style_warning = YES;
		}
	}
	
	// We actually support any style number you can think of (ie, an unlimited number of styles, not just the few standard Glk gives you)
	[cocoaglk_buffer setStyleHint: hint
						 forStyle: styl
						  toValue: val
					   windowType: wintype];
}

void glk_stylehint_clear(glui32 wintype, glui32 styl, glui32 hint) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_stylehint_clear(%u, %u, %u)", wintype, styl, hint);
#endif
	
	// Sanity checking
	switch (wintype) {
		case wintype_Pair:
		case wintype_Blank:
			// Pair and blank windows have no style
			return;
			
		case wintype_TextGrid:
		case wintype_TextBuffer:
		case wintype_Graphics:
		case wintype_AllTypes:
			break;
			
		default:
			// Unknown window type
			cocoaglk_error("glk_stylehint_clear called with an unknown window type");
			return;
	}
	
	[cocoaglk_buffer clearStyleHint: hint
						   forStyle: styl
						 windowType: wintype];
}

//
// This returns TRUE (1) if the two styles are visually distinguishable
// in the given window. If they are not, it returns FALSE (0). The exact
// meaning of this is left to the library to determine.
//
glui32 glk_style_distinguish(winid_t win, glui32 styl1, glui32 styl2) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_style_distinguish(%p, %u, %u)", win, styl1, styl2);
#endif

	// For the moment, we always return TRUE (as all styles are technically distinguishable)
	return 1;
}

//
// This tries to test an attribute of one style in the given window. The
// library may not be able to determine the attribute; if not, this returns
// FALSE (0). If it can, it returns TRUE (1) and stores the value in the
// location pointed at by result. [[As usual, it is legal for result to be
//	NULL, although fairly pointless.]]
// 
// The meaning of the value depends on the hint which was tested:
// 
// * stylehint_Indentation, stylehint_ParaIndentation: The indentation
// and paragraph indentation. These are in a metric which is
// platform-dependent. [[Most likely either characters or pixels.]]
// * stylehint_Justification: One of the constants
// stylehint_just_LeftFlush, stylehint_just_LeftRight,
// stylehint_just_Centered, or stylehint_just_RightFlush.
// * stylehint_Size: The font size. Again, this is in a
// platform-dependent metric. [[Pixels, points, or simply 1 if the
//     library does not support varying font sizes.]]
// * stylehint_Weight: 1 for heavy-weight fonts (boldface), 0 for normal
// weight, and -1 for light-weight fonts.
// * stylehint_Oblique: 1 for oblique fonts (italic), or 0 for normal
// angle.
// * stylehint_Proportional: 1 for proportional-width fonts, or 0
// for fixed-width.
// * stylehint_TextColor, stylehint_BackColor: These are values from
// 0x00000000 to 0x00FFFFFF, encoded as described in section 5.5.1,
// "Suggesting the Appearance of Styles".
// * stylehint_ReverseColor: 0 for normal printing, 1 if the foreground
// and background colors are reversed.
// 
glui32 glk_style_measure(winid_t win, glui32 styl, glui32 hint, 
						 glui32 *result) {
	// Sanity checking
	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_style_measure called with an invalid winid");
	}
	
	if (!result) {
		cocoaglk_error("glk_style_measure called with a NULL value for result");
	}
	
	if (hint >= stylehint_NUMHINTS) {
		// We should be able to measure any defined hint
		return 0;
	}
	
	if (win->wintype == wintype_Blank ||
		win->wintype == wintype_Pair) {
		// These window types have no styles
		return 0;
	}
	
	// We need to flush the buffer in order to get the latest values for the measurements
	cocoaglk_flushbuffer("Measuring a style");
	
	*result = [cocoaglk_session measureStyle: styl
										hint: hint
									inWindow: win->identifier];

#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_style_measure(%p, %u, %u, %p=%u) = 1", win, styl, hint, result, *result);
#endif
	
	return 1;
}
