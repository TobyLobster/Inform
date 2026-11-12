//
//  IFRestrictedStorages.h
//  Inform
//
//  Moved out of IFSyntaxData in November 2026.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

///
/// The text storages of the views that show only part of a text, as the source page shows a single heading. Each
/// holds the characters of its view's restricted range of the text, with their attributes, and is kept in step with
/// each edit to the text. An edit replaces the characters in one range with others, and is given by the range of the
/// new characters and the change in length.
///
NS_SWIFT_UI_ACTOR
@interface IFRestrictedStorages : NSObject

- (instancetype) init NS_UNAVAILABLE;
/// No restricted storages yet, for the given text
- (instancetype) initWithTextStorage: (NSTextStorage*) textStorage NS_DESIGNATED_INITIALIZER;

/// Shows a range of the text in a view, in a storage of its own with the given delegate, in place of any the view had
- (void) restrictToRange: (NSRange) range
             forTextView: (NSTextView*) view
                delegate: (id<NSTextStorageDelegate>) delegate
    NS_SWIFT_NAME(restrict(to:for:delegate:));
/// Empties the view's restricted storage and lets it go, though the view still has it
- (void) removeRestrictionForTextView: (NSTextView*) view NS_SWIFT_NAME(removeRestriction(for:));
/// Whether the view has a restricted storage
- (BOOL) isRestrictedForTextView: (NSTextView*) view NS_SWIFT_NAME(isRestricted(for:));
/// The range of the text the view shows, or a location of NSNotFound if it has no restricted storage
- (NSRange) restrictedRangeForTextView: (NSTextView*) view NS_SWIFT_NAME(restrictedRange(for:));
/// The view's restricted storage
- (nullable NSTextStorage*) restrictedTextStorageForTextView: (NSTextView*) view
    NS_SWIFT_NAME(restrictedTextStorage(for:));

/// Where a storage's characters start in the text: its restricted range's location, or 0 if it isn't a restricted
/// storage
- (NSInteger) locationInTextOfStorage: (NSTextStorage*) storage NS_SWIFT_NAME(locationInText(of:));
/// Makes in the text a change made to a restricted storage, given the range in that storage that it replaced
- (void) mirrorChangeInStorage: (NSTextStorage*) storage
                  replaceRange: (NSRange) range
          withAttributedString: (NSAttributedString*) attributedString
    NS_SWIFT_NAME(mirrorChange(in:replaceRange:withAttributedString:));
/// Keeps the restricted storages in step with an edit to the text: moves each restricted range, copies the edit into
/// each restricted storage but the one edited, if any, and copies the attributes of the text in the range given
- (void) updateAfterEditingRange: (NSRange) editedRange
                  changeInLength: (NSInteger) changeInLength
          changedAttributesRange: (NSRange) changedAttributesRange
                   editedStorage: (NSTextStorage*) editedStorage
    NS_SWIFT_NAME(update(afterEditingRange:changeInLength:changedAttributesRange:editedStorage:));

@end

NS_ASSUME_NONNULL_END
