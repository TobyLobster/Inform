//
//  GlkBufferedStream.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 18/07/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "GlkBufferedStream.h"

#include "glk.h"

@implementation GlkBufferedStream

#pragma mark - Initialisation

- (id) initWithStream: (id<GlkStream>) newSourceStream {
	self = [super init];
	
	if (self) {
		sourceStream = [newSourceStream retain];
		
		readAhead = 65536;
		lowTide = 0;
		highTide = 0;
		eof = NO;
		
		buffer = malloc(sizeof(*buffer)*readAhead);
		bufferRemaining = readAhead;
	}
	
	return self;
}

- (void) dealloc {
	[sourceStream autorelease];
	free(buffer);
	
	[super dealloc];
}

#pragma mark - Buffering

- (void) setReadAhead: (int) newReadAhead {
	if (bufferRemaining == readAhead) {
		// Reallocate the buffer if it's empty
		readAhead = newReadAhead;
		buffer = realloc(buffer, sizeof(*buffer)*readAhead);
		lowTide = highTide = 0;
		bufferRemaining = readAhead;
	}
}

- (BOOL) fillBuffer {
	// Do nothing if the buffer is already full
	if ((readAhead-bufferRemaining) > (readAhead>>3)) return YES;
	if (eof) return NO;
	
	NSData* fillData = [sourceStream getBufferWithLength: bufferRemaining];
	if (fillData == nil || [fillData length] == 0) {
		eof = YES;
		return NO;
	}
	
	// Fill from high tide to the end of the buffer
	NSInteger remaining = [fillData length];
	NSInteger toCopy = remaining;
	
	if (highTide + toCopy >= readAhead) toCopy = readAhead-highTide;
	
	if (toCopy > 0) {
		[fillData getBytes: buffer + highTide
					 range: NSMakeRange(0, toCopy)];
		highTide += toCopy;
		bufferRemaining -= toCopy;
		remaining -= toCopy;
		if (highTide >= readAhead) highTide = 0;
	}
	
	// Fill from the beginning of the buffer to the end of the bytes we read
	if (remaining > 0) {
		[fillData getBytes: buffer
					 range: NSMakeRange(toCopy, remaining)];
		highTide += remaining;
		bufferRemaining -= remaining;
		remaining -= remaining;
	}

	return YES;
}

#pragma mark - GlkStream implementation

// Control

- (void) closeStream {
	[sourceStream closeStream];

	eof = YES;
	lowTide = highTide = 0;
	bufferRemaining = readAhead;
}

- (void) setPosition: (in NSInteger) position
		  relativeTo: (in GlkSeekMode) seekMode {
	// Work out the target position
	if (seekMode == GlkSeekCurrent) {
		position -= (readAhead-bufferRemaining);
	}
	
	// Clear the buffer
	lowTide = highTide = 0;
	bufferRemaining = readAhead;
	eof = NO;
	
	// Seek in the source stream
	[sourceStream setPosition: position
				   relativeTo: seekMode];
	
	// Fill the buffer again
	[self fillBuffer];
}

- (unsigned long long) getPosition {
	return [sourceStream getPosition] - (readAhead-bufferRemaining);
}

// Writing

- (void) putChar: (in unichar) ch {
	// Writing not supported
}

- (void) putString: (in bycopy NSString*) string {
	// Writing not supported
}

- (void) putBuffer: (in bycopy NSData*) buffer {
	// Writing not supported
}

// Reading

- (unichar) getChar {
	NSData* read = [self getBufferWithLength: 1];
	if (read == nil || [read length] <= 0) return GlkEOFChar;
	
	unsigned char bytes[1];
	[read getBytes: bytes
			length: 1];
	return bytes[0];
}

- (bycopy NSString*) getLineWithLength: (NSInteger) maxLen {
	NSMutableString* res = [NSMutableString string];
	
	unichar ch;
	NSInteger len = 0;
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

- (bycopy NSData*) getBufferWithLength: (NSUInteger) length {
	// Return nothing if there's nothing in the buffer and we can't fill it up
	if (bufferRemaining == readAhead && ![self fillBuffer]) {
		return nil;
	}
	
	// Keep reading bytes until we run out of buffer
	NSMutableData* result = [[[NSMutableData alloc] init] autorelease];
	NSInteger toRead = length;
	
	while (bufferRemaining != readAhead && toRead > 0) {
		// Work out how much to read this pass through
		NSInteger thisPass = toRead;
		
		if (lowTide + thisPass > readAhead) {
			thisPass = readAhead - lowTide;
		}
		
		if (thisPass > (readAhead-bufferRemaining)) {
			thisPass = readAhead-bufferRemaining;
		}
		
		// Copy into the buffer
		[result appendBytes: buffer + lowTide
					 length: thisPass];
		
		// Prepare for the next pass
		lowTide += thisPass;
		if (lowTide > readAhead) {
			lowTide = 0;
			NSLog(@"BUG: buffer overrun!");
			abort();
		}
		if (lowTide == readAhead) lowTide = 0;
		bufferRemaining += thisPass;
		
		toRead -= thisPass;
		[self fillBuffer];
	}
	
	if ([result length] == 0) {
		return nil;
	}
	return result;
}

// Styles

- (void) setStyle: (int) styleId {
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

- (void) setHyperlink: (unsigned int) value {
}

- (void) clearHyperlink {
}

@end
