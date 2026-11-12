//
//  IFHighlighterState.h
//  Inform
//
//  Moved out of IFSyntaxData in November 2026.
//

#import <Cocoa/Cocoa.h>
#import "IFSyntaxTypes.h"

@class IFCharacterStyles;

NS_ASSUME_NONNULL_BEGIN

///
/// The highlighter's state as it runs through the lines of a text: its position, its state and mode, and a stack of
/// the states and modes it has saved, as on going into a comment. The highlighter reads and changes them through
/// IFSyntaxData. Each line starts with the stack as it was when the line before it was last run through, with that
/// line's last state and mode on top.
///
@interface IFHighlighterState : NSObject

- (instancetype) init NS_UNAVAILABLE;
/// The state of a text of one line, which starts in the default state and mode, with its characters' styles
- (instancetype) initWithText: (NSTextStorage*) text
              characterStyles: (IFCharacterStyles*) characterStyles NS_DESIGNATED_INITIALIZER;

// Each line's state
/// The number of lines whose starting states are kept
@property (nonatomic, readonly) NSInteger lineCount;
/// Keeps the lines' starting states in step with an edit that replaced the lines after one line, up to and including
/// another, with a number of new lines, which start not highlighted
- (void) replaceLinesAfter: (NSInteger) firstLine
                   through: (NSInteger) lastLine
                 withLines: (NSInteger) count
    NS_SWIFT_NAME(replaceLines(after:through:with:));
/// Starts on a line, at the index of its first character, with the stack it starts with
- (void) startLine: (NSInteger) line atIndex: (NSInteger) index NS_SWIFT_NAME(startLine(_:at:));
/// Finishes a line: the next line, if there is one, starts with the stack as it is, with the state and mode on top.
/// Says whether that's how it started before.
- (BOOL) finishLine: (NSInteger) line NS_SWIFT_NAME(finishLine(_:));

// As the highlighter runs through a line
/// The index of the character the highlighter is at
@property (nonatomic) NSInteger position;
/// The highlighter's state
@property (nonatomic) IFSyntaxState state;
/// The highlighter's mode, which extends its state
@property (nonatomic) IFHighlighterMode mode;
/// Saves the state and mode on the stack
- (void) pushState;
/// Takes the last state and mode saved off the stack, goes back to the mode and returns the state, or the default
/// state and mode if none is saved
- (IFSyntaxState) popState;
/// Gives a style to the characters before the position, up to a number of them
- (void) backtrackWithStyle: (IFSyntaxStyle) newStyle
                     length: (int) backtrackLength
    NS_SWIFT_NAME(backtrack(with:length:));
/// Whether a keyword, in any case, comes before the given number of characters before the position, with only spaces
/// and tabs between them
- (BOOL) preceededByKeyword: (NSString*) keyword
                     offset: (int) offset
    NS_SWIFT_NAME(preceeded(byKeyword:offset:));

@end

NS_ASSUME_NONNULL_END
