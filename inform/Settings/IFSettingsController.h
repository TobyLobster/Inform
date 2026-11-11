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

NS_ASSUME_NONNULL_BEGIN

///
/// Class used to manage a set of IFSettings
///
NS_SWIFT_UI_ACTOR
@interface IFSettingsController : NSObject

// Plug-in support
/// Adds a setting class (must be an IFSetting subclass). These form the 'standard' setting classes
+ (void) addStandardSettingsClass: (Class) settingClass;

/// Makes an array of settings objects using the classes added by addStandardSettingsClass:
+ (NSMutableArray<IFSetting*>*) makeStandardSettings;

/// A controller for the standard settings
- (instancetype) init;
/// A controller for the settings given
- (instancetype) initWithSettings: (NSArray<IFSetting*>*) settings NS_DESIGNATED_INITIALIZER;

// User interface
/// Change/retrieve the settings view (\c nil until one is set)
@property (nonatomic, strong, nullable) IBOutlet IFSettingsView *settingsView;

/// Called when a setting changes (\c sender is the IFSetting that changed; anything else, or \c nil, means all of them)
- (IBAction) settingsHaveChanged: (nullable id) sender;

// Model
/// The compiler settings object that contains the settings data (\c nil until one is set)
@property (nonatomic, strong, nullable) IBOutlet IFCompilerSettings *compilerSettings;

/// Gets every setting view to update its settings
- (void) updateAllSettings;

@end

NS_ASSUME_NONNULL_END
