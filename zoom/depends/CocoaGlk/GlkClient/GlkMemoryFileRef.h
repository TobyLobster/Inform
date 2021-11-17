//
//  GlkMemoryFileRef.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 12/11/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "GlkFileRefProtocol.h"

///
/// Client-side fileref object that refers to a memory stream
///
/// This can be used along with fileref binding in order to (for example), convert a game runner that expects a concrete
/// filename to a runner that can run games directly from memory.
///
@interface GlkMemoryFileRef : NSObject<GlkFileRef> {
	NSData* data;
	BOOL autoflush;
}

/// Initialise this fileref with the specified data
- (instancetype) initWithData: (NSData*) fileData;

@end
