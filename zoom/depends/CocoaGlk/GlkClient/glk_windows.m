//
//  glk_windows.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 16/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "glk.h"
#import "cocoaglk.h"
#import "glk_client.h"

/// The winid of the current root window
static winid_t cocoaglk_rootwindow = nil;
/// The next unused window identifier
static glui32 cocoaglk_nextidentifier = 0;

/// Big dictionary o'windows
static NSMutableDictionary* cocoaglk_windows = nil;


/// This returns the root window. If there are no windows, this returns \c NULL .
winid_t glk_window_get_root(void) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_window_get_root() = %p", cocoaglk_rootwindow);
#endif

	return cocoaglk_rootwindow;
}

/// Sanity check a window ID
BOOL cocoaglk_winid_sane(winid_t win) {
	// These failures of sanity can be caused by the application
	if (win == NULL)
		return NO;						// Not a winid
	if (win->key != GlkWindowKey)
		return NO;						// Not a winid
	
	// These failures should only ever be caused by the glk library itself (so we print a warning to help with debugging)
	if (win->parent == NULL && cocoaglk_rootwindow != win && !win->closing) {
		cocoaglk_warning("Warning: window with delusions of grandeur");
		return NO;						// Window that has fallen out of the window structure somehow (and not due to it closing)
	}
	
	if (win->parent && (win->parent->left != win && win->parent->right != win)) {
		if (!win->closing) {
			// This is sometimes valid when the window is being closed
			cocoaglk_warning("Warning: window with negligent parents");
			return NO;						// Window whose parents have disowned it
		}
	}
	
	if (win->left && win->left->parent != win) {
		cocoaglk_warning("Warning: window with delinquent children");
		return NO;						// Window with a child that's forgotten its parent
	}
	if (win->right && win->right->parent != win) {
		cocoaglk_warning("Warning: window with delinquent children");
		return NO;						// Window with a child that's forgotten its parent
	}
	
	return YES;
}

/// Set up a stream for a specific window
static strid_t cocoaglk_stream_for_window(unsigned winId) {
	// Constructs a stream object for a window
	strid_t res = cocoaglk_stream();
	
	// Stream is write-only
	res->fmode = filemode_Write;
	
	// Stream should be buffered
	res->buffered = YES;
	res->lazyFlush = YES;

	// Stream refers to a window
	res->windowStream = YES;
	
	// Set the window identifier
	res->windowIdentifier = winId;
	
	// Register the stream
	[cocoaglk_buffer registerStreamForWindow: winId
							   forIdentifier: res->identifier];
	
	if (cocoaglk_register) {
		res->giRock = cocoaglk_register(res, gidisp_Class_Stream);
	}
	
	return res;
}

/// Store a window identifier in the big dictionary o' windows
static void cocoaglk_winid_identify(winid_t win) {
	// Create the dictionary if it doesn't already exist
	if (!cocoaglk_windows) {
		cocoaglk_windows = [[NSMutableDictionary alloc] init];
	}
	
	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("Attempt to call cocoaglk_winid_identify with a bad winid");
		return;
	}
	
	// Add this identifier to the dictionary
	[cocoaglk_windows setObject: [NSValue valueWithPointer: win]
						 forKey: @(win->identifier)];
}

// Get a winid from an identifier
winid_t cocoaglk_winid_get(unsigned identifier) {
	NSValue* res = [cocoaglk_windows objectForKey: @(identifier)];
	
	if (res == nil) return NULL;
	
	winid_t win = [res pointerValue];
	
	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("cocoaglk_winid_get found a bad winid");
		return NULL;
	}
	
	return win;
}

//
// If there are no windows, the first three arguments are meaningless. split
// *must* be zero, and method and size are ignored. wintype is the type of
// window you're creating, and rock is the rock (see section 1.6.1, "Rocks").
// 
// If any windows exist, new windows must be created by splitting
// existing ones. split is the window you want to split; this *must not*
// be zero. method is a mask of constants to specify the direction and the
// split method (see below). size is the size of the split. wintype is the
// type of window you're creating, and rock is the rock.
// 
// The winmethod constants:
// 
// * winmethod_Above, winmethod_Below, winmethod_Left, winmethod_Right:
// The new window will be above, below, to the left, or to the right
// of the old one which was split.
// * winmethod_Fixed, winmethod_Proportional: The new window is a fixed
// size, or a given proportion of the old window's size. (See below.)
// 
// Remember that it is possible that the library will be unable to create
// a new window, in which case glk_window_open() will return NULL. [[It
// 	is acceptable to gracefully exit, if the window you are creating is an
// 	important one -- such as your first window. But you should not try to
// 	perform any window operation on the id until you have tested to make
// 	sure it is non-zero.]]
// 
// The examples we've seen so far have the simplest kind of size
// control. (Yes, this is "below".) Every pair is a percentage split,
// with X percent going to one side, and (100-X) percent going to the
// other side. If the player resizes the window, the whole mess expands,
// contracts, or stretches in a uniform way.
// 
// As I said above, you can also make fixed-size splits. This is a little
// more complicated, because you have to know how this fixed size is
// measured.
// 
// Sizes are measured in a way which is different for each window type. For
// example, a text grid window is measured by the size of its fixed-width
// font. You can make a text grid window which is fixed at a height of four
// rows, or ten columns. A text buffer window is measured by the size of
// *its* font. [[Remember that different windows may use different size
// 	fonts. Even two text grid windows may use fixed-size fonts of different
// 	sizes.]] Graphics windows are measured in pixels, not characters. Blank
// windows aren't measured at all; there's no meaningful way to measure
// them, and therefore you can't create a blank window of a fixed size,
// only of a proportional (percentage) size.
//
winid_t glk_window_open(winid_t split, glui32 method, glui32 size, 
						glui32 wintype, glui32 rock) {
	// Sanity checking
	if (split == NULL && cocoaglk_rootwindow != NULL) {
		cocoaglk_error("Attempt to create root window when a root window already exists");
	}
	
	if (split != NULL && split->key != GlkWindowKey) {
		cocoaglk_error("Attempt to call glk_window_open on an object that is not a window");
	}
	
	if (split != NULL && split->parent != NULL && (split->parent->left != split && split->parent->right != split)) {
		// Adulterous windows?
		cocoaglk_error("Window structure has become corrupt (a window being split does not appear to be a child of its parent)");
	}
	
	if (split != NULL && split->parent == NULL && split != cocoaglk_rootwindow) {
		cocoaglk_error("Window structure has become corrupt (a window being split does not have a parent, and yet is not the root window)");
	}
	
	if (wintype == wintype_Pair) {
		cocoaglk_error("Attempt to create a pair window (these can only be created automatically)");
	}
	
	if (wintype != wintype_Blank &&
		wintype != wintype_TextBuffer &&
		wintype != wintype_TextGrid &&
		wintype != wintype_Graphics) {
		cocoaglk_error("Attempt to create a window with an invalid type");
	}
	
	if (split != NULL) {
		glui32 dir = method&winmethod_DirMask;
		if (dir != winmethod_Above &&
			dir != winmethod_Below &&
			dir != winmethod_Left &&
			dir != winmethod_Right) {
			cocoaglk_warning("Attempt to create a window with a bad direction");
		
			// Recover from this error
			method &= ~winmethod_DirMask;
			method |= winmethod_Above;
		}
	
		glui32 divide = method&winmethod_DivisionMask;
		if (divide != winmethod_Fixed &&
			divide != winmethod_Proportional) {
			cocoaglk_warning("Attempt to create a window without a valid division type");
		
			// Recover from this error
			method &= ~winmethod_DivisionMask;
			method |= winmethod_Proportional;
		}
	} else {
		// Use some standard defaults for the root window (these values actually never matter)
		size = 100;
		method = winmethod_Proportional|winmethod_Above;
	}
	
	// Create the window structure(s)
	winid_t res = malloc(sizeof(struct glk_window_struct));
	winid_t pair = NULL;
	
	res->key = GlkWindowKey;
	res->identifier = cocoaglk_nextidentifier++;
	
	res->rock = rock;
	
	res->method = method;
	res->size = size;
	res->wintype = wintype;

	res->parent = NULL;
	res->keyId = NULL;
	res->left = NULL;
	res->right = NULL;
	
	res->stream = nil;
	res->closing = NO;
	
	res->ucs4 = NO;
	res->inputBufUcs4 = NULL;
	res->inputBuf = NULL;
	res->bufLen = 0;
	res->registered = NO;
	
	res->background = 0xffffff;
	
	res->loopIteration = -1;
	
	if (split == NULL) {
		// This is the topmost window
		cocoaglk_rootwindow = res;
	} else {
		// This is a split window (and has an underlying pair window, the creation of which we must also buffer)
		pair = malloc(sizeof(struct glk_window_struct));
		
		pair->key = GlkWindowKey;
		pair->identifier = cocoaglk_nextidentifier++;
		
		pair->method = method;
		pair->size = size;
		pair->wintype = wintype_Pair;
		
		if (split->parent != NULL) {
			if (split->parent->left == split) {
				split->parent->left = pair;
			} else if (split->parent->right == split) {
				split->parent->right = pair;
			} else {
				cocoaglk_error("glk_window_open found a window whose parent does not contain it");
			}
		}
		
		pair->parent = split->parent;
		pair->keyId = pair->left = split;
		pair->right = res;
		split->parent = pair;
		res->parent = pair;
		
		pair->stream = nil;
		pair->closing = NO;
		
		pair->ucs4 = NO;
		pair->inputBufUcs4 = NULL;
		pair->inputBuf = NULL;
		pair->bufLen = 0;
		pair->registered = NO;
		
		pair->rock = 0;
		pair->loopIteration = -1;
		
		if (split == cocoaglk_rootwindow) {
			// The root window has changed
			cocoaglk_rootwindow = pair;
		}
	}
	
	// Add the operation(s) to the buffer
	switch (wintype) {
		default:
			cocoaglk_warning("(BUG?) Tried to create unknown type of window");			// Should have already been caught
		case wintype_Blank:
			[cocoaglk_buffer createBlankWindowWithIdentifier: res->identifier];
			break;
		case wintype_TextBuffer:
			[cocoaglk_buffer createTextWindowWithIdentifier: res->identifier];
			break;
		case wintype_TextGrid:
			[cocoaglk_buffer createTextGridWindowWithIdentifier: res->identifier];
			break;
		case wintype_Graphics:
			[cocoaglk_buffer createGraphicsWindowWithIdentifier: res->identifier];
			break;
	}
	
	if (split == NULL) {
		// We've created a new root window
		[cocoaglk_buffer setRootWindow: res->identifier];
	} else {
		// We've created a pair window
		[cocoaglk_buffer createPairWindowWithIdentifier: pair->identifier
											  keyWindow: pair->keyId->identifier
											 leftWindow: pair->left->identifier
											rightWindow: pair->right->identifier
												 method: pair->method
												   size: pair->size];
		
		if (cocoaglk_rootwindow == pair) {
			[cocoaglk_buffer setRootWindow: pair->identifier];
		}
	}
	
	// Get the streams
	res->stream = cocoaglk_stream_for_window(res->identifier);
	if (pair) {
		pair->stream = cocoaglk_stream_for_window(pair->identifier);
	}
	
	// Register the windows
	cocoaglk_winid_identify(res);
	if (pair) {
		cocoaglk_winid_identify(pair);
	}
	
	// Also register the windows
	if (cocoaglk_register) {
		res->giRock = cocoaglk_register(res, gidisp_Class_Window);
		if (pair) {
			pair->giRock = cocoaglk_register(pair, gidisp_Class_Window);
		}
	}
	
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_window_open(%p, %u, %u, %u, %u) = %p", split, method, size, wintype, rock, res);
#endif
	
	// Return the result
	return res;
}

static void cocoaglk_window_discard(winid_t win) {
	// Discards a window (frees it, fixes key windows, adjusts the window tree, but doesn't do anything clever with the
	// window structure)
	if (!win->closing) {
		cocoaglk_error("cocoaglk_window_discard called with a window that is not closing");
	}
	
	// Unregister the window
	cocoaglk_unregister_line_buffers(win);
	if (cocoaglk_unregister) {
		cocoaglk_unregister(win, gidisp_Class_Window, win->giRock);
	}
	
	// Change the key window of any parent window to NULL if it's the same as win
	winid_t parent = win->parent;
	while (parent != NULL) {		
		if (parent->keyId == win) {
			parent->keyId = NULL;
		}
		
		parent = parent->parent;
	}
	
	// Discard the left and right windows as well
	if (win->left) {
		win->left->closing = YES;
		cocoaglk_window_discard(win->left);
		win->left = NULL;
	}

	if (win->right) {
		win->right->closing = YES;
		cocoaglk_window_discard(win->right);
		win->right = NULL;
	}
	
	// Change the parent pointers
	if (win->parent && win->parent->left == win) {
		win->parent->left = NULL;
	}

	if (win->parent && win->parent->right == win) {
		win->parent->right = NULL;
	}
	
	// Finish off this window
	[cocoaglk_windows removeObjectForKey: @(win->identifier)];
	
	// Finally kill the window
	win->key = 0;
	win->identifier = 0;
	
	if (win->stream) {
		glk_stream_close(win->stream, NULL);
		win->stream = NULL;
	}
	
	free(win);
}

/// This closes a window, which is pretty much exactly the opposite of
/// opening a window. It is legal to close all your windows, or to close
/// the root window (which does the same thing.)
///
/// The result argument is filled with the output character count of the
/// window stream. See section 5, "Streams" and section 5.3, "Closing
/// Streams".
///
/// When you close a window (and it is not the root window), the other
/// window in its pair takes over all the freed-up area.
void glk_window_close(winid_t win, stream_result_t *result) {	
	// Some broken games call this with a NULL winid, just do nothing in this case: result will contain whatever garbage it started out with
	if (!win) {
		if (result) {
			cocoaglk_error("glk_window_close called with a NULL winid: refusing to return an undefined stream result");
		} else {
			cocoaglk_warning("glk_window_close called with a NULL winid");
		}
		return;
	}
	
	// Sanity checking
	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_window_close called with an invalid winid");
	}
	
	win->closing = YES;

	// Make sure that the display knows about this
	[cocoaglk_buffer closeWindowIdentifier: win->identifier];
	
	// Close the stream
	glk_stream_close(win->stream, result);
	win->stream = NULL;
	
	// Get the parent window
	winid_t parent = win->parent;
	
	if (parent != NULL) {
		// The parent window is also closing (to be replaced by our sibling)
		winid_t sibling;
		winid_t grandparent = parent->parent;
		
		// Work out the surviving sibling
		if (parent->left == win) {
			sibling = parent->right;
			parent->right = NULL;
		} else if (parent->right == win) {
			sibling = parent->left;
			parent->left = NULL;
		} else {
			cocoaglk_error("glk_window_close found an invalid parent winid");
			return;
		}
		
		// Move the sibling to its new home
		if (grandparent != NULL) {
			// A child of the grandparent has changed
			if (grandparent->left == parent) {
				grandparent->left = sibling;
			} else if (grandparent->right == parent) {
				grandparent->right = sibling;
			} else {
				cocoaglk_error("glk_window_close found an invalid grandparent winid");
			}
		} else {
			// The window has no grandparent
			cocoaglk_rootwindow = sibling;
		}
		
		sibling->parent = grandparent;
		
		// Finish off the parent window
		parent->closing = YES;
		parent->parent = NULL;
		cocoaglk_window_discard(parent);
	} else {
		// We're releasing the root window
		cocoaglk_window_discard(win);
		cocoaglk_rootwindow = NULL;		
		
		// Make sure that the display knows about this
		[cocoaglk_buffer setRootWindow: GlkNoWindow];
	}

#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_window_close(%p, %p)", win, result);
#endif
		
	return;
}

/// \c cocoaglk_window_synchronise() synchronises the data stored with a window with the data
/// that is stored on the server. This call ensures that the server is not called too often
/// for systems that (for example) call \c glk_window_get_size obsessively. This saves on
/// buffer flushes.
static void cocoaglk_window_synchronise(winid_t win) {
	if (win->loopIteration == cocoaglk_loopIteration) return;
	
	// Flush the buffer
	cocoaglk_flushbuffer("Synchronising window details");
	
	// Get the window size (retrieve as many as possible for this flush)
	for (win = cocoaglk_rootwindow; win!=NULL; win = glk_window_iterate(win, NULL)) {
		if (win->loopIteration == cocoaglk_loopIteration) continue;
		
		GlkSize res = [cocoaglk_session sizeForWindowIdentifier: win->identifier];

		win->width = res.width;
		win->height = res.height;

		// Update the loopIteration so that we don't resynchronise too soon
		win->loopIteration = cocoaglk_loopIteration;
	}
}

/// \c glk_window_get_size() simply returns the actual size of the window,
/// in its measurement system. As described in section 1.9, "Other API
/// Conventions", either widthptr or heightptr can be NULL, if you only want
/// one measurement. [[Or, in fact, both, if you want to waste time.]]
void glk_window_get_size(winid_t win, glui32 *widthptr, 
						 glui32 *heightptr) {
	// Sanity checking
	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_window_get_size called with an invalid winid");
	}
	
	if (widthptr == NULL && heightptr == NULL) return;
	
	cocoaglk_window_synchronise(win);
	
	// Get the window dimensions (should now be cached in win)
	if (widthptr) *widthptr = win->width;
	if (heightptr) *heightptr = win->height;
	
#if 0
	// Must flush the buffer in order for the window to be up to date
	cocoaglk_flushbuffer("Reading a window size");
	
	// Get the window dimensions
	GlkSize res = [cocoaglk_session sizeForWindowIdentifier: win->identifier];
	
	if (widthptr) *widthptr = res.width;
	if (heightptr) *heightptr = res.height;
#endif

#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_window_get_size(%p, %p=%u, %p=%u)", win, widthptr, win->width, heightptr, win->height);
#endif
	
}


/// \c glk_window_set_arrangement() changes the size of an existing
/// split -- that is, it changes the constraint of a given pair
/// window. \c glk_window_get_arrangement() returns the constraint of a given
/// pair window.
void glk_window_set_arrangement(winid_t win, glui32 method,
								glui32 size, winid_t keywin) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_window_set_arrangement(%p, %u, %u, %p)", win, method, size, keywin);
#endif
	
	// Sanity check
	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_window_set_arrangement called with an invalid winid");
	}
	
	if (keywin != NULL && !cocoaglk_winid_sane(keywin)) {
		cocoaglk_error("glk_window_set_arrangement called with an invalid key window id");
	}
	
	if (win->wintype != wintype_Pair) {
		cocoaglk_warning("glk_window_set_arrangement called on a window that is not a pair window");
		return;
	}
	
	glui32 dir = method&winmethod_DirMask;
	if (dir != winmethod_Above &&
		dir != winmethod_Below &&
		dir != winmethod_Left &&
		dir != winmethod_Right) {
		cocoaglk_warning("Attempt to arrange a window with a bad direction");
		
		// Recover from this error
		method &= ~winmethod_DirMask;
		method |= winmethod_Above;
	}
	
	glui32 divide = method&winmethod_DivisionMask;
	if (divide != winmethod_Fixed &&
		divide != winmethod_Proportional) {
		cocoaglk_warning("Attempt to arrange a window without a valid division type");
		
		// Recover from this error
		method &= ~winmethod_DivisionMask;
		method |= winmethod_Proportional;
	}
	
	// Record the changes, plus tell the UI about what's supposed to happen
	win->method = method;
	win->size = size;
	win->keyId = keywin;
	
	[cocoaglk_buffer arrangeWindow: win->identifier
							method: method
							  size: size
						 keyWindow: keywin!=NULL?keywin->identifier:GlkNoWindow];
}

/// \c glk_window_set_arrangement() changes the size of an existing
/// split -- that is, it changes the constraint of a given pair
/// window. \c glk_window_get_arrangement() returns the constraint of a given
/// pair window.
void glk_window_get_arrangement(winid_t win, glui32 *methodptr,
								glui32 *sizeptr, winid_t *keywinptr) {
	// Sanity check
	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_window_get_arrangement called with an invalid winid");
	}
	
	if (win->wintype != wintype_Pair) {
		cocoaglk_warning("glk_window_get_arrangement called on a window that is not a pair window");
	}
	
	// Read out the values
	if (methodptr) *methodptr = win->method;
	if (sizeptr) *sizeptr = win->size;
	if (keywinptr) *keywinptr = win->keyId;

#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_window_get_arrangement(%p, %p=%u, %p=%u, %p=%p)", win, methodptr, win->method, sizeptr, win->size, keywinptr, win->keyId);
#endif
}

/// This function can be used to iterate through the list of all open windows
/// (including pair windows.) See section 1.6.2, "Iterating Through Opaque
/// Objects".
winid_t glk_window_iterate(winid_t win, glui32 *rockptr) {
	// Sanity checks
	if (win != NULL && !cocoaglk_winid_sane(win)) {
		// They're coming to take me away, haha
		cocoaglk_error("glk_window_iterate called with an invalid winid");
	}
	
	// Will store the result eventually
	winid_t res = NULL;
	
	// Return the root window first
	if (win == NULL) {
		res = cocoaglk_rootwindow;
	} else {
		if (win->left) {
			// Go up the left branch if one exists
			res = win->left;
		} else {
			// Walk up the tree until we find a window we walked left from
			winid_t lastwin = win;
			
			res = win->parent;
			
			while (res && res->right == lastwin) {
				lastwin = res;
				res = res->parent;
			}
			
			if (res && res->left != lastwin) {
				cocoaglk_error("glk_window_iterate found a window whose parent does not contain it");
			}
			
			// Walk right (we're finished if res = nil here)
			if (res) res = res->right;
		}
	}
	
	// Get our rocks out
	if (res && rockptr) {
		*rockptr = res->rock;
	}

#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_window_iterate(%p, %p=%u) = %p", win, rockptr, rockptr?*rockptr:0, res);
	
	if (res && !cocoaglk_winid_sane(res)) {
		cocoaglk_error("(Error only checked for due to tracing): window returned by glk_window_iterate is invalid");
	}
#endif
		
	return res;
}

/// This retrieves the window's rock value.
glui32 glk_window_get_rock(winid_t win) {
	// Sanity check
	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_window_get_rock called with an invalid winid");
	}

#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_window_get_rock(%p) = %u", win, win->rock);
#endif
	
	return win->rock;
}

/// This retrieve the type of the window
glui32 glk_window_get_type(winid_t win) {
	// Sanity check
	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_window_get_type called with an invalid winid");
	}
	
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_window_get_type(%p) = %u", win, win->wintype);
#endif
		
	// Dish the dirt
	return win->wintype;
}

/// This retrieves the parent of the given window
winid_t glk_window_get_parent(winid_t win) {
	if (win == NULL) {
		cocoaglk_warning("glk_window_get_parent called with a NULL winid");
		return NULL;
	}

	// Sanity check
	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_window_get_parent called with an invalid winid");
	}
	
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_window_get_parent(%p) = %p", win, win->parent);
#endif
	
	// Dish the dirt
	return win->parent;
}

winid_t glk_window_get_sibling(winid_t win) {
	// Sanity check
	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_window_get_sibling called with an invalid winid");
	}
	
	// Dish the dirt
	winid_t parent = win->parent;
	if (parent == NULL)
		return NULL;
	
	if (parent->left == win) {
#if COCOAGLK_TRACE
		NSLog(@"TRACE: glk_window_get_parent(%p) = %p", win, parent->right);
#endif

		return parent->right;
	} else if (parent->right == win) {
#if COCOAGLK_TRACE
		NSLog(@"TRACE: glk_window_get_parent(%p) = %p", win, parent->left);
#endif

		return parent->left;
	} else {
		// Only happens when life sucks
		cocoaglk_error("glk_window_get_sibling found a window whose parent has disowned it");
		return NULL;
	}
}

/// Erase the window. The meaning of this depends on the window type.
///
/// * Text buffer: This may do any number of things, such as delete all
/// text in the window, or print enough blank lines to scroll all text
/// beyond visibility, or insert a page-break marker which is treated
/// specially by the display part of the library.
///
/// * Text grid: This will clear the window, filling all positions
/// with blanks. The window cursor is moved to the top left corner
/// (position 0,0).
///
/// * Graphics: Clears the entire window to its current background
/// color. See section 3.5.5, "Graphics Windows".
///
/// * Other window types: No effect.
///
/// It is illegal to erase a window which has line input pending.
void glk_window_clear(winid_t win) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_window_clear(%p)", win);
#endif
	
	if (win == NULL) {
		cocoaglk_warning("glk_window_clear called with NULL winid");
		return;
	}
	
	// Sanity check
	if (!cocoaglk_winid_sane(win)) {
		// Mr Flibble is very cross
		cocoaglk_error("glk_window_clear called with an invalid winid");
	}
	
	// Clear the window (well, eventually)
	if (win->wintype == wintype_Graphics) {
		NSColor* bgColour = [NSColor colorWithSRGBRed: ((CGFloat)(win->background&0xff0000))/16711680.0
												green: ((CGFloat)(win->background&0xff00))/65280.0
												 blue: ((CGFloat)(win->background&0xff))/255.0
												alpha: 1.0];

		[cocoaglk_buffer clearWindowIdentifier: win->identifier
						  withBackgroundColour: bgColour];
	} else {
		[cocoaglk_buffer clearWindowIdentifier: win->identifier];
	}
}

/// If you move the cursor right past the end of a line, it wraps; the next
/// character which is printed will appear at the beginning of the next line.
///
/// If you move the cursor below the last line, or when the cursor reaches
/// the end of the last line, it goes "off the screen" and further output has
/// no effect. You must call \c glk_window_move_cursor() or \c glk_window_clear()
/// to move the cursor back into the visible region.
void glk_window_move_cursor(winid_t win, glui32 xpos, glui32 ypos) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_move_cursor(%p, %u, %u)", win, xpos, ypos);
#endif

	if (win == NULL) {
		cocoaglk_warning("glk_window_move_cursor called with a NULL winid");
		return;
	}

	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_window_move_cursor called with a bad window ID");
		return;
	}
	
	[cocoaglk_buffer moveCursorInWindow: win->identifier
							toXposition: xpos
							  yPosition: ypos];
}

/// This returns the stream which is associated with the window. (See section
/// 5.6.1, "Window Streams".) Every window has a stream which can be printed
/// to, but this may not be useful, depending on the window type. [[For
/// example, printing to a blank window's stream has no effect.]]
strid_t glk_window_get_stream(winid_t win) {
	if (win == NULL) {
		cocoaglk_warning("glk_window_get_stream called with a NULL winid");
		return NULL;
	}
	
	// Sanity check
	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_window_get_stream called with an invalid winid");
	}
	
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_window_get_stream(%p) = %p", win, win->stream);
#endif
		
	// Dig the dirt
	return win->stream;
}

/// Initially, a window has no echo stream, so \c glk_window_get_echo_stream(win)
/// will return NULL. You can set a window's echo stream to be any valid
/// output stream by calling glk_window_set_echo_stream(win, str). You can
/// reset a window to stop echoing by calling glk_window_set_echo_stream(win,
/// NULL).
///
/// An echo stream can be of any type, even another window's window
/// stream. [[This would be somewhat silly, since it would mean that any
///	text printed to the window would be duplicated in another window. More
///	commonly, you would set a window's echo stream to be a file stream,
///	in order to create a transcript file from that window.]]
///
/// A window can only have one echo stream. But a single stream can be the
/// echo stream of any number of windows, sequentially or simultaneously.
///
/// If a window is closed, its echo stream remains open; it is \b not
/// automatically closed. [[Do not confuse the window's window stream with
/// its echo stream. The window stream is "owned" by the window, and dies with
/// it. The echo stream is merely temporarily associated with the window.]]
///
/// If a stream is closed, and it is the echo stream of one or more
/// windows, those windows are reset to not echo anymore. (So then calling
/// \c glk_window_get_echo_stream() on them will return NULL.)
///
/// It is illegal to set a window's echo stream to be its \b own window
/// stream. That would create an infinite loop, and is nearly certain to
/// crash the Glk library. It is similarly illegal to create a longer loop
/// (two or more windows echoing to each other.)
void glk_window_set_echo_stream(winid_t win, strid_t str) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_window_set_echo_stream(%p, %p)", win, str);
#endif

	// Sanity check
	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_window_set_echo_stream called with a bad winid");
	}
	
	if (str != NULL && !cocoaglk_strid_sane(str)) {
		cocoaglk_error("glk_window_set_echo_stream called with a bad stream id");
	}
	
	if (str == win->stream) {
		cocoaglk_error("glk_window_set_echo_stream asked to echo a windows output to itself (would create a loop)");
	}
	
	if (str != NULL) {
		// Check for loops
		strid_t echo = str->echo;
		while (echo != NULL) {
			if (echo == win->stream) {
				cocoaglk_error("glk_window_set_echo_stream called with a stream that is already eventually receiving output from the window (would create a loop)");
			}
		
			echo = echo->echo;
		}
	}
	
	// Ensure that the stream knows it's being echoed to
	NSValue* echoTo = [NSValue valueWithPointer: win->stream];
	
	if (win->stream->echo != NULL) {
		// Stop echoing to the previous stream
		[win->stream->echo->echoesTo removeObject: echoTo];
		
		win->stream->echo = NULL;
	}
	
	if (str != NULL) {
		// Tell the other stream that we're echoing to it
		[str->echoesTo addObject: echoTo];
	}
	
	// Set the echo stream
	win->stream->echo = str;
}

/// Retrieves the currently active echo stream
strid_t glk_window_get_echo_stream(winid_t win) {
	// Sanity check
	if (!cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_window_get_echo_stream called with a bad winid");
	}
	
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_window_get_echo_stream(%p) = %p", win, win->stream->echo);
#endif
		
	// Dig the dirt
	return win->stream->echo;
}

/// This sets the current stream to the window's stream. It is exactly
/// equivalent to
/// \c glk_stream_set_current(glk_window_get_stream(win)).
void glk_set_window(winid_t win) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_set_window(%p)", win);
#endif

	// Sanity check
	if (win != NULL && !cocoaglk_winid_sane(win)) {
		cocoaglk_error("glk_set_window called with a bad winid");
		return;
	}
	
	glk_stream_set_current(glk_window_get_stream(win));
}
