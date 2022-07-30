//
//  IFBasicInformSettings.m
//  Inform
//
//  Created by Toby Nelson on 25/05/2022.
//  Copyright 2022 Toby Nelson. All rights reserved.
//

#import "IFBasicInformSettings.h"
#import "IFUtility.h"
#import "IFCompilerSettings.h"

@implementation IFBasicInformSettings {
    IBOutlet NSButton* basicInform;
}

- (instancetype) init {
	return [self initWithNibName: @"BasicInformSettings"];
}

- (NSString*) title {
	return [IFUtility localizedString: @"Basic Inform"];
}

#pragma mark - Setting up 

- (void) updateFromCompilerSettings {
    IFCompilerSettings* settings = [self compilerSettings];
	
	[basicInform setState: [settings basicInform]?NSControlStateValueOn:NSControlStateValueOff];
}

- (void) setSettings {
    IFCompilerSettings* settings = [self compilerSettings];

	[settings setBasicInform: [basicInform state] == NSControlStateValueOn];
}

- (BOOL) enableForCompiler: (NSString*) compiler {
	// These settings only apply to Natural Inform
	if ([compiler isEqualToString: IFCompilerNaturalInform])
		return YES;
	else
		return NO;
}

@end
