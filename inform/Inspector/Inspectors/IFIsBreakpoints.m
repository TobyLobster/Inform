//
//  IFIsBreakpoints.m
//  Inform
//
//  Created by Andrew Hunter on 14/12/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import "IFIsBreakpoints.h"
#import "IFUtility.h"
#import "NSBundle+IFBundleExtensions.h"
#import "IFProject.h"
#import "IFProjectController.h"
#import "IFCompilerSettings.h"

NSString* IFIsBreakpointsInspector = @"IFIsBreakpointsInspector";

@implementation IFIsBreakpoints {
    NSWindow* activeWin;								// The currently active window
    IFProject* activeProject;							// The currently active project
    IFProjectController* activeController;				// The currently active window controller (if it's a ProjectController)

    IBOutlet NSTableView* breakpointTable;				// The table that will contain the list of breakpoints
}

// = Initialisation =

+ (IFIsBreakpoints*) sharedIFIsBreakpoints {
	static IFIsBreakpoints* sharedBreakpoints = nil;
	
	if (!sharedBreakpoints) {
		sharedBreakpoints = [[[self class] alloc] init];
	}
	
	return sharedBreakpoints;
}

- (instancetype) init {
	self = [super init];
	
	if (self) {
		[NSBundle oldLoadNibNamed: @"BreakpointInspector"
                            owner: self];
		[self setTitle: [IFUtility localizedString: @"Inspector Breakpoints"
                                           default: @"Breakpoints"]];
		
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(breakpointsChanged:)
													 name: IFProjectBreakpointsChangedNotification
												   object: nil];
	}
	
	return self;
}

// = Inspectory stuff =

- (NSString*) key {
	return IFIsBreakpointsInspector;
}

- (void) inspectWindow: (NSWindow*) newWindow {
	activeWin = newWindow;
	
	activeController = nil;
	activeProject = nil;
	
	// Get the active project, if applicable
	NSWindowController* control = [newWindow windowController];
	
	if (control != nil && [control isKindOfClass: [IFProjectController class]]) {
		activeController = (IFProjectController*)control;
		activeProject = [control document];
	}
}

- (BOOL) available {
	// Can't be available if there's no project
	if (activeProject == nil) return NO;
	
	// Breakpoints and watchpoints are not implemented for Natural Inform projects
	if ([[activeProject settings] usingNaturalInform]) return NO;
	
	return YES;
}

// = Menu actions =

- (IBAction) cut: (id) sender {
}

- (IBAction) copy: (id) sender {
}

- (IBAction) paste: (id) sender {
}

- (IBAction) delete: (id) sender {
}

// = Table data source =

- (int)numberOfRowsInTableView: (NSTableView*) aTableView {
	return [activeProject breakpointCount];
}

- (id)				tableView: (NSTableView*) aTableView 
	objectValueForTableColumn: (NSTableColumn*) aTableColumn
						  row: (int) rowIndex {
	NSString* ident = [aTableColumn identifier];
	
	if ([ident isEqualToString: @"enabled"]) {
		return @YES;
	} else if ([ident isEqualToString: @"file"]) {
		return [[activeProject fileForBreakpointAtIndex: rowIndex] lastPathComponent];
	} else if ([ident isEqualToString: @"line"]) {
		return [NSString stringWithFormat: @"%i", [activeProject lineForBreakpointAtIndex: rowIndex]];
	}
	
	return nil;
}

- (void)tableViewSelectionDidChange: (NSNotification *)aNotification {
	if ([breakpointTable numberOfSelectedRows] != 1) return;
	
	int selectedRow = (int) [breakpointTable selectedRow];
	
	NSString* file = [activeProject fileForBreakpointAtIndex: selectedRow];
	int line = [activeProject lineForBreakpointAtIndex: selectedRow];
	
	// Move to this breakpoint
	[activeController selectSourceFile: file];
	[activeController moveToSourceFileLine: line+1];
}

- (void) breakpointsChanged: (NSNotification*) not {
	[breakpointTable reloadData];
}

@end
