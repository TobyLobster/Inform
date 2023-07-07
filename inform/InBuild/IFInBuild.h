//
//  IFInBuild.h
//  Inform
//
//  Created by Toby Nelson in 2023
//

#import <Foundation/Foundation.h>
#import "IFCompilerSettings.h"

extern NSNotificationName const IFInBuildStartingNotification;
extern NSNotificationName const IFInBuildStdoutNotification;
extern NSNotificationName const IFInBuildStderrNotification;
extern NSNotificationName const IFInBuildFinishedNotification;

//
// Class that handles actually running InBuild
//
@interface IFInBuild : NSObject

-(int) executeInBuildForInfoWithProject: (NSURL*) projectURL
                           forExtension: (NSURL*) extensionURL
                           withInternal: (NSURL*) internalURL
                       withConfirmation: (bool) confirmed
                            withResults: (NSURL*) resultsURL
                               settings: (IFCompilerSettings*) settings;

-(int) executeInBuildForCensus;

@property (readonly) NSMutableString* stdOut;
@property (readonly) NSMutableString* stdErr;

@end

