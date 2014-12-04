//
//  IFIsSkein.m
//  Inform
//
//  Created by Andrew Hunter on Mon Jul 05 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "IFIsSkein.h"
#import "IFUtility.h"
#import "NSBundle+IFBundleExtensions.h"

NSString* IFIsSkeinInspector = @"IFIsSkeinInspector";

@implementation IFIsSkein

+ (IFIsSkein*) sharedIFIsSkein {
	static IFIsSkein* sharedSkein = nil;
	
	if (!sharedSkein) {
		sharedSkein = [[[self class] alloc] init];
	}
	
	return sharedSkein;
}

- (id) init {
	self = [super init];
	
	if (self) {
		[NSBundle oldLoadNibNamed: @"SkeinInspector"
                            owner: self];
		[self setTitle: [IFUtility localizedString: @"Inspector Skein"
                                           default: @"Skein"]];
	}
	
	return self;
}

// = Inspector methods =

- (NSString*) key {
	return IFIsSkeinInspector;
}

- (void) inspectWindow: (NSWindow*) newWindow {
	[skeinView setDelegate: nil];
	
	activeWin = newWindow;
	
	if (activeProject) {
		// Need to remove the layout manager to prevent potential weirdness
		[activeProject release];
	}
	activeController = nil;
	activeProject = nil;
	
	// Get the active project, if applicable
	NSWindowController* control = [newWindow windowController];
	
	if (control != nil && [control isKindOfClass: [IFProjectController class]]) {
		activeController = (IFProjectController*)control;
		activeProject = [[control document] retain];
		
		[skeinView setSkein: [activeProject skein]];
		[skeinView setDelegate: activeController];
	}
}

- (BOOL) available {
	return activeProject==nil?NO:YES;
}

@end
