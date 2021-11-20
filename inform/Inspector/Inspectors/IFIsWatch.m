//
//  IFIsWatch.m
//  Inform
//
//  Created by Andrew Hunter on 11/12/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import "IFIsWatch.h"

#import "IFProjectController.h"
#import "IFProjectPane.h"
#import "IFProject.h"
#import "IFUtility.h"
#import "IFSettingsController.h"
#import "IFCompilerSettings.h"
#import "IFGamePage.h"
#import "NSBundle+IFBundleExtensions.h"
#import <ZoomView/ZoomView.h>

NSString* const IFIsWatchInspector = @"IFIsWatchInspector";

@implementation IFIsWatch {
    /// The 'quick watch' expression
    IBOutlet NSTextField* expression;
    /// Field that contains the result of evaluating the quick watch expression
    IBOutlet NSTextField* expressionResult;
    /// Table of more permanent watch expressions
    IBOutlet NSTableView* watchTable;

    /// The currently active window
    NSWindow* activeWin;
    /// The currently active project
    IFProject* activeProject;
    /// The active window controller (if it's a ProjectController)
    IFProjectController* activeController;
}

// = Initialisation =

+ (IFIsWatch*) sharedIFIsWatch {
	static IFIsWatch* sharedWatch = nil;
	
	if (!sharedWatch) {
		sharedWatch = [[[self class] alloc] init];
	}
	
	return sharedWatch;
}

- (instancetype) init {
	self = [super init];
	
	if (self) {
		[NSBundle oldLoadNibNamed: @"WatchInspector"
                            owner: self];
		[self setTitle: [IFUtility localizedString: @"Inspector Watch"
                                           default: @"Watch"]];
	}
	
	return self;
}

// = Inspector methods =

- (NSString*) key {
	return IFIsWatchInspector;
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

		[self refreshExpressions];
	}
}

- (BOOL) available {
	// Can't be available if there's no project
	if (activeProject == nil) return NO;
	
	// Breakpoints and watchpoints are not implemented for Natural Inform projects
	if ([[activeProject settings] usingNaturalInform]) return NO;
	
	return YES;
}

// = Evaluating things =

- (unsigned) evaluateExpression: (NSString*) expr {
	// Find the ZoomView, if there is one
	ZoomView* zView = [[[activeController runningGamePane] gamePage] zoomView];
	
	if (zView == nil) return IFEvalNoGame;
	
	// ... then get the zMachine
	NSObject<ZMachine>* zMachine = [zView zMachine];
	
	if (zMachine == nil) return IFEvalNoGame;
	
	// ... now we can evaluate the expression
	int shortAnswer = [zMachine evaluateExpression: expr];
	if (shortAnswer ==  0x7fffffff) return IFEvalError;

	unsigned answer = shortAnswer&0xffff;		// Answers are 16-bit only
		
	// OK, we've got the answer
	return answer;
}

- (NSString*) numericValueForAnswer: (unsigned) answer {
	if (answer >= 0x80000000) {
		if (answer == IFEvalNoGame) {
			return @"## No game running";
		} else {
			return @"## Error";
		}
	} else {
		int signedAnswer = answer;
		
		if (signedAnswer >= 0x8000) signedAnswer |= 0xffff0000;
		
		return [NSString stringWithFormat: @"%i ($%04x)", signedAnswer, answer];
	}
}

- (NSString*) textualValueForExpression: (unsigned) answer {
	// Find the ZoomView, if there is one
	ZoomView* zView = [[[activeController runningGamePane] gamePage] zoomView];
	
	if (zView == nil) return [self numericValueForAnswer: answer];
	
	// ... then get the zMachine
	NSObject<ZMachine>* zMachine = [zView zMachine];
	
	if (zMachine == nil) return [self numericValueForAnswer: answer];
	
	// Use the Z-Machine's evaluator
	return [zMachine  descriptionForValue: answer];
}

- (void) refreshExpressions {
	// The 'top' expression
	unsigned topAnswer = [self evaluateExpression: [expression stringValue]];
	[expressionResult setStringValue: [self numericValueForAnswer: topAnswer]];
	
	[watchTable reloadData];
}

// = The standard evaluator =

- (IBAction) expressionChanged: (id) sender {
	[self refreshExpressions];
}

// = Tableview delegate and data source =

- (int)numberOfRowsInTableView: (NSTableView*) aTableView {
	if (!activeProject) return 0;
	
	int count = [activeProject watchExpressionCount] + 1;
	
	// Minimum of 9 rows (ensures that the user can start editing anywhere)
	if (count < 9) count = 9;
	
	return count;
}

- (id)				tableView: (NSTableView*) aTableView 
	objectValueForTableColumn: (NSTableColumn*) aTableColumn
						  row: (int) rowIndex {
	// If there's no active project, this should never actually end up being called
	if (!activeProject) return @"## No active project";
	
	// Generic information
	unsigned numberOfRows = [activeProject watchExpressionCount];
	NSString* expr= @"";
	
	if (rowIndex >= numberOfRows) return @"";		// Last row is blank
	
	expr = [activeProject watchExpressionAtIndex: rowIndex];
	
	// Column-specific information
	NSString* ident = [aTableColumn identifier];
	
	if ([ident isEqualToString: @"expression"]) {
		return expr;
	}
	
	unsigned answer = [self evaluateExpression: expr];
	
	NSString* value = @"## Bad column";
	
	if ([ident isEqualToString: @"value"]) {
		value = [self numericValueForAnswer: answer];
	} else if ([ident isEqualToString: @"object"]) {
		value = [self textualValueForExpression: answer];
	}
	
	if ([[value substringToIndex: 2] isEqualToString: @"##"]) {
		return [[NSAttributedString alloc] initWithString: value
												attributes: @{NSForegroundColorAttributeName: [NSColor redColor]}];
	} else {
		return value;
	}
}

- (void)		tableView: (NSTableView*) aTableView 
		   setObjectValue: (id) anObject 
		   forTableColumn: (NSTableColumn *) aTableColumn 
					  row: (int)rowIndex {
	if (![[aTableColumn identifier] isEqualToString: @"expression"]) return;		// Can only edit the value column
	if (!activeProject) return;		// Can't edit anything if there's no active project
	
	unsigned numberOfRows = [activeProject watchExpressionCount];
	
	if (![anObject isKindOfClass: [NSString class]]) return;	// Must be a string of some sort
	
	if ([anObject isEqualToString: @""]) {
		// Blank expression - delete this row
		if (rowIndex >= numberOfRows) return;	// Nothing to do
		
		[activeProject removeWatchExpressionAtIndex: rowIndex];
		[watchTable reloadData];
		
		return;
	}
	
	if (rowIndex >= numberOfRows) {
		// New expression: add a new row
		[activeProject addWatchExpression: anObject];
		
		[watchTable reloadData];
	} else {
		// Replace an existing row
		[activeProject replaceWatchExpressionAtIndex: rowIndex
									  withExpression: anObject];
	}
}


@end
