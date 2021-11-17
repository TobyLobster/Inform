//
//  GlkHubProtocol.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 17/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#ifndef __GLKVIEW_GLKHUBPROTOCOL_H__
#define __GLKVIEW_GLKHUBPROTOCOL_H__

#import <Foundation/Foundation.h>
#if defined(COCOAGLK_IPHONE)
# import <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

#import <GlkView/GlkSessionProtocol.h>

///
/// Methods used to communicate with the hub object used by the main Glk server process.
///
NS_SWIFT_NAME(GlkHubProtocol)
@protocol GlkHub <NSObject>

// Setting up the connection
- (nullable byref id<GlkSession>) createNewSession;
- (nullable byref id<GlkSession>) createNewSessionWithHubCookie: (nullable in bycopy NSString*) hubCookie;
- (nullable byref id<GlkSession>) createNewSessionWithHubCookie: (nullable in bycopy NSString*) hubCookie
												  sessionCookie: (nullable in bycopy NSString*) sessionCookie;

@end

#endif
