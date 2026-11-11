//
//  IFCompilerSettings.h
//  Inform
//
//  Created by Andrew Hunter on Mon Aug 18 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

// Compiler settings definition class

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// The settings keys
static NSString* const IFSettingZCodeVersion = @"IFSettingZCodeVersion"; // default is 5, 256 = GLULX

// Switches
static NSString* const IFSettingNaturalInform = @"IFSettingNaturalInform"; // default NO
static NSString* const IFSettingStrict = @"IFSettingStrict"; // default YES
static NSString* const IFSettingInfix = @"IFSettingInfix"; // default NO
static NSString* const IFSettingDEBUG = @"IFSettingDEBUG"; // default YES
static NSString* const IFSettingTestingTabHelpShown = @"IFSettingTestingTabHelpShown"; // default YES
static NSString* const IFSettingTestingTabShownCount = @"IFSettingTestingTabShownCount"; // default 0
static NSString* const IFSettingNobbleRng = @"IFSettingNobbleRng"; // default NO
static NSString* const IFSettingBasicInform = @"IFSettingBasicInform"; // default NO
static NSString* const IFSettingCompilerVersion = @"IFSettingCompilerVersion"; // default "Latest"

// Debug
static NSString* const IFSettingAllowLegacyExtensionDirectory = @"IFSettingAllowLegacyExtensionDirectory";

// Notifications
static NSNotificationName const IFSettingNotification = @"IFSettingNotification";
/// Posted by a project, as its object, when it has read its settings, as it does again for Revert To Saved
static NSNotificationName const IFProjectSettingsReplacedNotification = @"IFProjectSettingsReplacedNotification";

// Compiler types
static NSString* const IFCompilerInform6 = @"IFCompilerInform6";
static NSString* const IFCompilerNaturalInform = @"IFCompilerNaturalInform";

@class IFSetting;

///
/// Object used to describe the settings for the compilers
///
NS_SWIFT_UI_ACTOR
@interface IFCompilerSettings : NSObject<NSCoding>

/// The paths to Inform 6 libraries
@property (class, atomic, readonly, copy) NSArray<NSString*> *inform6LibraryPaths;
/// Path to an Inform 6 library with a specific name. \c nil if there isn't one.
+ (nullable NSString*) pathForLibrary: (NSString*) library;
/// Set of available Inform 6 library
@property (class, atomic, readonly, copy) NSArray<NSString*> *availableLibraries;

// Getting information on what is going on
/// The primary compiler type represented by these settings
@property (atomic, readonly, copy) NSString *primaryCompilerType;

// Setting up the settings (deprecated: use an IFSetting object if at all possible)
@property (atomic) BOOL usingNaturalInform;
@property (atomic) BOOL strict;
@property (atomic) BOOL infix;
@property (atomic) BOOL allowLegacyExtensionDirectory;
@property (atomic) BOOL nobbleRng;
@property (atomic) BOOL basicInform;
@property (atomic) BOOL testingTabHelpShown;
@property (atomic) int  testingTabShownCount;
/// The Inform 7 compiler version ("" if none is set). Setting \c nil clears it.
@property (atomic, null_resettable) NSString * compilerVersion;


@property (atomic, readwrite, setter=setZCodeVersion:) int zcodeVersion;
@property (atomic, readonly, copy) NSString *fileExtension;

/// Generates a settings changed notification
- (void) settingsHaveChanged;

// Generic settings (IFSetting)
/// Sets the set of IFSetting objects to use
- (void)      setGenericSettings: (NSArray<IFSetting*>*) genericSettings;
/// Gets the dictionary for a given IFSetting class
- (NSMutableDictionary<NSString*, id>*) dictionaryForClass: (Class) cls;
/// Gets the implementation of a given IFSetting class within this object. \c nil if there isn't one.
- (nullable IFSetting*) settingForClass: (Class) cls;

// Getting command line arguments, etc
/// Retrieves the command line arguments to pass to the Inform 6 compiler. If \c release is YES, debugging options are turned off
- (NSArray<NSString*>*) commandLineArgumentsForRelease: (BOOL) release
                                            forTesting: (BOOL) testing;
/// Retrieves the path to the Inform 6 compiler that should be used (nil if it can't be found)
@property (atomic, readonly, copy, nullable) NSString *inform6CompilerToUse;
/// Retrieves a list of supported Z-Machine versions for the Inform 6 compiler that should be used
@property (atomic, readonly, copy) NSArray<NSNumber*> *supportedZMachines;

/// Retrieves the path to the Natural Inform compiler to use (nil if ni shouldn't be used, or can't be found)
@property (atomic, readonly, copy, nullable) NSString *naturalInformCompilerToUse;
/// Retrieves the command line arguments to use with the NI compiler
@property (atomic, readonly, copy) NSArray<NSString*> *naturalInformCommandLineArguments;

// Getting the data as a plist
/// Reloads the settings from the original Plist values
- (void)	reloadAllSettings;
/// Reloads the settings for a specific generic settings class from the original Plist values
- (void)	reloadSettingsForClass: (NSString*) class;
/// Generates a plist from the current settings (nil if they can't be written as one)
@property (atomic, readonly, copy, nullable) NSData *currentPlist;
/// Restores the settings from a Plist file
- (BOOL)    restoreSettingsFromPlist: (NSData*) plist;

- (BOOL) isNaturalInformCompilerPathValid;

@end

NS_ASSUME_NONNULL_END
