//
//  IFSetting.m
//  Inform
//
//  Created by Andrew Hunter on 06/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import "IFSetting.h"
#import "NSBundle+IFBundleExtensions.h"


NSString* IFSettingHasChangedNotification = @"IFSettingHasChangedNotification";

@implementation IFSetting

// = Initialisation =

- (id) init {
	return [self initWithNibName: nil];
}

- (id) initWithNibName: (NSString*) nibName {
	self = [super init];
	
	if (self) {
		settingView = nil;
		settingsChanging = NO;
		
		if (nibName != nil)
			[NSBundle oldLoadNibNamed: nibName
                                owner: self];
	}
	
	return self;
}

- (void) dealloc {
	if (settingView) [settingView release];
	[super dealloc];
}

// = Setting up the view =

- (NSView*) settingView {
	return settingView;
}

- (void) setSettingView: (NSView*) newSettingView {
	if (settingView) [settingView release];
	settingView = [newSettingView retain];
}

- (NSString*) title {
	return @"Setting";
}

// = Setting/retrieving the model =

- (void) setCompilerSettings: (IFCompilerSettings*) newSettings {
	compilerSettings = newSettings;
}

- (IFCompilerSettings*) compilerSettings {
	return compilerSettings;
}

// = Communicating with the IFCompilerSettings object =

- (void) setSettings {
	// Do nothing
}

- (void) updateFromCompilerSettings {
	// Do nothing
}

- (BOOL) enableForCompiler: (NSString*) compiler {
	return YES;
}

- (NSArray*) commandLineOptionsForCompiler: (NSString*) compiler {
	return nil;
}

- (NSArray*) includePathForCompiler: (NSString*) compiler {
	return nil;
}

- (NSMutableDictionary*) dictionary {
	if (compilerSettings) {
		return [compilerSettings dictionaryForClass: [self class]];
	}
	
	return nil;
}

// = Notifying the controller about things =

- (IBAction) settingsHaveChanged: (id) sender {
	if (settingsChanging) return;
	
	settingsChanging = YES;
	[[NSNotificationCenter defaultCenter] postNotificationName: IFSettingHasChangedNotification
														object: self];
	settingsChanging = NO;
}

// = Default way of dealing with the plist: copy entries from the dictionary =

- (NSDictionary*) plistEntries {
	return [self dictionary];
}

- (void) updateSettings: (IFCompilerSettings*) settings
	   withPlistEntries: (NSDictionary*) entries {
	if ([[entries allKeys] count] <= 0) return; // nothing to do
	
	NSMutableDictionary* dict = [self dictionary];
	
	if (entries == dict) return; // Really, just sanity checking: this shouldn't happen
	
	[dict removeAllObjects];
	
	// Load entries from the list of entries
	for( NSString* key in entries ) {
		[dict setObject: [entries objectForKey: key]
				 forKey: key];
	}
	
	// Cause the settings to be updated
	[self updateFromCompilerSettings];
}

@end
