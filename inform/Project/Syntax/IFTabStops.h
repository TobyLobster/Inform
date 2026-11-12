//
//  IFTabStops.h
//  Inform
//
//  Moved out of IFSyntaxData in November 2026.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

///
/// The tab stops of a source text: the standard ones, a tab's width apart, and those of a table laid out with elastic
/// tabs, where each column is as wide as its widest cell.
///
@interface IFTabStops : NSObject

- (instancetype) init NS_UNAVAILABLE;

/// The standard tab stops: 48 of them, a tab's width apart (or a point apart, for a width of less than a point)
+ (NSArray<NSTextTab*>*) standardTabStopsForTabWidth: (CGFloat) tabWidth;
/// The tab stops of a table, given the cells of each of its lines: a stop after each column, which is as wide as its
/// widest cell with a margin of 8 points, rounded down, and at least a tab's width
+ (NSArray<NSTextTab*>*) elasticTabStopsForCells: (NSArray<NSArray<NSAttributedString*>*>*) cells
                                        tabWidth: (CGFloat) tabWidth;

@end

NS_ASSUME_NONNULL_END
