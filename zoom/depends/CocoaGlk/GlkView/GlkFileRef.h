//
//  GlkFileRef.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 28/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#ifndef __GLKVIEW_GLKFILEREF_H__
#define __GLKVIEW_GLKFILEREF_H__

#import <GlkView/GlkViewDefinitions.h>
#if defined(COCOAGLK_IPHONE)
# import <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

#import <GlkView/GlkFileRefProtocol.h>

@interface GlkFileRef : NSObject<GlkFileRef> {
	NSURL* pathname;
	
	BOOL temporary;
	BOOL autoflush;
}

- (instancetype) init UNAVAILABLE_ATTRIBUTE;
/// Designated initialiser
- (instancetype) initWithPath: (NSURL*) pathname NS_DESIGNATED_INITIALIZER;

/// Temporary filerefs are deleted when deallocated
@property (getter=isTemporary) BOOL temporary;

@end

#endif
