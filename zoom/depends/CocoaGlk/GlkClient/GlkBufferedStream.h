//
//  GlkBufferedStream.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 18/07/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "GlkStreamProtocol.h"

///
/// Client-side object that implements a buffered stream for reading from. Used for dealing with server-side streams
/// that are otherwise very slow to read from (GlkBuffer is only useful for writing).
///
/// This is only suitable for 8-bit streams.
///
@interface GlkBufferedStream : NSObject<GlkStream> {
	/// The stream that we're going to read from
	id<GlkStream> sourceStream;
	
	/// The amount to read ahead by
	int readAhead;
	
	/// The buffer
	unsigned char* buffer;
	/// \c YES if the end of file has been reached
	BOOL eof;
	/// The buffer low tide mark
	int lowTide;
	/// The buffer high tide mark
	int highTide;
	/// The amount of space left in the buffer
	int bufferRemaining;
}

// Initialisation

- (instancetype) initWithStream: (id<GlkStream>) sourceStream;

// Dealing with the buffer

/// Sets the read ahead (only has an effect when the buffer is empty)
- (void) setReadAhead: (int) readAhead;
/// Fills the buffer
- (BOOL) fillBuffer;

@end
