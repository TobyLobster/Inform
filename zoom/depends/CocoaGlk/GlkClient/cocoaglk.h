//
//  cocoaglk.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 16/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

//
// Functions specific to the Cocoa GLK port
//

#ifndef __cocoaglk_h
#define __cocoaglk_h

#if defined(__OBJC__) && __OBJC__
# import <Foundation/Foundation.h>
#endif

#include <GlkView/glk.h>

#if defined(__OBJC__) && __OBJC__
# if __has_include (<GlkView/GlkImageSourceProtocol.h>)
#  import <GlkView/GlkImageSourceProtocol.h>
# else
@protocol GlkImageSource;
# endif
#endif

/// File that contains game executable data
#define fileusage_cocoaglk_GameFile 0x0f

/// File that contains game auxiliary data
#define fileusage_cocoaglk_GameData 0x0e

/// Sets up the connection to the server. Call this then glk_main().
extern void cocoaglk_start(int argv, const char** argc);

/// Flushes the cocoaglk buffer
extern void cocoaglk_flushbuffer(const char* reason);

/// Reports a warning to the server
extern void cocoaglk_warning(const char* warningText);

/// Reports an error to the server, then quits
extern void cocoaglk_error(const char* errorText);

/// Request to send a message to the game's log (if the runner supports it)
extern void cocoaglk_log(const char* logText);

/// Request to send a message to the game's log with a priority (0, 1 or 2)
extern void cocoaglk_log_ex(const char* logText, int priority);

#if defined(__OBJC__) && __OBJC__
/// Sets the extensions to use for a specific file usage
extern void cocoaglk_set_types_for_usage(glui32 usage, NSArray<NSString*>* extensions);

/// Retrieves a list of valid file types for a given usage
extern NSArray<NSString*>* cocoaglk_types_for_usage(glui32 usage);
#endif

/// Gets the input stream provided by the server (or \c NULL if none was provided)
extern strid_t cocoaglk_get_input_stream(void);

/// Gets a stream provided by the client with the specified key
extern strid_t cocoaglk_get_stream_for_key(const char* key);

#if defined(__OBJC__) && __OBJC__
/// Sets a new image source object
extern void cocoaglk_set_image_source(id<GlkImageSource> imageSource);

/// Turns a UCS-4 string into a UTF-16 cocoa string
extern NSString* cocoaglk_string_from_uni_buf(const glui32* buf, glui32 len);

/// Turns an NSString into a UCS-4 string
extern int cocoaglk_copy_string_to_uni_buf(NSString* string, glui32* buf, glui32 len);
#endif

/// Unbinds a known filename
extern void cocoaglk_unbind_file(const char* filename);

/// Binds a filename to a specified block of memory (it will become a read-only memory file)
extern void cocoaglk_bind_memory_to_named_file(const unsigned char* memory, int length, const char* filename);

/// Causes CocoaGlk to set a style hint immediately in the specified stream
extern void cocoaglk_set_immediate_style_hint(strid_t str, glui32 hint, glsi32 value);

/// Causes CocoaGlk to clear a style hint immediately in the specified stream
extern void cocoaglk_clear_immediate_style_hint(strid_t str, glui32 hint);

#if defined(__OBJC__) && __OBJC__

/// Sets a set of Cocoa text attributes to merge with those set by the current style. Set this to nil to indicate that only the current style should be used.
extern void cocoaglk_set_custom_text_attributes(strid_t str, NSDictionary<NSAttributedStringKey,id>* attributes);

#endif

#endif
