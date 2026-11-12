//
//  IFLineStyles.h
//  Inform
//
//  Moved out of IFSyntaxData in November 2026.
//

#import <Cocoa/Cocoa.h>
#import "IFSyntaxTypes.h"

@class IFLineStarts;

NS_ASSUME_NONNULL_BEGIN

///
/// The paragraph style of each line of a text, kept in step with edits to the text and put onto the text as it's
/// highlighted. A line has the standard style, with the standard tab stops for the highlighter's tab width, until
/// elastic tabs give the lines of a table the tab stops of its columns.
///
NS_SWIFT_UI_ACTOR
@interface IFLineStyles : NSObject

- (instancetype) init NS_UNAVAILABLE;
/// The styles of a text of one line, which has no style yet. The tab stops are for the highlighter's tab width.
- (instancetype) initWithText: (NSTextStorage*) text
                   lineStarts: (IFLineStarts*) lineStarts
                  highlighter: (nullable id<IFSyntaxHighlighter>) highlighter NS_DESIGNATED_INITIALIZER;

/// The number of lines whose styles are kept
@property (nonatomic, readonly) NSInteger count;
/// A line's style, as the attributes it gives the line's text
- (NSDictionary<NSAttributedStringKey, id>*) styleOfLine: (NSInteger) line NS_SWIFT_NAME(style(ofLine:));
/// Forgets the standard style, which is made again when it's next needed, as when the tab width may have changed
- (void) forgetStandardStyle;

/// Keeps the styles in step with an edit that replaced the lines after one line, up to and including another, with a
/// number of new lines. With fewer new lines than old, the first old lines' styles go, and the new lines keep the
/// rest; otherwise the old lines' styles go, and the new lines have the standard style.
- (void) replaceLinesAfter: (NSInteger) firstLine
                   through: (NSInteger) lastLine
                 withLines: (NSInteger) count
    NS_SWIFT_NAME(replaceLines(after:through:with:));
/// Gives a line the standard style
- (void) resetLine: (NSInteger) line NS_SWIFT_NAME(resetLine(_:));
/// Puts the lines' styles onto the text, from one line through another
- (void) applyStylesFromLine: (NSInteger) firstLine
                     through: (NSInteger) lastLine
    NS_SWIFT_NAME(applyStyles(from:through:));
/// Gives the lines of each table within a line of the lines given the tab stops of its columns, in their styles and on
/// the text, skipping lines that have them already unless all are to be updated. Returns the range given, extended over
/// each table laid out.
- (NSRange) layOutTablesNearLinesFrom: (NSInteger) firstLine
                              through: (NSInteger) lastLine
                          updatingAll: (BOOL) updateAll
                         changedRange: (NSRange) changedRange
    NS_SWIFT_NAME(layOutTables(nearLinesFrom:through:updatingAll:changedRange:));

@end

NS_ASSUME_NONNULL_END
