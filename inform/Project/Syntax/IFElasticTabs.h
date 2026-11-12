//
//  IFElasticTabs.h
//  Inform
//
//  Moved out of IFSyntaxData in November 2026.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Finding the tables in source text that elastic tabs lay out in columns, and the cells of their rows (see
/// http://nickgravgaard.com/elastictabstops/). A table is two or more lines in a row, each with a tab after something
/// other than white space.
///
@interface IFElasticTabs : NSObject

- (instancetype) init NS_UNAVAILABLE;
/// Finds the tables in a text, which shouldn't change while they're found
- (instancetype) initWithString: (NSString*) text NS_DESIGNATED_INITIALIZER;

/// The range of the table that a character is in, from the start of its first line to the end of its last, with what
/// ends it, or a location of NSNotFound if the character isn't in a table
- (NSRange) rangeOfRegionAtIndex: (NSUInteger) charIndex;
/// The cells of each line in a range of the text, each a range ending before a tab or before what ends its line. Tabs
/// at the start of a line don't end a cell. A range ending with what ends a line has a last line with no cells.
- (NSArray<NSArray<NSValue*>*>*) cellsInRegion: (NSRange) region;

@end

NS_ASSUME_NONNULL_END
