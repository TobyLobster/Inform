//
//  IFSettingsController.h
//  Inform
//
//  Created by Andrew Hunter on 06/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFSettingsView.h"
#import "IFCompilerSettings.h"
#import "IFSetting.h"

//
// Class used to manage a set of IFSettings
//
@interface IFSettingsController : NSObject {
	// UI + model
	IBOutlet IFSettingsView* settingsView;					// (V) The view that will contain the settings (IFSettingsView is derived from IFCollapsableView)
	IBOutlet IFCompilerSettings* compilerSettings;			// (M) The compiler settings object that contains the settings data

	// Settings to display
	NSMutableArray* settings;								// Array of IFSetting.
	
	BOOL settingsChanging;									// YES if we're dealing with a change of settings (stops settings from updating at the wrong time)
}

// Plug-in support
+ (void) addStandardSettingsClass: (Class) settingClass;	// Adds a setting class (must be an IFSetting subclass). These form the 'standard' setting classes

+ (NSMutableArray*) makeStandardSettings;					// Makes an array of settings objects using the classes added by addStandardSettingsClass:

// User interface
- (IFSettingsView*) settingsView;							// Retrieves the settings view
- (void) setSettingsView: (IFSettingsView*) view;			// Changes the settings view

- (IBAction) settingsHaveChanged: (id) sender;				// Called when a setting changes

// Model
- (IFCompilerSettings*) compilerSettings;					// Retrieves the compiler settings object
- (void) setCompilerSettings: (IFCompilerSettings*) settings; // Sets the compler settings object

- (void) updateAllSettings;									// Gets every setting view to update its settings

// The settings to display
- (void) addSettingsObject: (IFSetting*) setting;			// Adds a new settings object to the set managed by this controller

@end
