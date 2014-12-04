//
//  IFIsFlippedView.h
//  Inform
//
//  Created by Andrew Hunter on Mon May 03 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

//
// View whose main purpose in life is to return 'YES' to isFlipped.
//
// This ensures inspectors are laid out from the top to bottom and not vice-versa, which means the
// window doesn't 'move' downwards when inspectors are closed. Used as the content view of the
// inspector window.
//
// The 'Is' from the prefix 'IFIs' stands for 'Inspector System', as opposed to being part of
// isFlipped.
//
@interface IFIsFlippedView : NSView {

}

@end
