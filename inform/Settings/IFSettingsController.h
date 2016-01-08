//
//  IFSettingsController.h
//  Inform
//
//  Created by Andrew Hunter on 06/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class IFSettingsView;
@class IFCompilerSettings;
#import "IFSetting.h"

//
// Class used to manage a set of IFSettings
//
@interface IFSettingsController : NSObject

// Plug-in support
+ (void) addStandardSettingsClass: (Class) settingClass;	// Adds a setting class (must be an IFSetting subclass). These form the 'standard' setting classes

+ (NSMutableArray*) makeStandardSettings;					// Makes an array of settings objects using the classes added by addStandardSettingsClass:

// User interface
@property (atomic, strong) IFSettingsView *settingsView;	// Change/retrieve the settings view

- (IBAction) settingsHaveChanged: (id) sender;				// Called when a setting changes

// Model
@property (atomic, strong) IFCompilerSettings *compilerSettings;

- (void) updateAllSettings;									// Gets every setting view to update its settings

// The settings to display
- (void) addSettingsObject: (IFSetting*) setting;			// Adds a new settings object to the set managed by this controller

@end
