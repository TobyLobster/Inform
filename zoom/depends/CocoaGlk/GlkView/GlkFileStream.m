//
//  GlkFileStream.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 28/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "GlkFileStream.h"

#include "glk.h"


@implementation GlkFileStream

// = Initialisation =

- (id) initForReadWriteWithFilename: (NSString*) filename {
	self = [super init];
	
	if (self) {
		handle = [[NSFileHandle fileHandleForUpdatingAtPath: filename] retain];
		
		if (!handle) {
			if (![[NSFileManager defaultManager] createFileAtPath: filename
														 contents: [NSData data]
													   attributes: nil]) {
				[self release];
				return nil;
			}			

			handle = [[NSFileHandle fileHandleForUpdatingAtPath: filename] retain];
		}
		
		if (!handle) {
			[self release];
			return nil;
		}
	}
	
	return self;
}

- (id) initForWritingWithFilename: (NSString*) filename {
	self = [super init];
	
	if (self) {
		if (![[NSFileManager defaultManager] createFileAtPath: filename
													 contents: [NSData data]
												   attributes: nil]) {
			[self release];
			return nil;
		}
		
		handle = [[NSFileHandle fileHandleForWritingAtPath: filename] retain];
		
		if (!handle) {
			[self release];
			return nil;
		}
		
		[handle truncateFileAtOffset: 0];
	}
	
	return self;
}

- (id) initForReadingWithFilename: (NSString*) filename {
	self = [super init];
	
	if (self) {
		handle = [[NSFileHandle fileHandleForReadingAtPath: filename] retain];
		
		if (!handle) {
			[self release];
			return nil;
		}
	}
	
	return self;
}

- (void) dealloc {
	[handle release];
	
	[super dealloc];
}

// = GlkStream methods =

// Control

- (void) closeStream {
	[handle closeFile];
	[handle release];
	handle = nil;
}

- (void) setPosition: (in int) position
		  relativeTo: (in enum GlkSeekMode) seekMode {
	unsigned long long offset = [handle offsetInFile];
	
	switch (seekMode) {
		case GlkSeekStart:
			offset = position; 
			break;
			
		case GlkSeekCurrent:
			offset += position;
			break;
			
		case GlkSeekEnd:
			[handle seekToEndOfFile];
			offset = [handle offsetInFile];
			offset += position;
			break;
	}
	
	[handle seekToFileOffset: offset];
}

- (unsigned) getPosition {
	return (unsigned) [handle offsetInFile];
}

// Writing

- (void) putChar: (in unichar) ch {
	unsigned char data = ch;
	if (ch > 255) data = '?';
	
	[handle writeData: [NSData dataWithBytes: &data
									  length: 1]];
}

- (void) putString: (in bycopy NSString*) string {
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

	[handle writeData: latin1Data];
    [latin1Data release];
}

- (void) putBuffer: (in bycopy NSData*) buffer {
	[handle writeData: buffer];
}

// Reading

- (unichar) getChar {	
	NSData* data = [handle readDataOfLength: 1];
	
	if (data == nil || [data length] < 1) return GlkEOFChar;
	
	return ((unsigned char*)[data bytes])[0];
}

- (bycopy NSString*) getLineWithLength: (int) maxLen {
	NSMutableString* res = [NSMutableString string];
	
	unichar ch;
	int len = 0;
	do {
		ch = [self getChar];
		
		if (ch == GlkEOFChar) break;
		
		[res appendString: [NSString stringWithCharacters: &ch length: 1]];
		len++;
		if (len >= maxLen) {
			break;
		}
	} while (ch != '\n' && ch != GlkEOFChar);
	
	if (ch == GlkEOFChar && [res length] == 0) return nil;
	
	return res;
}

- (bycopy NSData*) getBufferWithLength: (unsigned) length {
	NSData* data = [handle readDataOfLength: length];
	
	if (data == nil || [data length] <= 0) return nil;
	
	return data;
}

// Styles

- (void) setStyle: (int) styleId {
	// Nothing to do
}

- (int) style {
	return style_Normal;
}

- (void) setImmediateStyleHint: (unsigned) hint
					   toValue: (int) value {
}

- (void) clearImmediateStyleHint: (unsigned) hint {
}

- (void) setCustomAttributes: (NSDictionary*) customAttributes {
}

// Hyperlinks

- (void) clearHyperlink {
}

- (void) setHyperlink: (unsigned int) value {
}

@end
