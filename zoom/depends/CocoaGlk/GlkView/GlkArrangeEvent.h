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

- (id) initWithGlkWindow: (GlkWindow*) window;

@end
