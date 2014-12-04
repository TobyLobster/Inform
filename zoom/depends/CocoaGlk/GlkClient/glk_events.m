//
//  glk_events.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 16/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#if defined(COCOAGLK_IPHONE)
# include <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

#include "glk.h"
#include "cocoaglk.h"
#import "glk_client.h"

BOOL cocoaglk_eventwaiting = NO;
int cocoaglk_timerlength = -1;
NSDate* cocoaglk_nextTimerEvent = nil;

@interface GlkListener : NSObject<GlkEventListener> 
@end

@implementation GlkListener

- (oneway void) eventReady: (int) syncCount {
	cocoaglk_eventwaiting = YES;
	cocoaglk_loopIteration = syncCount;
}

@end

//
// Advance the time that the next timer event should occur at
//
void cocoaglk_next_time() {
	if (!cocoaglk_nextTimerEvent) return;
	float interval = ((float)cocoaglk_timerlength)/1000.0;
	
	do {
		// Move cocoaglk_nextTimerEvent on
		NSDate* nextTime = [cocoaglk_nextTimerEvent dateByAddingTimeInterval: interval];
		
		[cocoaglk_nextTimerEvent release];
		cocoaglk_nextTimerEvent = [nextTime retain];
		
		// Continue until cocoaglk_nextTimerEvent is in the future
	} while ([cocoaglk_nextTimerEvent compare: [NSDate date]] < 0);
}

//
// Wait for the next event to come along
//
void glk_select(event_t *event) {
	// Sanity check
	if (event == NULL) {
		cocoaglk_error("glk_select called with a NULL argument");
	}

#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_select(%p)", event);
#endif
	
	// Clear the event structure
	event->type = evtype_None;
	event->win  = NULL;
	event->val1 = 0;
	event->val2 = 0;
	
	// We start by flushing the buffer
	cocoaglk_flushbuffer("glk_select called");
	
	// Then we cycle the autorelease pool
	[cocoaglk_pool release];
	cocoaglk_pool = [[NSAutoreleasePool alloc] init];
	
	// Register a new listener
	cocoaglk_eventwaiting = NO;

	GlkListener* listener = [[GlkListener alloc] init];
	[cocoaglk_session willSelect];
	[cocoaglk_session setEventListener: listener];

	// Wait for and retrieve the next event
	NSObject<GlkEvent>* evt = [cocoaglk_session nextEvent];
	
	while (evt == NULL) {
		if (cocoaglk_eventwaiting) {
			// Fetch the next event
			evt = [cocoaglk_session nextEvent];
		} else {
			// Hang around a while
			[[NSRunLoop currentRunLoop] acceptInputForMode: NSDefaultRunLoopMode
												beforeDate: cocoaglk_nextTimerEvent?cocoaglk_nextTimerEvent:[NSDate distantFuture]];
			
			if (!cocoaglk_eventwaiting && [cocoaglk_nextTimerEvent compare: [NSDate date]] < 0) {
				// Timer has fired
				cocoaglk_next_time();
				event->type = evtype_Timer;

				// Deregister the listener
				[cocoaglk_session setEventListener: nil];
				[listener release]; listener = nil;
				
				// Finish
				return;
			}
		}
	}
	
	// Deregister the listener
	[cocoaglk_session setEventListener: nil];
	[listener release]; listener = nil;
	cocoaglk_eventwaiting = NO;
	
	// Translate the event
	if (evt) {
		event->type = [evt type];
		event->win  = cocoaglk_winid_get([evt windowIdentifier]);
		event->val1 = [evt val1];
		event->val2 = [evt val2];
		
		switch (event->type) {
			case evtype_LineInput:
			{
				// Buffer up the line input
				NSString* lineInput = [evt lineInput];
				
				if (event->win && event->win->ucs4 && event->win->inputBufUcs4) {
					// Copy the line input data as UCS-4 information
					int length = cocoaglk_copy_string_to_uni_buf(lineInput, event->win->inputBufUcs4, event->win->bufLen-1);
					
					// Set the length correctly
					if (length > event->win->bufLen) length = event->win->bufLen;
					event->val1 = length;
					
					// Echo the text
					if (event->win->stream && event->win->stream->echo) {
						glk_put_buffer_stream_uni(event->win->stream->echo, event->win->inputBufUcs4, length);
						glk_put_char_stream_uni(event->win->stream->echo, '\n');
					}

					// Deregister the buffer
					cocoaglk_unregister_line_buffers(event->win);
				} else if (event->win && event->win->inputBuf) {
					NSData*   latin1Input = [lineInput dataUsingEncoding: NSISOLatin1StringEncoding
													allowLossyConversion: YES];
					
					int length = [latin1Input length];
					
					if (event->win && event->win->inputBuf) {
						if (length > event->win->bufLen) {
							length = event->win->bufLen-1;
						}
						
						[latin1Input getBytes: event->win->inputBuf
									   length: length];

						
						// Echo the text
						if (event->win->stream && event->win->stream->echo) {
							glk_put_buffer_stream(event->win->stream->echo, event->win->inputBuf, length);
							glk_put_char_stream_uni(event->win->stream->echo, '\n');
						}
						
						event->val1 = length;
					}

					// Deregister the buffer
					cocoaglk_unregister_line_buffers(event->win);
				}
					
				break;
			}
			
			default:
				// Nothing to do
				break;
		}
	}
}

//
// This checks if an internally-spawned event is available. If so, it stores
// it in the structure pointed to by event. If not, it sets event->type to
// evtype_None. Either way, it returns almost immediately.
//
// The first question you now ask is, what is an internally-spawned
// event? glk_select_poll() does *not* check for or return evtype_CharInput,
// evtype_LineInput, or evtype_MouseInput events. It is intended for you
// to test conditions which may have occurred while you are computing, and
// not interfacing with the player. For example, time may pass during slow
// computations; you can use glk_select_poll() to see if a evtype_Timer
// event has occured. (See section 4.4, "Timer Events".)
// 
// At the moment, glk_select_poll() checks for evtype_Timer, and possibly
// evtype_Arrange and evtype_SoundNotify events. But see section 4.9,
// "Other Events".
//
void glk_select_poll(event_t *event) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_select_poll(%p)", event);
#endif

	// Sanity check
	if (event == NULL) {
		cocoaglk_error("glk_select_poll called with a NULL argument");
	}
	
	// Clear the event structure
	event->type = evtype_None;
	event->win  = NULL;
	event->val1 = 0;
	event->val2 = 0;

	// See if the timer has fired
	if ([cocoaglk_nextTimerEvent compare: [NSDate date]] < 0) {
		// Yep: return in the event structure
		event->type = evtype_Timer;
		
		// Move on
		cocoaglk_next_time();
		
		return;
	}
}

//
// You can request that an event be sent at fixed intervals, regardless of
// what the player does. Unlike input events, timer events can be tested
// for with glk_select_poll() as well as glk_select().
//
void glk_request_timer_events(glui32 millisecs) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_request_timer_events(%u)", millisecs);
#endif
	
	// Release the old timer event date
	[cocoaglk_nextTimerEvent release];
	cocoaglk_nextTimerEvent = nil;
	
	// Set the length of time between events
	cocoaglk_timerlength = millisecs;
	
	if (cocoaglk_timerlength > 0) {
		// Create the timer object
		cocoaglk_nextTimerEvent = [[NSDate dateWithTimeIntervalSinceNow: ((float)millisecs)/1000.0] retain];
	}
}

//
// Unregisters any line input buffers associated with the specified window
//
void cocoaglk_unregister_line_buffers(winid_t win) {
	if (!win->registered) return;
	win->registered = NO;
	
	if (win->inputBuf && cocoaglk_unregister_memory) {
		cocoaglk_unregister_memory(win->inputBuf, win->bufLen, "&+#!Cn", win->bufRock);
		win->inputBuf = NULL;
	}
	if (win->inputBufUcs4 && cocoaglk_unregister_memory) {
		cocoaglk_unregister_memory(win->inputBufUcs4, win->bufLen, "&+#!Iu", win->bufUcs4Rock);
		win->inputBufUcs4 = NULL;
	}
}

//
// A window cannot have requests for both character and line input at the
// same time. It is illegal to call glk_request_line_event() if the window
// already has a pending request for either character or line input.
//
// The buf argument is a pointer to space where the line input will be
// stored. (This may not be NULL.) maxlen is the length of this space,
// in bytes; the library will not accept more characters than this. If
// initlen is nonzero, then the first initlen bytes of buf will be entered as
// pre-existing input -- just as if the player had typed them himself. [[The
//	player can continue composing after this pre-entered input, or delete
//	it or edit as usual.]]
// 
// The contents of the buffer are undefined until the input is completed
// (either by a line input event, or glk_cancel_line_event(). The library
// may or may not fill in the buffer as the player composes, while the
// input is still pending; it is illegal to change the contents of the
// buffer yourself.
//
void glk_request_line_event(winid_t win, 
							char *buf, 
							glui32 maxlen,
							glui32 initlen) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_request_line_event(%p, %p, %u, %u)", win, buf, maxlen, initlen);
#endif

	// Sanity check
	if (win == NULL) {
		cocoaglk_warning("glk_request_line_event called with a NULL winid");
		return;
	}
	
	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_request_line_event called with an invalid winid");
	}
	
	if (initlen > maxlen) {
		cocoaglk_warning("glk_request_line_event called with an initlen value greater than maxlen");
		initlen = maxlen;
	}
	
	if (buf == NULL) {
		cocoaglk_warning("glk_request_line_event called with a NULL buffer");
	}
	
	// Deregister the previous buffer
	cocoaglk_unregister_line_buffers(win);
	
	// Set up the buffer
	win->ucs4     = NO;
	win->inputBuf = buf;
	win->bufLen   = maxlen;
	
	if (cocoaglk_register_memory && buf) {
		win->registered = YES;
		win->bufRock = cocoaglk_register_memory(buf, maxlen, "&+#!Cn");
	}
	
	// Pass the initial string if specified
	if (initlen > 0) {
		NSString* string = [[NSString alloc] initWithBytes: buf
													length: initlen
												  encoding: NSISOLatin1StringEncoding];
		
		if (string) {
			[cocoaglk_buffer setInputLine: string
					  forWindowIdentifier: win->identifier];
		}
		
		[string release];
	}
	
	// Buffer up the request
	[cocoaglk_buffer requestLineEventsForWindowIdentifier: win->identifier];
}

//
// You can request character input from text buffer and text grid windows.
// 
// A window cannot have requests for both character and line input at the
// same time. It is illegal to call glk_request_char_event() if the window
// already has a pending request for either character or line input.
// 
void glk_request_char_event(winid_t win) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_request_char_event(%p)", win);
#endif

	// Sanity check
	if (win == NULL) {
		cocoaglk_warning("glk_request_char_event called with a NULL winid");
		return;
	}

	if (!cocoaglk_winid_sane(win)) {
		// Aah! The melons! The horrible melons!
		cocoaglk_error("glk_request_char_event called with an invalid winid");
	}
	
	// Buffer up the request
	[cocoaglk_buffer requestCharEventsForWindowIdentifier: win->identifier];
}

//
// On some platforms, Glk can recognize when the mouse (or other pointer)
// is used to select a spot in a window. You can request mouse input only
// in text grid windows and graphics windows.
//
// A window can have mouse input and character/line input pending at the
// same time.
// 
// If the player clicks in a window which has a mouse input event pending,
// glk_select() will return an event whose type is evtype_MouseInput. Again,
// once this happens, the request is complete, and you must request another
// if you want further mouse input.
//
void glk_request_mouse_event(winid_t win) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_request_mouse_event(%p)", win);
#endif

	// Sanity check
	if (win == NULL) {
		cocoaglk_warning("glk_request_mouse_event called with a NULL winid");
		return;
	}

	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_request_mouse_event called with an invalid winid");
	}
	
	// Buffer up the request
	[cocoaglk_buffer requestMouseEventsForWindowIdentifier: win->identifier];
}

void glk_cancel_line_event(winid_t win, event_t *event) {
	// Sanity check
	if (win == NULL) {
		cocoaglk_warning("glk_cancel_line_event called with a NULL winid");
		return;
	}

	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_cancel_line_event called with an invalid winid");
	}
	
	// Force the cancellation
	// TODO: we can avoid flushing the buffer if the last request for line input for this window has already gone out
	cocoaglk_flushbuffer("Cancelling line input");
	
	NSString* lineInput = [cocoaglk_session cancelLineEventsForWindowIdentifier: win->identifier];
	
	if (event) {
		event->type = evtype_LineInput;
		event->win = win;
		event->val1 = event->val2 = 0;
	}

	if (win->ucs4 && win->inputBufUcs4) {
		// Copy the line input data as UCS-4 information
		int length = cocoaglk_copy_string_to_uni_buf(lineInput, win->inputBufUcs4, win->bufLen);
		
		// Set the length correctly
		if (length > win->bufLen) length = win->bufLen;
		if (event) event->val1 = length;
	} else if (win->inputBuf) {
		NSData*   latin1Input = [lineInput dataUsingEncoding: NSISOLatin1StringEncoding
										allowLossyConversion: YES];
		
		int length = [latin1Input length];
		
		if (win && win->inputBuf) {
			if (length > win->bufLen) {
				length = win->bufLen;
			}
			
			[latin1Input getBytes: win->inputBuf
						   length: length];
			
			if (event) event->val1 = length;
		}
	}
	
	// Unregister the line buffers
	cocoaglk_unregister_line_buffers(win);
}

void glk_cancel_char_event(winid_t win) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_cancel_char_event(%p)", win);
#endif

	// Sanity check
	if (win == NULL) {
		cocoaglk_warning("glk_cancel_char_event called with a NULL winid");
		return;
	}

	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_cancel_char_event called with an invalid winid");
	}
	
	// Buffer up the request
	[cocoaglk_buffer cancelCharEventsForWindowIdentifier: win->identifier];
}

void glk_cancel_mouse_event(winid_t win) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_cancel_mouse_event(%p)", win);
#endif

	// Sanity check
	if (win == NULL) {
		cocoaglk_warning("glk_cancel_mouse_event called with a NULL winid");
		return;
	}

	if (!cocoaglk_winid_sane(win)) {
		// Blibbleblibbleblibble
		cocoaglk_error("glk_cancel_mouse_event called with an invalid winid");
	}
	
	// Buffer up the request
	[cocoaglk_buffer cancelMouseEventsForWindowIdentifier: win->identifier];
}
