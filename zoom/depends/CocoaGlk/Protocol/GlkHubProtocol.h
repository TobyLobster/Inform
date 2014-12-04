//
//  GlkHubProtocol.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 17/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#if defined(COCOAGLK_IPHONE)
# include <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

#import "GlkSessionProtocol.h"

//
// Method used to communicate with the hub object used by the main Glk server process
//

@protocol GlkHub

// Setting up the connection
- (byref NSObject<GlkSession>*) createNewSession;
- (byref NSObject<GlkSession>*) createNewSessionWithHubCookie: (in bycopy NSString*) hubCookie;
- (byref NSObject<GlkSession>*) createNewSessionWithHubCookie: (in bycopy NSString*) hubCookie
												sessionCookie: (in bycopy NSString*) sessionCookie;

@end
