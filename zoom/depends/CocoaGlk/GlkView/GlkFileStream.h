//
//  GlkFileStream.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 28/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#ifndef __GLKVIEW_GLKFILESTREAM_H__
#define __GLKVIEW_GLKFILESTREAM_H__

#import <Foundation/Foundation.h>

#import <GlkView/GlkStreamProtocol.h>

@interface GlkFileStream : NSObject<GlkStream> {
	/// The filehandle we're using to read/write from
	NSFileHandle* handle;
}

// Initialisation
- (instancetype) initForReadWriteWithFilename: (NSString*) filename;
- (instancetype) initForWritingWithFilename: (NSString*) filename;
- (instancetype) initForReadingWithFilename: (NSString*) filename;

- (instancetype) initForReadWriteWithFileURL: (NSURL*) filename;
- (instancetype) initForWritingToFileURL: (NSURL*) filename;
- (instancetype) initForReadingFromFileURL: (NSURL*) filename;

@end

#endif
