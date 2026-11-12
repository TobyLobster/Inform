//
//  IFLineStarts.h
//  Inform
//
//  Moved out of IFSyntaxData in November 2026.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Where each line of a text starts, kept in step with edits to the text. Each newline and each return ends a line, so
/// a return followed by a newline ends two. There's always at least one line, and the first starts at 0.
///
@interface IFLineStarts : NSObject

/// The lines of an empty text: one, starting at 0
- (instancetype) init NS_DESIGNATED_INITIALIZER;

/// The number of lines
@property (nonatomic, readonly) NSInteger count;

/// Where a line starts
- (NSInteger) startOfLine: (NSInteger) line NS_SWIFT_NAME(start(ofLine:));
/// The line that the character at an index is on. An index at or past the end of the text is on the last line.
- (NSInteger) lineForIndex: (NSInteger) index NS_SWIFT_NAME(line(forIndex:));

/// Updates the lines for an edit. The lines after firstLine, up to and including lastLine, are replaced by a line for
/// each line end in newText, which the edit put at location, and the lines after them move by changeInLength. Returns
/// the number of lines put in.
- (NSInteger) replaceLinesAfter: (NSInteger) firstLine
                        through: (NSInteger) lastLine
                    withLinesIn: (NSString*) newText
                     atLocation: (NSInteger) location
                 changeInLength: (NSInteger) changeInLength
    NS_SWIFT_NAME(replaceLines(after:through:withLinesIn:at:changeInLength:));

@end

NS_ASSUME_NONNULL_END
