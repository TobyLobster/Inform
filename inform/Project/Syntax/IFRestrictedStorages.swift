//
//  IFRestrictedStorages.swift
//  Inform
//
//  Moved out of IFSyntaxData in November 2026. The interface is IFRestrictedStorages.h.
//

import Cocoa

//
// Represents a restricted region of text. Used when viewing a limited section of Source.
//
@MainActor
private final class IFSyntaxRestricted {

    weak var textView: NSTextView?
    let restrictedTextStorage: NSTextStorage
    var restrictedRange: NSRange

    init(textView view: NSTextView, range: NSRange) {
        self.textView               = view
        self.restrictedTextStorage  = NSTextStorage()
        self.restrictedRange        = range
    }
}

@objc @implementation extension IFRestrictedStorages {

    /// The whole text
    private final let textStorage: NSTextStorage

    /// Restricted storage
    private final var restrictions: [IFSyntaxRestricted]

    /// The storages of views whose restrictions were removed, kept for each view's next restriction
    private final var unused: [IFSyntaxRestricted] = []

    init(textStorage: NSTextStorage) {
        self.textStorage = textStorage

        // Array of IFSyntaxRestricted storage (up to two)
        restrictions = []

        super.init()
    }

    private final func restrictedData(for view: NSTextView) -> IFSyntaxRestricted? {
        for restricted in restrictions {
            if restricted.textView === view {
                return restricted
            }
        }
        return nil
    }

    @objc(restrictToRange:forTextView:delegate:)
    func restrict(to range: NSRange, for view: NSTextView, delegate: NSTextStorageDelegate) {
        // Get text for the given range
        let attributedString = textStorage.attributedSubstring(from: range)

        // A view keeps its storage from one restriction to the next, as the text view undoes what was typed in the
        // storage it was typed in, which an earlier restriction may have shown
        let restricted: IFSyntaxRestricted
        if let current = restrictedData(for: view) {
            restricted = current
        } else if let index = unused.firstIndex(where: { $0.textView === view }) {
            restricted = unused.remove(at: index)
            restrictions.append(restricted)
        } else {
            restricted = IFSyntaxRestricted(textView: view,
                                            range: range)
            restrictions.append(restricted)
        }
        unused.removeAll { $0.textView == nil }

        // Set up the restricted text, which isn't an edit for the delegate
        restricted.restrictedTextStorage.delegate = nil
        restricted.restrictedRange = range
        restricted.restrictedTextStorage.setAttributedString(attributedString)
        restricted.restrictedTextStorage.delegate = delegate

        if view.textStorage !== restricted.restrictedTextStorage {
            view.layoutManager?.replaceTextStorage(restricted.restrictedTextStorage)
        }
    }

    @objc(removeRestrictionForTextView:)
    func removeRestriction(for view: NSTextView) {
        // Find an existing restriction
        if let restricted = restrictedData(for: view) {
            // The storage is no longer kept in step with the text, but keeps what it showed, for the view's next
            // restriction, and for undoing what was typed in it
            restricted.restrictedTextStorage.delegate = nil
            restrictions.removeAll { $0 === restricted }
            unused.append(restricted)
        }
    }

    @objc(isRestrictedForTextView:)
    func isRestricted(for view: NSTextView) -> Bool {
        // Find an existing restriction
        let restricted = restrictedData(for: view)
        return restricted != nil
    }

    @objc(restrictedRangeForTextView:)
    func restrictedRange(for view: NSTextView) -> NSRange {
        // Find an existing restriction
        if let restricted = restrictedData(for: view) {
            return restricted.restrictedRange
        }
        return NSRange(location: NSNotFound, length: 0)
    }

    @objc(restrictedTextStorageForTextView:)
    func restrictedTextStorage(for view: NSTextView) -> NSTextStorage? {
        // Find an existing restriction
        if let restricted = restrictedData(for: view) {
            return restricted.restrictedTextStorage
        }
        return nil
    }

    @objc(locationInTextOfStorage:)
    func locationInText(of storage: NSTextStorage) -> Int {
        for restricted in restrictions {
            if restricted.restrictedTextStorage === storage {
                return restricted.restrictedRange.location
            }
        }
        return 0
    }

    //
    // Copy a change made to one of the restricted storages into the main text
    //
    @objc(mirrorChangeInStorage:replaceRange:withAttributedString:)
    func mirrorChange(in storage: NSTextStorage,
                      replaceRange range: NSRange,
                      withAttributedString attributedString: NSAttributedString) {
        var range = range
        for restricted in restrictions {
            if restricted.restrictedTextStorage === storage {
                // Convert range to refer to full text
                range.location += restricted.restrictedRange.location

                // Change the main text
                textStorage.replaceCharacters(in: range, with: attributedString)
                return
            }
        }

        preconditionFailure("something not right with the text storage")
    }

    //
    // Copy changes from main text into each restricted text storage.
    // This copies not just the characters that have changed, but also the syntax highlighting
    // attributes too.
    //
    @objc(updateAfterEditingRange:changeInLength:changedAttributesRange:editedStorage:)
    func update(afterEditingRange editedRange: NSRange,
                changeInLength: Int,
                changedAttributesRange: NSRange,
                editedStorage storage: NSTextStorage) {
        let newRange = editedRange
        let oldRange = NSRange(location: newRange.location, length: newRange.length - changeInLength)

        for restricted in restrictions {
            // Adjust restricted range as appropriate to reflect the edit that's just occured
            // to the main text
            let oldRestrictedRange = restricted.restrictedRange
            let newRestrictedRange = IFRestrictedRanges.adjust(oldRestrictedRange,
                                                               editedRange: newRange,
                                                               changeInLength: changeInLength)
            restricted.restrictedRange = newRestrictedRange

            // Start editing
            restricted.restrictedTextStorage.beginEditing()

            //
            // Apply character changes
            //
            var newIntersectRange: NSRange

            // If this restricted storage was not the one that has already updated...
            if storage !== restricted.restrictedTextStorage {
                newIntersectRange = IFRestrictedRanges.intersect(newRange,
                                                                 withRestrictedRange: newRestrictedRange)
                let oldIntersectRange = IFRestrictedRanges.intersect(oldRange,
                                                                     withRestrictedRange: oldRestrictedRange)
                if oldIntersectRange.location != NSNotFound && newIntersectRange.location != NSNotFound {
                    let attributedString = textStorage.attributedSubstring(from: newIntersectRange)
                    let localRange = NSRange(location: oldIntersectRange.location - oldRestrictedRange.location,
                                             length: oldIntersectRange.length)
                    restricted.restrictedTextStorage.replaceCharacters(in: localRange,
                                                                       with: attributedString)
                }
            }

            //
            // Apply attribute changes
            //
            newIntersectRange = IFRestrictedRanges.intersect(changedAttributesRange,
                                                             withRestrictedRange: newRestrictedRange)
            if newIntersectRange.location != NSNotFound {
                let localRange = NSRange(location: newIntersectRange.location - newRestrictedRange.location,
                                         length: newIntersectRange.length)

                // Get the new attributed string
                let attributedString = textStorage.attributedSubstring(from: newIntersectRange)

                // Make sure we have got our calculations right and we are only changing attributes
                do {
                    let oldText = restricted.restrictedTextStorage.mutableString.substring(with: localRange)
                    let newText = attributedString.string

                    if (newText as NSString).isEqual(to: oldText) {
                        // Make the change
                        restricted.restrictedTextStorage.replaceCharacters(in: localRange,
                                                                           with: attributedString)
                    } else {
                        NSLog("Should be changing attributes only. Found oldText '%@' new Text '%@' differ",
                              oldText, newText)
                        preconditionFailure("Should be changing attributes only")
                    }
                }
            }

            // End editing
            restricted.restrictedTextStorage.endEditing()
        }
    }
}
