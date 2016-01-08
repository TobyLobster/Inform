//
//  IFNewEmptyInform6Project.m
//  Inform
//
//  Created by Andrew Hunter on Sat Sep 13 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "IFNewEmptyInform6Project.h"
#import "IFUtility.h"
#import "IFProjectFile.h"

@implementation IFNewEmptyInform6Project

- (NSObject<IFNewProjectSetupView>*) configView {
    return nil;
}

- (void) setInitialFocus:(NSWindow *)window {
    // Nothing to do
}

- (void) setupFile: (IFProjectFile*) file
          fromView: (NSObject<IFNewProjectSetupView>*) view
         withStory: (NSString*) story
  withExtensionURL: (NSURL*) extensionURL {
    [file addSourceFile: @"main.inf"];
}

-(NSRange) initialSelectionRange {
    return NSMakeRange(0, 0);
}

-(NSString*) typeName {
    return @"org.inform-fiction.project";
}

@end
