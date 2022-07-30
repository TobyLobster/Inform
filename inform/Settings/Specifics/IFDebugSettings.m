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
    IBOutlet NSButton* donotCompileNaturalInform;
    IBOutlet NSButton* runBuildSh;
    IBOutlet NSButton* runLoudly;
    IBOutlet NSButton* debugMemory;
}

- (instancetype) init {
	return [self initWithNibName: @"DebugSettings"];
}

- (NSString*) title {
	return [IFUtility localizedString: @"Debug Settings"];
}

#pragma mark - Setting up

- (void) updateFromCompilerSettings {
    IFCompilerSettings* settings = [self compilerSettings];
	
	[donotCompileNaturalInform setState:
        (![settings compileNaturalInformOutput])?NSControlStateValueOn:NSControlStateValueOff];
    [runBuildSh setState: [settings runBuildScript]?NSControlStateValueOn:NSControlStateValueOff];
    [runLoudly setState: [settings loudly]?NSControlStateValueOn:NSControlStateValueOff];
	[debugMemory setState: [settings debugMemory]?NSControlStateValueOn:NSControlStateValueOff];
}

- (void) setSettings {
    IFCompilerSettings* settings = [self compilerSettings];

	[settings setRunBuildScript: [runBuildSh state]==NSControlStateValueOn];
	[settings setCompileNaturalInformOutput: [donotCompileNaturalInform state]!=NSControlStateValueOn];
	[settings setLoudly: [runLoudly state]==NSControlStateValueOn];
	[settings setDebugMemory: [debugMemory state]==NSControlStateValueOn];
}

- (BOOL) enableForCompiler: (NSString*) compiler {
	// These settings are presently permanently disabled
	return NO;
}

@end
