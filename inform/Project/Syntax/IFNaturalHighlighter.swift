//
//  IFNaturalHighlighter.swift
//  Inform
//
//  Created by Andrew Hunter on 18/11/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFNaturalHighlighter.h.
//

import Cocoa

/// The code of an ASCII character, to compare with a `unichar` as a C character constant would be
private func ascii(_ scalar: Unicode.Scalar) -> unichar {
    return unichar(scalar.value)
}

private func isInform6Style(_ style: IFSyntaxStyle) -> Bool {
    return style.rawValue >= 0x20 && style.rawValue <= 0x40
}

@objc @implementation extension IFNaturalHighlighter {

    /// Syntax data that we're using
    private final var activeData: IFSyntaxData? = nil

    /// Highlighter for portions of the file that are Inform 6 code
    private final var inform6Highlighter: IFInform6Highlighter

    // MARK: - Initialisation

    override init() {
        inform6Highlighter = IFInform6Highlighter()

        super.init()
    }

    // MARK: - Notifying of the highlighter currently in use

    func setSyntaxData(_ aData: IFSyntaxData?) {
        activeData = aData

        inform6Highlighter.setSyntaxData(aData)
    }

    // MARK: - The highlighter itself

    func state(forCharacter chr: unichar,
               afterState lastState: IFSyntaxState) -> IFSyntaxState {
        switch activeData?.highlighterMode ?? 0 {
        case IFNaturalModeStandard:
            // Natural Inform mode
            switch lastState {
            case IFNaturalStateMaybeInform6:
                if chr == ascii("-") {
                    // Switch to Inform 6 mode
                    activeData?.pushState()
                    activeData?.highlighterMode = IFNaturalModeInform6

                    if activeData?.preceeded(byKeyword: "Include",
                                             offset: 1) ?? false {
                        // Is top-level Inform 6
                        return IFSyntaxStateDefault
                    } else {
                        // Is as if preceeded by '[T;'
                        var newState = inform6Highlighter.state(forCharacter: ascii("["),
                                                                afterState: IFSyntaxStateDefault)
                        newState = inform6Highlighter.state(forCharacter: ascii("T"),
                                                            afterState: newState)
                        newState = inform6Highlighter.state(forCharacter: ascii(";"),
                                                            afterState: newState)

                        // Those characters aren't in the text, so don't colour back over them
                        var primedState = IFInform6State(state: newState)
                        primedState.bitmap.colourBacktrack = 0
                        return primedState.state
                    }
                }
                fallthrough
            case IFNaturalStateBlankLine:
                if chr == ascii(" ") || chr == ascii("\n") || chr == ascii("\t") || chr == ascii("\r") {
                    return IFNaturalStateBlankLine
                }
                // ObRAIF: here is why fall-through cases are a *good* thing
                // (Of course, first time I tried this, I got these conditions the wrong way round... Mmm, bug)
                fallthrough
            case IFNaturalStateSpace:
                if (chr == ascii("\"")) || (chr == 0x201C) || (chr == 0x201D) {
                    return IFNaturalStateQuote
                }
                fallthrough
            case IFNaturalStateText:
                // Just plain ole text
                if chr == ascii("[") {
                    activeData?.pushState()
                    return IFNaturalStateComment
                }
                if chr == ascii("\n") || chr == ascii("\r") {
                    return IFNaturalStateBlankLine
                }

                if chr == ascii("(") {
                    return IFNaturalStateMaybeInform6
                }
                if chr == ascii(" ") || chr == ascii("\t") || chr == ascii(".") || chr == ascii(")") || chr == ascii("}") || chr == ascii(";")
                    || chr == ascii(":") || chr == ascii(",") || chr == ascii("?") || chr == ascii("!") || chr == ascii("{") {
                    return IFNaturalStateSpace
                }
                return IFNaturalStateText

            case IFNaturalStateComment:
                if chr == ascii("[") {
                    activeData?.pushState()
                    return IFNaturalStateComment
                }
                if chr == ascii("]") {
                    return activeData?.popState() ?? 0
                }
                return IFNaturalStateComment

            case IFNaturalStateSubstitution:
                if chr == ascii("]") {
                    return IFNaturalStateQuote
                }
                fallthrough
            case IFNaturalStateQuote:
                if (chr == ascii("\"")) || (chr == 0x201C) || (chr == 0x201D) {
                    return IFNaturalStateText
                }
                if chr == ascii("[") {
                    return IFNaturalStateSubstitution
                }
                return lastState

            default:
                break
            }
            // Unknown state
            return IFNaturalStateText

        // Various Inform 6 modes
        case IFNaturalModeInform6MightEnd:
            if chr == ascii(")") {
                // Switch back to standard mode
                _ = activeData?.popState()
                return IFNaturalStateText
            }

            // Switch back to Inform 6 mode
            activeData?.highlighterMode = IFNaturalModeInform6
            fallthrough

        case IFNaturalModeInform6:
            if chr == ascii("-") {
                // Next character might break us out of Inform 6 mode
                activeData?.highlighterMode = IFNaturalModeInform6MightEnd
            }

            // Run the Inform 6 highlighter
            return inform6Highlighter.state(forCharacter: chr,
                                            afterState: lastState)

        default:
            break
        }

        return IFNaturalStateText
    }

    func style(forCharacter chr: unichar,
               nextState: IFSyntaxState,
               lastState: IFSyntaxState) -> IFSyntaxStyle {
        var lastState = lastState

        switch activeData?.highlighterMode ?? 0 {
        // Natural Inform styles
        case IFNaturalModeStandard:
            // Some states override the next state
            if (lastState == IFNaturalStateQuote) &&
               (nextState != IFNaturalStateSubstitution) {
                return .gameText
            }
            if lastState == IFNaturalStateComment {
                return .comment
            }
            if lastState == IFNaturalStateSubstitution {
                return .substitution
            }

            switch nextState {
            case IFNaturalStateComment:
                return .comment

            case IFNaturalStateQuote:
                return .gameText

            case IFNaturalStateSubstitution:
                return .substitution

            case IFNaturalStateSpace,
                 IFNaturalStateText,
                 IFNaturalStateBlankLine,
                 IFNaturalStateMaybeInform6:
                return .naturalInform

            default:
                break
            }
            return .naturalInform

        // Inform 6 styles
        case IFNaturalModeInform6MightEnd,
             IFNaturalModeInform6:
            if lastState == IFNaturalStateMaybeInform6 {
                // The '-' that starts the Inform 6 code follows an Inform 7 state, so style it
                // in the state that the Inform 6 code starts in
                lastState = nextState
            }
            let style = inform6Highlighter.style(forCharacter: chr,
                                                 nextState: nextState,
                                                 lastState: lastState)
            return IFSyntaxStyle(rawValue: style.rawValue + 0x20)

        default:
            break
        }

        return []
    }

    func rehintLine(_ line: String,
                    styles: IFSyntaxStyles,
                    initialState: IFSyntaxState) {
        let line = line as NSString
        let thisLine = line.lowercased.trimmingCharacters(in: .whitespacesAndNewlines)

        // This line might be a header line
        var isHeader = false
        let isInAppropriateStateForHeader = (initialState == IFNaturalStateBlankLine) || (initialState == IFSyntaxStateDefault)

        if styles.numCharStyles == 0 {
            return
        }

        if isInAppropriateStateForHeader && !isInform6Style(styles.read(0)) {
            if thisLine.hasPrefix("---- documentation ----") { isHeader = true }
            if thisLine.hasPrefix("volume ")   { isHeader = true }
            if thisLine.hasPrefix("volume: ")  { isHeader = true }
            if thisLine.hasPrefix("book ")     { isHeader = true }
            if thisLine.hasPrefix("book: ")    { isHeader = true }
            if thisLine.hasPrefix("part ")     { isHeader = true }
            if thisLine.hasPrefix("part: ")    { isHeader = true }
            if thisLine.hasPrefix("chapter ")  { isHeader = true }
            if thisLine.hasPrefix("chapter: ") { isHeader = true }
            if thisLine.hasPrefix("section ")  { isHeader = true }
            if thisLine.hasPrefix("section: ") { isHeader = true }
            if thisLine.hasPrefix("example: ") { isHeader = true }
        }

        if isHeader {
            for x in 0..<line.length {
                styles.write(x, value: .heading)
            }
        }

        // This line might have some Inform 6 highlighting to do
        let i6Styles = IFSyntaxStyles()
        var x = 0
        while x < line.length {
            if isInform6Style(styles.read(x)) {
                // Found an Inform 6 region
                var thisRegion = NSRange(location: x, length: 0)

                // Convert to standard style, work out how long the region is
                while x < line.length && isInform6Style(styles.read(x)) {
                    thisRegion.length += 1
                    styles.write(x, value: IFSyntaxStyle(rawValue: styles.read(x).rawValue - 0x20))
                    x += 1
                }

                // Get the Inform 6 highlighter to rehint this section
                i6Styles.styles = styles.styles.map { $0 + thisRegion.location }
                i6Styles.numCharStyles = styles.numCharStyles - UInt(thisRegion.location)
                inform6Highlighter.rehintLine(line.substring(with: thisRegion),
                                              styles: i6Styles,
                                              initialState: IFSyntaxStateDefault)
            }
            x += 1
        }
    }

    // MARK: - Styles

    @objc(attributesForStyle:)
    func attributes(for style: IFSyntaxStyle) -> [NSAttributedString.Key: Any] {
        return IFProjectPane.attribute(for: style)
    }

    var tabStopWidth: CGFloat {
        return IFPreferences.shared.tabWidth
    }
}
