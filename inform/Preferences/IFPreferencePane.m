//
//  IFPreferencePane.m
//  Inform
//
//  Created by Andrew Hunter on 01/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "IFPreferencePane.h"
#import "NSBundle+IFBundleExtensions.h"

@implementation IFPreferencePane

// = Initialisation =

- (id) initWithNibName: (NSString*) nibName {
	self = [super init];
	
	if (self) {
		[NSBundle oldLoadNibNamed: nibName
                            owner: self];
	}
	
	return self;
}

- (void) dealloc {
	if (preferenceView) [preferenceView release];
	
	[super dealloc];
}

// = Information about the preference window =

- (NSImage*) toolbarImage {
	return nil;
}

- (NSString*) preferenceName {
	return @"Unnamed preference";
}

- (NSString*) identifier {
	return [[self class] description];
}

- (NSView*) preferenceView {
	return preferenceView;
}

- (NSString*) tooltip {
	return nil;
}

@end
