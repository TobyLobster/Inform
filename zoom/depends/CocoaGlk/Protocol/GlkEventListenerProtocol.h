//
//  GlkEventListenerProtocol.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 22/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#if defined(COCOAGLK_IPHONE)
# include <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

//
// When executing glk_select() and co, we need this to get notifications of when events arrive
//

@protocol GlkEventListener

- (oneway void) eventReady: (int) syncCount;			// Called by the session object whenever an event arrives

@end
