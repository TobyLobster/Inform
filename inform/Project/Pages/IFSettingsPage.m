//
//  IFSettingsPage.m
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFSettingsPage.h"
#import "IFSettingsController.h"
#import "IFUtility.h"
#import "IFProjectController.h"
#import "IFProject.h"
#import "IFCompilerSettings.h"
#import "Inform-Swift.h"

@implementation IFSettingsPage {
    // Settings
    /// The settings view
    IBOutlet IFSettingsView*        settingsView;
    /// The settings controller
    IFSettingsController*  settingsController;
}

#pragma mark - Initialisation

- (instancetype) initWithProjectController: (IFProjectController*) controller {
	self = [super initWithNibName: @"Settings"
				projectController: controller];
	
	if (self) {
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(updateSettings)
													 name: IFSettingNotification
												   object: [(self.parent).document settings]];
		
		[self updateSettings];
	}
	
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

#pragma mark - Details about this view

- (NSString*) title {
	return [IFUtility localizedString: @"Settings Page Title"
                              default: @"Settings"];
}

#pragma mark - Settings

@synthesize settingsController;

- (void) updateSettings {
	if (!self.parent) {
		return; // Nothing to do
	}

	settingsController.compilerSettings = [(self.parent).document settings];
	[settingsController updateAllSettings];
	
	return;
}

@end
