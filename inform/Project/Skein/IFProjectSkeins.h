//
//  IFProjectSkeins.h
//  Inform
//
//  Moved out of IFProject in November 2026.
//

#import <Foundation/Foundation.h>

@class IFProject;
@class IFProjectFile;
@class IFSkein;

NS_ASSUME_NONNULL_BEGIN

///
/// A project's skeins, and the one shown. A project has a skein, and an extension project one for each of its test
/// cases, titled with the test case's title, with none shown until a test case is chosen. The skeins are made for the
/// project, which they mark as edited, and they use its undo manager.
///
NS_SWIFT_UI_ACTOR
@interface IFProjectSkeins : NSObject

- (instancetype) init NS_UNAVAILABLE;
/// The skeins of the project given, which holds them. Until they're read, a skein that isn't one of them is shown.
- (instancetype) initWithProject: (nullable IFProject*) project NS_DESIGNATED_INITIALIZER;

@property (atomic, readonly, strong) NSMutableArray<IFSkein*> *skeins;
/// The skein shown; nil for none
@property (atomic, readonly, strong, nullable) IFSkein *currentSkein;

/// Shows the skein at the index given, made if there isn't one yet, or none for an index below 0. Showing another
/// skein, or none, takes the old one's actions off the undo stack. Showing another titles the skeins with the
/// project's test cases, and posts IFSkeinReplacedNotification from the project, as showing none always does.
- (void) selectSkein: (int) index;
/// Reads the skeins from the project's files, in place of any read before, as by Revert To Saved, and shows a project's
/// first skein, or none of an extension project's
- (void) loadSkeinsFromProjectFile: (nullable IFProjectFile*) projectFile
                isExtensionProject: (BOOL) isExtensionProject
    NS_SWIFT_NAME(loadSkeins(from:isExtensionProject:));

#pragma mark - Importing
/// A skein of the commands in a recording (a .rec or .txt file), as Import Into Skein makes one;
/// nil if the file doesn't look like a recording
- (nullable IFSkein*) skeinFromRecording: (NSString*) path;
/// Adds the threads of a recording (.rec or .txt), a skein (.skein) or a Zoom saved game (.zoomSave) to the skein shown,
/// as Import Into Skein does. nil once they're added, or else why the file couldn't be read.
- (nullable NSString*) importIntoCurrentSkeinFromFile: (NSString*) path;

@end

NS_ASSUME_NONNULL_END
