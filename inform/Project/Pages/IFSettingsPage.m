//
//  IFSettingsPage.m
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFSettingsPage.h"
#import "IFSettingsView.h"
#import "IFSettingsController.h"
#import "IFUtility.h"
#import "IFProjectController.h"
#import "IFProject.h"
#import "IFCompilerSettings.h"

@implementation IFSettingsPage {
    // Settings
    IBOutlet IFSettingsView*        settingsView;			// The settings view
    IBOutlet IFSettingsController*  settingsController;     // The settings controller
}

// = Initialisation =

- (instancetype) initWithProjectController: (IFProjectController*) controller {
	self = [super initWithNibName: @"Settings"
				projectController: controller];
	
	if (self) {
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(updateSettings)
													 name: IFSettingNotification
												   object: [[self.parent document] settings]];
		
		[self updateSettings];
	}
	
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

// = Details about this view =

- (NSString*) title {
	return [IFUtility localizedString: @"Settings Page Title"
                              default: @"Settings"];
}

// = Settings =

- (void) setSettingsController: (IFSettingsController*) controller {
	settingsController = controller;
}

- (IFSettingsController*) settingsController {
	return settingsController;
}

- (void) updateSettings {
	if (!self.parent) {
		return; // Nothing to do
	}

	[settingsController setCompilerSettings: [[self.parent document] settings]];
	[settingsController updateAllSettings];
	
	return;
}

@end
