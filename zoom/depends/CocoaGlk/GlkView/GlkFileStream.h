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
- (instancetype) initForReadWriteWithFilename: (NSString*) filename NS_DESIGNATED_INITIALIZER;
- (instancetype) initForWritingWithFilename: (NSString*) filename NS_DESIGNATED_INITIALIZER;
- (instancetype) initForReadingWithFilename: (NSString*) filename NS_DESIGNATED_INITIALIZER;

@end
