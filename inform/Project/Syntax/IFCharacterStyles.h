//
//  IFCharacterStyles.h
//  Inform
//
//  Moved out of IFSyntaxData in November 2026.
//

#import <Foundation/Foundation.h>
#import "IFSyntaxStyles.h"

NS_ASSUME_NONNULL_BEGIN

///
/// The highlighting style of each character of a text, kept in step with edits to the text. An edit replaces the
/// characters in one range with others, and is given by the range of the new characters and the change in length.
///
@interface IFCharacterStyles : NSObject

/// The styles of an empty text
- (instancetype) init NS_DESIGNATED_INITIALIZER;

/// The number of characters
@property (nonatomic, readonly) NSInteger count;

/// The style of a character, or none for the index just after the last character
- (IFSyntaxStyle) styleAtIndex: (NSInteger) index NS_SWIFT_NAME(style(at:));
/// Sets the style of a character
- (void) setStyle: (IFSyntaxStyle) style atIndex: (NSInteger) index NS_SWIFT_NAME(setStyle(_:at:));
/// The range of the characters around a character, and including it, that have the same style as it
- (NSRange) rangeOfStyleAtIndex: (NSInteger) index NS_SWIFT_NAME(rangeOfStyle(at:));
/// Keeps the styles in step with an edit: the new characters aren't highlighted, and those after them keep their styles
- (void) replaceStylesAfterEditingRange: (NSRange) editedRange
                         changeInLength: (NSInteger) changeInLength
    NS_SWIFT_NAME(replaceStyles(afterEditingRange:changeInLength:));
/// The styles from a character to the end of the text, as the highlighters and the intelligence read and write a
/// line's. They share these styles' memory, so they're only good until the next edit.
- (IFSyntaxStyles*) stylesFromIndex: (NSInteger) index NS_SWIFT_NAME(styles(from:));

@end

NS_ASSUME_NONNULL_END
