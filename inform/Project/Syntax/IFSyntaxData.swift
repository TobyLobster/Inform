//
//  IFSyntaxData.swift
//  Inform
//
//  Created by Toby Nelson in 2014.
//  Translated from Objective-C in November 2026. The interface is still IFSyntaxData.h.
//

import Cocoa

private let tab: unichar            = 0x09      // \t

@objc @implementation extension IFSyntaxData {

    let textStorage: NSTextStorage
    var name: String
    var type: IFHighlightType
    var undoManager: UndoManager?
    var isHighlighting: Bool

    // Restricted storage
    private final let restrictedStorages: IFRestrictedStorages

    //
    // Syntax state - Line and character information
    //
    private final let lineStarts: IFLineStarts                        // Start positions of each line

    private final let charStyles: IFCharacterStyles                   // Syntax state for each character

    //
    // Syntax state - the highlighter's state at the start of each line, and as it runs
    //
    private final let highlighterState: IFHighlighterState

    //
    // The highlighter
    //
    private final let highlighter: IFSyntaxHighlighter?

    //
    // Paragraph styles
    //
    private final let lineStyles: IFLineStyles                        // The paragraph style of each line

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
        charStyles = IFCharacterStyles()

        switch aType {
        case .inform6:
            highlighter = IFInform6Highlighter()
        case .inform7:
            highlighter = IFNaturalHighlighter()
        default:            // IFHighlightTypeNone
            highlighter = nil
        }

        // The views' restricted storages (up to two)
        restrictedStorages = IFRestrictedStorages(textStorage: aStorage)

        // Are we currently syntax highlighting?
        isHighlighting = false

        // Initial state
        lineStarts = IFLineStarts()
        highlighterState = IFHighlighterState(text: aStorage, characterStyles: charStyles)

        lineStyles = IFLineStyles(text: aStorage, lineStarts: lineStarts, highlighter: highlighter)

        intelSource = nil
        intelData = IFIntelFile()

        editingRange = NSRange(location: 0, length: 0)

        super.init()

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
        editingRange.location += restrictedStorages.locationInText(of: storage)

        // Rewrite the change if needed (e.g. to auto-insert tabs when user presses return)
        if let rewritten = rewriteInput(newString) {
            // Actually make the change
            storage.replaceCharacters(in: newRange, with: rewritten)

            // The text view undoes what was typed, so the rewriting is undone first, putting back what was typed. It's
            // undone in the main text, where the restricted storage's change is about to be mirrored.
            if let undoManager {
                IFSyntaxData.registerUndo(ofChangeAt: editingRange.location,
                                          from: newString,
                                          to: rewritten,
                                          in: textStorage,
                                          with: undoManager)
            }
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
        let oldRange = NSRange(location: newRange.location, length: newRange.length - changeInLength)

        // Start editing
        textStorage.beginEditing()

        //
        // Mirror the change from a restricted storage into main text storage. This makes sure the
        // main text is up to date.
        //
        if storage !== textStorage {
            let newString = storage.attributedSubstring(from: newRange)

            restrictedStorages.mirrorChange(in: storage,
                                            replaceRange: oldRange,
                                            withAttributedString: newString)

            // Convert local ranges to refer to full text
            newRange.location += restrictedStorages.locationInText(of: storage)
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
        restrictedStorages.update(afterEditingRange: newRange,
                                  changeInLength: changeInLength,
                                  changedAttributesRange: changedAttributesRange,
                                  editedStorage: storage)

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

        // Number of lines that have been added or taken away
        let lineDifference = nNewLines - (lastLine - firstLine)

#if HighlighterDebug
        NSLog("Highlighter: %ld %@ lines (%ld total)", lineDifference, nNewLines < (lastLine - firstLine) ? "new" : "removed", lineStarts.count - lineDifference)
#endif

        if nNewLines < (lastLine - firstLine) {
            // Remove the appropriate lines from the intelligence data
            intelData.removeLines(NSRange(location: firstLine + 1, length: -lineDifference))
        } else {
            intelData.removeLines(NSRange(location: firstLine + 1, length: lastLine - firstLine))

            for _ in 0..<nNewLines {
                intelData.insertLine(beforeLine: Int32(firstLine + 1))
            }
        }
        lineStyles.replaceLines(after: firstLine, through: lastLine, with: nNewLines)

        // Update the line states
        highlighterState.replaceLines(after: firstLine, through: lastLine, with: nNewLines)

        // Update the character styles of everything beyond our change, and mark the edited range's as no longer valid
        charStyles.replaceStyles(afterEditingRange: newRange, changeInLength: changeInLength)

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
            let style = charStyles.style(at: range.location)
            var styleRange = charStyles.rangeOfStyle(at: range.location)

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
        highlighterState.pushState()
    }

    func popState() -> IFSyntaxState {
        return highlighterState.popState()
    }

    @objc(backtrackWithStyle:length:)
    func backtrack(with newStyle: IFSyntaxStyle, length backtrackLength: Int32) {
        highlighterState.backtrack(with: newStyle, length: backtrackLength)
    }

    var highlighterMode: IFHighlighterMode {
        get {
            return highlighterState.mode
        }
        set {
            highlighterState.mode = newValue
        }
    }

    func preceeded(byKeyword keyword: String, offset: Int32) -> Bool {
        return highlighterState.preceeded(byKeyword: keyword, offset: offset)
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
        let styles = IFSyntaxStyles()
        let allStyles = charStyles.styles(from: 0)                           // Shared until the next edit
        let str = textStorage.mutableString
        let highlighter = self.highlighter

        for line in firstLine...lastLine {
            // The range of characters in this line
            let firstChar = lineStarts.start(ofLine: line)
            let lastChar  = (line + 1) < lineStarts.count ? lineStarts.start(ofLine: line + 1) : textStorage.length

            // Set up the state
            highlighterState.startLine(line, at: firstChar)

            let initialState = highlighterState.state

            // Highlight this line
            while highlighterState.position < lastChar {
                // Current state
                let curChar = str.character(at: highlighterState.position)

                // Next state
                let nextState = highlighter?.state(forCharacter: curChar,
                                                   afterState: highlighterState.state) ?? 0

                // Next style
                let nextStyle = highlighter?.style(forCharacter: curChar,
                                                   nextState: nextState,
                                                   lastState: highlighterState.state) ?? []

                // Store the style
                precondition(highlighterState.position < Int(allStyles.numCharStyles), "index out of range")
                allStyles.styles![highlighterState.position] = nextStyle

                // Store the state
                highlighterState.state = nextState

                highlighterState.position += 1
            }

            // Provide an opportunity for the highlighter to hint keywords, etc
            let lineToHint = str.substring(with: NSRange(location: firstChar, length: lastChar - firstChar))
#if HighlighterDebug
            NSLog("Highlighter: finished line %ld: '%@', rehinting", line, lineToHint)
#endif
            styles.styles = allStyles.styles.map { $0 + firstChar }
            styles.numCharStyles = allStyles.numCharStyles - UInt(firstChar)
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
            lineStyles.resetLine(line)

            // Store the current state on the stack, as the next line's, and compare it with the old one
            let nextLineUnchanged = highlighterState.finishLine(line)

            //
            // Optimisation: If the state stack for the next line hasn't changed from what it
            // was previously, then we are done. (However, if we are reformatting due to a tab
            // setting change, then we can't optimise this way, we must format the entire rest
            // of the text).
            //
            if !forceUpdateTabs {
                // If our state for the next line has not changed, then we are done syntax highlighting
                if nextLineUnchanged {
                    lastLine = line
                    break
                }
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
        lineStyles.applyStyles(from: firstLine, through: lastLine)

        //
        // Phase Three: Add elastic tabs
        //
        if IFPreferences.shared.elasticTabs {
            changedRange = lineStyles.layOutTables(nearLinesFrom: firstLine,
                                                   through: lastLine,
                                                   updatingAll: forceUpdateTabs,
                                                   changedRange: changedRange)
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
            lineStyles.forgetStandardStyle()
        }

        // Update highlighting for entire range
        textStorage.beginEditing()

        _ = syntaxHighlightRange(NSRange(location: 0, length: textStorage.length),
                                 forceUpdateTabs: forceUpdateTabs)

        textStorage.endEditing()

        // Restore old state
        isHighlighting = oldIsHighlighting
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
        return charStyles.style(at: lineStarts.start(ofLine: Int(lineNumber)))
    }

    func style(atEndOfLine lineNumber: Int32) -> IFSyntaxStyle {
        let line = Int(lineNumber)
        let pos = line + 1 < lineStarts.count ? lineStarts.start(ofLine: line + 1) - 1 : textStorage.length - 1

        if pos < 0 {
            return .styleNotHighlighted
        }
        return charStyles.style(at: pos)
    }

    @objc(styleAtIndex:)
    func style(at index: UInt) -> IFSyntaxStyle {
        if index >= textStorage.length {
            return .styleNotHighlighted
        }
        return charStyles.style(at: Int(index))
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

    /// Lets the undo manager undo a change to the text that wasn't typed, such as a heading's number, by putting back
    /// what it replaced, and then redo it
    private static func registerUndo(ofChangeAt location: Int,
                                     from oldText: String,
                                     to newText: String,
                                     in storage: NSTextStorage,
                                     with undoManager: UndoManager) {
        undoManager.registerUndo(withTarget: storage) { storage in
            registerUndo(ofChangeAt: location, from: newText, to: oldText, in: storage, with: undoManager)
            storage.replaceCharacters(in: NSRange(location: location, length: (newText as NSString).length),
                                      with: oldText)
        }
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
            let oldLine = textStorage.mutableString.substring(with: NSRange(location: lineStart, length: lineEnd - lineStart))
            IFSyntaxData.registerUndo(ofChangeAt: lineStart,
                                      from: oldLine,
                                      to: newLine,
                                      in: textStorage,
                                      with: undoManager)
        }

        // Perform the operation
        textStorage.replaceCharacters(in: NSRange(location: lineStart, length: lineEnd - lineStart),
                                      with: newLine)
    }

    //
    // Restricted text storage
    //
    @objc(restrictToRange:forTextView:)
    func restrict(to range: NSRange, for view: NSTextView) {
        // Start editing the text
        isHighlighting = true

        restrictedStorages.restrict(to: range, for: view, delegate: self)

        // Finish editing the text
        isHighlighting = false
    }

    @objc(removeRestrictionForTextView:)
    func removeRestriction(for view: NSTextView) {
        // Find an existing restriction
        if restrictedStorages.isRestricted(for: view) {
            // Start editing the text
            isHighlighting = true

            restrictedStorages.removeRestriction(for: view)

            // Finish editing the text
            isHighlighting = false
        }
    }

    @objc(isRestrictedForTextView:)
    func isRestricted(for view: NSTextView) -> Bool {
        return restrictedStorages.isRestricted(for: view)
    }

    @objc(restrictedRangeForTextView:)
    func restrictedRange(for view: NSTextView) -> NSRange {
        return restrictedStorages.restrictedRange(for: view)
    }

    @objc(restrictedTextStorageForTextView:)
    func restrictedTextStorage(for view: NSTextView) -> NSTextStorage? {
        return restrictedStorages.restrictedTextStorage(for: view)
    }
}
