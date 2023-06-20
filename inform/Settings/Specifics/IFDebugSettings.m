//
//  IFDebugSettings.m
//  Inform
//
//  Created by Andrew Hunter on 10/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import "IFDebugSettings.h"
#import "IFUtility.h"
#import "IFCompilerSettings.h"
@implementation IFDebugSettings {
    IBOutlet NSButton* allowLegacyExtensionDirectory;
}

- (instancetype) init {
	return [self initWithNibName: @"DebugSettings"];
}

- (NSString*) title {
	return [IFUtility localizedString: @"Extensions Settings"];
}

#pragma mark - Setting up

- (void) updateFromCompilerSettings {
    IFCompilerSettings* settings = [self compilerSettings];
	
    [allowLegacyExtensionDirectory setState: [settings allowLegacyExtensionDirectory]?NSControlStateValueOn:NSControlStateValueOff];
}

- (void) setSettings {
    IFCompilerSettings* settings = [self compilerSettings];

	[settings setAllowLegacyExtensionDirectory: [allowLegacyExtensionDirectory state]==NSControlStateValueOn];
}

- (BOOL) enableForCompiler: (NSString*) compiler {
	return YES;
}

@end
