//
//  GlkBufferedStream.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 18/07/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#if defined(COCOAGLK_IPHONE)
# include <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

#import "GlkStreamProtocol.h"

///
/// Client-side object that implements a buffered stream for reading from. Used for dealing with server-side streams
/// that are otherwise very slow to read from (GlkBuffer is only useful for writing).
///
/// This is only suitable for 8-bit streams.
///
@interface GlkBufferedStream : NSObject<GlkStream> {
	NSObject<GlkStream>* sourceStream;								// The stream that we're going to read from
	
	int readAhead;													// The amount to read ahead by
	
	unsigned char* buffer;											// The buffer
	BOOL eof;														// YES if the end of file has been reached
	int lowTide;													// The buffer low tide mark
	int highTide;													// The buffer high tide mark
	int bufferRemaining;											// The amount of space left in the buffer
}

// Initialisation

- (id) initWithStream: (NSObject<GlkStream>*) sourceStream;

// Dealing with the buffer

- (void) setReadAhead: (int) readAhead;								// Sets the read ahead (only has an effect when the buffer is empty)
- (BOOL) fillBuffer;												// Fills the buffer

@end
