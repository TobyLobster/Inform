//
//  GlkEventProtocol.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 20/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#ifndef __GLKVIEW_GLKEVENTPROTOCOL_H__
#define __GLKVIEW_GLKEVENTPROTOCOL_H__

#import <Foundation/Foundation.h>
#if defined(COCOAGLK_IPHONE)
# import <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

#include <GlkView/glk.h>

///
/// Protocol implemented by any class claiming to be a Glk event
///
NS_SWIFT_NAME(GlkEventProtocol)
@protocol GlkEvent <NSObject>

/// Type of event
@property (readonly) glui32 type;
/// Needs to be converted to a \c winid_t in the client
@property (readonly) unsigned windowIdentifier;
/// Event data
@property (readonly) glui32 val1;
/// More event data
@property (readonly) glui32 val2;

/// Line data for a line input event
@property (readonly, copy) NSString *lineInput;

@end

#endif
