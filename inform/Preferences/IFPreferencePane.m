//
//  IFPreferencePane.m
//  Inform
//
//  Created by Andrew Hunter on 01/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "IFPreferencePane.h"
#import "NSBundle+IFBundleExtensions.h"

@implementation IFPreferencePane {
    NSView* preferenceView;				// The view for these preferences
}

// = Initialisation =
- (instancetype) init { self = [super init]; return self; }

- (instancetype) initWithNibName: (NSString*) nibName {
	self = [super init];
	
	if (self) {
		[NSBundle oldLoadNibNamed: nibName
                            owner: self];
	}
	
	return self;
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
