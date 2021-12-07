//
//  IFLibrarySettings.m
//  Inform
//
//  Created by Andrew Hunter on 10/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import "IFLibrarySettings.h"
#import "IFUtility.h"
#import "IFCompilerSettings.h"

@implementation IFLibrarySettings {
    IBOutlet NSPopUpButton* libraryVersion;
}

- (instancetype) init {
	return [self initWithNibName: @"LibrarySettings"];
}

- (NSString*) title {
	return [IFUtility localizedString: @"Library Settings"
                              default: @"Library Settings"];
}

#pragma mark - Setting up

- (void) updateFromCompilerSettings {
    IFCompilerSettings* settings = [self compilerSettings];

    // Library versions
	NSArray* libraryDirectory = [IFCompilerSettings availableLibraries];
    
    NSString* currentLibVer = [settings libraryToUse];
    
    [libraryVersion removeAllItems];
    
    for( NSString* libVer in [libraryDirectory objectEnumerator] ) {
        [libraryVersion addItemWithTitle: libVer];
        
        if ([libVer isEqualToString: currentLibVer]) {
            [libraryVersion selectItemAtIndex: [libraryVersion numberOfItems]-1];
        }
    }
}

- (void) setSettings {
    IFCompilerSettings* settings = [self compilerSettings];

	[settings setLibraryToUse: [libraryVersion itemTitleAtIndex: [libraryVersion indexOfSelectedItem]]];
}

- (BOOL) enableForCompiler: (NSString*) compiler {
	// These settings are unsafe to change while using Natural Inform
	if ([compiler isEqualToString: IFCompilerNaturalInform])
		return NO;
	else
		return YES;
}

@end
