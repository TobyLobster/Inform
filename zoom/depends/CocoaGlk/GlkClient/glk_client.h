//
//  glk_client.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 16/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

//
// Types and functions used internally by the GlkClient framework
//

// Set to 1 to print debug messages
#define COCOAGLK_DEBUG 0

// Set to 1 to print trace messages
#define COCOAGLK_TRACE 0

#include <stdio.h>

#include "glk.h"
#include "gi_dispa.h"

#import "GlkHubProtocol.h"
#import "GlkSessionProtocol.h"
#import "GlkStreamProtocol.h"
#import "GlkFileRefProtocol.h"
#import "GlkBuffer.h"
#import "GlkImageSourceProtocol.h"

#pragma GCC visibility push(hidden)

/// Report an undefined function
#define UndefinedFunction() fprintf(stderr, "CocoaGlk: " __FILE__ " %i: Function not defined\n", __LINE__);

// Log simple debug messages
#ifdef COCOAGLK_DEBUG
# define DebugLog(x) NSLog(x)
#else
# define DebugLog(x)
#endif

#pragma mark - Functions

/// True if \c winid_t is probably a real window identifier
extern BOOL cocoaglk_winid_sane(winid_t win);
/// Turn an internal window identifier into a real winid
extern winid_t cocoaglk_winid_get(unsigned identifier);

/// \c YES if \c strid_t is probably a real stream identifier, \c NO otherwise
extern BOOL cocoaglk_strid_sane(strid_t stream);
/// Creates a non-functioning, empty stream
extern strid_t cocoaglk_stream(void);

/// \c YES if \c frefid_t is probably a real fref
extern BOOL cocoaglk_frefid_sane(frefid_t ref);

/// \c YES if the stream is writable
extern BOOL cocoaglk_strid_write(strid_t str);
/// \c YES if the stream is readable
extern BOOL cocoaglk_strid_read(strid_t str);
/// Ensures that the stream has a valid GlkStream object available
extern void cocoaglk_loadstream(strid_t stream);
/// Flushes the buffer for a stream
extern void cocoaglk_flushstream(strid_t stream, const char* reason);
/// Flushes the buffer for a stream, but only if necessary
extern void cocoaglk_maybeflushstream(strid_t stream, const char* reason);

/// Unregisters any line input buffers associated with the window
extern void cocoaglk_unregister_line_buffers(winid_t win);

extern frefid_t cocoaglk_open_file(NSURL *path, glui32 textmode, glui32 rock);

#pragma mark - Variables

/// The running session
extern id<GlkSession>			cocoaglk_session;
/// The hub session dispatcher object
extern id<GlkHub>				cocoaglk_hub;

/// The shared buffer object
extern GlkBuffer*				cocoaglk_buffer;
#if !__has_feature(objc_arc)
/// The interpreter thread autorelease pool
extern NSAutoreleasePool*		cocoaglk_pool;
#endif

/// The 'first stream' (typically containing the game to run)
extern strid_t					cocoaglk_firststream;

extern gidispatch_rock_t (*cocoaglk_register)(void *obj, glui32 objclass);
extern void (*cocoaglk_unregister)(void *obj, glui32 objclass, gidispatch_rock_t objrock);

extern void (*cocoaglk_interrupt)(void);

extern int cocoaglk_loopIteration;

extern strid_t cocoaglk_currentstream;
extern strid_t cocoaglk_firststream;
extern unsigned cocoaglk_maxstreamid;

extern gidispatch_rock_t (*cocoaglk_register_memory)(void *array, glui32 len, char *typecode);
extern void (*cocoaglk_unregister_memory)(void *array, glui32 len, char *typecode, gidispatch_rock_t objrock);

#pragma GCC visibility pop

#pragma mark - The structures

/// Windows
///
/// We cache the window details locally so we can avoid going to the server every time (maximising the use of the buffer)
struct glk_window_struct {
#define GlkWindowKey 'WIND'
	/// Used while sanity checking
	unsigned int key;
	
	/// The unique window identifier (used to identify this window to the server and in the buffer)
	unsigned int identifier;
	/// The window rock
	glui32 rock;
	
	/// The stream for this window
	strid_t stream;
	
	/// The method by which this window is split
	glui32 method;
	/// The size of this window
	glui32 size;
	/// The type of this window
	glui32 wintype;
	
	/// The parent for this window (NULL if this is the root window)
	winid_t parent;
	/// The 'key' window (if this is a pair window)
	winid_t keyId;
	/// The 'left' child window (if this is a pair window)
	winid_t left;
	/// The 'right' child window (if this is a pair window)
	winid_t right;
	
	/// YES only if the window is closing
	BOOL closing;
	
	/// Annoying \c gi_dispa rock
	gidispatch_rock_t giRock;
	
	/// True if the last input buffer request was for UCS-4 data
	BOOL    ucs4;
	/// The input buffer for line input events
	char*   inputBuf;
	/// The input buffer for UCS-4 line input events
	glui32* inputBufUcs4;
	/// The length of the input buffer
	int     bufLen;

	/// Set to true if this window has registered buffers
	BOOL registered;
	/// The rock for the input buffer (if non-NULL)
	gidispatch_rock_t bufRock;
	/// The rock for the UCS-4 input buffer (if non-NULL)
	gidispatch_rock_t bufUcs4Rock;
	
	/// Iteration through the event loop (used to guard against using old values for sizes, etc)
	int loopIteration;
	
	/// Most recent width (only valid while loopIteration is up to date)
	int width;
	/// Most recent heighht (only valid while loopIteration is up to date)
	int height;
	
	/// The window background colour
	glui32 background;
};

/// Streams
///
/// Streams are a pain in the neck, as we have server-side streams (windows and sometimes files) and client-side streams
/// (memory streams and sometimes files again).
///
/// Streams may have their own buffer, use the shared buffer or be unbuffered. Streams that are on the server should
/// pretty much always be buffered, as communications are often slow.
///
/// Window streams might not immediately have a GlkStream object available (as this won't get created until the window
/// is actually created later on).
struct glk_stream_struct {
#define GlkStreamKey 'STRM'
#define GlkStreamNullIdentifier 0xffffffff
	/// Used while sanity checking
	unsigned int key;
	
	/// The unique stream identifier (used to identify this stream in the buffer)
	unsigned int identifier;
	/// The stream rock
	glui32 rock;
	
	/// The mode to open the stream in
	glui32 fmode;
	
	/// Whether or not to buffer output to this stream
	BOOL buffered;
	/// Whether or not to flush this stream's buffer 'lazily'
	BOOL lazyFlush;
	/// The stream buffer to use (nil to use the standard buffer)
	__strong GlkBuffer* streamBuffer;
	/// Amount of stuff buffered (flushes when this gets too large)
	int bufferedAmount;
	
	/// The actual stream object
	__strong id<GlkStream> stream;
	/// The amount written to the stream object (not necessarily accurate, depending on how the stream object really responds to writes)
	unsigned written;
	/// The amount read from the stream object
	unsigned read;
	
	/// YES if this stream belongs to a window
	BOOL windowStream;
	/// The identifier of the window this stream belongs to
	unsigned int windowIdentifier;
	
	/// The active style for this stream
	glui32 style;
	
	/// The echo stream for this stream
	strid_t echo;
	/// The list of streams that this stream is echoing to
	__strong NSMutableArray* echoesTo;
	
	/// Annoying gi_dispa rock
	gidispatch_rock_t giRock;
	
	/// The next stream in the list
	strid_t next;
	/// The previous stream in the list
	strid_t last;
};

/// Filerefs
///
/// The user interface task is the ultimate arbiter of what a fileref can and cannot be.
/// 'Named' filerefs are probably a bad idea in general, and 'temp' filerefs are just annoying.
struct glk_fileref_struct {
#define GlkFileRefKey 'FIRF'
	/// Used while sanity fleeble blurgle blorp
	unsigned int key;
	
	/// The fileref rock
	glui32 rock;
	/// The usage specified for this fileref when it was created
	glui32 usage;
	
	/// The actual fileref object
	__strong id<GlkFileRef> fileref;
	
	/// Annoying gi_dispa rock
	gidispatch_rock_t giRock;
	
	/// The next fref in the list
	frefid_t next;
	/// The last fref in the list
	frefid_t last;
};

/// Images
///
/// This class is used for passing Blorb image information to the server process
@interface GlkBlorbImageSource : NSObject<GlkImageSource>

@end
