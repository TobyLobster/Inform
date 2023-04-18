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
    /// The view for these preferences
    NSView* preferenceView;
}

#pragma mark - Initialisation

- (instancetype) init { self = [super init]; return self; }

- (instancetype) initWithNibName: (NSString*) nibName {
	self = [super init];
	
	if (self) {
		[NSBundle oldLoadNibNamed: nibName
                            owner: self];
	}
	
	return self;
}


#pragma mark - Information about the preference window

- (NSImage*) toolbarImage {
	return nil;
}

- (NSString*) preferenceName {
	return @"Unnamed preference";
}

- (NSString*) identifier {
	return [[self class] description];
}

- (CGFloat) maxHeight {
    if (preferenceView)
        return preferenceView.frame.size.height;
    else return 0;
}

- (CGFloat) minHeight {
    return [self maxHeight];
}

@synthesize preferenceView;

- (NSString*) tooltip {
	return nil;
}

@end
