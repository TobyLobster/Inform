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

#pragma mark - Initialisation

- (instancetype) initForReadWriteWithFilename: (NSString*) filename
{
	return [self initForReadWriteWithFileURL:[NSURL fileURLWithPath:filename]];
}

- (id) initForReadWriteWithFileURL: (NSURL*) filename {
	self = [super init];
	
	if (self) {
		handle = [NSFileHandle fileHandleForUpdatingURL: filename error: nil];
		
		if (!handle) {
			if (![filename isFileURL]
                || ![[NSFileManager defaultManager] createFileAtPath: [filename path]
														 contents: [NSData data]
													   attributes: nil]) {
				return nil;
			}			

			handle = [NSFileHandle fileHandleForUpdatingURL: filename error: nil];
		}
		
		if (!handle) {
			return nil;
		}
	}
	
	return self;
}

- (instancetype) initForWritingWithFilename: (NSString*) filename
{
	return [self initForWritingToFileURL:[NSURL fileURLWithPath:filename]];
}

- (id) initForWritingToFileURL: (NSURL*) filename {
	self = [super init];
	
	if (self) {
        if (![filename isFileURL]
            || ![[NSFileManager defaultManager] createFileAtPath: [filename path]
                                                        contents: [NSData data]
                                                      attributes: nil]) {
				return nil;
			}			
		
		handle = [NSFileHandle fileHandleForWritingToURL: filename error: nil];
		
		if (!handle) {
			return nil;
		}
		
		[handle truncateFileAtOffset: 0];
	}
	
	return self;
}

- (instancetype) initForReadingWithFilename: (NSString*) filename
{
	return [self initForReadingFromFileURL:[NSURL fileURLWithPath:filename]];
}

- (id) initForReadingFromFileURL: (NSURL*) filename {
	self = [super init];
	
	if (self) {
		handle = [NSFileHandle fileHandleForReadingFromURL: filename error: nil];
		
		if (!handle) {
			return nil;
		}
	}
	
	return self;
}

#pragma mark - GlkStream methods

#pragma mark Control

- (void) closeStream {
	[handle closeFile];
	handle = nil;
}

- (void) setPosition: (in NSInteger) position
		  relativeTo: (in GlkSeekMode) seekMode {
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

- (unsigned long long) getPosition {
	return [handle offsetInFile];
}

#pragma mark Writing

- (void) putChar: (in unichar) ch {
	NSString *preData = [NSString stringWithFormat:@"%C", ch];
	
	[handle writeData: [preData dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:YES]];
}

- (void) putString: (in bycopy NSString*) string {
	NSData* latin1Data = [string dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:YES];

	[handle writeData: latin1Data];
}

- (void) putBuffer: (in bycopy NSData*) buffer {
	[handle writeData: buffer];
}

#pragma mark Reading

- (unichar) getChar {	
	NSData* data = [handle readDataOfLength: 1];
	
	if (data == nil || [data length] < 1) return GlkEOFChar;
	
	return ((unsigned char*)[data bytes])[0];
}

- (bycopy NSString*) getLineWithLength: (NSInteger) maxLen {
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

- (bycopy NSData*) getBufferWithLength: (NSUInteger) length {
	NSData* data = [handle readDataOfLength: length];
	
	if (data == nil || [data length] <= 0) return nil;
	
	return data;
}

#pragma mark Styles

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

#pragma mark Hyperlinks

- (void) clearHyperlink {
}

- (void) setHyperlink: (unsigned int) value {
}

@end
