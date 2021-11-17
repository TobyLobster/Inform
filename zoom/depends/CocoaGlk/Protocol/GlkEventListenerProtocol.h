//
//  GlkEventListenerProtocol.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 22/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#ifndef __GLKVIEW_GLKEVENTLISTENERPROTOCOL_H__
#define __GLKVIEW_GLKEVENTLISTENERPROTOCOL_H__

#import <Foundation/Foundation.h>

///
/// When executing \c glk_select() and co, we need this to get notifications of when events arrive
///
@protocol GlkEventListener <NSObject>

/// Called by the session object whenever an event arrives
- (oneway void) eventReady: (int) syncCount;

@end

#endif
