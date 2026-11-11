//
//  IFFindTextView.swift
//  Inform
//
//  Created by Andrew Hunter on 05/02/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

import Cocoa

/// The groups of the last regular expression found, in any text view
private var groupsLastFound: NSArray?

@objc(IFFindTextView) @implementation extension NSTextView {

    private final func find(_ phrase: String,
                            type: IFFindType,
                            direction: Int,
                            fromPoint point: UInt,
                            hasLooped hasLoopedOut: inout Bool,
                            regexFoundGroups foundGroupsOut: UnsafeMutablePointer<NSArray?>?) -> NSRange {
        var point = point
        var result: NSRange
        hasLoopedOut = false
        foundGroupsOut?.pointee = nil

        let text = textStorage?.string ?? ""
        let length = textStorage?.length ?? 0

        if direction > 0 {
            // Forwards search
            result = IFScanner.findNextMatch(phrase,
                                             storage: text,
                                             position: point,
                                             options: type,
                                             regexFoundGroups: foundGroupsOut)
            if result.location == NSNotFound {
                hasLoopedOut = true
                // Wrap around if we didn't start at the beginning
                if point > 0 {
                    point = 0
                    result = IFScanner.findNextMatch(phrase,
                                                     storage: text,
                                                     position: point,
                                                     options: type,
                                                     regexFoundGroups: foundGroupsOut)
                }
            }
        }
        else {
            // Backwards search
            result = IFScanner.findPreviousMatch(phrase,
                                                 storage: text,
                                                 position: point,
                                                 options: type,
                                                 regexFoundGroups: foundGroupsOut)
            if result.location == NSNotFound {
                hasLoopedOut = true
                // Wrap around if we didn't start at the end
                if point < UInt(length) {
                    point = UInt(length)
                    result = IFScanner.findPreviousMatch(phrase,
                                                         storage: text,
                                                         position: point,
                                                         options: type,
                                                         regexFoundGroups: foundGroupsOut)
                }
            }
        }
        precondition(result.location == NSNotFound || result.length > 0, "Found match of length zero")
        return result
    }

    // MARK: - Basic interface

    @objc(findNextMatch:ofType:completionHandler:)
    func findNextMatch(_ match: String,
                       of type: IFFindType,
                       completionHandler: (@MainActor @Sendable (Bool) -> Void)?) {
        // Start after the current selection
        var matchPos = UInt(selectedRange().location + selectedRange().length)

        // If we have just moved beyond the end of the text, start at the beginning
        if matchPos >= UInt(textStorage?.length ?? 0) {
            matchPos = 0
        }
        var hasLooped = false
        let matchRange = find(match,
                              type: type,
                              direction: 1,
                              fromPoint: matchPos,
                              hasLooped: &hasLooped,
                              regexFoundGroups: &groupsLastFound)

        if matchRange.location != NSNotFound {
            scrollRangeToVisible(matchRange)
            setSelectedRange(matchRange)
            showFindIndicator(for: matchRange)
            completionHandler?(true)
        } else {
            NSSound.beep()
            completionHandler?(false)
        }
    }

    @objc(findPreviousMatch:ofType:completionHandler:)
    func findPreviousMatch(_ match: String,
                           of type: IFFindType,
                           completionHandler: (@MainActor @Sendable (Bool) -> Void)?) {
        // Start searching at the previous character
        let matchPos: UInt
        let length = textStorage?.length ?? 0

        if selectedRange().location > 0 {
            matchPos = UInt(selectedRange().location - 1)
        }
        else if length > 0 {
            // If we have just moved before the start of the text, start searching at the end
            matchPos = UInt(length - 1)
        }
        else {
            // There's no text to search
            matchPos = 0
        }

        var hasLooped = false
        let matchRange = find(match,
                              type: type,
                              direction: -1,
                              fromPoint: matchPos,
                              hasLooped: &hasLooped,
                              regexFoundGroups: &groupsLastFound)

        if matchRange.location != NSNotFound {
            scrollRangeToVisible(matchRange)
            setSelectedRange(matchRange)
            showFindIndicator(for: matchRange)
            completionHandler?(true)
        } else {
            NSSound.beep()
            completionHandler?(false)
        }
    }

    @objc(canUseFindType:)
    func canUse(_ find: IFFindType) -> Bool {
        return true
    }

    func currentSelectionForFind(completionHandler: @escaping @MainActor @Sendable (String?) -> Void) {
        completionHandler((string as NSString).substring(with: selectedRange()))
    }

    // MARK: - 'Find all'

    @objc(highlightFindResult:)
    func highlight(_ result: IFFindResult) {
        let matchRange = result.fileRange

        scrollRangeToVisible(matchRange)
        setSelectedRange(matchRange)
        showFindIndicator(for: matchRange)
    }

    @objc(findAllMatches:ofType:inLocation:inFindController:withIdentifier:)
    func findAllMatches(_ match: String,
                        of type: IFFindType,
                        in location: IFFindLocation,
                        in controller: IFFindController,
                        withIdentifier identifier: Any) -> [IFFindResult]? {
        // Do nothing if no phrase is supplied
        if match.isEmpty { return nil }

        // Prepare to match all of the results
        var pos: UInt = 0
        var hasLooped = false
        var nextMatch: NSRange
        var results: [IFFindResult] = []
        var foundGroups: NSArray?

        while true {
            //
            // Find the next match.
            //
            nextMatch = find(match,
                             type: type,
                             direction: 1,
                             fromPoint: pos,
                             hasLooped: &hasLooped,
                             regexFoundGroups: &foundGroups)

            // Stop when we reach the end of the text
            if hasLooped {
                break
            }

            //
            // If we found a match, add it to the list of results
            //
            if nextMatch.location != NSNotFound {
                //
                // Calculate context (text around the match to display in the search results)
                //
                var contextRange = NSRange()
                let context = IFFindInFiles.getContextFromText(textStorage?.string ?? "",
                                                               withLocation: UInt(nextMatch.location),
                                                               andLength: UInt(nextMatch.length),
                                                               findingContextRange: &contextRange)

                //
                // Store result
                //
                let result = IFFindResult(filepath: nil,
                                          rangeInFile: nextMatch,
                                          documentDisplayName: nil,
                                          documentSortName: nil,
                                          locationType: .currentPage,
                                          context: context,
                                          contextRange: contextRange,
                                          exampleName: "",
                                          exampleAnchorTag: "",
                                          codeAnchorTag: "",
                                          definitionAnchorTag: "",
                                          regexFoundGroups: foundGroups as? [String])
                results.append(result)

                // Remember the last set of group results, so that "replace and find" can use it.
                groupsLastFound = foundGroups?.copy() as? NSArray

                // Move to the next position
                pos = UInt(nextMatch.location + 1)
            } else {
                break
            }
        }

        return results
    }

    // MARK: - Replace

    var lastFoundGroups: [String]? {
        return groupsLastFound as? [String]
    }

    private final func replaceFound(with match: String, range selected: NSRange) {
        var selected = selected
        let previousValue = (string as NSString).substring(with: selected)

        textStorage?.replaceCharacters(in: selected, with: match)
        selected.length = (match as NSString).length
        setSelectedRange(selected)

        // Create an undo action for this replacement
        undoManager?.setActionName(IFUtility.localizedString("Replace"))
        undoManager?.registerUndo(withTarget: self) { [selected] textView in
            textView.replaceFound(with: previousValue, range: selected)
        }
    }

    func replaceFound(with match: String) {
        // Text that can't be edited isn't replaced
        if !isEditable {
            NSSound.beep()
            return
        }

        let selected = selectedRange()
        replaceFound(with: match, range: selected)
    }

    func beginReplaceAll(_ sender: IFFindController) {
        // Begin an undo action for this operation
        undoManager?.beginUndoGrouping()
        undoManager?.setActionName(IFUtility.localizedString("Replace All"))
    }

    func finishedReplaceAll(_ sender: IFFindController) {
        // Finished with the replace all operation
        undoManager?.endUndoGrouping()
    }

    private final func replaceFindAllResult(_ match: String, range selected: NSRange) {
        var selected = selected
        let previousValue = (string as NSString).substring(with: selected)

        textStorage?.replaceCharacters(in: selected, with: match)
        selected.length = (match as NSString).length
        setSelectedRange(selected)

        // Create an undo action for this replacement
        undoManager?.registerUndo(withTarget: self) { [selected] textView in
            textView.replaceFindAllResult(previousValue, range: selected)
        }
    }

    @objc(replaceFindAllResult:withString:offset:)
    func replaceFindAllResult(_ result: IFFindResult,
                              with replacement: String,
                              offset: UnsafeMutablePointer<Int32>) -> IFFindResult? {
        // Text that can't be edited isn't replaced
        if !isEditable {
            return nil
        }

        // Get the original match
        var matchRange = result.fileRange

        // Replacing an earlier match with something shorter can move one that overlapped it to before the start
        if matchRange.location + Int(offset.pointee) < 0 {
            return nil
        }
        matchRange.location += Int(offset.pointee)
        let originalMatch = (result.context as NSString).substring(with: result.contextRange)

        // Check that the user hasn't edited the text since the match was made
        let currentText = ((textStorage?.string ?? "") as NSString).substring(with: matchRange)
        if !(currentText as NSString).isEqual(to: originalMatch) {
            return nil
        }

        // Update the context to create a new match
        let contextRange = result.contextRange
        let oldContext = result.context as NSString
        let newContext = oldContext.substring(to: contextRange.location)
                         + replacement
                         + oldContext.substring(from: contextRange.location + contextRange.length)
        var newContextRange = result.contextRange
        newContextRange.length = (replacement as NSString).length

        var newMatchRange = matchRange
        newMatchRange.length = (replacement as NSString).length

        let newResult = IFFindResult(filepath: result.filepath,
                                     rangeInFile: newMatchRange,
                                     documentDisplayName: result.documentDisplayName,
                                     documentSortName: result.documentSortName,
                                     locationType: result.locationType,
                                     context: newContext,
                                     contextRange: newContextRange,
                                     exampleName: result.exampleName,
                                     exampleAnchorTag: result.exampleAnchorTag,
                                     codeAnchorTag: result.codeAnchorTag,
                                     definitionAnchorTag: result.definitionAnchorTag,
                                     regexFoundGroups: result.regexFoundGroups)

        // Perform the replacement
        replaceFindAllResult(replacement, range: matchRange)

        // Update the offset so future matches are replaced correctly
        offset.pointee += Int32((replacement as NSString).length) - Int32((originalMatch as NSString).length)

        return newResult
    }
}
