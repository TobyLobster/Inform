//
//  GlkSessionProtocol.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 20/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#ifndef __GLKVIEW_GLKSTREAMPROTOCOL_H__
#define __GLKVIEW_GLKSTREAMPROTOCOL_H__

#import <Foundation/Foundation.h>


typedef NS_ENUM(int, GlkSeekMode) {
	GlkSeekStart,
	GlkSeekCurrent,
	GlkSeekEnd
};

#define GlkEOFChar 0xffff

NS_ASSUME_NONNULL_BEGIN

///
/// Streams can also be accessed through the buffer (and usually are for writing)
///
/// Our streams use unichars and unicode strings rather than the Latin-1 specified by Glk.
/// This amounts to the same things overall, but makes it easy to update later.
///
@protocol GlkStream <NSObject>

// Control
- (void) closeStream;
- (void) setPosition: (in NSInteger) position
		  relativeTo: (in GlkSeekMode) seekMode;

- (unsigned long long) getPosition;

// Writing
- (void) putChar: (in unichar) ch;
- (void) putString: (in bycopy NSString*) string;
- (void) putBuffer: (in bycopy NSData*) buffer;

// Reading
- (unichar) getChar;
- (nullable bycopy NSString*) getLineWithLength: (NSInteger) maxLen;
- (nullable bycopy NSData*) getBufferWithLength: (NSUInteger) length;

// Styles
@property (nonatomic, readwrite) int style;

- (void) setImmediateStyleHint: (unsigned) hint
					   toValue: (int) value;
- (void) clearImmediateStyleHint: (unsigned) hint;
- (void) setCustomAttributes: (NSDictionary*) customAttributes;

- (void) setHyperlink: (unsigned int) value;
- (void) clearHyperlink;

@end

NS_ASSUME_NONNULL_END

#endif
