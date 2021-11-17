//
//  ZoomWindowThatCanBecomeKey.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 19/10/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

//!
//! Apple, for reasons best known to themselves, have made it so that border windows can't be
//! key by default. So we need this class to override this behaviour.
//!
@interface ZoomWindowThatCanBecomeKey : NSWindow

@end
