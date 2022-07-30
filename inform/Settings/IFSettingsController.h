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

///
/// Class used to manage a set of IFSettings
///
@interface IFSettingsController : NSObject

// Plug-in support
/// Adds a setting class (must be an IFSetting subclass). These form the 'standard' setting classes
+ (void) addStandardSettingsClass: (Class) settingClass;

/// Makes an array of settings objects using the classes added by addStandardSettingsClass:
+ (NSMutableArray*) makeStandardSettings;

// User interface
/// Change/retrieve the settings view
@property (nonatomic, strong) IBOutlet IFSettingsView *settingsView;

/// Called when a setting changes
- (IBAction) settingsHaveChanged: (id) sender;

// Model
/// The compiler settings object that contains the settings data
@property (nonatomic, strong) IBOutlet IFCompilerSettings *compilerSettings;

/// Gets every setting view to update its settings
- (void) updateAllSettings;

// The settings to display
/// Adds a new settings object to the set managed by this controller
- (void) addSettingsObject: (IFSetting*) setting;

@end
