//
//  glk_unicode.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 19/08/2006.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "glk.h"
#import "cocoaglk.h"
#import "glk_client.h"

#import "GlkUcs4Stream.h"

NSString* cocoaglk_string_from_uni_buf(const glui32* buf, glui32 len) {
	// Convert these character to UTF-16
	
	// Try using Cocoa's built-in UTF32 converter first.
	NSString *theStr = [[NSString alloc] initWithBytes:buf length:len * 4 encoding:NSUTF32LittleEndianStringEncoding];
	if (theStr) {
		return theStr;
	}

	// buf has a maximum length of twice as long as length
	unichar uniBuf[len*2+1];
	int uniLen = 0;
	
	// Run through the string...
	int pos;
	for (pos = 0; pos<len; pos++) {
		glui32 chr = buf[pos];
		
		if (chr >= 0xd800 && chr <= 0xdfff) {
			// These UCS-4 characters have no valid Unicode equivalent
			chr = 0xfffd;
		}
		
		if (chr <= 0xffff) {
			// This is a UCS-2 character
			uniBuf[uniLen++] = chr;
		} else if (chr <= 0x10ffff) {
			// This is a character that can be represented by a surrogate pair
			// 000uuuuuxxxxxxxxxxxxxxxx -> 110110wwwwxxxxxx 110111xxxxxxxxxx (wwww = uuuuu-1)
			int w = (chr>>16)-1;
			int x = (chr&0xffff);
			
			uniBuf[uniLen++] = 0xd800|(w<<6)|(x>>10);
			uniBuf[uniLen++] = 0xdc00|(x&0x3ff);
		} else {
			// This is a UCS-4 character outside the range of allowed unicode values
			uniBuf[uniLen++] = 0xfffd;
		}
	}
	
	// Return the result
	return [NSString stringWithCharacters: uniBuf
								   length: uniLen];
}

int cocoaglk_copy_string_to_uni_buf(NSString* string, glui32* buf, glui32 len) {
	// Try using Cocoa's built-in UTF32 converter first.
	NSData *ucs4Data = [string dataUsingEncoding:NSUTF32LittleEndianStringEncoding];
	if (ucs4Data) {
		// TODO: test if this adds a BOM to the data. We might not want that...
		NSInteger copyLen = ucs4Data.length;
		if (copyLen > len * 4) {
			copyLen = len * 4;
		}
		memcpy(buf, ucs4Data.bytes, copyLen);
		return (int)(ucs4Data.length / 4);
	}
	// Fetch the string into a UTF-16 buffer
	NSInteger stringLength = [string length];
	unichar characters[stringLength];
	
	[string getCharacters: characters];
	
	// Convert as much as possible to UCS-4
	NSInteger finalLength = 0;
	NSInteger pos;
	
	for (pos = 0; pos<stringLength; pos++) {
		// Retrieve this character
		glui32 chr = characters[pos];
		
		if (chr >= 0xd800 && chr <= 0xdbff && pos+1 < stringLength && characters[pos+1] >= 0xdc00 && characters[pos+1] <= 0xdfff) {
			// This is the first character of a surrogate pair
			int high = characters[++pos];
			
			int w = (chr&~0xd800)>>6;
			int x = ((chr&0x3f)<<10)|(high&~0xdc00);
			int u = w+1;
			
			chr = (u<<16)|x;
		} else if (chr >= 0xd800 && chr <= 0xdfff) {
			// This is a lone surrogate character (can't be translated)
			chr = 0xfffd;
		}
		
		// Add this character to the result
		if (finalLength < len) {
			buf[finalLength] = chr;
		}
		
		// Increase the length of the result
		finalLength++;
	}
	
	return (int)finalLength;
}

//
// These functions provide two length arguments because a string of Unicode 
// characters may expand when its case changes. The len argument is the 
// available length of the buffer; numchars is the number of characters in the 
// buffer initially. (So numchars must be less than or equal to len. The 
// contents of the buffer after numchars do not affect the operation.) 
// 
// The functions return the number of characters after conversion. If this is 
// greater than len, the characters in the array will be safely truncated at 
// len, but the true count will be returned. (The contents of the buffer after 
// the returned count are undefined.)
//
// The lower_case and upper_case functions do what you'd expect: they convert 
// every character in the buffer (the first numchars of them) to its upper or 
// lower-case equivalent, if there is such a thing. 
//
glui32 glk_buffer_to_lower_case_uni(glui32 *buf, glui32 len,
									glui32 numchars) {
	return cocoaglk_copy_string_to_uni_buf([cocoaglk_string_from_uni_buf(buf, numchars) lowercaseString],
										   buf, len);
}

//
// These functions provide two length arguments because a string of Unicode 
// characters may expand when its case changes. The len argument is the 
// available length of the buffer; numchars is the number of characters in the 
// buffer initially. (So numchars must be less than or equal to len. The 
// contents of the buffer after numchars do not affect the operation.) 
// 
// The functions return the number of characters after conversion. If this is 
// greater than len, the characters in the array will be safely truncated at 
// len, but the true count will be returned. (The contents of the buffer after 
// the returned count are undefined.)
//
// The lower_case and upper_case functions do what you'd expect: they convert 
// every character in the buffer (the first numchars of them) to its upper or 
// lower-case equivalent, if there is such a thing. 
//
glui32 glk_buffer_to_upper_case_uni(glui32 *buf, glui32 len,
									glui32 numchars) {
	return cocoaglk_copy_string_to_uni_buf([cocoaglk_string_from_uni_buf(buf, numchars) uppercaseString],
										   buf, len);
}

//
// The title_case function has an additional (boolean) flag. Its basic 
// function is to change the first character of the buffer to upper-case, and 
// leave the rest of the buffer unchanged. If lowerrest is true, it changes 
// all the non-first characters to lower-case (instead of leaving them alone.)
//
glui32 glk_buffer_to_title_case_uni(glui32 *buf, glui32 len,
									glui32 numchars, glui32 lowerrest) {
	if (lowerrest) {
		// If this flag is on, then use the standard capitalisation routine
		return cocoaglk_copy_string_to_uni_buf([cocoaglk_string_from_uni_buf(buf, numchars) capitalizedString],
											   buf, len);
	} else {
		int finalLength;
		@autoreleasepool {
			// If the flag is off, then only capitalise characters that come after whitespace
			NSCharacterSet* whitespace = [NSCharacterSet whitespaceCharacterSet];
			NSScanner* stringScanner = [[NSScanner alloc] initWithString: cocoaglk_string_from_uni_buf(buf, numchars)];
			NSMutableString* result = [NSMutableString string];
			
			[stringScanner setCharactersToBeSkipped: [NSCharacterSet characterSetWithCharactersInString: @""]];
			
			NSString* lastWord;
			NSString* lastWhitespace;
			
			// Scan the string
			while (![stringScanner isAtEnd]) {
				// Scan any whitespace at the start of the string
				[stringScanner scanCharactersFromSet: whitespace
										  intoString: &lastWhitespace];
				
				[result appendString: lastWhitespace];
				
				// Give up if there's nothing following the whitespace
				if ([stringScanner isAtEnd]) break;
				
				// Get the next word
				[stringScanner scanUpToCharactersFromSet: whitespace
											  intoString: &lastWord];
				
				// Capitalize the last word
				NSString* capitalized = [lastWord capitalizedString];
				
				// Join the capitalized letter from the last word with whatever was in the original word
				if ([lastWord length] > 0 && [capitalized length] > 0) {
					lastWord = [[capitalized substringToIndex: 1] stringByAppendingString: [lastWord substringFromIndex: 1]];
				}
				
				// Append to the result
				[result appendString: lastWord];
			}
			
			// Copy the buffer
			finalLength = cocoaglk_copy_string_to_uni_buf(result, buf, len);
		}
		// Return
		return finalLength;
	}
}

// These just use the current buffer and call the various put_*_stream_uni functions instead
void glk_put_char_uni(glui32 ch) {
	glk_put_char_stream_uni(cocoaglk_currentstream, ch);
}

void glk_put_string_uni(glui32 *s) {
	glk_put_string_stream_uni(cocoaglk_currentstream, s);
}

void glk_put_buffer_uni(glui32 *buf, glui32 len) {
	glk_put_buffer_stream_uni(cocoaglk_currentstream, buf, len);
}

// Unicode equivalents of the put_foo range of functions
void glk_put_char_stream_uni(strid_t str, glui32 ch) {
	// Sanity checking
	if (!cocoaglk_strid_sane(str)) {
		cocoaglk_error("glk_put_char_stream_uni called with a bad stream");
	}
	
	if (!cocoaglk_strid_write(str)) {
		cocoaglk_error("glk_put_char_stream_uni called on a read-only stream");
	}
	
	GlkBuffer* buf = nil;
	
	if (str->echo) {
		// Echo this character
		glk_put_char_stream_uni(str->echo, ch);
	}
	
	if (str->buffered) {
		// Get the buffer
		buf = str->streamBuffer;
		if (buf == nil) {
			buf = cocoaglk_buffer;
		}
	}
	
	if (buf) {
		// Write using the buffer
		if (ch < 0x10000) {
			[buf putChar: ch
				toStream: str->identifier];
		} else if (ch <= 0x10ffff) {
			// This is a character that can be represented by a surrogate pair
			// 000uuuuuxxxxxxxxxxxxxxxx -> 110110wwwwxxxxxx 110111xxxxxxxxxx (wwww = uuuuu-1)
			int w = (ch>>16)-1;
			int x = (ch&0xffff);
			
			unichar chr = 0xd800|(w<<6)|(x>>10);
			[buf putChar: chr
				toStream: str->identifier];
			str->bufferedAmount++;
			chr = 0xdc00|(x&0x3ff);
			[buf putChar: chr
				toStream: str->identifier];
		} else {
			// *shrug*
			[buf putChar: ch
				toStream: str->identifier];
		}
		
		str->bufferedAmount++;
	} else {
		// Write direct
		cocoaglk_loadstream(str);
		
		if (ch < 0x10000) {
			[str->stream putChar: ch];
		} else if (ch <= 0x10ffff) {
			// This is a character that can be represented by a surrogate pair
			// 000uuuuuxxxxxxxxxxxxxxxx -> 110110wwwwxxxxxx 110111xxxxxxxxxx (wwww = uuuuu-1)
			int w = (ch>>16)-1;
			int x = (ch&0xffff);
			
			unichar chr = 0xd800|(w<<6)|(x>>10);
			[str->stream putChar: chr];
			chr = 0xdc00|(x&0x3ff);
			[str->stream putChar: chr];
		} else {
			// *shrug*
			[str->stream putChar: ch];
		}
	}
	
	str->written++;
	
	cocoaglk_maybeflushstream(str, "Writing a unicode character");
}

void glk_put_string_stream_uni(strid_t str, glui32 *s) {
	// Sanity checking
	if (s == NULL) {
		cocoaglk_error("glk_put_string_stream_uni called will a null string");
	}
	
	int len;
	
	for (len=0; s[len] != 0; len++);
	
	glk_put_buffer_stream_uni(str, s, len);
}

void glk_put_buffer_stream_uni(strid_t str, glui32 *buffer, glui32 len) {
	// Sanity checking
	if (!cocoaglk_strid_sane(str)) {
		cocoaglk_error("glk_put_buffer_stream_uni called with a bad stream");
	}
	
	if (!cocoaglk_strid_write(str)) {
		cocoaglk_error("glk_put_buffer_stream_uni called on a read-only stream");
	}
	
	if (buffer == NULL) {
		cocoaglk_error("glk_put_buffer_stream_uni called will a null buffer");
	}
	
	GlkBuffer* buf = nil;
	NSString* string = cocoaglk_string_from_uni_buf(buffer, len);
	
	if (str->echo) {
		// Echo this buffer
		glk_put_buffer_stream_uni(str->echo, buffer, len);
	}
	
	if (str->buffered) {
		// Get the buffer
		buf = str->streamBuffer;
		if (buf == nil) {
			buf = cocoaglk_buffer;
		}
	}
	
	if (buf) {
		// Write using the buffer
		[buf putString: string
			  toStream: str->identifier];
		
		str->bufferedAmount += [string length];
	} else {
		// Write direct
		cocoaglk_loadstream(str);
		
		[str->stream putString: string];
	}
	
	str->written += [string length];
	
	cocoaglk_maybeflushstream(str, "Writing a string");
}

glsi32 glk_get_char_stream_uni(strid_t str) {
	// Sanity checking
	if (!cocoaglk_strid_sane(str)) {
		cocoaglk_error("glk_get_char_stream called with an invalid strid");
	}
	
	if (!cocoaglk_strid_read(str)) {
		cocoaglk_error("glk_get_char_stream called with a strid that cannot be read from");
	}
	
	// First, flush the stream
	cocoaglk_flushstream(str, "Retrieving a character");
	
	// Next, use the stream object to get our result
	unichar res = [str->stream getChar];
	
#if COCOAGLK_TRACE > 1
	NSLog(@"TRACE: glk_get_char_stream(%p) = %i", str, res);
#endif
	
	if (res == GlkEOFChar) return -1;
	
	str->read++;
	return res;
}

glui32 glk_get_buffer_stream_uni(strid_t str, glui32 *buf, glui32 len) {
	// Sanity checking
	if (!cocoaglk_strid_sane(str)) {
		cocoaglk_error("glk_get_line_stream_uni called with an invalid strid");
	}
	
	if (!cocoaglk_strid_read(str)) {
		cocoaglk_error("glk_get_line_stream_uni called with a strid that cannot be read from");
	}
	
	if (buf == NULL) {
		cocoaglk_error("glk_get_line_stream_uni called with a NULL buffer");
	}
	
	// First, flush the stream
	cocoaglk_flushstream(str, "Retrieving a UCS-4 buffer");
	
	// Next, use the stream object to get our result (assumption: the stream is using UCS-4 encoding)
	NSData* data = [str->stream getBufferWithLength: len*4];
	
	// Decode the characters that have been read
	const unsigned char* bytes = [data bytes];
	NSInteger numChars = [data length]/4;
	NSInteger x;
	for (x=0; x<numChars; x++) {
		NSInteger pos = x*4;
		
		buf[x] = (bytes[pos+0]<<24)|(bytes[pos+1]<<16)|(bytes[pos+2]<<8)|(bytes[pos+3]<<0);
	}
	
	str->read += numChars;
	return (glui32)numChars;
}

glui32 glk_get_line_stream_uni(strid_t str, glui32 *buf, glui32 len) {
	// Sanity checking
	if (!cocoaglk_strid_sane(str)) {
		cocoaglk_error("glk_get_line_stream_uni called with an invalid strid");
	}
	
	if (!cocoaglk_strid_read(str)) {
		cocoaglk_error("glk_get_line_stream_uni called with a strid that cannot be read from");
	}
	
	if (buf == NULL) {
		cocoaglk_error("glk_get_line_stream_uni called with a NULL buffer");
	}
	
	// First, flush the stream
	cocoaglk_flushstream(str, "Retrieving a line of UCS-4 text");
	
	// Next, use the stream object to get our result
	NSString* line = [str->stream getLineWithLength: len-1];
	int readChars = cocoaglk_copy_string_to_uni_buf(line, buf, len);
	str->read += readChars;
	return readChars;
}

void glk_request_char_event_uni(winid_t win) {
	glk_request_char_event(win);
}

void glk_request_line_event_uni(winid_t win, glui32 *buf,
								glui32 maxlen, glui32 initlen) {
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
	
	// Deregister the previous buffer
	cocoaglk_unregister_line_buffers(win);
	
	// Set up the buffer
	win->ucs4         = YES;
	win->inputBufUcs4 = buf;
	win->bufLen       = maxlen;

	// Register it
	if (cocoaglk_register_memory && buf) {
		win->registered = YES;
		win->bufUcs4Rock = cocoaglk_register_memory(buf, maxlen, "&+#!Iu");
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
	}
	
	// Buffer up the request
	[cocoaglk_buffer requestLineEventsForWindowIdentifier: win->identifier];
}

glui32 glk_buffer_canon_decompose_uni(glui32 *buf, glui32 len,
									  glui32 numchars)
{
	@autoreleasepool {
		NSMutableString *str = [[NSMutableString alloc] initWithBytes:buf length:numchars*sizeof(glui32) encoding:NSUTF32LittleEndianStringEncoding];
		CFStringNormalize((CFMutableStringRef)str, kCFStringNormalizationFormD);
		NSData *strData = [str dataUsingEncoding:NSUTF32LittleEndianStringEncoding];
		
		[strData getBytes:buf length:MIN(len * sizeof(glui32), strData.length)];
		
		return (glui32)(strData.length/sizeof(glui32));
	}
}

glui32 glk_buffer_canon_normalize_uni(glui32 *buf, glui32 len,
									  glui32 numchars)
{
	@autoreleasepool {
		NSMutableString *str = [[NSMutableString alloc] initWithBytes:buf length:numchars*sizeof(glui32) encoding:NSUTF32LittleEndianStringEncoding];
		CFStringNormalize((CFMutableStringRef)str, kCFStringNormalizationFormC);
		NSData *strData = [str dataUsingEncoding:NSUTF32LittleEndianStringEncoding];
		
		[strData getBytes:buf length:MIN(len * sizeof(glui32), strData.length)];
		
		return (glui32)(strData.length/sizeof(glui32));
	}
}
