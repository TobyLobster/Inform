//
//  GlkEvent.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 22/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#if !defined(COCOAGLK_IPHONE)
# import <Cocoa/Cocoa.h>
#else
# import <UIKit/UIKit.h>
#endif

#import "GlkSessionProtocol.h"

//
// Generic Glk event class
//

@interface GlkEvent : NSObject<NSCoding, GlkEvent>

- (instancetype) initWithType: (unsigned) type
   windowIdentifier: (unsigned) windowId;
- (instancetype) initWithType: (unsigned) type
   windowIdentifier: (unsigned) windowId
			   val1: (unsigned) val1;
- (instancetype) initWithType: (unsigned) type
   windowIdentifier: (unsigned) windowId
			   val1: (unsigned) val1
			   val2: (unsigned) val2 NS_DESIGNATED_INITIALIZER;

- (void) setLineInput: (NSString*) input;

@end

//
// Protocol used to send events from objects like windows to a target
//

@protocol GlkEventReceiver

- (void) queueEvent: (GlkEvent*) evt;							// Request that an event be processed

@end
