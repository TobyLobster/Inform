//
//  IFRandomSettings.m
//  Inform
//
//  Created by Andrew Hunter on 17/09/2009.
//  Copyright 2009 Andrew Hunter. All rights reserved.
//

#import "IFRandomSettings.h"
#import "IFUtility.h"
#import "IFCompilerSettings.h"

@implementation IFRandomSettings {
    IBOutlet NSButton* makePredictable;
}

- (instancetype) init {
	return [self initWithNibName: @"RandomSettings"];
}

- (NSString*) title {
	return [IFUtility localizedString: @"Randomness Settings"];
}

#pragma mark - Setting up 

- (void) updateFromCompilerSettings {
    IFCompilerSettings* settings = self.compilerSettings;
	
	makePredictable.state = settings.nobbleRng?NSControlStateValueOn:NSControlStateValueOff;
}

- (void) setSettings {
    IFCompilerSettings* settings = self.compilerSettings;

	settings.nobbleRng = makePredictable.state == NSControlStateValueOn;
}

- (BOOL) enableForCompiler: (NSString*) compiler {
	// These settings only apply to Natural Inform
	if ([compiler isEqualToString: IFCompilerNaturalInform])
		return YES;
	else
		return NO;
}

@end
