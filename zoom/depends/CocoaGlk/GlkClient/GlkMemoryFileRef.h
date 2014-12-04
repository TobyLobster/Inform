//
//  GlkMemoryFileRef.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 12/11/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#if defined(COCOAGLK_IPHONE)
# include <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

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

- (id) initWithData: (NSData*) fileData;					// Initialise this fileref with the specified data

@end
