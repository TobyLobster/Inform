//
//  IFMiscSettings.m
//  Inform
//
//  Created by Andrew Hunter on 10/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import "IFMiscSettings.h"
#import "IFUtility.h"
#import "IFCompilerSettings.h"

@implementation IFMiscSettings {
    IBOutlet NSButton* strictMode;
    IBOutlet NSButton* infixMode;
    IBOutlet NSButton* debugMode;
}

- (instancetype) init {
	return [self initWithNibName: @"MiscSettings"];
}

- (NSString*) title {
	return [IFUtility localizedString: @"Misc Settings"];
}

// = Setting up =

- (void) updateFromCompilerSettings {
    [strictMode setState: [self strict]?NSOnState:NSOffState];
    [infixMode setState: [self infix]?NSOnState:NSOffState];
    [debugMode setState: [self debug]?NSOnState:NSOffState];
	
	if ([[self compilerSettings] usingNaturalInform]) {
		[infixMode setEnabled: NO];
		[infixMode setState: NSOffState];
		[self dictionary][IFSettingInfix] = @NO;
	} else {
		[infixMode setEnabled: YES];
	}
}

- (void) setSettings {
	[self setStrict: [strictMode state]==NSOnState];
	[self setInfix: [infixMode state]==NSOnState];
	[self setDebug: [debugMode state]==NSOnState];
}

// = The settings =

- (void) setStrict: (BOOL) setting {
    [self dictionary][IFSettingStrict] = @(setting);
    [self settingsHaveChanged: self];
}

- (BOOL) strict {
    NSNumber* setting = [self dictionary][IFSettingStrict];
	
    if (setting) {
        return [setting boolValue];
    } else {
        return YES;
    }
}

- (void) setInfix: (BOOL) setting {
    [self dictionary][IFSettingInfix] = @(setting);
    [self settingsHaveChanged: self];
}

- (BOOL) infix {
    NSNumber* setting = [self dictionary][IFSettingInfix];
	
    if (setting) {
        return [setting boolValue];
    } else {
        return NO;
    }
}

- (void) setDebug: (BOOL) setting {
    [self dictionary][IFSettingDEBUG] = @(setting);
    [self settingsHaveChanged: self];
}

- (BOOL) debug {
    NSNumber* setting = [self dictionary][IFSettingDEBUG];
	
    if (setting) {
        return [setting boolValue];
    } else {
        return YES;
    }
}

- (BOOL) enableForCompiler: (NSString*) compiler {
	// These settings are unsafe to change while using Natural Inform
	if ([compiler isEqualToString: IFCompilerNaturalInform])
		return NO;
	else
		return YES;
}

@end
