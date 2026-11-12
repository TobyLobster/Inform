//
//  IFSyntaxData.swift
//  Inform
//
//  Created by Toby Nelson in 2014.
//  Translated from Objective-C in November 2026. The interface is still IFSyntaxData.h.
//

import Cocoa

private let tab: unichar            = 0x09      // \t
private let lineFeed: unichar       = 0x0A      // \n
private let carriageReturn: unichar = 0x0D      // \r
private let space: unichar          = 0x20      // ' '

/// An entry on a syntax stack: the highlighter's state, and its mode
private struct IFSyntaxStackEntry: Equatable {
    var state: IFSyntaxState
    var mode: IFHighlighterMode
}

private func isWhitespace(_ c: unichar) -> Bool {
    if c == space || c == tab {
        return true
    } else {
        return false
    }
}

//
// Represents a restricted region of text. Used when viewing a limited section of Source.
//
@objc @implementation extension IFSyntaxRestricted {

    var textView: NSTextView
    var restrictedTextStorage: NSTextStorage
    var restrictedRange: NSRange

    init(textView view: NSTextView, range: NSRange) {
        self.textView               = view
        self.restrictedTextStorage  = NSTextStorage()
        self.restrictedRange        = range
        super.init()
    }
}

@objc @implementation extension IFSyntaxData {

    var textStorage: NSTextStorage
    var name: String
    var type: IFHighlightType
    var undoManager: UndoManager?
    var isHighlighting: Bool

    // Restricted storage
    private final var restrictions: [IFSyntaxRestricted]

    //
    // Syntax state - Line and character information
    //
    private final var lineStarts: IFLineStarts                        // Start positions of each line
    private final var lineStates: [[IFSyntaxStackEntry]]              // Syntax stack at the start of lines

    private final var charStyles: IFSyntaxStyles                      // Syntax state for each character
    private final var lineStyles: [[NSAttributedString.Key: Any]]     // NSParagraphStyles for each line

    //
    // Syntax state - current highlighter state
    //
    private final var syntaxStack: [IFSyntaxStackEntry]               // Current syntax stack
    private final var syntaxPos: Int                                  // Current highlighter position
    private final var syntaxState: IFSyntaxState                      // Active state
    private final var syntaxMode: IFHighlighterMode                   // 'Mode' - possible extra state from the highlighter

    //
    // The highlighter
    //
    private final var highlighter: IFSyntaxHighlighter?

    //
    // Paragraph styles
    //

    /// Tab stop array
    private final var tabStops: [NSTextTab]?
    /// The paragraph style of each line, until elastic tabs give a table's lines their own
    private final var lineParagraphStyle: [NSAttributedString.Key: Any]?

    //
    // 'Intelligence'
    //
    private final var intelSource: IFSyntaxIntelligence?
    /// 'Intelligence' data
    private final var intelData: IFIntelFile

    /// Used while rewriting
    private final var editingRange: NSRange

    init(storage aStorage: NSTextStorage,
         name aName: String,
         type aType: IFHighlightType,
         intelligence: IFSyntaxIntelligence?,
         undoManager aUndoManager: UndoManager?) {
        self.textStorage = aStorage
        self.name        = aName
        self.type        = aType
        self.undoManager = aUndoManager

        // Setup variables for syntax highlighting
        charStyles = IFSyntaxStyles()
        lineStyles = [[:]]

        syntaxStack = []
        syntaxPos = 0
        syntaxState = IFSyntaxState(IFSyntaxStateDefault)
        syntaxMode = 0

        switch aType {
        case .inform6:
            highlighter = IFInform6Highlighter()
        case .inform7:
            highlighter = IFNaturalHighlighter()
        default:            // IFHighlightTypeNone
            highlighter = nil
        }

        // Array of IFSyntaxRestricted storage (up to two)
        restrictions = []

        // Are we currently syntax highlighting?
        isHighlighting = false

        // Initial state
        lineStarts = IFLineStarts()
        lineStates = [[IFSyntaxStackEntry(state: IFSyntaxState(IFSyntaxStateDefault), mode: 0)]]    // Initial stack starts with the default state

        tabStops = nil
        lineParagraphStyle = nil

        intelSource = nil
        intelData = IFIntelFile()

        editingRange = NSRange(location: 0, length: 0)

        super.init()

        // Set up default tabs
        _ = paragraphStyle()

        // Set up intelligence
        self.intelligence = intelligence

        // Set delegate to get notified about changes to the text
        textStorage.delegate = self

        // Syntax highlight the initial text
        textStorage.beginEditing()
        isHighlighting = true

        // Lines end with newlines: the highlighting takes a return as the end of a line too, and so a return and a
        // newline as two. (What's typed later is converted as it's typed.)
        let text = textStorage.mutableString
        text.replaceOccurrences(of: "\r\n", with: "\n", options: [], range: NSRange(location: 0, length: text.length))
        text.replaceOccurrences(of: "\r", with: "\n", options: [], range: NSRange(location: 0, length: text.length))

        let length = textStorage.length
        _ = updateAfterEditingRange(NSRange(location: 0, length: length),
                                    changeInLength: length,
                                    forceUpdateTabs: true)

        // The text storage processes the highlighting as the editing ends, which mustn't be taken for an edit
        textStorage.endEditing()
        isHighlighting = false

        // Register for preference change notifications
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(preferencesChanged(_:)),
                                               name: .IFPreferencesEditingDidChange,
                                               object: IFPreferences.shared)
    }

    deinit {
        // Text storages, and the syntax data they're registered with, are let go of on the main thread
        MainActor.assumeIsolated {
            NotificationCenter.default.removeObserver(self)

            if charStyles.styles != nil {
                free(charStyles.styles)
                charStyles.styles = nil
                charStyles.numCharStyles = 0
            }

            highlighter?.setSyntaxData(nil)

            intelSource?.setSyntaxData(nil)
        }
    }

    // MARK: - Utility methods

    //
    // Helper method.
    // Which line of text does the character index occur on?
    //
    private final func lineForIndex(_ index: Int) -> Int {
        return lineStarts.line(forIndex: index)
    }

    //
    // Helper method.
    // What's the current style and range at the given character index?
    //
    private final func style(at index: Int, effectiveRange range: UnsafeMutablePointer<NSRange>?) -> IFSyntaxStyle {
        let style = charStyles.read(index)

        if let range {
            var localRange = NSRange(location: index, length: 0)       // Optimisation suggested by Shark

            while localRange.location > 0 {
                if charStyles.read(localRange.location - 1) == style {
                    localRange.location -= 1
                } else {
                    break
                }
            }

            let strLen = textStorage.length

            while localRange.location + localRange.length < strLen {
                if charStyles.read(localRange.location + localRange.length) == style {
                    localRange.length += 1
                } else {
                    break
                }
            }

            range.pointee = localRange
        }

        return style
    }

    //
    // Copy a change made to one of the restricted storages into the main text
    //
    private final func mirrorChange(in storage: NSTextStorage,
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

    // Update the text to account for different line endings and intelligence changes
    private final func rewriteInput(_ newString: String) -> String? {
        var result = newString
        var changed = false

        // Give intelligence a chance to rewrite the change
        if let intelSource, (newString as NSString).length == 1 {
            if let rewritten = intelSource.rewriteInput(newString) {
                result = rewritten
                changed = true
            }
        }

        // Normalize line endings
        if (result as NSString).range(of: "\r").location != NSNotFound {
            result = (result as NSString).replacingOccurrences(of: "\r\n", with: "\n")
            result = (result as NSString).replacingOccurrences(of: "\r", with: "\n")
            changed = true
        }

        if changed {
            return result
        }
        return nil
    }

    // MARK: - Delegate methods

    //
    // When the textView is *about to* accept a change (i.e. update it's text), this method can
    // update the text first. We use it to (e.g.) insert tabs automatically when you press
    // newline. This rewriting is calculated by the 'intelligence'.
    //
    // (See also the other main delegate method 'textStorageDidProcessEditing' below, which updates
    // syntax highlighting and related text storages *after* a change has been made).
    //
    // A 'change' consists replacing one range of characters with another. A change is defined by
    // an editedRange (this is the range of the *new* characters in the text) and a changeInLength
    // (how many characters were added or taken away). A single change is effectively:
    //      (a) first delete one range of characters, and then
    //      (b) add a new different bunch of characters starting at the same location.
    //
    func textStorage(_ storage: NSTextStorage,
                     willProcessEditing editedMask: NSTextStorageEditActions,
                     range editedRange: NSRange,
                     changeInLength delta: Int) {
        if isHighlighting {
            return
        }

        if let undoManager {
            if undoManager.isUndoing || undoManager.isRedoing {
                return
            }
        }

        let newRange = editedRange
        let newString = storage.mutableString.substring(with: newRange)

        // The intelligence reads the main text, so a change to a restricted storage is offset by
        // its restricted range
        editingRange = newRange
        for restricted in restrictions {
            if restricted.restrictedTextStorage === storage {
                editingRange.location += restricted.restrictedRange.location
                break
            }
        }

        // Rewrite the change if needed (e.g. to auto-insert tabs when user presses return)
        if let rewritten = rewriteInput(newString) {
            // Actually make the change
            storage.replaceCharacters(in: newRange, with: rewritten)
        }
    }

    //
    // Delegate method.
    //
    // When a change has occured to a text storage (whether it's to the main text or a restricted
    // text) we want to keep all versions of the restricted and main text in sync.
    //
    // Therefore we:
    //      (a) update the full text (if the change was to a restricted text),
    //      (b) update the syntax highlighting on the full text
    //      (c) copy the results into each of the restricted text storage(s).
    //
    // This process is quite fiddly, but it makes sure the different text storages are all in sync.
    //
    // A 'change' consists replacing one range of characters with another. A change is defined by
    // an editedRange (this is the range of the *new* characters in the text) and a changeInLength
    // (how many characters were added or taken away). A single change is effectively:
    //      (a) first delete one range of characters, and then
    //      (b) add a new different bunch of characters starting at the same location.
    //
    func textStorage(_ storage: NSTextStorage,
                     didProcessEditing editedMask: NSTextStorageEditActions,
                     range editedRange: NSRange,
                     changeInLength: Int) {
        if isHighlighting {
            return
        }

        isHighlighting = true

        var newRange = editedRange
        var oldRange = NSRange(location: newRange.location, length: newRange.length - changeInLength)

        // Start editing
        textStorage.beginEditing()

        //
        // Mirror the change from a restricted storage into main text storage. This makes sure the
        // main text is up to date.
        //
        if storage !== textStorage {
            let newString = storage.attributedSubstring(from: newRange)

            mirrorChange(in: storage,
                         replaceRange: oldRange,
                         withAttributedString: newString)

            // Convert local ranges to refer to full text
            for restricted in restrictions {
                if restricted.restrictedTextStorage === storage {
                    let restrictedRange = restricted.restrictedRange
                    newRange.location += restrictedRange.location
                    oldRange.location += restrictedRange.location
                    break
                }
            }
        }

        //
        // Update syntax highlighting on main text.
        //
        let changedAttributesRange = updateAfterEditingRange(newRange,
                                                             changeInLength: changeInLength,
                                                             forceUpdateTabs: false)

        //
        // Copy changes from main text into each restricted text storage.
        // This copies not just the characters that have changed, but also the syntax highlighting
        // attributes too.
        //
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
                        NSLog("Should be changing attributes only. Found oldText '%@' new Text '%@' differ", oldText, newText)
                        preconditionFailure("Should be changing attributes only")
                    }
                }
            }

            // End editing
            restricted.restrictedTextStorage.endEditing()
        }

        textStorage.endEditing()

        isHighlighting = false
    }

    //
    // Given an update that has just occured to the main text storage, update it's syntax highlighting
    //
    private final func updateAfterEditingRange(_ newRange: NSRange,
                                               changeInLength: Int,
                                               forceUpdateTabs: Bool) -> NSRange {
        var newRange      = newRange
        let oldRange      = NSRange(location: newRange.location, length: newRange.length - changeInLength)
        let newString     = textStorage.mutableString.substring(with: newRange)
        let newFullLength = textStorage.length
        let oldFullLength = newFullLength - changeInLength

        // The range of lines to be replaced
        let firstLine = lineForIndex(oldRange.location)
        let lastLine = lineForIndex(oldRange.location + oldRange.length)

#if HighlighterDebug
        NSLog("Highlighter: editing lines in the range %ld-%ld", firstLine, lastLine)
#endif

        // Replace the line start positions (first line is still at the same position, with the same initial state, of course)
        let nNewLines = lineStarts.replaceLines(after: firstLine,
                                                through: lastLine,
                                                withLinesIn: newString,
                                                at: oldRange.location,
                                                changeInLength: changeInLength)

        // newLineStates - an array of 'stacks' (one stack per line). Each 'stack' is a dictionary of the current
        // highlighter state and inform6/7 'mode'.
        let notHighlighted = [IFSyntaxStackEntry(state: IFSyntaxState(IFSyntaxStateNotHighlighted), mode: 0)]
        let newLineStates = [[IFSyntaxStackEntry]](repeating: notHighlighted, count: nNewLines)

        // Number of lines that have been added or taken away
        let lineDifference = nNewLines - (lastLine - firstLine)

#if HighlighterDebug
        NSLog("Highlighter: %ld %@ lines (%ld total)", lineDifference, nNewLines < (lastLine - firstLine) ? "new" : "removed", lineStarts.count - lineDifference)
#endif

        if nNewLines < (lastLine - firstLine) {
            // Remove the appropriate lines from the intelligence data
            intelData.removeLines(NSRange(location: firstLine + 1, length: -lineDifference))
            lineStyles.removeSubrange((firstLine + 1)..<(firstLine + 1 - lineDifference))
        } else {
            lineStyles.removeSubrange((firstLine + 1)..<(lastLine + 1))
            intelData.removeLines(NSRange(location: firstLine + 1, length: lastLine - firstLine))

            for _ in 0..<nNewLines {
                lineStyles.insert(paragraphStyle(), at: firstLine + 1)
                intelData.insertLine(beforeLine: Int32(firstLine + 1))
            }
        }

        // Update the line states
        lineStates.replaceSubrange((firstLine + 1)..<(lastLine + 1), with: newLineStates)

        // Update the character styles of everything beyond our change
        let charactersToCopy = oldFullLength - oldRange.location - oldRange.length
        if changeInLength > 0 {
            // Move characters down (i.e. towards the back of the string)
            charStyles.styles = realloc(charStyles.styles, newFullLength)?.bindMemory(to: IFSyntaxStyle.self, capacity: newFullLength)
            charStyles.numCharStyles = UInt(newFullLength)

            if let styles = charStyles.styles {
                memmove(styles + newRange.location + newRange.length,
                        styles + oldRange.location + oldRange.length,
                        MemoryLayout<IFSyntaxStyle>.size * charactersToCopy)
            }
        } else {
            // Move characters up (i.e. towards the front of the string)
            if let styles = charStyles.styles {
                memmove(styles + newRange.location + newRange.length,
                        styles + oldRange.location + oldRange.length,
                        MemoryLayout<IFSyntaxStyle>.size * charactersToCopy)
            }

            charStyles.styles = realloc(charStyles.styles, newFullLength)?.bindMemory(to: IFSyntaxStyle.self, capacity: newFullLength)
            charStyles.numCharStyles = UInt(newFullLength)
        }

        // Characters in the edited range no longer have valid states
        precondition((newRange.length == 0) || ((newRange.length + newRange.location - 1) < Int(charStyles.numCharStyles)), "index out of range")
        var x = 0
        while x < newRange.length {
            charStyles.write(x + newRange.location, value: .styleNotHighlighted)
            x += 1
        }

        // Syntax highlight (up to) the rest of the text
        newRange.length = newFullLength - newRange.location
        newRange = syntaxHighlightRange(newRange,
                                        forceUpdateTabs: forceUpdateTabs)
        return newRange
    }

    //
    // Update the attributes based on the new character styles for the range specified
    //
    private final func updateHighlightingForAttributedString(in range: NSRange) {
        var range = range

        guard let highlighter else {
            return
        }

        // No syntax highlighting/colouring
        if !IFPreferences.shared.enableSyntaxHighlighting &&
            !IFPreferences.shared.enableSyntaxColouring {
            // Just use standard attributes
            textStorage.setAttributes(highlighter.attributes(for: .naturalInform),
                                      range: range)
            textStorage.fixFontAttribute(in: range)
            return
        }

        while range.length > 0 {
            // What's the current style and it's range?
            var styleRange = NSRange(location: 0, length: 0)
            let style = self.style(at: range.location,
                                   effectiveRange: &styleRange)

            // The run of this style can extend past either end of the range we were asked
            // to update, across line boundaries. Never touch text outside the range: those
            // lines were not re-highlighted, and -setAttributes: would wipe their paragraph
            // style (including any elastic tab stops) while lineStyles[] still records it.
            styleRange = NSIntersectionRange(styleRange, range)

            // Get the style attributes
            let styleAttributes = highlighter.attributes(for: style)
            textStorage.setAttributes(styleAttributes, range: styleRange)
            textStorage.fixFontAttribute(in: styleRange)

            precondition((styleRange.location + styleRange.length) <= textStorage.length, "Help!")

            let nextStart = styleRange.location + styleRange.length
            let consumed  = nextStart - range.location
            range.location = nextStart

            precondition(consumed >= 1, "Consumed too little")

            range.length -= min(consumed, range.length)
        }

#if HighlighterDebug
        textStorage.enumerateAttributes(in: NSRange(location: 0, length: textStorage.length),
                                        options: []) { _, aRange, _ in
            precondition((aRange.location + aRange.length) <= self.textStorage.length, "Help!!!!")
        }
#endif
    }

    // MARK: - Communication from the highlighter

    func pushState() {
        // When the highlighter opens a comment bracket (etc), it pushes the current state onto a stack.
        syntaxStack.append(IFSyntaxStackEntry(state: syntaxState,
                                              mode: syntaxMode))
    }

    func popState() -> IFSyntaxState {
        // When the highlighter closes a comment bracket (etc), it pops the state off the current stack.
        let poppedState = syntaxStack.last?.state ?? 0
        syntaxMode = syntaxStack.last?.mode ?? 0
        _ = syntaxStack.popLast()

        return poppedState
    }

    @objc(backtrackWithStyle:length:)
    func backtrack(with newStyle: IFSyntaxStyle, length backtrackLength: Int32) {
        // Change the character style, going backwards for the specified length
        precondition(syntaxPos < Int(charStyles.numCharStyles), "index out of range")
        for x in stride(from: syntaxPos - Int(backtrackLength), to: syntaxPos, by: 1) {
            if x >= 0 {
                charStyles.write(x, value: newStyle)
            }
        }
    }

    var highlighterMode: IFHighlighterMode {
        get {
            // Retrieves the mode
            return syntaxMode
        }
        set {
            // Sets the 'mode' of the highlighter (additional state info, basically)
            syntaxMode = newValue
        }
    }

    func preceeded(byKeyword keyword: String, offset: Int32) -> Bool {
        // If the given keyword preceeds the current position (case insensitively), this returns true
        if syntaxPos == 0 {
            return false
        }

        var pos = syntaxPos - 1 - Int(offset)
        let str = textStorage.mutableString

        // Skip whitespace
        while pos > 0 && isWhitespace(str.character(at: pos)) {
            pos -= 1
        }

        // pos should now point at the last letter of the keyword (if it is the keyword)
        pos += 1

        // See if the keyword is there
        let keywordLen = (keyword as NSString).length
        if pos < keywordLen {
            return false
        }

        let substring = str.substring(with: NSRange(location: pos - keywordLen, length: keywordLen))

        return (substring as NSString).caseInsensitiveCompare(keyword) == .orderedSame
    }

    ///
    /// Apply the paragraph style recorded in lineStyles[] for the given line to the text.
    ///
    private final func applyLineStyle(forLine line: Int) {
        let firstChar = lineStarts.start(ofLine: line)
        let lastChar  = (line + 1) < lineStarts.count ? lineStarts.start(ofLine: line + 1) : textStorage.length
        let lineRange = NSRange(location: firstChar, length: lastChar - firstChar)

        textStorage.addAttributes(lineStyles[line],
                                  range: lineRange)
        textStorage.fixFontAttribute(in: lineRange)
    }

    ///
    /// Actually performing highlighting
    ///
    /// * Phase One: Calculate charStyles, hint keywords, gather intelligence, indent paragraphs.
    /// * Phase Two: Apply the character styles as attributes.
    /// * Phase Three: Add elastic tabs.
    ///
    private final func syntaxHighlightRange(_ range: NSRange,
                                            forceUpdateTabs: Bool) -> NSRange {
        var changedRange = range

        //
        // The range of lines to be highlighted
        //
        let firstLine = lineForIndex(range.location)
        var lastLine = (range.length > 0) ? lineForIndex(range.location + range.length - 1) : firstLine

#if HighlighterDebug
        NSLog("Highlighter: highlighting range %ld-%ld (lines %ld-%ld)", range.location, range.location + range.length, firstLine, lastLine)
#endif

        // Setup
        highlighter?.setSyntaxData(self)

        // Perform the highlighting

        //
        // Phase One: Calculate charStyles, hint keywords, gather intelligence, indent paragraphs.
        //
        var previousOldStack: [IFSyntaxStackEntry]? = nil                  // The 'old' stack for the previous line
        var previousElasticRange = NSRange(location: NSNotFound, length: 0) // The previous range formatted with elastic tabs
        let styles = IFSyntaxStyles()
        let str = textStorage.mutableString
        let highlighter = self.highlighter

        for line in firstLine...lastLine {
            // The range of characters in this line
            let firstChar = lineStarts.start(ofLine: line)
            let lastChar  = (line + 1) < lineStarts.count ? lineStarts.start(ofLine: line + 1) : textStorage.length

            // Set up the state
            syntaxStack = lineStates[line]

            syntaxState = syntaxStack.last?.state ?? 0
            syntaxMode  = syntaxStack.last?.mode ?? 0
            _ = syntaxStack.popLast()

            let initialState = syntaxState

            // Highlight this line
            syntaxPos = firstChar
            while syntaxPos < lastChar {
                // Current state
                let curChar = str.character(at: syntaxPos)

                // Next state
                let nextState = highlighter?.state(forCharacter: curChar,
                                                   afterState: syntaxState) ?? 0

                // Next style
                let nextStyle = highlighter?.style(forCharacter: curChar,
                                                   nextState: nextState,
                                                   lastState: syntaxState) ?? []

                // Store the style
                precondition(syntaxPos < Int(charStyles.numCharStyles), "index out of range")
                charStyles.styles![syntaxPos] = nextStyle

                // Store the state
                syntaxState = nextState

                syntaxPos += 1
            }

            // Provide an opportunity for the highlighter to hint keywords, etc
            let lineToHint = str.substring(with: NSRange(location: firstChar, length: lastChar - firstChar))
#if HighlighterDebug
            NSLog("Highlighter: finished line %ld: '%@', rehinting", line, lineToHint)
#endif
            styles.styles = charStyles.styles.map { $0 + firstChar }
            styles.numCharStyles = charStyles.numCharStyles - UInt(firstChar)
            highlighter?.rehintLine(lineToHint,
                                    styles: styles,
                                    initialState: initialState)

            //
            // Gather intelligence for the line, if we have something to gather it with
            //
            if let intelSource {
                intelSource.gatherIntel(forLine: lineToHint,
                                        styles: styles,
                                        initialState: initialState,
                                        lineNumber: Int32(line),
                                        intoData: intelData)
            }

            // Reset this line's paragraph style to the default (non-elastic) one.
            //
            // lineStyles[] is the record of which paragraph style each line of the text is
            // supposed to carry. Every edited line starts from the default here; Phase Two
            // applies it to the text, and Phase Three replaces it with an elastic one for
            // lines that turn out to be part of a table. Lines that are not edited keep
            // whatever they already have, in both lineStyles[] and the text.
            let newStyle = paragraphStyle()
            while lineStyles.count <= line {
                lineStyles.append(newStyle)
            }
            lineStyles[line] = newStyle

            // Store the current state on the stack
            syntaxStack.append(IFSyntaxStackEntry(state: syntaxState,
                                                  mode: syntaxMode))

            // Compare the new stack against the old version to see if anything has changed
            previousOldStack = nil
            if line + 1 < lineStates.count {
                previousOldStack = lineStates[line + 1]

                //
                // Optimisation: If the state stack for the next line hasn't changed from what it
                // was previously, then we are done. (However, if we are reformatting due to a tab
                // setting change, then we can't optimise this way, we must format the entire rest
                // of the text).
                //
                if !forceUpdateTabs {
                    // If our state for the next line has not changed, then we are done syntax highlighting
                    if previousOldStack == syntaxStack {
                        lastLine = line
                        break
                    }
                }
                lineStates[line + 1] = syntaxStack
            }
        }

        // Clean up
        highlighter?.setSyntaxData(nil)

        //
        // Phase Two: Apply the character styles as attributes
        //
        let firstRangeChar = lineStarts.start(ofLine: firstLine)
        let lastRangeChar = (lastLine + 1) < lineStarts.count ? lineStarts.start(ofLine: lastLine + 1) : textStorage.length

        updateHighlightingForAttributedString(in: NSRange(location: firstRangeChar, length: lastRangeChar - firstRangeChar))

        // The call above uses -setAttributes:, which replaces *every* attribute on the edited
        // lines. The highlighter's attributes have no paragraph style, so the lines are left
        // with none. Put each line's own paragraph style back, so that the text agrees with
        // lineStyles[] again. Without this, an edited table row silently lost
        // its elastic tab stops here while lineStyles[] still claimed it had them, and Phase
        // Three then skipped the row as "already up to date" (issue #50).
        for line in firstLine...lastLine {
            applyLineStyle(forLine: line)
        }

        //
        // Phase Three: Add elastic tabs
        //
        if IFPreferences.shared.elasticTabs {
            // The tables in the text
            let tables = IFElasticTabs(string: textStorage.string)

            // Look one line either side of the edited lines as well. An edit can change the
            // layout of a table that it is not (or is no longer) part of: deleting a table's
            // last row, removing the tab from a row so that it leaves the table, or splitting
            // a table in two. Checking an extra line is cheap when it is not in a table, and
            // the comparison against lineStyles[] below skips any row whose stops are unchanged.
            let firstTabLine = (firstLine > 0) ? firstLine - 1 : firstLine
            let lastTabLine  = (lastLine + 1 < lineStarts.count) ? lastLine + 1 : lastLine
            var line = firstTabLine
            while line <= lastTabLine {
                // The range of characters on the line
                let firstChar = lineStarts.start(ofLine: line)

                // Get the region affected by these elastic tabs
                let elasticRange = tables.rangeOfRegion(at: UInt(firstChar))

                // If this was not the same as the region just handled...
                if elasticRange.location != NSNotFound &&
                    elasticRange.location != previousElasticRange.location {
                    // This is now the last elastic range (prevents us from formatting the same region twice)
                    previousElasticRange = elasticRange

                    // Lay out the tabs properly
                    let newTabStops = elasticTabs(inRegion: elasticRange, of: tables)

                    // Update the tabs over this region if necessary
                    let firstElasticLine    = lineForIndex(elasticRange.location)
                    var lastElasticLine     = lineForIndex(elasticRange.location + elasticRange.length)
                    if elasticRange.location + elasticRange.length >= textStorage.length {
                        lastElasticLine += 1
                    }
                    while lastElasticLine >= lineStyles.count {
                        // Create a default line style for all unstyled lines,
                        // in case stage 1 didn't get here (for example, if this
                        // table runs past the edited region)
                        lineStyles.append(paragraphStyle())
                    }
                    for formatLine in stride(from: firstElasticLine, to: lastElasticLine, by: 1) {
                        // Skip lines that already carry these tab stops. lineStyles[] is
                        // reliable here: Phase One reset every edited line to the default
                        // style and Phase Two applied exactly that to the text, so a line
                        // whose recorded stops match the new ones really does have them.
                        // Edited lines never match (they hold the default), and if a
                        // column width changed then no line in the region matches, so
                        // the whole table is re-laid-out, as it must be.
                        if !forceUpdateTabs {
                            let currentPara = lineStyles[formatLine][.paragraphStyle] as? NSParagraphStyle
                            let currentTabs = currentPara?.tabStops ?? []
                            if newTabStops.count == currentTabs.count {
                                var tabsIdentical = true
                                for i in 0..<newTabStops.count {
                                    if newTabStops[i].location != currentTabs[i].location {
                                        tabsIdentical = false
                                        break
                                    }
                                }
                                if tabsIdentical {
                                    continue
                                }
                            }
                        }

                        // Copy the styles for this line
                        var style = lineStyles[formatLine]
                        let paraStyle: NSMutableParagraphStyle
                        if let currentPara = style[.paragraphStyle] as? NSParagraphStyle {
                            paraStyle = currentPara.mutableCopy() as! NSMutableParagraphStyle
                        } else {
                            paraStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                        }

                        // Update the paragraph style with the new tabstops
                        paraStyle.tabStops = newTabStops
                        style[.paragraphStyle] = paraStyle

                        // Replace the line style, and apply it to the text
                        lineStyles[formatLine] = style
                        applyLineStyle(forLine: formatLine)
                    }

                    // Record that we have changed this range of attributes
                    changedRange = NSUnionRange(changedRange, elasticRange)

                    // Advance the enclosing loop to skip the lines we just laid out
                    if line < lastElasticLine {
                        line = lastElasticLine - 1
                    }
                }

                line += 1
            }
        }

        //
        // Return the range of all characters/attributes changed, including any elastic tabs that
        // were updated. We use this to copy the changes into restricted text storage.
        //
        return changedRange
    }

    // MARK: - Notifications from the preferences object

    func preferencesChanged(_ not: Notification?) {
        //
        // When the preferences have changed, force a re-highlight of everything
        //
        highlightAllForceUpdateTabs(true)
    }

    func highlightAllForceUpdateTabs(_ forceUpdateTabs: Bool) {

        // Set current state to highlighting
        let oldIsHighlighting = isHighlighting
        isHighlighting = true

        // Flush out old indents / tabs if we force an update of tabs
        if forceUpdateTabs {
            lineParagraphStyle = nil

            tabStops = nil
        }

        // Update highlighting for entire range
        textStorage.beginEditing()

        _ = syntaxHighlightRange(NSRange(location: 0, length: textStorage.length),
                                 forceUpdateTabs: forceUpdateTabs)

        textStorage.endEditing()

        // Restore old state
        isHighlighting = oldIsHighlighting
    }

    // MARK: - Tabbing

    private final func standardTabStops() -> [NSTextTab] {
        // Set up member variable 'tabStops' - a standard set of tabs at the current width
        let newTabStops = IFTabStops.standardTabStops(forTabWidth: highlighter?.tabStopWidth ?? 0)
        tabStops = newTabStops

        return newTabStops
    }

    private final func generateParagraphStyle() -> [NSAttributedString.Key: Any] {
        let res = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle

        // Create standard tab stops if needed
        if tabStops == nil {
            _ = standardTabStops()
        }

        // Set tabs
        res.tabStops = tabStops

        return [.paragraphStyle: res]
    }

    /// The paragraph style of a line, with the standard tab stops. (Each number of tabs at the start of a line had a
    /// style of its own, to indent the line's wrapped text past them, until 515e4ae0 stopped indenting it.)
    private final func paragraphStyle() -> [NSAttributedString.Key: Any] {
        // Use the cached version if available
        if let lineParagraphStyle {
            return lineParagraphStyle
        }

        let style = generateParagraphStyle()
        lineParagraphStyle = style
        return style
    }

    // MARK: - Elastic tabs

    // Given a character range, calculate the positions the 'elastic' tab stops should go at
    private final func elasticTabs(inRegion region: NSRange, of tables: IFElasticTabs) -> [NSTextTab] {
        // Now, chop up into lines and columns. Columns are separated by tabs. The last of the
        // lines is the current line.
        let lines = tables.cells(inRegion: region).map { line in
            line.map { textStorage.attributedSubstring(from: $0.rangeValue) }
        }
        return IFTabStops.elasticTabStops(forCells: lines, tabWidth: highlighter?.tabStopWidth ?? 0)
    }

    // MARK: - Gathering/retrieving intelligence data

    var intelligence: IFSyntaxIntelligence? {
        get {
            return intelSource
        }
        set {
            intelSource?.setSyntaxData(nil)

            intelData = IFIntelFile()
            intelSource = newValue

            intelSource?.setSyntaxData(self)
        }
    }

    var intelligenceData: IFIntelFile {
        return intelData
    }

    // MARK: - Intelligence callbacks

    var editingLineNumber: Int32 {
        return Int32(lineForIndex(editingRange.location))
    }

    func numberOfTabStops(forLine lineNumber: Int32) -> Int32 {
        // Details about the string
        let strLen = textStorage.length
        let str = textStorage.mutableString

        // Our current location, and the number of acquired tab stops
        var lineStart = lineStarts.start(ofLine: Int(lineNumber))
        var nTabStops: Int32 = 0

        while lineStart < strLen && str.character(at: lineStart) == tab {
            lineStart += 1
            nTabStops += 1
        }

        return nTabStops
    }

    func text(forLine lineNumber: Int32) -> String {
        let line = Int(lineNumber)
        if line < 0 || line >= lineStarts.count {
            return ""
        }

        // Get the start/end of the line
        let lineStart = lineStarts.start(ofLine: line)
        let lineEnd = line + 1 < lineStarts.count ? lineStarts.start(ofLine: line + 1) : textStorage.length

        return textStorage.mutableString.substring(with: NSRange(location: lineStart, length: lineEnd - lineStart))
    }

    func style(atStartOfLine lineNumber: Int32) -> IFSyntaxStyle {
        return charStyles.read(lineStarts.start(ofLine: Int(lineNumber)))
    }

    func style(atEndOfLine lineNumber: Int32) -> IFSyntaxStyle {
        let line = Int(lineNumber)
        let pos = line + 1 < lineStarts.count ? lineStarts.start(ofLine: line + 1) - 1 : textStorage.length - 1

        if pos < 0 {
            return .styleNotHighlighted
        }
        return charStyles.read(pos)
    }

    @objc(styleAtIndex:)
    func style(at index: UInt) -> IFSyntaxStyle {
        if index >= textStorage.length {
            return .styleNotHighlighted
        }
        return charStyles.read(Int(index))
    }

    func character(atEndOfLine lineNumber: Int32) -> unichar {
        let line = Int(lineNumber)
        let pos: Int

        if line + 1 < lineStarts.count {
            // Move back -2 to skip the newline at the end of the previous line
            pos = lineStarts.start(ofLine: line + 1) - 2
        } else {
            // Final character of the document
            pos = textStorage.length - 1
        }

        if pos < 0 {
            return 0
        }
        if textStorage.length < pos {
            return 0
        }

        return textStorage.mutableString.character(at: pos)
    }

    func callback(forEditing selector: Selector, withValue parameter: Any?) {
        if let intelSource {
            RunLoop.current.perform(selector,
                                    target: intelSource,
                                    argument: parameter,
                                    order: 9,
                                    modes: [.default])
        }
    }

    func replaceLine(_ lineNumber: Int32, withLine newLine: String) {
        let line = Int(lineNumber)
        if line >= lineStarts.count {
            NSLog("Attempt to replace line %i (but we only have %ld lines)", lineNumber, lineStarts.count)
        }

        // Get the start/end of the line
        let lineStart = lineStarts.start(ofLine: line)
        let lineEnd = line + 1 < lineStarts.count ? lineStarts.start(ofLine: line + 1) : textStorage.length

        // Make sure the undo manager can undo this change
        if let undoManager {
            let newLineRange = NSRange(location: lineStart, length: (newLine as NSString).length)
            let oldLine = textStorage.mutableString.substring(with: NSRange(location: lineStart, length: lineEnd - lineStart))
            undoManager.registerUndo(withTarget: textStorage) { storage in
                storage.replaceCharacters(in: newLineRange, with: oldLine)
            }
        }

        // Perform the operation
        textStorage.replaceCharacters(in: NSRange(location: lineStart, length: lineEnd - lineStart),
                                      with: newLine)
    }

    //
    // Restricted text storage
    //
    private final func restrictedData(for view: NSTextView) -> IFSyntaxRestricted? {
        for restricted in restrictions {
            if restricted.textView === view {
                return restricted
            }
        }
        return nil
    }

    @objc(restrictToRange:forTextView:)
    func restrict(to range: NSRange, for view: NSTextView) {
        // Get text for the given range
        let attributedString = textStorage.attributedSubstring(from: range)

        // Start editing the text
        isHighlighting = true

        // Remove old restricted region
        if let restricted = restrictedData(for: view) {
            // Remove delegate
            restricted.restrictedTextStorage.delegate = nil
            restrictions.removeAll { $0 === restricted }
        }

        // Create new restricted region
        let restricted = IFSyntaxRestricted(textView: view,
                                            range: range)

        // Set up the restricted text
        restricted.restrictedRange = range
        restricted.restrictedTextStorage.setAttributedString(attributedString)

        // Add new text storage
        restricted.restrictedTextStorage.delegate = self
        restrictions.append(restricted)
        view.layoutManager?.replaceTextStorage(restricted.restrictedTextStorage)

        // Finish editing the text
        isHighlighting = false
    }

    @objc(removeRestrictionForTextView:)
    func removeRestriction(for view: NSTextView) {
        // Find an existing restriction
        if let restricted = restrictedData(for: view) {
            // Start editing the text
            isHighlighting = true

            restricted.restrictedRange = NSRange(location: NSNotFound, length: 0)

            // Set restricted storage to an empty string
            let attributedString = NSAttributedString(string: "")
            restricted.restrictedTextStorage.setAttributedString(attributedString)

            // Remove delegate
            restricted.restrictedTextStorage.delegate = nil

            // Remove from list of restrictions
            restrictions.removeAll { $0 === restricted }

            // Finish editing the text
            isHighlighting = false
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
}
