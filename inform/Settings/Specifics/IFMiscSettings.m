//
//  IFMiscSettings.m
//  Inform
//
//  Created by Andrew Hunter on 10/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import "IFMiscSettings.h"
#import "IFUtility.h"

@implementation IFMiscSettings

- (id) init {
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
		[[self dictionary] setObject: [NSNumber numberWithBool: NO]
							  forKey: IFSettingInfix];
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
    [[self dictionary] setObject: [NSNumber numberWithBool: setting]
						  forKey: IFSettingStrict];
    [self settingsHaveChanged: self];
}

- (BOOL) strict {
    NSNumber* setting = [[self dictionary] objectForKey: IFSettingStrict];
	
    if (setting) {
        return [setting boolValue];
    } else {
        return YES;
    }
}

- (void) setInfix: (BOOL) setting {
    [[self dictionary] setObject: [NSNumber numberWithBool: setting]
						  forKey: IFSettingInfix];
    [self settingsHaveChanged: self];
}

- (BOOL) infix {
    NSNumber* setting = [[self dictionary] objectForKey: IFSettingInfix];
	
    if (setting) {
        return [setting boolValue];
    } else {
        return NO;
    }
}

- (void) setDebug: (BOOL) setting {
    [[self dictionary] setObject: [NSNumber numberWithBool: setting]
						  forKey: IFSettingDEBUG];
    [self settingsHaveChanged: self];
}

- (BOOL) debug {
    NSNumber* setting = [[self dictionary] objectForKey: IFSettingDEBUG];
	
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
