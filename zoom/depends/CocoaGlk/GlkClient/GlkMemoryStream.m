//
//  GlkMemoryStream.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 27/03/2005.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "GlkMemoryStream.h"

#include "glk.h"
#include "cocoaglk.h"
#include "glk_client.h"


@implementation GlkMemoryStream

// = Initialisation =

- (id) initWithMemory: (unsigned char*) mem
			   length: (int) len {
	self = [super init];
	
	if (self) {
		memory = mem;
		length = len;
		
		pointer = 0;
	}
	
	return self;
}

- (id) initWithMemory: (unsigned char*) mem
			   length: (int) len
				 type: (char*) glkType {
	self = [self initWithMemory: mem
						 length: len];
	
	if (self) {
		if (cocoaglk_register_memory) {
			type = glkType;
			rock = cocoaglk_register_memory(memory, strcmp(glkType, "&+#!Iu")==0?length/4:length, type);
		}
	}
	
	return self;
}

- (void) dealloc {
	[super dealloc];
}

// = The stream protocol =

// Control

- (void) closeStream {
	if (memory == nil) {
		// Already closed
		return;
	}
	
	if (type && cocoaglk_unregister_memory) {
		cocoaglk_unregister_memory(memory, strcmp(type, "&+#!Iu")==0?length/4:length, type, rock);
	}
	
	memory = nil;
}

- (void) setPosition: (in int) position
		  relativeTo: (in enum GlkSeekMode) seekMode {
	switch (seekMode) {
		case GlkSeekStart:
			pointer = position;
			break;
			
		case GlkSeekCurrent:
			pointer += position;
			break;
			
		case GlkSeekEnd:
			pointer = length + position;
			break;
	}
	
	if (pointer < 0) pointer = 0;
	if (pointer > length) pointer = length;
}

- (unsigned) getPosition {
	return pointer;
}

// Writing

- (void) putChar: (in unichar) ch {
	if (ch > 255) ch = '?';
	
	if (memory == nil) {
		NSLog(@"Warning: tried to write to a closed memory stream");
		return;
	}
	
	if (pointer >= length) return;			// Nothing to do
	
	memory[pointer++] = ch;
}

- (void) putString: (in bycopy NSString*) string {
	if (memory == nil) {
		NSLog(@"Warning: tried to write to a closed memory stream");
		return;
	}
	
	int len = [string length];
	char* latin1 = malloc(sizeof(char)*[string length]);

	int x;
	for (x=0; x<len; x++) {
		unichar ch = [string characterAtIndex: x];
		if (ch > 255) ch = '?';
		latin1[x] = ch;
	}
	
	NSData* latin1Data = [[NSData alloc] initWithBytesNoCopy: latin1
													  length: len
												freeWhenDone: YES];
	
	[self putBuffer: latin1Data];
	[latin1Data release];
}

- (void) putBuffer: (in bycopy NSData*) buffer {
	if (memory == nil) {
		NSLog(@"Warning: tried to write to a closed memory stream");
		return;
	}
	
	int bufLen = [buffer length];
	
	if (pointer + bufLen > length) {
		bufLen = length - pointer;
	}
	
	memcpy(memory + pointer, [buffer bytes], bufLen);
	pointer += bufLen;
}

// Reading

- (unichar) getChar {
	if (memory == nil) {
		NSLog(@"Warning: tried to read from a closed memory stream");
		return GlkEOFChar;
	}
	
	if (pointer >= length) return GlkEOFChar;
	
	return memory[pointer++];
}

- (bycopy NSString*) getLineWithLength: (int) maxLen {
	if (memory == nil) {
		NSLog(@"Warning: tried to read from a closed memory stream");
		return nil;
	}
	
	int start = pointer;
	
	if (pointer >= length) return nil;
	
	while (pointer < length && (pointer-start) < maxLen && memory[pointer++] != '\n');
	
	NSString* result = [[NSString alloc] initWithBytes: memory + start
												length: pointer-start 
											  encoding: NSISOLatin1StringEncoding];
	
	return [result autorelease];
}

- (bycopy NSData*) getBufferWithLength: (unsigned) bufLen {
	if (memory == nil) {
		NSLog(@"Warning: tried to read from a closed memory stream");
		return nil;
	}
	
	if (pointer >= length) return nil;
	
	if (pointer + bufLen > length) {
		bufLen = length - pointer;
	}

	NSData* result = [NSData dataWithBytes: memory + pointer
									length: bufLen];
	
	pointer += bufLen;
	
	return result;
}

// Styles

- (void) setStyle: (int) styleId {
	// Do nothing
}

- (int) style {
	// Style is always style_Normal
	return style_Normal;
}

- (void) setImmediateStyleHint: (unsigned) hint
					   toValue: (int) value {
	// Do nothing
}

- (void) clearImmediateStyleHint: (unsigned) hint {
	// Do nothing
}

- (void) setCustomAttributes: (NSDictionary*) customAttributes {
	// Do nothing
}

// Hyperlinks

- (void) setHyperlink: (unsigned int) value {
}

- (void) clearHyperlink {
}

@end
