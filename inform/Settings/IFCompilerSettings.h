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
extern NSString* IFSettingLibraryToUse; // default is `Standard'
extern NSString* IFSettingZCodeVersion; // default is 5, 256 = GLULX

// Switches
extern NSString* IFSettingNaturalInform; // default NO
extern NSString* IFSettingStrict;        // default YES
extern NSString* IFSettingInfix;         // default NO
extern NSString* IFSettingDEBUG;         // default YES
extern NSString* IFSettingTestingTabHelpShown;  // default YES
extern NSString* IFSettingTestingTabShownCount; // default 0
extern NSString* IFSettingNobbleRng;            // default NO
extern NSString* IFSettingCompilerVersion;      // default "Latest"

// Debug
extern NSString* IFSettingCompileNatOutput;
extern NSString* IFSettingRunBuildScript;
extern NSString* IFSettingMemoryDebug;

// Notifications
extern NSString* IFSettingNotification;

// Natural Inform
extern NSString* IFSettingLoudly;

// Compiler types
extern NSString* IFCompilerInform6;
extern NSString* IFCompilerNaturalInform;

@class IFSetting;

//
// Object used to describe the settings for the compilers
//
@interface IFCompilerSettings : NSObject<NSCoding>

+ (NSArray*) inform6LibraryPaths;							// The paths to Inform 6 libraries
+ (NSString*) pathForLibrary: (NSString*) library;			// Path to an Inform 6 library with a specific name
+ (NSArray*) availableLibraries;							// Set of available Inform 6 library

// Getting information on what is going on
@property (atomic, readonly, copy) NSString *primaryCompilerType;	// The primary compiler type represented by these settings

// Setting up the settings (deprecated: use an IFSetting object if at all possible)
@property (atomic) BOOL usingNaturalInform;
@property (atomic) BOOL strict;
@property (atomic) BOOL infix;
@property (atomic) BOOL debug;
@property (atomic) BOOL compileNaturalInformOutput;
@property (atomic) BOOL runBuildScript;
@property (atomic) BOOL nobbleRng;
@property (atomic) BOOL testingTabHelpShown;
@property (atomic) int  testingTabShownCount;
@property (atomic) NSString * compilerVersion;


@property (atomic, copy) NSString *libraryToUse;

- (void)      setZCodeVersion: (int) version;
@property (atomic, readonly) int zcodeVersion;
@property (atomic, readonly, copy) NSString *fileExtension;

@property (atomic) BOOL loudly;

@property (atomic) BOOL debugMemory;

- (void) settingsHaveChanged;										// Generates a settings changed notification

// Generic settings (IFSetting)
- (void)      setGenericSettings: (NSArray*) genericSettings;		// Sets the set of IFSetting objects to use
- (NSMutableDictionary*) dictionaryForClass: (Class) cls;			// Gets the dictionary for a given IFSetting class
- (IFSetting*) settingForClass: (Class) cls;						// Gets the implementation of a given IFSetting class within this object

// Getting command line arguments, etc
@property (atomic, readonly, copy) NSArray *commandLineArguments;	// Retrieves the command line arguments to pass to the Inform 6 compiler
- (NSArray*) commandLineArgumentsForRelease: (BOOL) release
                                 forTesting: (BOOL) testing;        // Retrieves the command line arguments to pass to the Inform 6 compiler. If release is YES, debugging options are turned off
@property (atomic, readonly, copy) NSString *compilerToUse;			// Retrieves the path to the Inform 6 compiler that should be used
@property (atomic, readonly, copy) NSArray *supportedZMachines;		// Retrieves a list of supported Z-Machine versions for the Inform 6 compiler that should be used

@property (atomic, readonly, copy) NSString *naturalInformCompilerToUse;		// Retrieves the path to the Natural Inform compiler to use (nil if ni shouldn't be used)
@property (atomic, readonly, copy) NSArray *naturalInformCommandLineArguments;	// Retrieves the command line arguments to use with the NI compiler

// Getting the data as a plist
- (void)	reloadAllSettings;										// Reloads the settings from the original Plist values
- (void)	reloadSettingsForClass: (NSString*) class;				// Reloads the settings for a specific generic settings class from the original Plist values
@property (atomic, readonly, copy) NSData *currentPlist;			// Generates a plist from the current settings
- (BOOL)    restoreSettingsFromPlist: (NSData*) plist;				// Restores the settings from a Plist file

@end
