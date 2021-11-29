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
    /// The view that contains the inspector
    NSView* inspectorView;
    /// The title of this inspector
    NSString* title;
    /// The window controller that contains this inspector
    IFInspectorWindow* inspectorWin;
}

- (instancetype) init {
	self = [super init];
	
	if (self) {
		title = @"Untitled inspector";
		inspectorView = nil;
	}
	
	return self;
}


#pragma mark - Titles

@synthesize title;
- (void) setTitle: (NSString*) newTitle {
	title = [newTitle copy];

	[inspectorWin updateInspectors];
}

- (NSString*) title {
	return (title!=nil)?[title copy]:@"No title";
}

- (void) setExpanded: (BOOL) exp {
	[inspectorWin setInspectorState: exp
							 forKey: [self key]];
}

- (BOOL) isExpanded {
	return [inspectorWin inspectorStateForKey: [self key]];
}

- (BOOL) expanded {
    return [self isExpanded];
}

#pragma mark - Inspector view

@synthesize inspectorView;

- (BOOL) available {
	// Override to make inspectors disappear when required
	return NO;
}

#pragma mark - The controller

- (void) setInspectorWindow: (IFInspectorWindow*) window {
	inspectorWin = window;
}

#pragma mark - Inspecting things

- (void) inspectWindow: (NSWindow*) window {
	// Should be overridden in subclasses
	NSLog(@"BUG: Inspector doesn't know what to do");
}

#pragma mark - The key

- (NSString*) key {
	[NSException raise: @"IFInspectorHasNoKey" 
				format: @"Attempt to register an inspector with no key"];
	return @"IFNoSuchInspector";
}

@end
