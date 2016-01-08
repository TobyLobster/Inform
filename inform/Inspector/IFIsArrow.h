//
//  IFIsArrow.h
//  Inform
//
//  Created by Andrew Hunter on Fri Apr 30 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

//
// The Inspector arrow control
//
@interface IFIsArrow : NSControl {

}
// Sets whether the arrow is in the 'open' or 'closed' state
// YES if the arrow is in the open state
@property (atomic) BOOL open;

- (void) performFlip;       // Flips the arrow (animates it)

@end
