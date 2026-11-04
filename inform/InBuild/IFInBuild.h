//
//  IFInBuild.h
//  Inform
//
//  Created by Toby Nelson in 2023
//

#import <Foundation/Foundation.h>
#import "IFCompilerSettings.h"

NS_ASSUME_NONNULL_BEGIN

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

/// What inbuild wrote to stdout on its last run; nil before the first run, or if it wasn't UTF-8
@property (nonatomic,readonly,nullable) NSMutableString* stdOut;
/// What inbuild wrote to stderr on its last run; nil before the first run, or if it wasn't UTF-8
@property (nonatomic,readonly,nullable) NSMutableString* stdErr;

@end

NS_ASSUME_NONNULL_END
