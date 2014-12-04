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

NSString* IFSettingLibraryToUse		= @"IFSettingLibraryToUse";
NSString* IFSettingZCodeVersion		= @"IFSettingZCodeVersion";

NSString* IFSettingNaturalInform	= @"IFSettingNaturalInform";
NSString* IFSettingStrict			= @"IFSettingStrict";
NSString* IFSettingInfix			= @"IFSettingInfix";
NSString* IFSettingDEBUG			= @"IFSettingDEBUG";
NSString* IFSettingNobbleRng		= @"IFSettingNobbleRng";

// Debug
NSString* IFSettingCompileNatOutput = @"IFSettingCompileNatOutput";
NSString* IFSettingRunBuildScript   = @"IFSettingRunBuildScript";
NSString* IFSettingMemoryDebug		= @"IFSettingMemoryDebug";

// Natural Inform
NSString* IFSettingLoudly = @"IFSettingLoudly";

// Compiler types
NSString* IFCompilerInform6		  = @"IFCompilerInform6";
NSString* IFCompilerNaturalInform = @"IFCompilerNaturalInform";

// Notifications
NSString* IFSettingNotification = @"IFSettingNotification";

// The classes the settings are associated with
// (Legacy-type stuff: ie, tentacles that are too much bother to remove)
#include "IFDebugSettings.h"
#include "IFOutputSettings.h"
#include "IFI7OutputSettings.h"
#include "IFCompilerOptions.h"
#include "IFLibrarySettings.h"
#include "IFMiscSettings.h"

@implementation IFCompilerSettings

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
- (id) init {
    self = [super init];

    if (self) {
        store = [[NSMutableDictionary alloc] init];

        // Default settings
        [self setUsingNaturalInform: NO];
		
		genericSettings = [[IFSettingsController makeStandardSettings] retain];
		
		for( IFSetting* setting in genericSettings ) {
			[setting setCompilerSettings: self];
		}
    }

    return self;
}

- (void) dealloc {
    [store release];
	if (genericSettings) {
		[genericSettings makeObjectsPerformSelector: @selector(setCompilerSettings:)
										 withObject: nil];
		[genericSettings release];
	}
	
	if (originalPlist) [originalPlist autorelease];

    [super dealloc];
}

// = Getting information on what is going on =

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
		![supportedZCodeVersions containsObject: [NSNumber numberWithInt: zcVersion]]) {
		// Use default version
		zcVersion = [[supportedZCodeVersions objectAtIndex: 0] intValue];
	}

	if (zcVersion < 255) {
		// ZCode
		[switches appendString: [NSString stringWithFormat: @"v%i",
			[self zcodeVersion]]];
	} else {
		// Glulx
		
		// FIXME: this assumes we only ever use a biplatform compiler
		// Not sure this is an urgent fix, though: all future versions of Inform should be BP
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
	if (libPath == nil) libPath = [[self class] pathForLibrary: [[[self class] availableLibraries] objectAtIndex: 0]];
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

	// Include paths from settings modules

	[includePath addObjectsFromArray: [self includePathsForCompiler: IFCompilerInform6]];

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

	// Command line options from the set of generic settings objects
	[result addObjectsFromArray: [self genericCommandLineForCompiler: IFCompilerInform6]];

    return result;
}

- (NSString*) compilerToUse {
    return [[[[NSBundle mainBundle] executablePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent: @"inform6"];
}

- (NSArray*) supportedZMachines {
	return [NSArray arrayWithObjects:
					[NSNumber numberWithInt: 5],
					[NSNumber numberWithInt: 3],
					[NSNumber numberWithInt: 4],
					[NSNumber numberWithInt: 6],
					[NSNumber numberWithInt: 7],
					[NSNumber numberWithInt: 8],
					[NSNumber numberWithInt: 256],
					nil];
}


- (NSString*) naturalInformCompilerToUse {
    if (![self usingNaturalInform]) {
        return nil;
    }

    NSString *compilerPath = [[[[NSBundle mainBundle] executablePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent: @"ni"];

    return compilerPath;
}

- (NSArray*) naturalInformCommandLineArguments {
    NSMutableArray* res = [NSMutableArray array];
    
    BOOL isLoudly = [self loudly];
    
    if (isLoudly) {
        [res addObject: @"-loudly"];
    }
	
	NSString* internalPath = [IFUtility pathForInformInternalAppSupport];
	if (internalPath != nil) {
		[res addObject: @"-internal"];
		[res addObject: internalPath];
	}

    NSString* externalPath = [IFUtility pathForInformExternalAppSupport];
	if (externalPath != nil) {
		[res addObject: @"-external"];
		[res addObject: externalPath];
	}

	[res addObjectsFromArray: [self genericCommandLineForCompiler: IFCompilerNaturalInform]];
    
    return res;
}

// = Setting up the settings =

// Originally, there was only this object for dealing with settings, which did not require the 
// structured approach we're now using. Using these routines is deprecated: use a settings controller
// instead where possible.

- (void) settingsHaveChanged {
    [[NSNotificationCenter defaultCenter] postNotificationName: IFSettingNotification
                                                        object: self];
}

- (void) setUsingNaturalInform: (BOOL) setting {
    [[self dictionaryForClass: [IFCompilerOptions class]] setObject: [NSNumber numberWithBool: setting]
															 forKey: IFSettingNaturalInform];
    [self settingsHaveChanged];
}

- (BOOL) usingNaturalInform {
    NSNumber* usingNaturalInform = [[self dictionaryForClass: [IFCompilerOptions class]] objectForKey: IFSettingNaturalInform];

    if (usingNaturalInform) {
        return [usingNaturalInform boolValue];
    } else {
        return NO;
    }
}

- (void) setStrict: (BOOL) setting {
    [[self dictionaryForClass: [IFMiscSettings class]] setObject: [NSNumber numberWithBool: setting]
														  forKey: IFSettingStrict];
    [self settingsHaveChanged];
}

- (BOOL) strict {
    NSNumber* setting = [[self dictionaryForClass: [IFMiscSettings class]] objectForKey: IFSettingStrict];

    if (setting) {
        return [setting boolValue];
    } else {
        return YES;
    }
}

- (void) setInfix: (BOOL) setting {
    [[self dictionaryForClass: [IFMiscSettings class]] setObject: [NSNumber numberWithBool: setting]
														  forKey: IFSettingInfix];
    [self settingsHaveChanged];
}

- (BOOL) infix {
    NSNumber* setting = [[self dictionaryForClass: [IFMiscSettings class]] objectForKey: IFSettingInfix];

    if (setting) {
        return [setting boolValue];
    } else {
        return NO;
    }
}

- (void) setDebug: (BOOL) setting {
    [[self dictionaryForClass: [IFMiscSettings class]] setObject: [NSNumber numberWithBool: setting]
														  forKey: IFSettingDEBUG];
    [self settingsHaveChanged];
}

- (BOOL) debug {
    NSNumber* setting = [[self dictionaryForClass: [IFMiscSettings class]] objectForKey: IFSettingDEBUG];

    if (setting) {
        return [setting boolValue];
    } else {
        return YES;
    }
}

- (void) setCompileNaturalInformOutput: (BOOL) setting {
    [[self dictionaryForClass: [IFDebugSettings class]] setObject: [NSNumber numberWithBool: setting]
														   forKey: IFSettingCompileNatOutput];
    [self settingsHaveChanged];
}

- (BOOL) compileNaturalInformOutput {
    NSNumber* setting = [[self dictionaryForClass: [IFDebugSettings class]] objectForKey: IFSettingCompileNatOutput];

    if (setting) {
        return [setting boolValue];
    } else {
        return YES;
    }
}

- (void) setNobbleRng: (BOOL) setting {
    [[self dictionaryForClass: [IFOutputSettings class]] setObject: [NSNumber numberWithBool: setting]
														   forKey: IFSettingNobbleRng];
    [self settingsHaveChanged];
}

- (BOOL) nobbleRng {
    NSNumber* setting = [[self dictionaryForClass: [IFOutputSettings class]] objectForKey: IFSettingNobbleRng];
	
    if (setting) {
        return [setting boolValue];
    } else {
        return NO;
    }
}

- (void) setRunBuildScript: (BOOL) setting {
    [[self dictionaryForClass: [IFDebugSettings class]] setObject: [NSNumber numberWithBool: setting]
														   forKey: IFSettingRunBuildScript];
    [self settingsHaveChanged];
}

- (BOOL) runBuildScript {
    NSNumber* setting = [[self dictionaryForClass: [IFDebugSettings class]] objectForKey: IFSettingRunBuildScript];

    if (setting) {
        return [setting boolValue];
    } else {
        return NO;
    }
}

- (void) setLoudly: (BOOL) setting {
    [[self dictionaryForClass: [IFDebugSettings class]] setObject: [NSNumber numberWithBool: setting]
														   forKey: IFSettingLoudly];
    [self settingsHaveChanged];
}

- (BOOL) loudly {
    return [[[self dictionaryForClass: [IFDebugSettings class]] objectForKey: IFSettingLoudly] boolValue];
}


- (void) setDebugMemory: (BOOL) memDebug {
    [[self dictionaryForClass: [IFDebugSettings class]] setObject: [NSNumber numberWithBool: memDebug]
														   forKey: IFSettingMemoryDebug];
    [self settingsHaveChanged];
}

- (BOOL) debugMemory {
    return [[[self dictionaryForClass: [IFDebugSettings class]] objectForKey: IFSettingMemoryDebug] boolValue];
}

- (void) setZCodeVersion: (int) version {
    [[self dictionaryForClass: [IFOutputSettings class]] setObject: [NSNumber numberWithInt: version]
															forKey: IFSettingZCodeVersion];
    [self settingsHaveChanged];
}

- (int) zcodeVersion {
    NSNumber* setting = [[self dictionaryForClass: [IFOutputSettings class]] objectForKey: IFSettingZCodeVersion];

    if (setting) {
        return [setting intValue];
    } else {
        return 256;
    }
}

- (NSString*) fileExtension {
    int version = [self zcodeVersion];
	
	if (version == 256) return @"ulx";
    return [NSString stringWithFormat: @"z%i", version];
}

- (void) setLibraryToUse: (NSString*) library {
    [[self dictionaryForClass: [IFLibrarySettings class]] setObject: [[library copy] autorelease]
															 forKey: IFSettingLibraryToUse];
    [self settingsHaveChanged];
}

- (NSString*) libraryToUse {
	NSString* library = [[self dictionaryForClass: [IFLibrarySettings class]] objectForKey: IFSettingLibraryToUse];
	
	if (library == nil) library = @"Standard";
	
	return library;
}

// = Generic settings =

- (void) setGenericSettings: (NSArray*) newGenericSettings {
	if (newGenericSettings == genericSettings) return;
	
	if (genericSettings) [genericSettings release];
	genericSettings = [newGenericSettings retain];
}

- (NSArray*) genericCommandLineForCompiler: (NSString*) compiler {
	NSMutableArray* result = [NSMutableArray array];
	
	for( IFSetting* setting in genericSettings ) {
		NSArray* settingOptions = [setting commandLineOptionsForCompiler: compiler];
		
		if (settingOptions) {
            [result addObjectsFromArray: settingOptions];
        }
	}
	
	return result;
}

- (NSArray*) includePathsForCompiler: (NSString*) compiler {
	NSMutableArray* result = [NSMutableArray array];
	
	for( IFSetting* setting in genericSettings ) {
		NSArray* settingOptions = [setting includePathForCompiler: compiler];
		
		if (settingOptions) {
            [result addObjectsFromArray: settingOptions];
        }
	}
	
	return result;
}

- (NSMutableDictionary*) dictionaryForClass: (Class) cls {
	NSMutableDictionary* dict = [store objectForKey: [cls description]];
	
	if (dict == nil) {
		dict = [NSMutableDictionary dictionary];
		
		[store setObject: dict
				  forKey: [cls description]];
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

// = NSCoding =

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject: store];
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [self init]; // Call the designated initialiser first

    [store release];
    store = [[decoder decodeObject] retain];
	
	// Convert from the old format to the new format -- not done yet (do we really need this?)

    return self;
}

// = Property lists =

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
			[plData setObject: [setting plistEntries]
					   forKey: [[setting class] description]];
		}
	}
	
	// Update the original list to reflect the current one
	[originalPlist release];
	originalPlist = [plData copy];
	
	// Create the actual plist	
	NSString* error;
	NSData* res = [NSPropertyListSerialization dataFromPropertyList: plData
															 format: NSPropertyListXMLFormat_v1_0
												   errorDescription:&error];
	
	if (!res) {
		NSLog(@"Couldn't create settings data: %@", error);
		NSLog(@"Settings data was: %@", plData);
	}
	
	// Finish up
	[plData release];
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
		NSDictionary* settingData = [originalPlist objectForKey: class];
		
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
	if (originalPlist) [originalPlist release];
	originalPlist = nil;
	
	// Parse the plist into a dictionary
	NSString* error = nil;
	NSPropertyListFormat fmt = NSPropertyListXMLFormat_v1_0;
	NSDictionary* plist = [NSPropertyListSerialization propertyListFromData: plData
														   mutabilityOption: NSPropertyListMutableContainersAndLeaves
																	 format: &fmt
														   errorDescription: &error];
	
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
