//
//  GlkFileStream.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 28/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "GlkStreamProtocol.h"

@interface GlkFileStream : NSObject<GlkStream> {
	NSFileHandle* handle;						// The filehandle we're using to read/write from
}

// Initialisation
- (id) initForReadWriteWithFilename: (NSString*) filename;
- (id) initForWritingWithFilename: (NSString*) filename;
- (id) initForReadingWithFilename: (NSString*) filename;

@end
