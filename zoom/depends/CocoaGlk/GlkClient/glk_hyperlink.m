//
//  glk_hyperlink.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 16/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "glk.h"
#import "cocoaglk.h"
#import "glk_client.h"

void glk_set_hyperlink(glui32 linkval) {
	glk_set_hyperlink_stream(cocoaglk_currentstream, linkval);
}

void glk_set_hyperlink_stream(strid_t str, glui32 linkval) {
#if COCOAGLK_TRACE > 1
	NSLog(@"TRACE: glk_set_hyperlink_stream(%p, %u)", str, linkval);
#endif

	if (!cocoaglk_strid_sane(str)) {
		cocoaglk_warning("glk_set_hyperlink_stream called with an invalid strid");
		return;
	}
	
	GlkBuffer* buf = nil;
	
	if (str->buffered) {
		// Get the buffer
		buf = str->streamBuffer;
		if (buf == nil) {
			buf = cocoaglk_buffer;
		}
	}
	
	if (buf) {
		// Write using the buffer
		if (linkval == 0) {
			[buf clearHyperlinkOnStream: str->identifier];
		} else {
			[buf setHyperlink: linkval
					 onStream: str->identifier];
		}
		
		str->bufferedAmount++;
	} else {
		// Write direct
		cocoaglk_loadstream(str);
		
		if (linkval == 0) {
			[str->stream clearHyperlink];
		} else {
			[str->stream setHyperlink: linkval];
		}
	}
	
	cocoaglk_maybeflushstream(str, "Setting/clearing a hyperlink");
}

void glk_request_hyperlink_event(winid_t win) {
#if COCOAGLK_TRACE > 1
	NSLog(@"TRACE: glk_request_hyperlink_event(%p)", win);
#endif

	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_warning("glk_request_hyperlink_event called with an invalid winid");
		return;
	}
	
	[cocoaglk_buffer requestHyperlinkEventsForWindowIdentifier: win->identifier];
}

void glk_cancel_hyperlink_event(winid_t win) {
#if COCOAGLK_TRACE > 1
	NSLog(@"TRACE: glk_cancel_hyperlink_event(%p)", win);
#endif
	
	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_warning("glk_cancel_hyperlink_event called with an invalid winid");
		return;
	}
	
	[cocoaglk_buffer cancelHyperlinkEventsForWindowIdentifier: win->identifier];
}
