//
//  IFNotifyingWindow.h
//  Inform
//
//  Created by Andrew Hunter on 06/01/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>


///
/// NSWindow subclass that notifies its delegate of responder changes
///
@interface IFNotifyingWindow : NSWindow {

}

@end

@interface NSObject(IFWindowDelegate)

- (void) changeFirstResponder: (NSResponder*) newResponder;

@end
