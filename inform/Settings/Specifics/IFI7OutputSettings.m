//
//  IFI7OutputSettings.m
//  Inform
//
//  Created by Andrew Hunter on 10/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import "IFI7OutputSettings.h"
#import "IFUtility.h"
#import "IFCompilerSettings.h"

@implementation IFI7OutputSettings {
    IBOutlet NSMatrix* zmachineVersion;
    IBOutlet NSButton* releaseBlorb;
}

- (instancetype) init {
	return [self initWithNibName: @"OutputSettingsI7"];
}

- (NSString*) title {
	return [IFUtility localizedString: @"Output Settings"];
}

#pragma mark - Setting up

- (BOOL) createBlorbForRelease {
    IFCompilerSettings* settings = self.compilerSettings;
	NSNumber* value = [settings dictionaryForClass: [self class]][IFSettingCreateBlorb];
	
    BOOL result;
    
	if (value)
		result = value.boolValue;
	else
		result = YES;
    
    return result;
}

- (void) setCreateBlorbForRelease: (BOOL) setting {
    IFCompilerSettings* settings = self.compilerSettings;
	
	[settings dictionaryForClass: [self class]][IFSettingCreateBlorb] = @(setting);
	[settings settingsHaveChanged];
}

- (void) updateFromCompilerSettings {
    IFCompilerSettings* settings = self.compilerSettings;

	// Supported Z-Machine versions
	NSArray* supportedZMachines = settings.supportedZMachines;
	
	for( NSCell* cell in zmachineVersion.cells ) {
		if (supportedZMachines == nil) {
			[cell setEnabled: YES];
		} else {
			if ([supportedZMachines containsObject: @((int) cell.tag)]) {
				[cell setEnabled: YES];
			} else {
				[cell setEnabled: NO];
			}
		}
	}
	
	// Selected Z-Machine version
    if ([zmachineVersion cellWithTag: settings.zcodeVersion] != nil) {
        [zmachineVersion selectCellWithTag: settings.zcodeVersion];
    } else {
        [zmachineVersion deselectAllCells];
    }
	
	// Whether or not we should generate a blorb file on release
	releaseBlorb.state = self.createBlorbForRelease?NSControlStateValueOn:NSControlStateValueOff;
}

- (void) setSettings {
	BOOL willCreateBlorb = releaseBlorb.state==NSControlStateValueOn;
    IFCompilerSettings* settings = self.compilerSettings;

	settings.zcodeVersion = (int) zmachineVersion.selectedCell.tag;
	self.createBlorbForRelease = willCreateBlorb;
}

- (BOOL) enableForCompiler: (NSString*) compiler {
	// These settings are unsafe to change while using Natural Inform
	if ([compiler isEqualToString: IFCompilerNaturalInform])
		return YES;
	else
		return NO;
}

@end
