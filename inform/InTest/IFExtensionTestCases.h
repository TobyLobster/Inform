//
//  IFExtensionTestCases.h
//  Inform
//
//  Moved out of IFProject in November 2026.
//

#import <Foundation/Foundation.h>

@class IFInTest;

NS_ASSUME_NONNULL_BEGIN

///
/// An extension project's test cases: the examples in its extension's documentation, as intest finds them. A test case
/// is tested by writing its source out as the project's story, compiling it and giving it the test case's commands.
/// intest reports on each test case tested, and combines the reports when they're all done.
///
NS_SWIFT_UI_ACTOR
@interface IFExtensionTestCases : NSObject

- (instancetype) init NS_DESIGNATED_INITIALIZER;

/// Runs intest, which keeps where each test case written out came from in the extension
@property (atomic, readonly, strong) IFInTest *inTest;
/// The test cases, each with its key and title; nil until they're refreshed
@property (atomic, readonly, strong, nullable) NSArray<NSDictionary<NSString*, id>*> *testCases;

/// Finds the test cases of the extension at the path given. There are none without one.
- (void) refreshTestCasesForExtension: (nullable NSString*) extensionPathName;
/// Writes out the source of a test case, from the extension at the path given, to the source file given. Nothing is
/// written without a test case.
- (void) extractSourceTaskForExtensionTestCase: (nullable NSString*) testCase
                                 fromExtension: (NSString*) extensionPathName
                            outputToSourceFile: (NSString*) sourcePathName;
/// A link to a problem in a test case's story ({ file, test case, line }), as an extension project's problems give one,
/// redirected to the extension's source ({ file, line }): the story's line becomes the extension's line it came from,
/// as the test case was last written out. Other links in three parts, and those of a project that isn't an extension
/// project, only lose their test case; the rest are returned as they are.
- (NSArray*) redirectLinksToExtensionSourceCode: (NSArray*) link
                             inExtensionProject: (BOOL) isExtensionProject;

/// The commands to test a test case with; nil if intest fails
- (nullable NSArray<NSString*>*) testCommandsForExtensionTestCase: (NSString*) testCase
                                                      ofExtension: (NSString*) extensionPathName;

/// Where the reports on the test cases go, which intest combines: each test case's report is numbered after this one's
/// name
@property (class, atomic, readonly) NSURL *baseReportURL;
/// Where the report on the test case at the index given goes
+ (NSURL*) reportURLForTestCaseAtIndex: (NSInteger) index NS_SWIFT_NAME(reportURL(forTestCaseAt:));

/// Writes intest's report on a test case to the URL given; NO, logging intest's exit code, if it couldn't
- (BOOL) generateReportForTestCase: (NSString*) testCase
                       ofExtension: (NSString*) extensionPathName
                         errorCode: (NSString*) errorCode
                       problemsURL: (NSURL*) problemsURL
                       skeinNodeId: (unsigned long) skeinNodeId
                        skeinNodes: (int) skeinNodes
                         outputURL: (NSURL*) outputURL;
/// Writes intest's combination of the reports on the test cases to the URL given; NO, logging intest's exit code, if
/// it couldn't
- (BOOL) generateCombinedReportForBaseInputURL: (NSURL*) baseInputURL
                                   ofExtension: (NSString*) extensionPathName
                                      numTests: (int) numTests
                                     outputURL: (NSURL*) outputURL;

@end

NS_ASSUME_NONNULL_END
