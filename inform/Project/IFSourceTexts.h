//
//  IFSourceTexts.h
//  Inform
//
//  Moved out of IFProject in November 2026.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

///
/// The texts of a project's source files, as the Source page shows and edits them. Each text is registered with the
/// syntax manager, which highlights it, until the project is done with it.
///
NS_SWIFT_UI_ACTOR
@interface IFSourceTexts : NSObject

/// No texts, until the source files are read
- (instancetype) init NS_DESIGNATED_INITIALIZER;

/// The text of each file in the Source folder, by name; nil until the folder is read
@property (nonatomic, readonly, copy, nullable) NSDictionary<NSString*, NSTextStorage*>* texts;

/// Reads each file in a Source folder into a text, whose edits are undone with an undo manager. A file read before
/// keeps its text, given the file's contents, as the pages show it, and the texts of files that have gone are
/// unregistered.
- (void) readSourceDirectory: (NSFileWrapper*) sourceDirectory
                 undoManager: (nullable NSUndoManager*) undoManager
    NS_SWIFT_NAME(read(sourceDirectory:undoManager:));
/// Writes each text into a Source folder, in place of any file of its name: as RTF for an RTF file, and otherwise in
/// UTF-8
- (void) writeIntoSourceDirectory: (nullable NSFileWrapper*) sourceDirectory NS_SWIFT_NAME(write(into:));
/// Unregisters the texts, as the project closes, and lets go of those read from the disk for other files
- (void) unregisterTexts;

/// The text of a file: one of the texts, for a file in the Source folder, by its name or its path; otherwise a new text
/// read from the disk, for a file in a folder within the Source folder, or in the project's folder by its path relative
/// to it, if there's no such file in the Source folder. nil for no file, for a file outside the Source folder by its
/// path, or for one that isn't there. With no project's URL, a file by its name has no text, and one by its path is
/// read from the disk.
- (nullable NSTextStorage*) textForFile: (nullable NSString*) file
                              inProject: (nullable NSURL*) projectURL
                            undoManager: (nullable NSUndoManager*) undoManager
    NS_SWIFT_NAME(text(forFile:inProjectAt:undoManager:));

@end

NS_ASSUME_NONNULL_END
