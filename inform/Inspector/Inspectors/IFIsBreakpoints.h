//
//  IFIsBreakpoints.h
//  Inform
//
//  Created by Andrew Hunter on 14/12/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFInspector.h"

#import "IFProject.h"
#import "IFProjectController.h"

// The inspector key for this window
extern NSString* IFIsBreakpointsInspector;

//
// The breakpoints inspector
//
@interface IFIsBreakpoints : IFInspector {
	NSWindow* activeWin;								// The currently active window
	IFProject* activeProject;							// The currently active project
	IFProjectController* activeController;				// The currently active window controller (if it's a ProjectController)
	
	IBOutlet NSTableView* breakpointTable;				// The table that will contain the list of breakpoints
}

+ (IFIsBreakpoints*) sharedIFIsBreakpoints;				// Retrieves the shared breakpoint inspector

// Menu actions
- (IBAction) cut:    (id) sender;						// Cuts the current breakpoint
- (IBAction) copy:   (id) sender;						// Copies the current breakpoint
- (IBAction) paste:  (id) sender;						// Pastes a breakpoint on the clipboard
- (IBAction) delete: (id) sender;						// Deletes the current breakpoint

@end
