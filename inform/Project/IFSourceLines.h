//
//  IFSourceLines.h
//  Inform
//
//  Moved out of IFSourcePage in November 2026.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Finding lines in source text, whose lines may end in a newline, a return, or both (either way round). Lines are
/// numbered from 1.
///
@interface IFSourceLines : NSObject

- (instancetype) init NS_UNAVAILABLE;

/// Where a line starts, or NSNotFound if the text has no such line
+ (NSUInteger) startOfLine: (NSInteger) line
                  inString: (NSString*) store;
/// The range of the text on a line, without what ends it, or a location of NSNotFound if the text has no such line
+ (NSRange) rangeOfTextOnLine: (int) line
                     inString: (NSString*) store;
/// The range of a line with the character that ends it (if something does), or a location of NSNotFound if the text
/// has no such line
+ (NSRange) rangeOfLine: (NSUInteger) line
               inString: (NSString*) store;
/// The index of the last character that ends the line before a line (0 for the first line), or NSNotFound if the text
/// has no such line
+ (NSUInteger) indexOfLine: (NSUInteger) line
                  inString: (NSString*) store;
/// The line a character is on, as the source page's headings count it
+ (int) lineForCharacter: (NSUInteger) charNum
                inString: (NSString*) store;

@end

NS_ASSUME_NONNULL_END
