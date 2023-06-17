//
//  IFInBuild.h
//  Inform
//
//  Created by Toby Nelson in 2023
//

#import <Foundation/Foundation.h>

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
                                version: (NSString*) compilerVersion;

@end
