//
//  IFProjectPanels.h
//  Inform
//
//  Moved out of IFProject in November 2026.
//

#import <AppKit/AppKit.h>

@class IFProject;

NS_ASSUME_NONNULL_BEGIN

///
/// The panels a project's window shows as sheets: to save a copy of the iFiction record, the compiler's output or an
/// extension project's extension, and to choose a recording, skein or Zoom saved game to import into the skein shown.
/// Each shows an alert if the file couldn't be saved or read.
///
NS_SWIFT_UI_ACTOR
@interface IFProjectPanels : NSObject

- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithProject: (IFProject*) project NS_DESIGNATED_INITIALIZER;

/// Asks where to save a copy of the iFiction record, or says that the compiler didn't make one
- (void) saveIFictionWithWindow: (NSWindow*) window;
/// Asks where to save a copy of the compiler's output, offering to try again if it couldn't be saved
- (void) saveCompilerOutputWithWindow: (NSWindow*) window;
/// Saves an extension project, then asks where to save a copy of its extension; nothing for another project
- (void) exportExtensionWithWindow: (NSWindow*) window;
/// Asks for a recording, skein or Zoom saved game to import into the skein shown
- (void) importIntoSkeinWithWindow: (NSWindow*) window;

@end

NS_ASSUME_NONNULL_END
