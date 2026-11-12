//
//  IFHighlighterState.swift
//  Inform
//
//  Moved out of IFSyntaxData in November 2026. The interface is IFHighlighterState.h.
//

import Cocoa

private let tab: unichar            = 0x09      // \t
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

@objc @implementation extension IFHighlighterState {

    /// The text, whose characters' styles are given and whose lines' states are kept
    private final let textStorage: NSTextStorage
    private final let charStyles: IFCharacterStyles

    private final var lineStates: [[IFSyntaxStackEntry]]    // Syntax stack at the start of lines

    //
    // Syntax state - current highlighter state
    //
    private final var syntaxStack: [IFSyntaxStackEntry]     // Current syntax stack
    private final var syntaxPos: Int                        // Current highlighter position
    private final var syntaxState: IFSyntaxState            // Active state
    private final var syntaxMode: IFHighlighterMode         // 'Mode' - possible extra state from the highlighter

    init(text: NSTextStorage, characterStyles: IFCharacterStyles) {
        textStorage = text
        charStyles = characterStyles

        syntaxStack = []
        syntaxPos = 0
        syntaxState = IFSyntaxState(IFSyntaxStateDefault)
        syntaxMode = 0

        // Initial stack starts with the default state
        lineStates = [[IFSyntaxStackEntry(state: IFSyntaxState(IFSyntaxStateDefault), mode: 0)]]

        super.init()
    }

    // MARK: - Each line's state

    var lineCount: Int {
        return lineStates.count
    }

    @objc(replaceLinesAfter:through:withLines:)
    func replaceLines(after firstLine: Int, through lastLine: Int, with nNewLines: Int) {
        // newLineStates - an array of 'stacks' (one stack per line). Each 'stack' is a dictionary of the current
        // highlighter state and inform6/7 'mode'.
        let notHighlighted = [IFSyntaxStackEntry(state: IFSyntaxState(IFSyntaxStateNotHighlighted), mode: 0)]
        let newLineStates = [[IFSyntaxStackEntry]](repeating: notHighlighted, count: nNewLines)

        // Update the line states
        lineStates.replaceSubrange((firstLine + 1)..<(lastLine + 1), with: newLineStates)
    }

    @objc(startLine:atIndex:)
    func startLine(_ line: Int, at index: Int) {
        // Set up the state
        syntaxStack = lineStates[line]

        syntaxState = syntaxStack.last?.state ?? 0
        syntaxMode  = syntaxStack.last?.mode ?? 0
        _ = syntaxStack.popLast()

        syntaxPos = index
    }

    @objc(finishLine:)
    func finishLine(_ line: Int) -> Bool {
        // Store the current state on the stack
        syntaxStack.append(IFSyntaxStackEntry(state: syntaxState,
                                              mode: syntaxMode))

        // Compare the new stack against the old version to see if anything has changed
        var unchanged = false
        if line + 1 < lineStates.count {
            let previousOldStack = lineStates[line + 1]
            unchanged = previousOldStack == syntaxStack
            lineStates[line + 1] = syntaxStack
        }
        return unchanged
    }

    // MARK: - Communication from the highlighter

    var position: Int {
        get {
            return syntaxPos
        }
        set {
            syntaxPos = newValue
        }
    }

    var state: IFSyntaxState {
        get {
            return syntaxState
        }
        set {
            syntaxState = newValue
        }
    }

    var mode: IFHighlighterMode {
        get {
            // Retrieves the mode
            return syntaxMode
        }
        set {
            // Sets the 'mode' of the highlighter (additional state info, basically)
            syntaxMode = newValue
        }
    }

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
        precondition(syntaxPos < charStyles.count, "index out of range")
        for x in stride(from: syntaxPos - Int(backtrackLength), to: syntaxPos, by: 1) {
            if x >= 0 {
                charStyles.setStyle(newStyle, at: x)
            }
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
}
