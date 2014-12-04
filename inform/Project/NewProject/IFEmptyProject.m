//
//  IFEmptyProject.m
//  Inform
//
//  Created by Andrew Hunter on Sat Sep 13 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "IFEmptyProject.h"
#import "IFUtility.h"

@implementation IFEmptyProject

- (NSObject<IFProjectSetupView>*) configView {
    return nil;
}

- (void) setInitialFocus:(NSWindow *)window {
    // Nothing to do
}

- (void) setupFile: (IFProjectFile*) file
          fromView: (NSObject<IFProjectSetupView>*) view
         withStory: (NSString*) story {
    [file addSourceFile: @"main.inf"];
}

-(NSRange) initialSelectionRange {
    return NSMakeRange(0, 0);
}

@end
