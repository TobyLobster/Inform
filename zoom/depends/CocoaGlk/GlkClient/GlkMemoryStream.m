//
//  GlkMemoryStream.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 27/03/2005.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "GlkMemoryStream.h"

#include "glk.h"
#import "cocoaglk.h"
#include "glk_client.h"


@implementation GlkMemoryStream

#pragma mark - Initialisation

- (id) initWithMemory: (unsigned char*) mem
			   length: (NSInteger) len {
	self = [super init];
	
	if (self) {
		memory = mem;
		length = len;
		
		pointer = 0;
	}
	
	return self;
}

- (id) initWithMemory: (unsigned char*) mem
			   length: (NSInteger) len
				 type: (char*) glkType {
	self = [self initWithMemory: mem
						 length: len];
	
	if (self) {
		if (cocoaglk_register_memory) {
			type = glkType;
			rock = cocoaglk_register_memory(memory, (glui32)(strcmp(glkType, "&+#!Iu")==0?length/4:length), type);
		}
	}
	
	return self;
}

- (void) dealloc {
	[super dealloc];
}

#pragma mark - The stream protocol

#pragma mark Control

- (void) closeStream {
	if (memory == nil) {
		// Already closed
		return;
	}
	
	if (type && cocoaglk_unregister_memory) {
		cocoaglk_unregister_memory(memory, (glui32)(strcmp(type, "&+#!Iu")==0?length/4:length), type, rock);
	}
	
	memory = nil;
}

- (void) setPosition: (in NSInteger) position
		  relativeTo: (in GlkSeekMode) seekMode {
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

- (unsigned long long) getPosition {
	return pointer;
}

#pragma mark Writing

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
	
	NSData* latin1Data = [string dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:YES];
	
	[self putBuffer: latin1Data];
}

- (void) putBuffer: (in bycopy NSData*) buffer {
	if (memory == nil) {
		NSLog(@"Warning: tried to write to a closed memory stream");
		return;
	}
	
	NSInteger bufLen = [buffer length];
	
	if (pointer + bufLen > length) {
		bufLen = length - pointer;
	}
	
	memcpy(memory + pointer, [buffer bytes], bufLen);
	pointer += bufLen;
}

#pragma mark Reading

- (unichar) getChar {
	if (memory == nil) {
		NSLog(@"Warning: tried to read from a closed memory stream");
		return GlkEOFChar;
	}
	
	if (pointer >= length) return GlkEOFChar;
	
	return memory[pointer++];
}

- (bycopy NSString*) getLineWithLength: (NSInteger) maxLen {
	if (memory == nil) {
		NSLog(@"Warning: tried to read from a closed memory stream");
		return nil;
	}
	
	NSInteger start = pointer;
	
	if (pointer >= length) return nil;
	
	while (pointer < length && (pointer-start) < maxLen && memory[pointer++] != '\n');
	
	NSString* result = [[NSString alloc] initWithBytes: memory + start
												length: pointer-start 
											  encoding: NSISOLatin1StringEncoding];
	
	return [result autorelease];
}

- (bycopy NSData*) getBufferWithLength: (NSUInteger) bufLen {
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

#pragma mark Styles

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

#pragma mark Hyperlinks

- (void) setHyperlink: (unsigned int) value {
}

- (void) clearHyperlink {
}

@end
