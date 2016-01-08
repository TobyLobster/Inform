//
//  GlkArrangeEvent.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 22/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <GlkView/GlkEvent.h>
#import <GlkView/GlkWindow.h>

@interface GlkArrangeEvent : GlkEvent {

}

- (instancetype) initWithGlkWindow: (GlkWindow*) window NS_DESIGNATED_INITIALIZER;

@end
