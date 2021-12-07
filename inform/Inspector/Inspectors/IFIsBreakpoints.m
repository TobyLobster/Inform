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

NSString* const IFIsBreakpointsInspector = @"IFIsBreakpointsInspector";

@implementation IFIsBreakpoints {
    /// The currently active window
    NSWindow* activeWin;
    /// The currently active project
    IFProject* activeProject;
    /// The currently active window controller (if it's a ProjectController)
    IFProjectController* activeController;

    /// The table that will contain the list of breakpoints
    IBOutlet NSTableView* breakpointTable;
}

#pragma mark - Initialisation

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

#pragma mark - Inspectory stuff

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

#pragma mark - Menu actions

- (IBAction) cut: (id) sender {
}

- (IBAction) copy: (id) sender {
}

- (IBAction) paste: (id) sender {
}

- (IBAction) delete: (id) sender {
}

#pragma mark - Table data source

- (NSInteger)numberOfRowsInTableView: (NSTableView*) aTableView {
	return [activeProject breakpointCount];
}

- (id)				tableView: (NSTableView*) aTableView 
	objectValueForTableColumn: (NSTableColumn*) aTableColumn
						  row: (NSInteger) rowIndex {
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
