//
//  IFRestrictedRanges.h
//  Inform
//
//  Moved out of IFSyntaxData in November 2026.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Keeping a restricted range of a text, the part of it that a view shows, as the source page shows a single heading,
/// in step with edits to the whole text. An edit replaces the characters in one range with others, and is given by the
/// range of the new characters and the change in length.
///
@interface IFRestrictedRanges : NSObject

- (instancetype) init NS_UNAVAILABLE;

/// Where a range is after an edit. Characters inserted at its start or its end become part of it.
+ (NSRange) adjustRange: (NSRange) range
            editedRange: (NSRange) editedRange
         changeInLength: (NSInteger) changeInLength;
/// The part of a range within a restricted range: empty if it only touches the restricted range's start or end, or a
/// location of NSNotFound if it doesn't reach it
+ (NSRange) intersectRange: (NSRange) range
       withRestrictedRange: (NSRange) restrictedRange;

@end

NS_ASSUME_NONNULL_END
