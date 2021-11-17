//
//  GlkUcs4Stream.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 19/08/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import "GlkUcs4Stream.h"

#include "glk.h"
#import "cocoaglk.h"
#import "glk_client.h"

@implementation GlkUcs4Stream

- (id) initWithStream: (id<GlkStream>) stream
			bigEndian: (BOOL) isBigEndian {
	self = [super init];
	
	if (self) {
		dataStream = [stream retain];
		bigEndian = isBigEndian;
	}
	
	return self;
}

- (void) dealloc {
	[dataStream release];
	[super dealloc];
}

// Control
- (void) closeStream {
	[dataStream closeStream];
}

- (void) setPosition: (in NSInteger) position
		  relativeTo: (in GlkSeekMode) seekMode {
	[dataStream setPosition: position
				 relativeTo: seekMode];
}

- (unsigned long long) getPosition {
	return [dataStream getPosition];
}

// Writing

- (void) putChar: (in unichar) ch {
	[self putString: [NSString stringWithCharacters: &ch
											 length: 1]];
}

- (void) putString: (in bycopy NSString*) string {
	NSStringEncoding encoding;
	if (bigEndian) {
		encoding = NSUTF32BigEndianStringEncoding;
	} else {
		encoding = NSUTF32LittleEndianStringEncoding;
	}
	NSData *strData = [string dataUsingEncoding:encoding];
	if (strData) {
		// TODO: test if this adds a BOM to the data. We might not want that...
		[self putBuffer:strData];
		return;
	}
	NSInteger len = [string length]*2;
	glui32 buf[len];
	
	len = cocoaglk_copy_string_to_uni_buf(string, buf, (glui32)len);
	
	// Convert to a big-endian buffer
	NSMutableData* data = [NSMutableData dataWithLength: len*4];
	unsigned char* bytes = [data mutableBytes];
	int x, pos;
	
	if (bigEndian) {
		pos = 0;
		for (x=0; x<len; x++) {
			bytes[pos++] = (buf[x]>>24)&0xff;
			bytes[pos++] = (buf[x]>>16)&0xff;
			bytes[pos++] = (buf[x]>>8)&0xff;
			bytes[pos++] = (buf[x]>>0)&0xff;
		}
	} else {
		pos = 0;
		for (x=0; x<len; x++) {
			bytes[pos++] = (buf[x]>>0)&0xff;
			bytes[pos++] = (buf[x]>>8)&0xff;
			bytes[pos++] = (buf[x]>>16)&0xff;
			bytes[pos++] = (buf[x]>>24)&0xff;
		}		
	}
		
	[self putBuffer: data];
}

- (void) putBuffer: (in bycopy NSData*) buffer {
	[dataStream putBuffer: buffer];
}

// Reading

- (unichar) getChar {
	NSData* charData = [self getBufferWithLength: 4];
	if ([charData length] != 4) return GlkEOFChar;
	
	const unsigned char* ucs4 = [charData bytes];
	
	glui32 res = (ucs4[0]<<24)|(ucs4[1]<<16)|(ucs4[2]<<8)|(ucs4[3]<<0);
	
	if (res < 0xffff) 
		return res;
	else
		return '?';
}

- (bycopy NSString*) getLineWithLength: (NSInteger) maxLen {
	glui32* line = NULL;
	int lineLength = 0;
	int lineAllocated = 0;
	
	for (;;) {
		// Read the next character
		NSData* charData = [self getBufferWithLength: 4];
		if ([charData length] != 4) break;
		
		// Append to the result
		if (lineLength+1 > lineAllocated) {
			lineAllocated = lineLength + 256;
			line = realloc(line, sizeof(glui32)*lineAllocated);
		}
		
		const unsigned char* ucs4 = [charData bytes];
		line[lineLength++] = (ucs4[0]<<24)|(ucs4[1]<<16)|(ucs4[2]<<8)|(ucs4[3]<<0);
		
		// Check if it is a \n or a \r
		if (ucs4[0] == 0 && ucs4[1] == 0 && ucs4[2] == 0 && (ucs4[3] == '\n' || ucs4[3] == '\r')) {
			break;
		}
	}
	
	// Convert to a NSString
	NSString* res = [[[NSString alloc] initWithBytes:line length:lineLength*4 encoding:NSUTF32LittleEndianStringEncoding] autorelease];
	
	if (!res) {
		// Convert to a NSString
		res = cocoaglk_string_from_uni_buf(line, lineLength);
	}
	
	free(line);
	return res;
}

- (bycopy NSData*) getBufferWithLength: (NSUInteger) length {
	return [dataStream getBufferWithLength: length];
}

// Styles

- (void) setStyle: (int) styleId {
	[dataStream setStyle: styleId];
}

- (int) style {
	return [dataStream style];
}

- (void) setImmediateStyleHint: (unsigned) hint
					   toValue: (int) value {
	[dataStream setImmediateStyleHint: hint
							  toValue: value];
}

- (void) clearImmediateStyleHint: (unsigned) hint {
	[dataStream clearImmediateStyleHint: hint];
}

- (void) setCustomAttributes: (NSDictionary*) customAttributes {
	[dataStream setCustomAttributes: customAttributes];
}

// Hyperlinks

- (void) setHyperlink: (unsigned int) value {
	[dataStream setHyperlink: value];
}

- (void) clearHyperlink {
	[dataStream clearHyperlink];
}

@end
