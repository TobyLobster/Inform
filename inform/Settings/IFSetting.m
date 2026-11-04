//
//  IFSetting.m
//  Inform
//
//  Created by Andrew Hunter on 06/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import "IFSetting.h"
#import "NSBundle+IFBundleExtensions.h"
#import "IFCompilerSettings.h"

NSString* const IFSettingHasChangedNotification = @"IFSettingHasChangedNotification";
NSString* const IFSettingCreateBlorb = @"IFSettingCreateBlorb";

@implementation IFSetting {
    /// The view that can be used to edit the settings
    NSView*             settingView;
    /// The compiler settings object that this setting should manage
    __weak IFCompilerSettings* compilerSettings;
    /// YES if the settings are in the process of changing
    BOOL                settingsChanging;
}

#pragma mark - Initialisation

- (instancetype) init {
	return [self initWithNibName: nil];
}

- (instancetype) initWithNibName: (NSString*) nibName {
	self = [super init];
	
	if (self) {
		settingView = nil;
		settingsChanging = NO;
		
		if (nibName != nil)
			[NSBundle customLoadNib: nibName
                              owner: self];
	}
	
	return self;
}


#pragma mark - Setting up the view

@synthesize settingView;

- (NSString*) title {
	return @"Setting";
}

#pragma mark - Setting/retrieving the model

@synthesize compilerSettings;

#pragma mark - Communicating with the IFCompilerSettings object

- (void) setSettings {
	// Do nothing
}

- (void) updateFromCompilerSettings {
	// Do nothing
}

- (BOOL) enableForCompiler: (NSString*) compiler {
	return YES;
}

- (NSMutableDictionary*) dictionary {
	if (compilerSettings) {
		return [compilerSettings dictionaryForClass: [self class]];
	}
	
	return nil;
}

#pragma mark - Notifying the controller about things

- (IBAction) settingsHaveChanged: (id) sender {
	if (settingsChanging) return;
	
	settingsChanging = YES;
	[[NSNotificationCenter defaultCenter] postNotificationName: IFSettingHasChangedNotification
														object: self];
	settingsChanging = NO;
}

#pragma mark - Default way of dealing with the plist: copy entries from the dictionary

- (NSDictionary*) plistEntries {
	return [self dictionary];
}

- (void) updateSettings: (IFCompilerSettings*) settings
	   withPlistEntries: (NSDictionary*) entries {
	if (entries.allKeys.count <= 0) return; // nothing to do
	
	NSMutableDictionary* dict = [self dictionary];
	
	if (entries == dict) return; // Really, just sanity checking: this shouldn't happen
	
	[dict removeAllObjects];
	
	// Load entries from the list of entries
	for( NSString* key in entries ) {
		dict[key] = entries[key];
	}
	
	// Cause the settings to be updated
	[self updateFromCompilerSettings];
}

@end
