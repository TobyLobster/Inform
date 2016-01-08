//
//  IFInspector.m
//  Inform
//
//  Created by Andrew Hunter on Thu Apr 29 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "IFInspector.h"
#import "IFInspectorWindow.h"

@implementation IFInspector {
    IBOutlet NSView* inspectorView;								// The view that contains the inspector
    NSString* title;											// The title of this inspector
    IFInspectorWindow* inspectorWin;							// The window controller that contains this inspector
}

- (instancetype) init {
	self = [super init];
	
	if (self) {
		title = @"Untitled inspector";
		inspectorView = nil;
	}
	
	return self;
}


// = Titles =

- (void) setTitle: (NSString*) newTitle {
	title = [newTitle copy];

	[inspectorWin updateInspectors];
}

- (NSString*) title {
	return (title!=nil)?title:@"No title";
}

- (void) setExpanded: (BOOL) exp {
	[inspectorWin setInspectorState: exp
							 forKey: [self key]];
}

- (BOOL) expanded {
	return [inspectorWin inspectorStateForKey: [self key]];
}

// = Inspector view =
- (void) setInspectorView: (NSView*) view {
	inspectorView = view;
}

- (NSView*) inspectorView {
	return inspectorView;
}

- (BOOL) available {
	// Override to make inspectors disappear when required
	return NO;
}

// = The controller =

- (void) setInspectorWindow: (IFInspectorWindow*) window {
	inspectorWin = window;
}

// = Inspecting things =

- (void) inspectWindow: (NSWindow*) window {
	// Should be overridden in subclasses
	NSLog(@"BUG: Inspector doesn't know what to do");
}

// = The key =

- (NSString*) key {
	[NSException raise: @"IFInspectorHasNoKey" 
				format: @"Attempt to register an inspector with no key"];
	return @"IFNoSuchInspector";
}

@end
