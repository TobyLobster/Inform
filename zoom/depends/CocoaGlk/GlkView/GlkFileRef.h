//
//  GlkFileRef.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 28/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "GlkFileRefProtocol.h"

@interface GlkFileRef : NSObject<GlkFileRef> {
	NSString* pathname;
	
	BOOL temporary;
	BOOL autoflush;
}

- (id) initWithPath: (NSString*) pathname;				// Designated initialiser

- (void) setTemporary: (BOOL) isTemp;					// Temporary filerefs are deleted when deallocated

@end
