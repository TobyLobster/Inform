//
//  IFCompilerSettings.h
//  Inform
//
//  Created by Andrew Hunter on Mon Aug 18 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

// Compiler settings definition class

#import <Foundation/Foundation.h>

// The settings keys
extern NSString* const IFSettingZCodeVersion; // default is 5, 256 = GLULX

// Switches
extern NSString* const IFSettingNaturalInform; // default NO
extern NSString* const IFSettingStrict;        // default YES
extern NSString* const IFSettingInfix;         // default NO
extern NSString* const IFSettingDEBUG;         // default YES
extern NSString* const IFSettingTestingTabHelpShown;  // default YES
extern NSString* const IFSettingTestingTabShownCount; // default 0
extern NSString* const IFSettingNobbleRng;            // default NO
extern NSString* const IFSettingBasicInform;          // default NO
extern NSString* const IFSettingCompilerVersion;      // default "Latest"

// Debug
extern NSString* const IFSettingCompileNatOutput;
extern NSString* const IFSettingAllowLegacyExtensionDirectory;

// Notifications
extern NSNotificationName const IFSettingNotification;

// Compiler types
extern NSString* const IFCompilerInform6;
extern NSString* const IFCompilerNaturalInform;

@class IFSetting;

///
/// Object used to describe the settings for the compilers
///
@interface IFCompilerSettings : NSObject<NSCoding>

/// The paths to Inform 6 libraries
@property (class, atomic, readonly, copy) NSArray<NSString*> *inform6LibraryPaths;
/// Path to an Inform 6 library with a specific name
+ (NSString*) pathForLibrary: (NSString*) library;
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
@property (atomic) NSString * compilerVersion;


@property (atomic, readwrite, setter=setZCodeVersion:) int zcodeVersion;
@property (atomic, readonly, copy) NSString *fileExtension;

@property (atomic) BOOL debugMemory;

/// Generates a settings changed notification
- (void) settingsHaveChanged;

// Generic settings (IFSetting)
/// Sets the set of IFSetting objects to use
- (void)      setGenericSettings: (NSArray*) genericSettings;
/// Gets the dictionary for a given IFSetting class
- (NSMutableDictionary*) dictionaryForClass: (Class) cls;
/// Gets the implementation of a given IFSetting class within this object
- (IFSetting*) settingForClass: (Class) cls;

// Getting command line arguments, etc
/// Retrieves the command line arguments to pass to the Inform 6 compiler
@property (atomic, readonly, copy) NSArray<NSString*> *commandLineArguments;
/// Retrieves the command line arguments to pass to the Inform 6 compiler. If \c release is YES, debugging options are turned off
- (NSArray<NSString*>*) commandLineArgumentsForRelease: (BOOL) release
                                            forTesting: (BOOL) testing;
/// Retrieves the path to the Inform 6 compiler that should be used
@property (atomic, readonly, copy) NSString *inform6CompilerToUse;
/// Retrieves a list of supported Z-Machine versions for the Inform 6 compiler that should be used
@property (atomic, readonly, copy) NSArray<NSNumber*> *supportedZMachines;

/// Retrieves the path to the Natural Inform compiler to use (nil if ni shouldn't be used)
@property (atomic, readonly, copy) NSString *naturalInformCompilerToUse;
/// Retrieves the command line arguments to use with the NI compiler
@property (atomic, readonly, copy) NSArray<NSString*> *naturalInformCommandLineArguments;

// Getting the data as a plist
/// Reloads the settings from the original Plist values
- (void)	reloadAllSettings;
/// Reloads the settings for a specific generic settings class from the original Plist values
- (void)	reloadSettingsForClass: (NSString*) class;
/// Generates a plist from the current settings
@property (atomic, readonly, copy) NSData *currentPlist;
/// Restores the settings from a Plist file
- (BOOL)    restoreSettingsFromPlist: (NSData*) plist;

- (BOOL) isNaturalInformCompilerPathValid;

@end
