//
//  GlkMemoryStream.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 27/03/2005.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#if defined(COCOAGLK_IPHONE)
# include <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

#import "GlkStreamProtocol.h"
#include "glk.h"
#include "gi_dispa.h"

//
// A stream that sends it output to memory
//
@interface GlkMemoryStream : NSObject<GlkStream> {
	unsigned char* memory;
	char* type;
	int length;

	int pointer;
	gidispatch_rock_t rock;
}

- (id) initWithMemory: (unsigned char*) mem					// Constructs this object with the given memory
			   length: (int) length;
- (id) initWithMemory: (unsigned char*) mem					// Constructs this object with the given memory and registers the memory
			   length: (int) length
				 type: (char*) glkType;

@end
