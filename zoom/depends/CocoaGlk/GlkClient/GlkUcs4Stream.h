//
//  GlkUcs4Stream.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 19/08/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <GlkView/GlkStreamProtocol.h>

///
/// Conversion stream that turns standard GlkStream objects into UCS-4 ones
///
@interface GlkUcs4Stream : NSObject<GlkStream> {
	/// The stream that gets the results of writing to this stream
	id<GlkStream> dataStream;
	/// YES if the stream should be written in a big-endian manner
	BOOL bigEndian;
}

- (instancetype) initWithStream: (id<GlkStream>) dataStream
					  bigEndian: (BOOL) bigEndian;

@end
