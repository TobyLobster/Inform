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

#pragma mark - Setting up

- (void) updateFromCompilerSettings {
    strictMode.state = self.strict?NSControlStateValueOn:NSControlStateValueOff;
    infixMode.state = self.infix?NSControlStateValueOn:NSControlStateValueOff;
    debugMode.state = self.debug?NSControlStateValueOn:NSControlStateValueOff;
	
	if (self.compilerSettings.usingNaturalInform) {
		[infixMode setEnabled: NO];
		infixMode.state = NSControlStateValueOff;
		[self dictionary][IFSettingInfix] = @NO;
	} else {
		[infixMode setEnabled: YES];
	}
}

- (void) setSettings {
	self.strict = strictMode.state==NSControlStateValueOn;
	self.infix = infixMode.state==NSControlStateValueOn;
	self.debug = debugMode.state==NSControlStateValueOn;
}

#pragma mark - The settings

- (void) setStrict: (BOOL) setting {
    [self dictionary][IFSettingStrict] = @(setting);
    [self settingsHaveChanged: self];
}

- (BOOL) strict {
    NSNumber* setting = [self dictionary][IFSettingStrict];
	
    if (setting) {
        return setting.boolValue;
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
        return setting.boolValue;
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
        return setting.boolValue;
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
