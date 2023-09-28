//
//  IFSettingsController.m
//  Inform
//
//  Created by Andrew Hunter on 06/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import "IFSettingsController.h"
#import "IFCompilerSettings.h"
#import "Inform-Swift.h"

@implementation IFSettingsController {
    // UI + model
    /// (V) The view that will contain the settings (IFSettingsView is derived from IFCollapsableView)
    IFSettingsView* settingsView;
    /// (M) The compiler settings object that contains the settings data
    IFCompilerSettings* compilerSettings;

    // Settings to display
    /// Array of IFSetting.
    NSMutableArray<IFSetting*>* settings;

    /// \c YES if we're dealing with a change of settings (stops settings from updating at the wrong time)
    BOOL settingsChanging;
}

#pragma mark - Settings methods

static NSMutableArray* standardSettingsClasses = nil;

+ (void) initialize {
	if (standardSettingsClasses == nil) {
		standardSettingsClasses = [[NSMutableArray alloc] init];
	}
}

// 'Standard' settings classes are always added to the controller on startup
+ (void) addStandardSettingsClass: (Class) settingClass {
	if (![settingClass isSubclassOfClass: [IFSetting class]]) {
		[NSException raise: @"IFNotASettingClass" 
					format: @"Class %@ is not a derivative of the IFSetting class", [settingClass class]];
		return;
	}
	
	[standardSettingsClasses addObject: settingClass];
}

+ (NSMutableArray*) makeStandardSettings {
	NSMutableArray* res = [[NSMutableArray alloc] init];

	// Create all the 'standard' classes
	// These must know how to initialise themselves with just an init call
	for( Class settingClass in standardSettingsClasses ) {
		[res addObject: [[settingClass alloc] init]];
	}
	
	return res;
}

#pragma mark - Initialisation, etc

- (instancetype) init {
	self = [super init];
	
	if (self) {
		settings = [[self class] makeStandardSettings];
		
		settingsChanging = NO;
	}
	
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

#pragma mark - User interface

- (void) settingChangedNotification: (NSNotification*) not {
	[self settingsHaveChanged: not.object];
}

- (void) repopulateSettings {
	// Re-add all the settings views
	NSString* compilerType = compilerSettings.primaryCompilerType;
		
	[settingsView startRearranging];
	[settingsView removeAllSubviews];
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];

	for( IFSetting* setting in settings ) {
		// Skip this view if it's not enabled for this compiler type
		if ([setting enableForCompiler: compilerType] == NO) {
            continue;
        }
		
		[settingsView addSubview: setting.settingView
					   withTitle: setting.title];
		
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(settingChangedNotification:) 
													 name: IFSettingHasChangedNotification
												   object: setting];
	}
	
	// This notification will also have been removed above
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(updateAllSettings)
												 name: IFSettingNotification
											   object: self.compilerSettings];
	
	[settingsView finishRearranging];
	
	[compilerSettings setGenericSettings: settings];

	[settings makeObjectsPerformSelector: @selector(setCompilerSettings:)
							  withObject: self.compilerSettings];
}

@synthesize settingsView;

- (void) setSettingsView: (IFSettingsView*) view {
	settingsView = view;
	
	[self repopulateSettings];
}

- (IBAction) settingsHaveChanged: (id) sender {
	if (sender == nil) {
		// All settings have changed
		for( IFSetting* setting in settings ) {
			[self settingsHaveChanged: setting];
		}
		
		return;
	}
	
	if ([sender isKindOfClass: [IFSetting class]]) {
		// A specific settings object has changed
		settingsChanging = YES;
		[(IFSetting*)sender setSettings];
		settingsChanging = NO;
		
		[self updateAllSettings];
	} else {
		// Same as all settings changed, really
		[self settingsHaveChanged: nil];
	}
	
	[compilerSettings settingsHaveChanged];
}

#pragma mark - Model

@synthesize compilerSettings;

- (void) setCompilerSettings: (IFCompilerSettings*) cSettings {
	if (cSettings == compilerSettings) return;
	
	// NOTE: this implementation assumes a one-to-one relationship between the IFCompilerSettings object
	// and ourselves: things may go a bit wonky if multiple settings controllers refer to the same
	// IFCompilerSettings object.
	
	// (FIXME: this actually happens, as each pane has its own SettingsController. Though I don't think
	// this will cause any pain for now)

	// Deregister/release the compiler settings if we're not using them any more
	if (compilerSettings) {
		[[NSNotificationCenter defaultCenter] removeObserver: self
														name: IFSettingNotification
													  object: self.compilerSettings];
	}
	
	// Store the new compiler settings object
	compilerSettings = cSettings;
	[compilerSettings setGenericSettings: settings];
	
	[settings makeObjectsPerformSelector: @selector(setCompilerSettings:)
							  withObject: compilerSettings];
	[compilerSettings reloadAllSettings];
	[self repopulateSettings];

	// Update ourselves when the compiler settings change
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(updateAllSettings)
												 name: IFSettingNotification
											   object: self.compilerSettings];
}

- (void) updateAllSettings {
	// Don't do anything if we're already in the middle of updating the settings
	if (settingsChanging) return;
	
	// Get each setting object to reflect the status of the current compilerSettings
	for( IFSetting* setting in settings ) {
		[setting updateFromCompilerSettings];
	}
}

#pragma mark - The settings to display

- (void) addSettingsObject: (IFSetting*) setting {
	[settings addObject: setting];
	setting.compilerSettings = self.compilerSettings;
	[compilerSettings reloadSettingsForClass: [[setting class] description]];
}

@end
