//
//  IFCompilerResultFiles.h
//  Inform
//
//  Moved out of IFCompilerController in November 2026.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// List of tabs
typedef NS_ENUM(unsigned int, IFCompilerTabId) {
    IFTabReport,
    IFTabConsole,
    IFTabDebugging,
    IFTabInform6,
    IFTabRuntime,
    IFTabInBuild,
    IFTabInvalid,
};

///
/// The files in a build folder that the Errors page shows a tab for once the compiler has run, and the tab each one is.
///
@interface IFCompilerResultFiles : NSObject

- (instancetype) init NS_UNAVAILABLE;

/// The tab for a file of results, by its name in any case, or IFTabInvalid for a file without one of its own
+ (IFCompilerTabId) tabIdForFile: (NSString*) file;

/// The files to show tabs for, of those in a build folder: Inform 6 files, text files and web pages, leaving out
/// temporary files, the debugging logs unless they're to be shown, and the problems page when the compiler gave one
+ (NSArray<NSString*>*) filesToShowOf: (NSArray<NSString*>*) files
                    showDebuggingLogs: (BOOL) showDebuggingLogs
                          problemsURL: (nullable NSURL*) problemsURL
    NS_SWIFT_NAME(filesToShow(of:showDebuggingLogs:problemsURL:));

@end

NS_ASSUME_NONNULL_END
