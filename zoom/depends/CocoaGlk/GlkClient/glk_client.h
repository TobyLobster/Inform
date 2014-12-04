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

// Report an undefined function
#define UndefinedFunction() fprintf(stderr, "CocoaGlk: " __FILE__ " %i: Function not defined\n", __LINE__);

// Log simple debug messages
#ifdef COCOAGLK_DEBUG
# define DebugLog(x) NSLog(x)
#else
# define DebugLog(x)
#endif

// = Functions =

extern BOOL cocoaglk_winid_sane(winid_t win);			// True if winid_t is probably a real window identifier
extern winid_t cocoaglk_winid_get(unsigned identifier);	// Turn an internal window identifier into a real winid

extern BOOL cocoaglk_strid_sane(strid_t stream);		// YES if strid_t is probably a real stream identifier, NO otherwise
extern strid_t cocoaglk_stream(void);					// Creates a non-functioning, empty stream

extern BOOL cocoaglk_frefid_sane(frefid_t ref);			// YES if frefid_t is probably a real fref

extern BOOL cocoaglk_strid_write(strid_t str);			// YES if the stream is writable
extern BOOL cocoaglk_strid_read(strid_t str);			// YES if the stream is readable
extern void cocoaglk_loadstream(strid_t stream);		// Ensures that the stream has a valid GlkStream object available
extern void cocoaglk_flushstream(strid_t stream, const char* reason);		// Flushes the buffer for a stream
extern void cocoaglk_maybeflushstream(strid_t stream, const char* reason);	// Flushes the buffer for a stream, but only if necessary

extern void cocoaglk_unregister_line_buffers(winid_t win);	// Unregisters any line input buffers associated with the window

// = Variables =

extern NSObject<GlkSession>*	cocoaglk_session;		// The running session
extern NSObject<GlkHub>*		cocoaglk_hub;			// The hub session dispatcher object

extern GlkBuffer*				cocoaglk_buffer;		// The shared buffer object
extern NSAutoreleasePool*		cocoaglk_pool;			// The interpreter thread autorelease pool

extern strid_t					cocoaglk_firststream;	// The 'first stream' (typically containing the game to run)

extern gidispatch_rock_t (*cocoaglk_register)(void *obj, glui32 objclass);
extern void (*cocoaglk_unregister)(void *obj, glui32 objclass, gidispatch_rock_t objrock);

extern void (*cocoaglk_interrupt)(void);

extern int cocoaglk_loopIteration;

extern strid_t cocoaglk_currentstream;
extern strid_t cocoaglk_firststream;
extern unsigned cocoaglk_maxstreamid;

extern gidispatch_rock_t (*cocoaglk_register_memory)(void *array, glui32 len, char *typecode);
extern void (*cocoaglk_unregister_memory)(void *array, glui32 len, char *typecode, gidispatch_rock_t objrock);

// = The structures =

// Windows
//
// We cache the window details locally so we can avoid going to the server every time (maximising the use of the buffer)

#define GlkWindowKey 'WIND'
struct glk_window_struct {
	unsigned int key;					// Used while sanity checking
	
	unsigned int identifier;			// The unique window identifier (used to identify this window to the server and in the buffer)
	glui32 rock;						// The window rock
	
	strid_t stream;						// The stream for this window
	
	glui32 method;						// The method by which this window is split
	glui32 size;						// The size of this window
	glui32 wintype;						// The type of this window
	
	winid_t parent;						// The parent for this window (NULL if this is the root window)
	winid_t keyId;						// The 'key' window (if this is a pair window)
	winid_t left;						// The 'left' child window (if this is a pair window)
	winid_t right;						// The 'right' child window (if this is a pair window)
	
	BOOL closing;						// YES only if the window is closing
	
	gidispatch_rock_t giRock;			// Annoying gi_dispa rock
	
	BOOL    ucs4;						// True if the last input buffer request was for UCS-4 data
	char*   inputBuf;					// The input buffer for line input events
	glui32* inputBufUcs4;				// The input buffer for UCS-4 line input events
	int     bufLen;						// The length of the input buffer

	BOOL registered;					// Set to true if this window has registered buffers
	gidispatch_rock_t bufRock;			// The rock for the input buffer (if non-NULL)
	gidispatch_rock_t bufUcs4Rock;		// The rock for the UCS-4 input buffer (if non-NULL)
	
	int loopIteration;					// Iteration through the event loop (used to guard against using old values for sizes, etc)
	
	int width;							// Most recent width (only valid while loopIteration is up to date)
	int height;							// Most recent heighht (only valid while loopIteration is up to date)
	
	glui32 background;					// The window background colour
};

// Streams
//
// Streams are a pain in the neck, as we have server-side streams (windows and sometimes files) and client-side streams
// (memory streams and sometimes files again).
//
// Streams may have their own buffer, use the shared buffer or be unbuffered. Streams that are on the server should
// pretty much always be buffered, as communications are often slow.
//
// Window streams might not immediately have a GlkStream object available (as this won't get created until the window
// is actually created later on).

#define GlkStreamKey 'STRM'
#define GlkStreamNullIdentifier 0xffffffff
struct glk_stream_struct {
	unsigned int key;					// Used while sanity checking
	
	unsigned int identifier;			// The unique stream identifier (used to identify this stream in the buffer)
	glui32 rock;						// The stream rock
	
	glui32 fmode;						// The mode to open the stream in
	
	BOOL buffered;						// Whether or not to buffer output to this stream
	BOOL lazyFlush;						// Whether or not to flush this stream's buffer 'lazily'
	GlkBuffer* streamBuffer;			// The stream buffer to use (nil to use the standard buffer)
	int bufferedAmount;					// Amount of stuff buffered (flushes when this gets too large)
	
	NSObject<GlkStream>* stream;		// The actual stream object
	unsigned written;					// The amount written to the stream object (not necessarily accurate, depending on how the stream object really responds to writes)
	unsigned read;						// The amount read from the stream object
	
	BOOL windowStream;					// YES if this stream belongs to a window
	unsigned int windowIdentifier;		// The identifier of the window this stream belongs to
		
	glui32 style;						// The active style for this stream
	
	strid_t echo;						// The echo stream for this stream
	NSMutableArray* echoesTo;			// The list of streams that this stream is echoing to
	
	gidispatch_rock_t giRock;			// Annoying gi_dispa rock
	
	strid_t next;						// The next stream in the list
	strid_t last;						// The previous stream in the list
};

// Filerefs
//
// The user interface task is the ultimate arbiter of what a fileref can and cannot be.
// 'Named' filerefs are probably a bad idea in general, and 'temp' filerefs are just annoying.

#define GlkFileRefKey 'FIRF'

struct glk_fileref_struct {
	unsigned int key;					// Used while sanity fleeble blurgle blorp
	
	glui32 rock;						// The fileref rock
	glui32 usage;						// The usage specified for this fileref when it was created
	
	NSObject<GlkFileRef>* fileref;		// The actual fileref object
	
	gidispatch_rock_t giRock;			// Annoying gi_dispa rock
	
	frefid_t next;						// The next fref in the list
	frefid_t last;						// The last fref in the list
};

// Images
//
// This class is used for passing Blorb image information to the server process

@interface GlkBlorbImageSource : NSObject<GlkImageSource> {
}

@end
