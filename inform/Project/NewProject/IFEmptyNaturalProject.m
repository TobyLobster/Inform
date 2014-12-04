//
//  IFEmptyNaturalProject.m
//  Inform
//
//  Created by Andrew Hunter on Sat Sep 13 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "IFEmptyNaturalProject.h"
#import "IFPreferences.h"
#import "IFUtility.h"


@implementation IFEmptyNaturalProject

- (id) init {
    self = [super init];
    if( self != nil ) {
        initialSelectionRange = NSMakeRange(0, 0);
    }
    return self;
}

- (NSObject<IFProjectSetupView>*) configView {
    return nil;
}

- (void) setInitialFocus:(NSWindow *)window {
    // Nothing to do
}

- (void) setupFile: (IFProjectFile*) file
          fromView: (NSObject<IFProjectSetupView>*) view
         withStory: (NSString*) story {
    IFCompilerSettings* settings = [[IFCompilerSettings alloc] init];

    [settings setUsingNaturalInform: YES];
	[settings setLibraryToUse: @"Natural"];
    [file setSettings: [settings autorelease]];
	
    NSString* defaultContents = story;

	// Default file content
    if( !story ) {
        NSString* name = [[[file filename] lastPathComponent] stringByDeletingPathExtension];
        if ([name length] == 0 || name == nil) name = @"Untitled";
        
        NSString* longuserName = [[IFPreferences sharedPreferences] freshGameAuthorName];

        // If longusername contains a '.', then we have to enclose it in quotes
        BOOL needQuotes = NO;
        int x;
        for (x=0; x<[longuserName length]; x++) {
            if ([longuserName characterAtIndex: x] == '.') needQuotes = YES;
        }
        
        if (needQuotes) longuserName = [NSString stringWithFormat: @"\"%@\"", longuserName];
            
        // The contents of the file
        defaultContents = [NSString stringWithFormat: @"\"%@\" by %@\n\n", name, longuserName];

        initialSelectionRange = NSMakeRange([defaultContents length], [@"Example Location" length]);
        defaultContents = [defaultContents stringByAppendingString:@"Example Location is a room. "];
    }
    
	// Create the default file
    [file addSourceFile: @"story.ni" 
		   withContents: [defaultContents dataUsingEncoding: NSUTF8StringEncoding]];
}

-(NSRange) initialSelectionRange {
    return initialSelectionRange;
}

@end
