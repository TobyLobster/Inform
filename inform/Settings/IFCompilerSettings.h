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
extern NSString* IFSettingNobbleRng;

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
@interface IFCompilerSettings : NSObject<NSCoding>  {
    NSMutableDictionary* store;						// (DEPRECATED) Maps keys to settings
	NSArray* genericSettings;						// IFSetting object that deals with specific settings areas
	
	NSDictionary* originalPlist;					// The PList we loaded to construct this object (used if there's some settings in the plist that aren't handled)
}

+ (NSArray*) inform6LibraryPaths;							// The paths to Inform 6 libraries
+ (NSString*) pathForLibrary: (NSString*) library;			// Path to an Inform 6 library with a specific name
+ (NSArray*) availableLibraries;							// Set of available Inform 6 library

// Getting information on what is going on
- (NSString*) primaryCompilerType;							// The primary compiler type represented by these settings

// Setting up the settings (deprecated: use an IFSetting object if at all possible)
- (void) setUsingNaturalInform: (BOOL) setting;
- (void) setStrict: (BOOL) setting;
- (void) setInfix: (BOOL) setting;
- (void) setDebug: (BOOL) setting;
- (void) setCompileNaturalInformOutput: (BOOL) setting;
- (void) setRunBuildScript: (BOOL) setting;
- (void) setNobbleRng: (BOOL) setting;
- (BOOL) usingNaturalInform;
- (BOOL) strict;
- (BOOL) infix;
- (BOOL) debug;
- (BOOL) compileNaturalInformOutput;
- (BOOL) runBuildScript;
- (BOOL) nobbleRng;

- (void) setLibraryToUse: (NSString*) library;
- (NSString*) libraryToUse;

- (void)      setZCodeVersion: (int) version;
- (int)       zcodeVersion;
- (NSString*) fileExtension;

- (void)      setLoudly: (BOOL) loudly;
- (BOOL)      loudly;

- (void)	  setDebugMemory: (BOOL) memDebug;
- (BOOL)	  debugMemory;

- (void) settingsHaveChanged;										// Generates a settings changed notification

// Generic settings (IFSetting)
- (void)      setGenericSettings: (NSArray*) genericSettings;		// Sets the set of IFSetting objects to use
- (NSArray*)  includePathsForCompiler: (NSString*) compiler;		// Gets the list of include paths to use for a specific compiler (IFCompilerInform6 or IFCompilerNaturalInform)
- (NSArray*)  genericCommandLineForCompiler: (NSString*) compiler;	// Gets the list of 'generic' compiler options for a specific compiler (IFCompilerInform6 or IFCompilerNaturalInform)
- (NSMutableDictionary*) dictionaryForClass: (Class) cls;			// Gets the dictionary for a given IFSetting class
- (IFSetting*) settingForClass: (Class) cls;						// Gets the implementation of a given IFSetting class within this object

// Getting command line arguments, etc
- (NSArray*) commandLineArguments;									// Retrieves the command line arguments to pass to the Inform 6 compiler
- (NSArray*) commandLineArgumentsForRelease: (BOOL) release
                                 forTesting: (BOOL) testing;        // Retrieves the command line arguments to pass to the Inform 6 compiler. If release is YES, debugging options are turned off
- (NSString*) compilerToUse;										// Retrieves the path to the Inform 6 compiler that should be used
- (NSArray*) supportedZMachines;									// Retrieves a list of supported Z-Machine versions for the Inform 6 compiler that should be used

- (NSString*) naturalInformCompilerToUse;							// Retrieves the path to the Natural Inform compiler to use (nil if ni shouldn't be used)
- (NSArray*) naturalInformCommandLineArguments;						// Retrieves the command line arguments to use with the NI compiler

// Getting the data as a plist
- (void)	reloadAllSettings;										// Reloads the settings from the original Plist values
- (void)	reloadSettingsForClass: (NSString*) class;				// Reloads the settings for a specific generic settings class from the original Plist values
- (NSData*) currentPlist;											// Generates a plist from the current settings
- (BOOL)    restoreSettingsFromPlist: (NSData*) plist;				// Restores the settings from a Plist file

@end
