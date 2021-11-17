//
//  GlkMemoryStream.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 27/03/2005.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "GlkStreamProtocol.h"
#include "glk.h"
#include "gi_dispa.h"

///
/// A stream that sends it output to memory
///
@interface GlkMemoryStream : NSObject<GlkStream> {
	unsigned char* memory;
	char* type;
	NSInteger length;

	NSInteger pointer;
	gidispatch_rock_t rock;
}

/// Constructs this object with the given memory
- (instancetype) initWithMemory: (unsigned char*) mem
						 length: (NSInteger) length;
/// Constructs this object with the given memory and registers the memory
- (instancetype) initWithMemory: (unsigned char*) mem
						 length: (NSInteger) length
						   type: (char*) glkType;

@end
