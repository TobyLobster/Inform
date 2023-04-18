//
//  IFCompilerSettings.m
//  Inform
//
//  Created by Andrew Hunter on Mon Aug 18 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

//
// We've got a bit of an evolutionary thing going on here. Originally, this was going to be the 
// repository of all settings. Back in those days, Inform.app was just a front-end for the Inform 6
// compiler and didn't really do anything fancy. Now, I've redesigned things so that we can have
// 'IFSetting' objects: these are controller objects for individual sets of settings, and can have
// their own store. But we've still got this object, which acts as the interface to the compiler itself,
// so the 'older' settings are stored here and not as part of the new settings system.
//
// At some point, the settings that are here should probably be moved into their respective IFSetting 
// objects, but for the moment, they will remain.
//

#import "IFCompilerSettings.h"
#import "IFCompiler.h"
#import "IFSetting.h"
#import "IFUtility.h"

#import "IFSettingsController.h"

NSString* const IFSettingLibraryToUse         = @"IFSettingLibraryToUse";
NSString* const IFSettingZCodeVersion         = @"IFSettingZCodeVersion";

NSString* const IFSettingNaturalInform        = @"IFSettingNaturalInform";
NSString* const IFSettingStrict               = @"IFSettingStrict";
NSString* const IFSettingInfix                = @"IFSettingInfix";
NSString* const IFSettingDEBUG                = @"IFSettingDEBUG";
NSString* const IFSettingTestingTabHelpShown  = @"IFSettingTestingTabHelpShown";
NSString* const IFSettingTestingTabShownCount = @"IFSettingTestingTabShownCount";
NSString* const IFSettingNobbleRng            = @"IFSettingNobbleRng";
NSString* const IFSettingBasicInform          = @"IFSettingBasicInform";
NSString* const IFSettingCompilerVersion      = @"IFSettingCompilerVersion";

// Debug
NSString* const IFSettingCompileNatOutput = @"IFSettingCompileNatOutput";
NSString* const IFSettingRunBuildScript   = @"IFSettingRunBuildScript";
NSString* const IFSettingMemoryDebug		= @"IFSettingMemoryDebug";

// Natural Inform
NSString* const IFSettingLoudly = @"IFSettingLoudly";

// Compiler types
NSString* const IFCompilerInform6		  = @"IFCompilerInform6";
NSString* const IFCompilerNaturalInform = @"IFCompilerNaturalInform";

// Notifications
NSString* const IFSettingNotification = @"IFSettingNotification";

// The classes the settings are associated with
// (Legacy-type stuff: ie, tentacles that are too much bother to remove)
#include "IFDebugSettings.h"
#include "IFOutputSettings.h"
#include "IFI7OutputSettings.h"
#include "IFCompilerOptions.h"
#include "IFLibrarySettings.h"
#include "IFMiscSettings.h"

@implementation IFCompilerSettings
{
    /// (DEPRECATED) Maps keys to settings
    NSMutableDictionary* store;
    /// \c IFSetting object that deals with specific settings areas
    NSArray<IFSetting*>* genericSettings;

    /// The PList we loaded to construct this object (used if there's some settings in the plist that aren't handled)
    NSDictionary* originalPlist;
}

// == Possible locations for the library ==
+ (NSArray*) inform6LibraryPaths {
	static NSArray* libPaths = nil;
	
	if (libPaths == nil) {
		NSMutableArray* res = [NSMutableArray array];
		
		// User-supplied library directories
		[res addObject: [IFUtility pathForInformExternalLibraries]];

		// Internal library directories
		NSString* bundlePath = [[NSBundle mainBundle] resourcePath];
		[res addObject: [bundlePath stringByAppendingPathComponent: @"Library"]];

		libPaths = [res copy];
	}
	
	return libPaths;
}

+ (NSString*) pathForLibrary: (NSString*) library {
	NSArray* searchPaths = [[self class] inform6LibraryPaths];
	
	for( NSString* path in searchPaths ) {
		NSString* libDir = [path stringByAppendingPathComponent: library];
		BOOL isDir;
		
		if ([[NSFileManager defaultManager] fileExistsAtPath: libDir
												 isDirectory: &isDir]) {
			if (isDir == NO) {
				// Should be a file containing the actual library directory
				// (We do this because we can't rely on the finder to reliably copy
				// symbolic links)
				// Must be a directory
                NSError *error;
				NSString* newDir = [NSString stringWithContentsOfFile: libDir encoding:NSUTF8StringEncoding error:&error];

				libDir = [path stringByAppendingPathComponent: newDir];

				if (![[NSFileManager defaultManager] fileExistsAtPath: libDir
														  isDirectory: &isDir]) {
					NSLog(@"Couldn't find library link (%@) from %@ in %@", newDir, library, path);
					continue;
				}
				if (!isDir) {
					NSLog(@"Library link to %@ not a directory in %@", newDir, path);
					continue;
				}
			}
			
			return libDir;
		}
	}
	
	return nil;
}

+ (NSArray*) availableLibraries {
	NSMutableArray* result = [NSMutableArray array];
	NSArray* paths = [[self class] inform6LibraryPaths];
	
	for( NSString* path in paths ) {
        NSError *error;
		NSArray* libraryDirectory = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: path error:&error];
		
		for( NSString* lib in [libraryDirectory objectEnumerator] ) {
			if (![result containsObject: lib]) {
                [result addObject: lib];
            }
		}
	}
	
	return result;
}

// == Initialisation ==
- (instancetype) init {
    self = [super init];

    if (self) {
        store = [[NSMutableDictionary alloc] init];

        // Default settings
        [self setUsingNaturalInform: NO];
		
		genericSettings = [IFSettingsController makeStandardSettings];
		
		for( IFSetting* setting in genericSettings ) {
			[setting setCompilerSettings: self];
		}
    }

    return self;
}

- (void) dealloc {
	if (genericSettings) {
		[genericSettings makeObjectsPerformSelector: @selector(setCompilerSettings:)
										 withObject: nil];
	}
}

#pragma mark - Getting information on what is going on

- (NSString*) primaryCompilerType {
	if ([self usingNaturalInform]) {
		return IFCompilerNaturalInform;
	} else {
		return IFCompilerInform6;
	}
}

// == The command line ==
- (NSArray*) commandLineArguments {
	return [self commandLineArgumentsForRelease: NO forTesting: NO];
}

- (NSArray*) commandLineArgumentsForRelease: (BOOL) release
                                 forTesting: (BOOL) testing {
    NSMutableArray* result = [NSMutableArray array];

    // Switches
    NSMutableString* switches = [NSMutableString stringWithString: @"-"];
	[switches appendString: @"k"];
    [switches appendString: @"E2"];

    if (([self strict] && !release) || testing) {
        [switches appendString: @"S"];
    } else {
        [switches appendString: @"~S"];
    }

    if ([self infix] && !release) {
        [switches appendString: @"X"];
    } else {
        // Off by default
    }

    if (([self debug] && !release) || testing) {
        [switches appendString: @"D"];
    } else {
        [switches appendString: @"~D"];
    }

    if ([self usingNaturalInform]) {
        // Disable warnings when compiling with Natural Inform
        [switches appendString: @"w"];
    }

	// Select a zcode version
	NSArray* supportedZCodeVersions = [self supportedZMachines];
	int zcVersion = [self zcodeVersion];
	
	if (supportedZCodeVersions != nil && 
		![supportedZCodeVersions containsObject: @(zcVersion)]) {
		// Use default version
		zcVersion = [supportedZCodeVersions[0] intValue];
	}

	if (zcVersion < 255) {
		// ZCode
		[switches appendString: [NSString stringWithFormat: @"v%i", [self zcodeVersion]]];
	} else {
		// Glulx
		[switches appendString: [NSString stringWithFormat: @"G"]];
	}

    [result addObject: switches];

    // Paths
    NSMutableArray* includePath = [NSMutableArray array];

    // User-defined includes
    
    // Library
    NSString* library = [self libraryToUse];
	NSString* libPath = [[self class] pathForLibrary: library];
	
	if (libPath == nil) libPath = [[self class] pathForLibrary: @"Standard"];
	if (libPath == nil) libPath = [[self class] pathForLibrary: [[self class] availableLibraries][0]];
	if (library == nil) libPath = nil;

    if (library != nil) {
        BOOL isDir;

        if (![[NSFileManager defaultManager] fileExistsAtPath: libPath
                                                  isDirectory: &isDir]) {
            // IMPLEMENT ME: try user preferences file
            libPath = nil;
        }
    }

    if (libPath) {
        [includePath addObject: libPath];
    }

	// Current directory and source directory
    [includePath addObject: @"."];
    [includePath addObject: @"../Source"];

    // Finish up paths

    NSMutableString* incString = [NSMutableString stringWithString: @"+include_path="];
    BOOL comma = NO;

    for( NSString* path in includePath ) {
        if (comma) [incString appendString: @","];
        [incString appendString: path];
        comma = YES;
    }

    [result addObject: incString];

    return result;
}

- (NSString*) compilerToUse {
    return [[NSBundle mainBundle] pathForAuxiliaryExecutable: @"inform6"];
}

- (NSArray*) supportedZMachines {
	return @[ @5, @3, @4, @6, @7, @8, @256 ];
}

- (BOOL) isNaturalInformCompilerPathValid {
    NSString* path = [self naturalInformCompilerToUse];
    return [[NSFileManager defaultManager] fileExistsAtPath: path];
}

- (NSString*) naturalInformCompilerToUse {
    if (![self usingNaturalInform]) {
        return nil;
    }

    return [IFUtility pathForCompiler: [self compilerVersion]];
}

- (NSArray*) naturalInformCommandLineArguments {
    NSMutableArray* res = [NSMutableArray array];
    
    BOOL isLoudly = [self loudly];
    
    if (isLoudly) {
        [res addObject: @"-loudly"];
    }

    NSString* version = [self compilerVersion];
    NSComparisonResult result = [IFUtility compilerVersionCompare: version other:@"6L02"];

    if(result == NSOrderedAscending)
    {
        // Very old
        NSString* internalPath = [IFUtility pathForInformInternalAppSupport:version];
        if (internalPath != nil)
        {
            [res addObject: @"-rules"];
            [res addObject: [internalPath stringByAppendingPathComponent: @"Extensions"]];
        }

        [res addObject: @"-log"];
    }
    else if(result == NSOrderedSame)
    {
        // Fairly old
        NSString* externalPath = [IFUtility pathForInformExternalAppSupport];
        if (externalPath != nil)
        {
            [res addObject: @"-extensions"];
            [res addObject: [externalPath stringByAppendingPathComponent: @"Extensions"]];
        }

        NSString* internalPath = [IFUtility pathForInformInternalAppSupport:version];
        if (internalPath != nil)
        {
            [res addObject: @"-rules"];
            [res addObject: [internalPath stringByAppendingPathComponent: @"Extensions"]];
        }

        [res addObject: @"-log"];
    }
    else
    {
        // New
        NSString* internalPath = [IFUtility pathForInformInternalAppSupport:version];
        if (internalPath != nil) {
            [res addObject: @"-internal"];
            [res addObject: internalPath];
        }

        NSString* externalPath = [IFUtility pathForInformExternalAppSupport];
        if (externalPath != nil) {
            [res addObject: @"-external"];
            [res addObject: externalPath];
        }
    }

    return res;
}

#pragma mark - Setting up the settings

// Originally, there was only this object for dealing with settings, which did not require the 
// structured approach we're now using. Using these routines is deprecated: use a settings controller
// instead where possible.

- (void) settingsHaveChanged {
    [[NSNotificationCenter defaultCenter] postNotificationName: IFSettingNotification
                                                        object: self];
}

- (void) setUsingNaturalInform: (BOOL) setting {
    //[self dictionaryForClass: [IFCompilerOptions class]][IFSettingNaturalInform] = @(setting);
    //[self settingsHaveChanged];
}

- (BOOL) usingNaturalInform {
    return YES;
}

- (void) setStrict: (BOOL) setting {
    [self dictionaryForClass: [IFMiscSettings class]][IFSettingStrict] = @(setting);
    [self settingsHaveChanged];
}

- (BOOL) strict {
    NSNumber* setting = [self dictionaryForClass: [IFMiscSettings class]][IFSettingStrict];

    if (setting) {
        return [setting boolValue];
    } else {
        return YES;
    }
}

- (void) setInfix: (BOOL) setting {
    [self dictionaryForClass: [IFMiscSettings class]][IFSettingInfix] = @(setting);
    [self settingsHaveChanged];
}

- (BOOL) infix {
    NSNumber* setting = [self dictionaryForClass: [IFMiscSettings class]][IFSettingInfix];

    if (setting) {
        return [setting boolValue];
    } else {
        return NO;
    }
}

- (void) setDebug: (BOOL) setting {
    [self dictionaryForClass: [IFMiscSettings class]][IFSettingDEBUG] = @(setting);
    [self settingsHaveChanged];
}

- (BOOL) debug {
    NSNumber* setting = [self dictionaryForClass: [IFMiscSettings class]][IFSettingDEBUG];

    if (setting) {
        return [setting boolValue];
    } else {
        return YES;
    }
}

- (void) setCompileNaturalInformOutput: (BOOL) setting {
    [self dictionaryForClass: [IFDebugSettings class]][IFSettingCompileNatOutput] = @(setting);
    [self settingsHaveChanged];
}

- (BOOL) compileNaturalInformOutput {
    NSNumber* setting = [self dictionaryForClass: [IFDebugSettings class]][IFSettingCompileNatOutput];

    if (setting) {
        return [setting boolValue];
    } else {
        return YES;
    }
}

- (void) setNobbleRng: (BOOL) setting {
    [self dictionaryForClass: [IFOutputSettings class]][IFSettingNobbleRng] = @(setting);
    [self settingsHaveChanged];
}

- (BOOL) nobbleRng {
    NSNumber* setting = [self dictionaryForClass: [IFOutputSettings class]][IFSettingNobbleRng];
	
    if (setting) {
        return [setting boolValue];
    } else {
        return NO;
    }
}

- (void) setBasicInform: (BOOL) setting {
    [self dictionaryForClass: [IFOutputSettings class]][IFSettingBasicInform] = @(setting);
    [self settingsHaveChanged];
}

- (BOOL) basicInform {
    NSNumber* setting = [self dictionaryForClass: [IFOutputSettings class]][IFSettingBasicInform];

    if (setting) {
        return [setting boolValue];
    } else {
        return NO;
    }
}

- (void) setCompilerVersion: (NSString *) setting {
    [self dictionaryForClass: [IFOutputSettings class]][IFSettingCompilerVersion] = [setting copy];
    [self settingsHaveChanged];
}

- (NSString *) compilerVersion {
    NSString* setting = [self dictionaryForClass: [IFOutputSettings class]][IFSettingCompilerVersion];

    if (setting) {
        return setting;
    } else {
        return @"";
    }
}

- (void) setRunBuildScript: (BOOL) setting {
    [self dictionaryForClass: [IFDebugSettings class]][IFSettingRunBuildScript] = @(setting);
    [self settingsHaveChanged];
}

- (BOOL) runBuildScript {
    NSNumber* setting = [self dictionaryForClass: [IFDebugSettings class]][IFSettingRunBuildScript];

    if (setting) {
        return [setting boolValue];
    } else {
        return NO;
    }
}

- (void) setLoudly: (BOOL) setting {
    [self dictionaryForClass: [IFDebugSettings class]][IFSettingLoudly] = @(setting);
    [self settingsHaveChanged];
}

- (BOOL) loudly {
    return [[self dictionaryForClass: [IFDebugSettings class]][IFSettingLoudly] boolValue];
}


- (void) setDebugMemory: (BOOL) memDebug {
    [self dictionaryForClass: [IFDebugSettings class]][IFSettingMemoryDebug] = @(memDebug);
    [self settingsHaveChanged];
}

- (BOOL) debugMemory {
    return [[self dictionaryForClass: [IFDebugSettings class]][IFSettingMemoryDebug] boolValue];
}

- (void) setZCodeVersion: (int) version {
    [self dictionaryForClass: [IFOutputSettings class]][IFSettingZCodeVersion] = @(version);
    [self settingsHaveChanged];
}

- (int) zcodeVersion {
    NSNumber* setting = [self dictionaryForClass: [IFOutputSettings class]][IFSettingZCodeVersion];

    if (setting) {
        return [setting intValue];
    } else {
        return 256;
    }
}

- (void) setTestingTabHelpShown: (BOOL) shown {
    if (shown != [self testingTabHelpShown]) {
        [self dictionaryForClass: [IFMiscSettings class]][IFSettingTestingTabHelpShown] = @(shown);
        [self settingsHaveChanged];
    }
}

- (BOOL) testingTabHelpShown {
    NSNumber* setting = [self dictionaryForClass: [IFMiscSettings class]][IFSettingTestingTabHelpShown];

    if (setting) {
        return [setting boolValue];
    } else {
        return YES;
    }
}

- (void) setTestingTabShownCount: (int) shownCount {
    [self dictionaryForClass: [IFMiscSettings class]][IFSettingTestingTabShownCount] = @(shownCount);
    [self settingsHaveChanged];
}

- (int) testingTabShownCount {
    NSNumber* setting = [self dictionaryForClass: [IFMiscSettings class]][IFSettingTestingTabShownCount];

    if (setting) {
        return [setting intValue];
    } else {
        return 0;
    }
}


- (NSString*) fileExtension {
    int version = [self zcodeVersion];
	
	if (version == 256) return @"ulx";
    return [NSString stringWithFormat: @"z%i", version];
}

- (void) setLibraryToUse: (NSString*) library {
    [self dictionaryForClass: [IFLibrarySettings class]][IFSettingLibraryToUse] = [library copy];
    [self settingsHaveChanged];
}

- (NSString*) libraryToUse {
	NSString* library = [self dictionaryForClass: [IFLibrarySettings class]][IFSettingLibraryToUse];
	
	if (library == nil) library = @"Standard";
	
	return library;
}

#pragma mark - Generic settings

- (void) setGenericSettings: (NSArray*) newGenericSettings {
	if (newGenericSettings == genericSettings) return;
	
	genericSettings = newGenericSettings;
}

- (NSMutableDictionary*) dictionaryForClass: (Class) cls {
	NSMutableDictionary* dict = store[[cls description]];
	
	if (dict == nil) {
		dict = [NSMutableDictionary dictionary];
		
		store[[cls description]] = dict;
	}
	
	return dict;
}

- (IFSetting*) settingForClass: (Class) cls {
	for( IFSetting* setting in genericSettings ) {
		if ([[[setting class] description] isEqualToString: [cls description]]) {
			return setting;
		}
	}
	
	return nil;
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject: store];
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [self init]; // Call the designated initialiser first

    store = [decoder decodeObject];
	
	// Convert from the old format to the new format -- not done yet (do we really need this?)

    return self;
}

#pragma mark - Property lists

- (NSData*) currentPlist {
	// Use the original plist as a template if it exists (this will preserve any plist data that
	// say, the Windows version might produce)
	NSMutableDictionary* plData;
	
	if (originalPlist) {
		plData = [originalPlist mutableCopy];
	} else {
		plData = [[NSMutableDictionary alloc] init];
	}
	
	// Get updated data from all the generic settings classes
	for( IFSetting* setting in genericSettings ) {
		if ([setting plistEntries]) {
			plData[[[setting class] description]] = [setting plistEntries];
		}
	}
	
	// Update the original list to reflect the current one
	originalPlist = [plData copy];
	
	// Create the actual plist	
	NSError* error;
	NSData* res = [NSPropertyListSerialization dataWithPropertyList: plData
															 format: NSPropertyListXMLFormat_v1_0
                                                            options: 0
                                                              error: &error];
	
	if (!res) {
		NSLog(@"Couldn't create settings data: %@", error);
		NSLog(@"Settings data was: %@", plData);
	}
	
	// Finish up
	return res;
}

- (void) reloadSettingsForClass: (NSString*) class {
	IFSetting* settingToReload = nil;
	
	// Find the setting corresponding to the supplied class
	for( IFSetting* settingToTest in genericSettings ) {
		if ([[[settingToTest class] description] isEqualToString: class]) {
			settingToReload = settingToTest;
			break;
		}
	}
	
	// If it exists, get it to update from the plist data
	if (settingToReload) {
		NSDictionary* settingData = originalPlist[class];
		
		[settingToReload updateSettings: self
					   withPlistEntries: settingData];
	}
}

- (void) reloadAllSettings {
	if (originalPlist) {
		// Load the setting data from the plist
		for( NSString* key in originalPlist ) {
			[self reloadSettingsForClass: key];
		}
	}
}

- (BOOL) restoreSettingsFromPlist: (NSData*) plData {
	// This new data will replace the original data (even if the parsing fails)
	originalPlist = nil;
	
	// Parse the plist into a dictionary
	NSError* error = nil;
	NSPropertyListFormat fmt = NSPropertyListXMLFormat_v1_0;
	NSDictionary* plist = [NSPropertyListSerialization propertyListWithData: plData
                                                                    options: NSPropertyListMutableContainersAndLeaves
																	 format: &fmt
                                                                      error: &error];
	
	if (!plist) {
		NSLog(@"Failed to load settings: %@", error);
		return NO;
	} else if (![plist isKindOfClass: [NSDictionary class]]) {
		NSLog(@"Failed to load settings: property list is not a dictionary");
		return NO;
	}
	
	// Store as the 'original' plist
	originalPlist = [plist copy];
	
	// Load the plist into the various property items
	for( NSString* key in plist ) {
		[self reloadSettingsForClass: key];
	}
		
	return YES;
}

@end
