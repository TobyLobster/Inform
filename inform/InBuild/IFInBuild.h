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
                                 action: (NSString*) action
                           forExtension: (NSURL*) extensionURL
                           withInternal: (NSURL*) internalURL
                       withConfirmation: (bool) confirmed
                            withResults: (NSURL*) resultsURL
                               settings: (IFCompilerSettings*) settings;

-(int) executeInBuildForCensus;
-(int) executeInBuildForConvertingMarkdown: (NSString*) markdownFilepath
                                    toHTML: (NSString*) htmlFilepath
                              withInternal: (NSURL*) internalURL
                                  settings: (IFCompilerSettings*) settings;

@property (nonatomic,readonly) NSMutableString* stdOut;
@property (nonatomic,readonly) NSMutableString* stdErr;

@end

