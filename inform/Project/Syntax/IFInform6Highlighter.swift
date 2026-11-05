//
//  IFInform6Highlighter.swift
//  Inform
//
//  Created by Andrew Hunter on 18/11/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFInform6Highlighter.h.
//

import Cocoa

/// The code of an ASCII character, to compare with a `unichar` as a C character constant would be
private func ascii(_ scalar: Unicode.Scalar) -> unichar {
    return unichar(scalar.value)
}

// MARK: - The statemachine itself

private func isIdentifier(_ chr: unichar) -> Bool {
    return isalpha(Int32(chr)) != 0 || isdigit(Int32(chr)) != 0
        || chr == ascii("$") || chr == ascii("#") || chr == ascii("_")
}

// The keywords, in lower case
private let codeKeywords: Set<String> = [
    "box", "break", "child", "children", "continue", "default",
    "do", "elder", "eldest", "else", "false", "font", "for", "give", "glk",
    "has", "hasnt", "if", "in", "indirect", "inversion", "jump",
    "metaclass", "move", "new_line", "nothing", "notin", "objectloop",
    "ofclass", "or", "parent", "print", "print_ret", "provides", "quit",
    "random", "read", "remove", "restore", "return", "rfalse", "rtrue",
    "save", "sibling", "spaces", "string", "style", "switch", "to",
    "true", "until", "while", "younger", "youngest",
]

private let otherKeywords: Set<String> = [
    "first", "last", "meta", "only", "private", "replace", "reverse",
    "string", "table",
]

@objc @implementation extension IFInform6Highlighter {

    private final var activeData: IFSyntaxData? = nil

    private final func innerStateMachine(_ state: inout IFInform6State,
                                         character chr: unichar) -> Bool {
        var terminalFlag = false

        if state.bitmap.inner >= 0x8000 {
            state.bitmap.inner = 0
        }

        if state.bitmap.inner == 0 {
            switch chr {
            case ascii("-"):
                state.bitmap.inner = 1
            case ascii("*"):
                state.bitmap.inner = 3
                terminalFlag = true
            case ascii(" "), ascii("\t"), ascii("#"), ascii("\n"), ascii("\r"):
                state.bitmap.inner = 0
            case ascii("_"):
                state.bitmap.inner = 0x100
            case ascii("w"):
                state.bitmap.inner = 0x101
            case ascii("h"):
                state.bitmap.inner = 0x111
            case ascii("c"):
                state.bitmap.inner = 0x121
            default:
                if isalpha(Int32(chr)) != 0 { state.bitmap.inner = 0x100 } else { state.bitmap.inner = 0xff }
            }
        } else if state.bitmap.inner == 1 {
            if chr == ascii(">") {
                state.bitmap.inner = 2
                terminalFlag = true
            } else {
                state.bitmap.inner = 0xff
            }
        } else if state.bitmap.inner == 2 {
            state.bitmap.inner = 0
        } else if state.bitmap.inner == 3 {
            state.bitmap.inner = 0
        } else if state.bitmap.inner == 0xff {
            if chr == ascii(" ") || chr == ascii("\t") || chr == ascii("\n") || chr == ascii("\r") {
                state.bitmap.inner = 0
            } else {
                state.bitmap.inner = 0xff
            }
        } else if state.bitmap.inner >= 0x100 && state.bitmap.inner < 0x8000 {
            if !(isalpha(Int32(chr)) != 0 || isdigit(Int32(chr)) != 0 || chr == ascii("_")) {
                state.bitmap.inner += 0x8000
                terminalFlag = true
            }

            switch state.bitmap.inner {
            case 0x101:
                if chr == ascii("i") {
                    state.bitmap.inner = 0x202
                } else {
                    state.bitmap.inner = 0x200
                }
            case 0x202:
                if chr == ascii("t") {
                    state.bitmap.inner = 0x303
                } else {
                    state.bitmap.inner = 0x300
                }
            case 0x303:
                if chr == ascii("h") {
                    state.bitmap.inner = 0x404
                } else {
                    state.bitmap.inner = 0x400
                }
            case 0x111:
                if chr == ascii("a") {
                    state.bitmap.inner = 0x212
                } else {
                    state.bitmap.inner = 0x200
                }
            case 0x212:
                if chr == ascii("s") {
                    state.bitmap.inner = 0x313
                } else {
                    state.bitmap.inner = 0x300
                }
            case 0x121:
                if chr == ascii("l") {
                    state.bitmap.inner = 0x222
                } else {
                    state.bitmap.inner = 0x200
                }
            case 0x222:
                if chr == ascii("a") {
                    state.bitmap.inner = 0x323
                } else {
                    state.bitmap.inner = 0x300
                }
            case 0x323:
                if chr == ascii("s") {
                    state.bitmap.inner = 0x424
                } else {
                    state.bitmap.inner = 0x400
                }
            case 0x424:
                if chr == ascii("s") {
                    state.bitmap.inner = 0x525
                } else {
                    state.bitmap.inner = 0x500
                }

            default:
                if isalpha(Int32(chr)) != 0 || isdigit(Int32(chr)) != 0 || chr == ascii("_") {
                    state.bitmap.inner += 0x100
                }
            }
        } else if state.bitmap.inner >= 0x8000 {
            state.bitmap.inner = 0
        }

        return terminalFlag
    }

    private final func nextState(_ state: IFInform6State,
                                 nextCharacter chr: unichar) -> IFInform6State {
        var newState = state

        // 1.  Is the comment bit set?
        //        Is the character a new-line?
        //           If so, clear the comment bit.
        //           Stop.

        if state.bitmap.comment != 0 {
            if chr == ascii("\n") || chr == ascii("\r") {
                newState.bitmap.comment = 0
            }
            return newState
        }

        // 2.  Is the double-quote bit set?
        //        Is the character a double-quote?
        //           If so, clear the double-quote bit.
        //           Stop.

        if state.bitmap.doubleQuote != 0 {
            if chr == ascii("\"") {
                newState.bitmap.doubleQuote = 0
            }
            return newState
        }

        // 3.  Is the single-quote bit set?
        //        Is the character a single-quote?
        //           If so, clear the single-quote bit.
        //           Stop.

        if state.bitmap.singleQuote != 0 {
            if chr == ascii("'") {
                newState.bitmap.singleQuote = 0
            }
            return newState
        }

        // 4.  Is the character a single quote?
        //        If so, set the single-quote bit and stop.

        if chr == ascii("'") {
            newState.bitmap.singleQuote = 1
            return newState
        }

        // 5.  Is the character a double quote?
        //        If so, set the double-quote bit and stop.

        if chr == ascii("\"") {
            newState.bitmap.doubleQuote = 1
            return newState
        }

        // 6.  Is the character an exclamation mark?
        //        If so, set the comment bit and stop.

        if chr == ascii("!") {
            newState.bitmap.comment = 1
            return newState
        }

        // 7.  Is the statement bit set?
        if state.bitmap.statement != 0 {
            //        If so:
            //           Is the character "]"?
            //              If so:
            //                 Clear the statement bit.
            //                 Stop.

            if chr == ascii("]") {
                newState.bitmap.statement = 0
                return newState
            }

            //           If the after-restart bit is clear, stop.

            if state.bitmap.afterRestart == 0 {
                return newState
            }

            //           Run the inner finite state machine.

            let terminalFlag = innerStateMachine(&newState,
                                                 character: chr)

            //           If it results in a keyword terminal (that is, a terminal
            //           which has inner state 0x100 or above):
            //              Set colour-backtrack (and record the backtrack colour
            //              as "function" colour).
            //              Clear after-restart.

            if terminalFlag && newState.bitmap.inner >= 0x100 {
                newState.bitmap.colourBacktrack = 1
                newState.bitmap.backtrackColour = UInt32(IFSyntaxStyle.function.rawValue)
                newState.bitmap.afterRestart = 0
            }

            //           Stop.

            return newState
        } else {
            //        If not:
            //           Is the character "["?
            //              If so:
            //                 Set the statement bit.
            //                 If the after-marker bit is clear, set after-restart.
            //                 Stop.

            if chr == ascii("[") {
                newState.bitmap.statement = 1
                if newState.bitmap.afterMarker == 0 {
                    newState.bitmap.afterRestart = 1
                }
                return newState
            }

            //           Run the inner finite state machine.

            let terminalFlag = innerStateMachine(&newState,
                                                 character: chr)

            //           If it results in a terminal:
            if terminalFlag {
                //              Is the inner state 2 [after "->"] or 3 [after "*"]?
                //                 If so:
                //                    Set after-marker.
                //                    Set colour-backtrack (and record the backtrack
                //                    colour as "directive" colour).
                //                    Zero the inner state.

                if newState.bitmap.inner == 2 {
                    newState.bitmap.afterMarker = 1
                    newState.bitmap.colourBacktrack = 1
                    newState.bitmap.backtrackColour = UInt32(IFSyntaxStyle.directive.rawValue)
                    newState.bitmap.inner = 0
                }

                //              [If not, the terminal must be from a keyword.]
                //              Is the inner state 0x404 [after "with"]?
                //                 If so:
                //                    Set colour-backtrack (and record the backtrack
                //                    colour as "directive" colour).
                //                    Set after-marker.
                //                    Set highlight.
                //                    Clear highlight-all.

                else if newState.bitmap.inner == 0x8404 {
                    newState.bitmap.colourBacktrack = 1
                    newState.bitmap.backtrackColour = UInt32(IFSyntaxStyle.directive.rawValue)
                    newState.bitmap.afterMarker = 1
                    newState.bitmap.highlight = 1
                    newState.bitmap.highlightAll = 0
                }

                //              Is the inner state 0x313 ["has"] or 0x525 ["class"]?
                //                 If so:
                //                    Set colour-backtrack (and record the backtrack
                //                    colour as "directive" colour).
                //                    Set after-marker.
                //                    Clear highlight.
                //                    Set highlight-all.

                else if newState.bitmap.inner == 0x8313 || newState.bitmap.inner == 0x8525 {
                    newState.bitmap.colourBacktrack = 1
                    newState.bitmap.backtrackColour = UInt32(IFSyntaxStyle.directive.rawValue)
                    newState.bitmap.afterMarker = 1
                    newState.bitmap.highlight = 0
                    newState.bitmap.highlightAll = 1
                }

                //              If the inner state isn't one of these: [so that recent
                //              text has formed some alphanumeric token which might or
                //              might not be a reserved word of some kind]
                //                 If waiting-for-directive is set:
                //                       Set colour-backtrack (and record the backtrack
                //                       colour as "directive" colour)
                //                       Clear waiting-for-directive.
                //                 If not, but highlight-all is set:
                //                       Set colour-backtrack (and record the backtrack
                //                       colour as "property" colour)
                //                 If not, but highlight is set:
                //                       Clear highlight.
                //                       Set colour-backtrack (and record the backtrack
                //                       colour as "property" colour).

                else {
                    if newState.bitmap.waitingForDirective == 0 {
                        newState.bitmap.colourBacktrack = 1
                        newState.bitmap.backtrackColour = UInt32(IFSyntaxStyle.directive.rawValue)
                        newState.bitmap.waitingForDirective = 1    // inverted
                    } else if newState.bitmap.highlightAll != 0 {
                        newState.bitmap.colourBacktrack = 1
                        newState.bitmap.backtrackColour = UInt32(IFSyntaxStyle.property.rawValue)
                    } else if newState.bitmap.highlight != 0 {
                        newState.bitmap.highlight = 0
                        newState.bitmap.colourBacktrack = 1
                        newState.bitmap.backtrackColour = UInt32(IFSyntaxStyle.property.rawValue)
                    }
                }
            }

            //              Is the character ";"?
            //                 If so:
            //                    Set wait-direct.
            //                    Clear after-marker.
            //                    Clear after-restart.
            //                    Clear highlight.
            //                    Clear highlight-all.

            if chr == ascii(";") {
                newState.bitmap.waitingForDirective = 0 // Inverted
                newState.bitmap.afterMarker = 0
                newState.bitmap.afterRestart = 0
                newState.bitmap.highlight = 0
                newState.bitmap.highlightAll = 0
            }

            //              Is the character ","?
            //                 If so:
            //                    Set after-marker.
            //                    Set highlight.

            if chr == ascii(",") {
                newState.bitmap.afterMarker = 1
                newState.bitmap.highlight = 1
            }

            //           Stop.

            return newState
        }
    }

    // MARK: - Notifying of the highlighter currently in use

    func setSyntaxData(_ aData: IFSyntaxData?) {
        activeData = aData
    }

    // MARK: - The highlighter itself

    func state(forCharacter chr: unichar,
               afterState lastState: IFSyntaxState) -> IFSyntaxState {
        var state = IFInform6State(state: lastState)
        state.bitmap.colourBacktrack = 0 // Only lives once!

        return nextState(state,
                         nextCharacter: chr).state
    }

    func style(forCharacter chr: unichar,
               nextState: IFSyntaxState,
               lastState: IFSyntaxState) -> IFSyntaxStyle {
        let state = IFInform6State(state: lastState)

        // Colour backtracking
        let newState = IFInform6State(state: nextState)

        if newState.bitmap.colourBacktrack != 0 {
            var backLen = Int32(newState.bitmap.inner)

            backLen &= ~0x8000
            backLen >>= 8
            backLen += 1

            activeData?.backtrack(with: IFSyntaxStyle(rawValue: UInt8(newState.bitmap.backtrackColour)),
                                  length: backLen)
        }

        // Colour for this character
        if state.bitmap.singleQuote != 0 || state.bitmap.doubleQuote != 0 { return .string }
        if state.bitmap.comment != 0 { return .comment }
        if chr == ascii("!") { return .comment }     // Starts a comment
        if state.bitmap.statement != 0 {
            if chr == ascii("[") || chr == ascii("]") { return .function }
            if chr == ascii("'") || chr == ascii("\"") { return .string }
            return .codeAlpha
        }

        if chr == ascii(",") || chr == ascii(";") || chr == ascii("*") || chr == ascii(">") { return .directive }
        if chr == ascii("[") || chr == ascii("]") { return .function }
        if chr == ascii("'") || chr == ascii("\"") { return .string }

        return []
    }

    func rehintLine(_ line: String,
                    styles: IFSyntaxStyles,
                    initialState state: IFSyntaxState) {
        let line = line as NSString
        let strLen = line.length
        var x: Int
        var chr: unichar

        // Firstly, any characters with colour Q (quoted-text) which have special
        // meanings are given "escape-character colour" instead.  This applies
        // to "~", "^", "\" and "@" followed by (possibly) another "@" and a
        // number of digits.

        x = 0
        while x < strLen {
            if styles.read(x) == .string {
                chr = line.character(at: x)

                switch chr {
                case ascii("~"), ascii("^"), ascii("\\"):
                    styles.write(x, value: .escapeCharacter)

                case ascii("@"):
                    styles.write(x, value: .escapeCharacter)

                    if (x + 1) < strLen {
                        chr = line.character(at: x + 1)

                        if chr == ascii("@") {
                            x += 1
                            styles.write(x, value: .escapeCharacter)
                        }
                    }

                    repeat {
                        x += 1
                        if x >= strLen { break }

                        chr = line.character(at: x)

                        if isdigit(Int32(chr)) != 0 { styles.write(x, value: .escapeCharacter) }
                    } while isdigit(Int32(chr)) != 0

                    // Go back one, so the character after the digits is looked at next
                    x -= 1

                default:
                    break
                }
            }
            x += 1
        }

        // Next we look for identifiers.  An identifier for these purposes includes
        // a number, for it is just a sequence of:

        //      "_" or "$" or "#" or "0" to "9" or "a" to "z" or "A" to "Z".

        x = 0
        while x < strLen {
            var identifierLen = 0
            var identifierStart = x
            let colour = styles.read(identifierStart)

            chr = line.character(at: x)

            if colour != .codeAlpha &&
                colour != [] {
                // No further highlighting will be required
                x += 1
                continue
            }

            while isIdentifier(chr) {
                identifierLen += 1

                x += 1
                if x >= strLen { break }

                chr = line.character(at: x)
            }

            if identifierLen == 0 {
                x += 1
                continue
            }

            // The initial colouring of an identifier tells us its context.  We're
            // only interested in those in foreground colour (these must be used
            // in the body of a directive) or code colour (used in statements).

            var newColour: IFSyntaxStyle? = nil

            if colour == .codeAlpha {
                // If an identifier is in code colour, then:

                if identifierStart > 0 && line.character(at: identifierStart - 1) == ascii("@") {
                    //     If it follows an "@", recolour the "@" and the identifier in
                    //        assembly-language colour.
                    identifierStart -= 1
                    identifierLen += 1
                    newColour = .assembly
                } else {
                    //     Otherwise, unless it is one of the following:

                    //       "box"  "break"  "child"  "children"  "continue"  "default"
                    //       "do"  "elder"  "eldest"  "else"  "false"  "font"  "for"  "give"
                    //       "has"  "hasnt"  "if"  "in"  "indirect"  "inversion"  "jump"
                    //       "metaclass"  "move"  "new_line"  "nothing"  "notin"  "objectloop"
                    //       "ofclass"  "or"  "parent"  "print"  "print_ret"  "provides"  "quit"
                    //       "random"  "read"  "remove"  "restore"  "return"  "rfalse"  "rtrue"
                    //       "save"  "sibling"  "spaces"  "string"  "style"  "switch"  "to"
                    //       "true"  "until"  "while"  "younger"  "youngest"

                    //     we recolour the identifier to "codealpha colour".
                    let identifier = line.substring(with: NSRange(location: identifierStart, length: identifierLen))

                    if codeKeywords.contains(identifier.lowercased()) { newColour = .code }
                }
            } else if colour == [] {
                // On the other hand, if an identifier is in foreground colour, then we
                // check it to see if it's one of the following interesting keywords:

                //       "first"  "last"  "meta"  "only"  "private"  "replace"  "reverse"
                //       "string"  "table"

                // If it is, we recolour it in directive colour.

                let identifier = line.substring(with: NSRange(location: identifierStart, length: identifierLen))

                if otherKeywords.contains(identifier.lowercased()) {
                    newColour = .directive
                }
            }

            if let newColour {
                for y in identifierStart..<(identifierStart + identifierLen) {
                    styles.write(y, value: newColour)
                }
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
        return 28.0
    }
}
