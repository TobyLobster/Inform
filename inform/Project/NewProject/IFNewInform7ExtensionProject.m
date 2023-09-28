//
//  IFNewInform7ExtensionProject.m
//  Inform
//
//  Created by Toby Nelson in 2015

#import "IFNewInform7ExtensionProject.h"
#import "IFPreferences.h"
#import "IFUtility.h"
#import "IFProjectFile.h"
#import "IFCompilerSettings.h"

@implementation IFNewInform7ExtensionProject {
    NSRange initialSelectionRange;
}

- (instancetype) init {
    self = [super init];
    if( self != nil ) {
        initialSelectionRange = NSMakeRange(0, 0);
    }
    return self;
}

- (NSObject<IFNewProjectSetupView>*) configView {
    return nil;
}

- (void) setInitialFocus:(NSWindow *)window {
    // Nothing to do
}

- (void) setupFile: (IFProjectFile*) file
          fromView: (NSObject<IFNewProjectSetupView>*) view
         withStory: (NSString*) story
  withExtensionURL: (NSURL*) extensionURL
{
    IFCompilerSettings* settings = [[IFCompilerSettings alloc] init];

    [settings setUsingNaturalInform: YES];
    [settings setAllowLegacyExtensionDirectory: NO];
    file.settings = settings;

    // Read extension source
    NSData* data = [NSData dataWithContentsOfURL: extensionURL];

    // Create the extension file
    [file addSourceFile: @"extension.i7x"
           withContents: data];
}

-(NSRange) initialSelectionRange {
    return initialSelectionRange;
}

-(NSString*) typeName {
    return @"org.inform-fiction.xproject";
}

@end
