//
//  IFInTest.h
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <Foundation/Foundation.h>

extern NSString* IFInTestStartingNotification;
extern NSString* IFInTestStdoutNotification;
extern NSString* IFInTestStderrNotification;
extern NSString* IFInTestFinishedNotification;

@class IFProgress;

//
// Class that handles actually running InTest
//
@interface IFInTest : NSObject

- (NSArray*) refreshExtensionCatalogue: (NSString*) extensionPathName;

-(void) extractSourceTaskForExtensionFile: (NSString*) extensionPathName
                              forTestCase: (NSString*) testCase
                       outputToSourceFile: (NSString*) sourcePathName;

-(int) adjustLine:(int) lineNumber forTestCase:(NSString*) testCase;

// Return an array of commands to test the given extension and test case.
- (NSString*) testCommandsForExtension: (NSString*) extensionPathName
                              testCase: (NSString*) testCase;

// Outputs an HTML report for the specified test case
- (int) generateReportForExtension: (NSString*) extensionPathName
                          testCase: (NSString*) testCase
                         errorCode: (NSString*) errorCode
                       problemsURL: (NSURL*) problemsURL
                          skeinURL: (NSURL*) skeinURL
                       skeinNodeId: (unsigned long) skeinNodeId
                        skeinNodes: (int) skeinNodes
                         outputURL: (NSURL*) outputURL;

// Outputs an HTML report that combinines the individual reports
- (int) generateCombinedReportForExtension: (NSString*) extensionPathName
                              baseInputURL: (NSURL*) baseInputURL
                                  numTests: (int) numTests
                                 outputURL: (NSURL*) outputURL;


@end
