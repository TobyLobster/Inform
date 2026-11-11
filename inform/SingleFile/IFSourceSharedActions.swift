//
//  IFSourceSharedActions.swift
//  Inform
//
//  Created by Andrew Hunter on Wed Aug 27 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFSourceSharedActions.h.
//

import Cocoa

/// The code of an ASCII character, to compare with a `unichar` as a C character constant would be
private func ascii(_ scalar: Unicode.Scalar) -> unichar {
    return unichar(scalar.value)
}

@objc @implementation extension IFSourceSharedActions {

    // MARK: Menu options

    private final func shiftRange(_ range: NSRange,
                                  inStorage storage: NSTextStorage,
                                  tabStops: Int) -> NSRange {
        var range = range

        if tabStops == 0 { return NSRange(location: 0, length: 0) }

        let string = storage.mutableString

        // Find the start of the line preceeding range
        while range.location > 0 &&
              string.character(at: range.location - 1) != ascii("\n") {
            range.location -= 1
            range.length += 1
        }

        // Tab string to insert
        var tabs: String? = nil
        if tabStops > 0 {
            tabs = "".padding(toLength: tabStops, withPad: "\t", startingAt: 0)
        }

        // Shift each line in turn
        if range.length == 0 { range.length = 1 }
        var x = 0
        while x < range.length {
            // Position at x should be the start of a line
            if let tabs {
                // Insert tabs at the start of this line
                string.replaceCharacters(in: NSRange(location: range.location + x, length: 0),
                                         with: tabs)

                range.length += tabStops    // String is longer
                x += tabStops               // No need to process these again when finding the next line
            } else if tabStops < 0 {
                // Delete tabs at the start of this line

                // Work out how many tabs to delete
                var nTabs = 0
                while range.location + x + nTabs < string.length &&
                      nTabs < -tabStops &&
                      string.character(at: range.location + x + nTabs) == ascii("\t") {
                    nTabs += 1
                }

                // Delete them
                string.deleteCharacters(in: NSRange(location: range.location + x, length: nTabs))

                range.length -= nTabs       // String is shorter
            }

            // Find the next line
            x += 1
            while x < range.length &&
                  range.location + x < string.length &&
                  string.character(at: range.location + x - 1) != ascii("\n") {
                x += 1
            }

            if range.location + x >= string.length { break }
        }

        // On an empty last line, the range goes past the end of the text
        if NSMaxRange(range) > string.length {
            range.length = string.length - range.location
        }

        return range
    }

    private final func shiftRangeLeft(in document: NSDocument,
                                      range: NSRange,
                                      storage textStorage: NSTextStorage) -> NSRange {
        // These functions are used to help with undo
        textStorage.beginEditing()

        // This works because the undo manager for the text view will always be the same as the undo manager for this controller
        // If this ever changes, you will need to rewrite this somehow
        let undo = document.undoManager

        // Lines without a tab are left as they are, so shifting right wouldn't undo this: undoing it puts back the text
        let original = NSString(string: textStorage.string)
        let newRange = shiftRange(range,
                                  inStorage: textStorage,
                                  tabStops: -1)
        let originalRange = NSRange(location: newRange.location,
                                    length: newRange.length + original.length - textStorage.length)
        let originalString = original.substring(with: originalRange)
        undo?.registerUndo(withTarget: self) { actions in
            actions.restoreText(in: document,
                                range: newRange,
                                originalString: originalString,
                                inStorage: textStorage)
        }
        textStorage.endEditing()

        return newRange
    }

    private final func shiftRangeRight(in document: NSDocument,
                                       range: NSRange,
                                       storage textStorage: NSTextStorage) -> NSRange {
        // These functions are used to help with undo
        textStorage.beginEditing()

        // This works because the undo manager for the text view will always be the same as the undo manager for this controller
        // If this ever changes, you will need to rewrite this somehow
        let undo = document.undoManager
        let newRange = shiftRange(range,
                                  inStorage: textStorage,
                                  tabStops: 1)
        undo?.registerUndo(withTarget: self) { actions in
            _ = actions.shiftRangeLeft(in: document,
                                       range: newRange,
                                       storage: textStorage)
        }

        textStorage.endEditing()

        return newRange
    }

    @objc(shiftLeftTextViewInDocument:textView:)
    func shiftLeftTextView(in document: NSDocument, textView: NSTextView) {
        let selRange = textView.selectedRange()

        guard let storage = textView.textStorage else {
            return
        }

        // The change is named here, not as it's made, as undoing it makes the opposite shift, and Redo keeps this name
        document.undoManager?.setActionName(IFUtility.localizedString("Shift Left"))
        let lengthBefore = storage.length
        let newRange = shiftRangeLeft(in: document,
                                      range: selRange,
                                      storage: storage)

        if selRange.length == 0 {
            // The insertion point stays where it was in the line's text, or goes to the start of the line with the tab
            // it was after
            let removed = lengthBefore - storage.length
            textView.setSelectedRange(NSRange(location: max(newRange.location, selRange.location - removed), length: 0))
        } else {
            textView.setSelectedRange(newRange)
        }
    }

    @objc(shiftRightTextViewInDocument:textView:)
    func shiftRightTextView(in document: NSDocument, textView: NSTextView) {
        let selRange = textView.selectedRange()

        guard let storage = textView.textStorage else {
            return
        }

        // The change is named here, not as it's made, as undoing it makes the opposite shift, and Redo keeps this name
        document.undoManager?.setActionName(IFUtility.localizedString("Shift Right"))
        let lengthBefore = storage.length
        let newRange = shiftRangeRight(in: document,
                                       range: selRange,
                                       storage: storage)

        if selRange.length == 0 {
            // The insertion point stays where it was in the line's text, after the new tab
            textView.setSelectedRange(NSRange(location: selRange.location + storage.length - lengthBefore, length: 0))
        } else {
            textView.setSelectedRange(newRange)
        }
    }

    @objc(renumberSectionsInDocument:textView:)
    func renumberSections(in document: NSDocument, textView: NSTextView) {
        // The full text, even if the view only shows part of it
        guard let storage = IFSyntaxManager.registeredStorage(for: textView),
              let intel = IFSyntaxManager.intelligenceData(for: storage) else {
            return      // Also can't do this if we haven't actually gathered any data
        }

        let undo = document.undoManager

        // Renumber each section stored in the intelligence data
        var section = intel.firstSymbol

        // The lines are replaced one at a time, not in one beginEditing/endEditing batch. A batch is
        // reported as a single edit covering every renumbered line, which can straddle the start of a
        // view restricted to one heading, and the restricted range can't be adjusted for that.
        undo?.beginUndoGrouping()

        // Collect the lines that need to be renumbered
        var linesToRenumber: [(lineNumber: UInt, lastLineNumber: UInt)] = []

        while let current = section {
            if current.level > 0 {
                let lineNumber = intel.line(for: current)

                let lastSection = current.previousSibling
                let lastLineNumber = intel.line(for: lastSection)

                linesToRenumber.append((lineNumber: lineNumber, lastLineNumber: lastLineNumber))
            }

            section = current.next
        }

        // Renumber these lines
        // Note that if these operations were concatenated, we'd have a bug as
        // the intelligence would sometimes delete symbols
        for lineInfo in linesToRenumber {
            let lineNumber = Int32(truncatingIfNeeded: lineInfo.lineNumber)
            let sectionLine = IFSyntaxManager.textForLine(with: storage, lineNumber: lineNumber)
            let words = sectionLine?.components(separatedBy: " ") ?? []

            let sectionNumber = words.count > 1 ? (words[1] as NSString).intValue : 0

            if sectionNumber > 0 {
                // This looks like something we can renumber... Get the preceding number (none for the first section)
                let lastLineNumber = lineInfo.lastLineNumber
                var lastLine: String? = ""
                if lastLineNumber != UInt(NSNotFound) {
                    lastLine = IFSyntaxManager.textForLine(with: storage,
                                                           lineNumber: Int32(truncatingIfNeeded: lastLineNumber))
                }
                let lastWords = lastLine?.components(separatedBy: " ") ?? []

                let lastSectionNumber = lastWords.count > 1 ? (lastWords[1] as NSString).intValue : 0

                // (A number too big for intValue is read as Int32.max, so adding one wraps round, as in C)
                if lastSectionNumber >= 0 && lastSectionNumber &+ 1 != sectionNumber {
                    // This section needs renumbering
                    var newWords = words

                    if newWords.count == 2 {
                        // Must be followed by a newline
                        newWords[1] = String(format: "%i\n", lastSectionNumber &+ 1)
                    } else {
                        // Must not be followed by a newline
                        newWords[1] = String(format: "%i", lastSectionNumber &+ 1)
                    }

                    // OK, replace the text
                    IFSyntaxManager.replaceLine(with: storage,
                                                lineNumber: lineNumber,
                                                withLine: newWords.joined(separator: " "))
                }
            }
        }

        undo?.endUndoGrouping()
    }

    // MARK: Commenting out source

    private final func restoreText(in document: NSDocument,
                                   range: NSRange,
                                   originalString original: String,
                                   inStorage storage: NSTextStorage) {
        // Fetch the string that now occupies the specified range
        let replacing = storage.mutableString.substring(with: range)

        // Replace the range with the original string
        storage.mutableString.replaceCharacters(in: range,
                                                with: original)

        // Generate a new undo action
        let undo = document.undoManager
        undo?.registerUndo(withTarget: self) { actions in
            actions.restoreText(in: document,
                                range: NSRange(location: range.location, length: (original as NSString).length),
                                originalString: replacing,
                                inStorage: storage)
        }
    }

    @objc(commentOutSelectionInDocument:textView:)
    func commentOutSelection(in document: NSDocument, textView: NSTextView) {
        guard let storage = textView.textStorage else {
            return
        }
        var commentRange = textView.selectedRange()
        let original = storage.mutableString.substring(with: commentRange)

        // Comment out the region
        let changed = storage.mutableString.commentOutInform7(&commentRange)

        if changed {
            // Select the newly commented region
            textView.setSelectedRange(commentRange)

            // Generate an undo action
            let undo = document.undoManager
            undo?.registerUndo(withTarget: self) { [commentRange] actions in
                actions.restoreText(in: document,
                                    range: commentRange,
                                    originalString: original,
                                    inStorage: storage)
            }
        }
    }

    @objc(uncommentSelectionInDocument:textView:)
    func uncommentSelection(in document: NSDocument, textView: NSTextView) {
        guard let storage = textView.textStorage else {
            return
        }
        var commentRange = textView.selectedRange()
        let original = storage.mutableString.substring(with: commentRange)

        // Uncomment the region
        let changed = storage.mutableString.removeCommentsInform7(&commentRange)

        if changed {
            // Select the newly uncommented region
            textView.setSelectedRange(commentRange)

            // Generate an undo action
            let undo = document.undoManager
            undo?.registerUndo(withTarget: self) { [commentRange] actions in
                actions.restoreText(in: document,
                                    range: commentRange,
                                    originalString: original,
                                    inStorage: storage)
            }
        }
    }
}
