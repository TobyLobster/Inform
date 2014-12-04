//
//  IFSettingsPage.m
//  Inform-xc2
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFSettingsPage.h"
#import "IFUtility.h"

@implementation IFSettingsPage

// = Initialisation =

- (id) initWithProjectController: (IFProjectController*) controller {
	self = [super initWithNibName: @"Settings"
				projectController: controller];
	
	if (self) {
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(updateSettings)
													 name: IFSettingNotification
												   object: [[parent document] settings]];
		
		[self updateSettings];
	}
	
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[settingsController release];
	
	[super dealloc];
}

// = Details about this view =

- (NSString*) title {
	return [IFUtility localizedString: @"Settings Page Title"
                              default: @"Settings"];
}

// = Settings =

- (void) setSettingsController: (IFSettingsController*) controller {
	[settingsController release];
	settingsController = [controller retain];
}

- (IFSettingsController*) settingsController {
	return settingsController;
}

- (void) updateSettings {
	if (!parent) {
		return; // Nothing to do
	}
	
	[settingsController setCompilerSettings: [[parent document] settings]];
	[settingsController updateAllSettings];
	
	return;
}

@end
