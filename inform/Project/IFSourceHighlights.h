//
//  IFSourceHighlights.h
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//

#import <Foundation/Foundation.h>
#import "IFProjectTypes.h"

NS_ASSUME_NONNULL_BEGIN

///
/// The lines highlighted in a project's source files, such as the line of a problem. Each file, by its full path, has
/// its highlights in the order they were made, each a line number and a style.
///
@interface IFSourceHighlights : NSObject

/// The files that have had highlights
@property (atomic, readonly, copy) NSArray<NSString*>* files;
/// Whether a temporary highlight has been made since the temporary highlights were last all removed
@property (atomic, readonly) BOOL hasTemporaryHighlights;

/// The highlights in a file, each its line and style, or nil if it's never had any
- (nullable NSArray<NSArray<NSNumber*>*>*) highlightsInFile: (nullable NSString*) file;
/// Highlights a line of a file in a style
- (void) highlightLine: (NSInteger) line
                inFile: (NSString*) file
                 style: (IFLineStyle) style;
/// Removes a file's highlights of a style, and says whether it had any
- (BOOL) removeHighlightsOfStyle: (IFLineStyle) style
                          inFile: (nullable NSString*) file NS_SWIFT_NAME(removeHighlights(of:inFile:));
/// Notes that the temporary highlights have all been removed
- (void) temporaryHighlightsWereRemoved;

@end

NS_ASSUME_NONNULL_END
