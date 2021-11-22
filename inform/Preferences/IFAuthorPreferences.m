//
//  IFAuthorPreferences.m
//  Inform
//
//  Created by Andrew Hunter on 18/10/2009.
//  Copyright 2009 Andrew Hunter. All rights reserved.
//

#import "IFAuthorPreferences.h"

#import "IFPreferences.h"
#import "IFUtility.h"

@implementation IFAuthorPreferences {
    /// The preferred name for new Natural Inform games
    IBOutlet NSTextField* newGameName;
}

- (instancetype) init {
	self = [super initWithNibName: @"AuthorPreferences"];
	
	if (self) {
		[self reflectCurrentPreferences];
		
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(reflectCurrentPreferences)
													 name: IFPreferencesAuthorDidChangeNotification
												   object: [IFPreferences sharedPreferences]];
	}
	
	return self;
}

// = Setting ourselves up =

- (void) reflectCurrentPreferences {
	IFPreferences* prefs = [IFPreferences sharedPreferences];

	[newGameName setStringValue: [prefs freshGameAuthorName]];
}

- (IBAction) setPreference: (id) sender {
	IFPreferences* prefs = [IFPreferences sharedPreferences];
	
	if (sender == newGameName) [prefs setFreshGameAuthorName: [newGameName stringValue]];
}

// = PreferencePane overrides =

- (NSString*) preferenceName {
	return @"Author";
}

- (NSImage*) toolbarImage {
	NSImage* image = [NSImage imageNamed: NSImageNameUser];
	return image;
}

- (NSString*) tooltip {
	return [IFUtility localizedString: @"Author preferences tooltip"];
}

@end
