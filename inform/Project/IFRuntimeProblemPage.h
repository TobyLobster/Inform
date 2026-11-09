//
//  IFRuntimeProblemPage.h
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// The page explaining a run-time problem that a story reported. A story that names no folder for the problem has one
/// of the app's own pages, RTP_ and the problem's name, or failing that RTP_Unknown. Otherwise the page is made from
/// the problem's markdown file in that folder, which is given in Inform's internal files (Internal/), in the project's
/// materials (Materials/), or in full.
///
@interface IFRuntimeProblemPage : NSObject

- (instancetype) init NS_UNAVAILABLE;
/// The page for a problem, and the folder the story named for it, if any
- (instancetype) initWithProblem: (NSString*) problem
                     inDirectory: (nullable NSString*) directory
              materialsDirectory: (nullable NSString*) materialsDirectory
               internalDirectory: (NSString*) internalDirectory NS_DESIGNATED_INITIALIZER;

/// The app's own page, for a problem with no folder, or nil
@property (atomic, readonly, nullable) NSURL* appPageURL;
/// The markdown file to make the page from, for a problem with a folder, or nil
@property (atomic, readonly, nullable) NSString* markdownPath;

@end

NS_ASSUME_NONNULL_END
