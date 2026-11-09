//
//  IFCompileCheck.h
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Decides whether a project must be compiled before its story is used, remembering what the project's files can't
/// show: whether its test case has changed since the last successful compile
///
@interface IFCompileCheck : NSObject

/// The test case has changed, so the next compile can't be skipped
- (void) testCaseDidChange;
/// A compile has succeeded, so the story is for the current test case
- (void) compileDidSucceed;

/// Whether the project must be compiled: always when forced, when the Always Compile preference is on, when the
/// project has unsaved changes, or when the test case has changed since the last successful compile; and otherwise
/// when its source or settings were changed after its story was written, or any of the three is missing
- (BOOL) needsCompileForcing: (BOOL) force
               alwaysCompile: (BOOL) alwaysCompile
              unsavedChanges: (BOOL) unsavedChanges
                   sourceURL: (nullable NSURL*) sourceURL
                 settingsURL: (nullable NSURL*) settingsURL
                   outputURL: (nullable NSURL*) outputURL;

@end

NS_ASSUME_NONNULL_END
