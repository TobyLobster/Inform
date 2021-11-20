//
//  IFIsBreakpoints.h
//  Inform
//
//  Created by Andrew Hunter on 14/12/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFInspector.h"

/// The inspector key for this window
extern NSString* const IFIsBreakpointsInspector;

///
/// The breakpoints inspector
///
@interface IFIsBreakpoints : IFInspector

/// Retrieves the shared breakpoint inspector
+ (IFIsBreakpoints*) sharedIFIsBreakpoints;

#pragma mark Menu actions
/// Cuts the current breakpoint
- (IBAction) cut:    (id) sender;
/// Copies the current breakpoint
- (IBAction) copy:   (id) sender;
/// Pastes a breakpoint on the clipboard
- (IBAction) paste:  (id) sender;
/// Deletes the current breakpoint
- (IBAction) delete: (id) sender;

@end
