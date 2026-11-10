//
//  IFSourceSections.h
//  Inform
//
//  Moved out of IFSourcePage in November 2026.
//

#import <Foundation/Foundation.h>

@class IFIntelFile;
@class IFIntelSymbol;

NS_ASSUME_NONNULL_BEGIN

///
/// The sections of source text under its headings, as the source page shows one at a time: the heading a section is
/// under is a symbol in the text's intelligence file, which counts lines from 0.
///
@interface IFSourceSections : NSObject

- (instancetype) init NS_UNAVAILABLE;

/// The section after a heading's, for the tear at the bottom: the next heading at its level, or else the next at the
/// level of the nearest heading above it that has one
+ (nullable IFIntelSymbol*) sectionAfter: (nullable IFIntelSymbol*) section;
/// The section before a heading's, for the tear at the top: the previous heading at its level, or else the heading
/// above it, unless that's the file's first
+ (nullable IFIntelSymbol*) sectionBefore: (nullable IFIntelSymbol*) section
                                   inFile: (nullable IFIntelFile*) intelFile NS_SWIFT_NAME(section(before:inFile:));
/// The section above a heading's, for Show More Headings: the heading above it, unless that's the file's first
+ (nullable IFIntelSymbol*) sectionAbove: (IFIntelSymbol*) section
                                  inFile: (nullable IFIntelFile*) intelFile NS_SWIFT_NAME(section(above:inFile:));
/// The section below one, for Show Fewer Headings: the heading just under it that the other section is in, or nil if
/// there's no other section, it's the same one or it isn't under this one
+ (nullable IFIntelSymbol*) sectionBelow: (nullable IFIntelSymbol*) currentSection
                                 towards: (nullable IFIntelSymbol*) cursorSection;
/// The section a character is in
+ (nullable IFIntelSymbol*) sectionAtCharacter: (NSUInteger) charNum
                                        inFile: (nullable IFIntelFile*) intelFile
                                      inString: (NSString*) store NS_SWIFT_NAME(section(atCharacter:inFile:in:));

/// The range of a heading's section, from the heading's first character that isn't white space to the end of the line
/// two before the next section's heading, or the end of the text. The location is NSNotFound, and the length 0, if the
/// heading or the next isn't in the file, or either's line isn't in the text.
+ (NSRange) rangeOfSection: (IFIntelSymbol*) symbol
                    inFile: (nullable IFIntelFile*) intelFile
                  inString: (NSString*) store NS_SWIFT_NAME(range(ofSection:inFile:in:));
/// The lines a range of characters covers, for highlighting its heading in the header page
+ (NSRange) linesOfRange: (NSRange) restriction
                inString: (NSString*) store;

@end

NS_ASSUME_NONNULL_END
