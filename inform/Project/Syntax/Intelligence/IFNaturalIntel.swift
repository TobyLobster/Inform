//
//  IFNaturalIntel.swift
//  Inform
//
//  Created by Andrew Hunter on 05/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFNaturalIntel.h.
//

import Cocoa

/// The code of an ASCII character, to compare with a `unichar` as a C character constant would be
private func ascii(_ scalar: Unicode.Scalar) -> unichar {
    return unichar(scalar.value)
}

private let headingList = ["---- documentation ----", "volume", "book", "part", "chapter", "section", "example"]
private let autoNumberHeading = [false, true, true, true, true, true, false]

@objc @implementation extension IFNaturalIntel {

    /// The highlighter that wants us to gather intelligence
    private final var highlighter: IFSyntaxData? = nil

    // MARK: - Useful parsing functions

    private static func parseNumber(_ number: String) -> Int32 {
        // IMPLEMENT ME: parse english numbers (one, two, three, etc)

        return (number as NSString).intValue
    }

    private static func numberOfHeading(_ heading: String) -> Int32 {
        let words = heading.components(separatedBy: " ")

        if words.count < 2 { return 0 }

        return IFNaturalIntel.parseNumber(words[1])
    }

    // MARK: - Notifying of the highlighter currently in use

    func setSyntaxData(_ aData: IFSyntaxData?) {
        highlighter = aData
    }

    // MARK: - Gathering information (works like rehint)

    private final func isHeading(_ line: String) -> Bool {
        let line = (line as NSString).lowercased as NSString
        for heading in headingList {
            if line.isEqual(to: heading) {
                return true
            }
        }

        return false
    }

    private final func indexOfHeading(_ line: String) -> Int {
        var index = 0

        let line = (line as NSString).lowercased as NSString
        for heading in headingList {
            if line.starts(with: heading) {
                return index
            }
            index += 1
        }

        return NSNotFound
    }

    private final func autonumberHeading(_ line: String) -> Bool {
        var index = 0

        let line = (line as NSString).lowercased as NSString
        for heading in headingList {
            if line.starts(with: heading) {
                return autoNumberHeading[index]
            }
            index += 1
        }

        return false
    }

    func gatherIntel(forLine line: String,
                     styles: IFSyntaxStyles,
                     initialState state: IFSyntaxState,
                     lineNumber: Int32,
                     intoData data: IFIntelFile) {
        // Clear out old data for this line
        data.clearSymbols(forLines: NSRange(location: Int(lineNumber), length: 1))

        // Heading lines beginning with 'Volume', 'Part', etc  are added to the intelligence
        if styles.read(0) == .heading {
            // Check if this is a heading or not
            // Trim whitespace
            let prefix = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let headingType = indexOfHeading(prefix)
            if headingType == NSNotFound {
                return
            }

            // Got a heading: add to the intel
            let newSymbol = IFIntelSymbol()

            newSymbol.type = IFSectionSymbolType
            newSymbol.name = line
            newSymbol.relation = .onLevel
            newSymbol.levelDelta = Int32(headingType)

            data.add(newSymbol, atLine: lineNumber)

        } else if lineNumber == 0 {
            // The title string
            let length = (line as NSString).length
            var x = 0
            var start = 0
            while x < length && styles.read(x) != .gameText {
                x += 1
            }
            start = x
            while x < length && styles.read(x) == .gameText {
                x += 1
            }

            // Add this as a level 0 item
            let newSymbol = IFIntelSymbol()

            var title = (line as NSString).substring(with: NSRange(location: start, length: x - start))
            if (title as NSString).length == 0 {
                title = IFUtility.localizedString("Story")
            }

            newSymbol.type = IFSectionSymbolType
            newSymbol.name = title
            newSymbol.relation = .onLevel
            newSymbol.levelDelta = 0

            data.add(newSymbol, atLine: lineNumber)

        }
    }

    // MARK: - Rewriting

    func rewriteInput(_ input: String) -> String? {
        if input == "\n" {
            // Auto-tab
            if !IFPreferences.shared.indentAfterNewline { return nil }

            guard let highlighter else { return nil }

            // 'editingLineNumber' will still be the previous line
            let lineNumber = highlighter.editingLineNumber
            var tabs = highlighter.numberOfTabStops(forLine: lineNumber)

            // If we're not currently in a string...
            let lastStyle = highlighter.style(atEndOfLine: lineNumber)
            if lastStyle != .gameText && lastStyle != .substitution {
                let lastChar = highlighter.character(atEndOfLine: lineNumber)

                if lastChar == ascii(":") {
                    // Increase tab depth if last character of last line was ':'
                    tabs += 1
                } else if lastChar == ascii("\t") || lastChar == ascii(" ") {
                    // If line was entirely whitespace then reduce tabs back to 0
                    let line = highlighter.text(forLine: lineNumber) as NSString
                    let len = line.length
                    var whitespace = true

                    var x = 0
                    while x < len - 1 {
                        // Loop to len-1 as last character will always be '\n'
                        // Exception is the very last line in the file. But we're OK there, as we know the last
                        // character is whitespace anyway
                        let chr = line.character(at: x)

                        if chr != ascii("\t") && chr != ascii(" ") {
                            whitespace = false
                            break
                        }
                        x += 1
                    }

                    if whitespace {
                        // Line was entirely whitespace: no tabs now
                        tabs = 0
                    }
                }
            }

            if tabs > 0 {
                // Auto-indent the next line
                var res = "\n"

                for _ in 0..<tabs {
                    res += "\t"
                }

                return res
            } else {
                // Leave as-is
                return nil
            }
        } else if input == " " {
            if !IFPreferences.shared.autoNumberSections { return nil }

            guard let highlighter else { return nil }

            let lineNumber = highlighter.editingLineNumber
            let lastStyle = highlighter.style(atStartOfLine: lineNumber)

            if lastStyle != .gameText && lastStyle != .substitution {
                // If we've got a line 'Volume\n', or (pedantic last line case) 'Volume', then automagically fill
                // in the section number using context info
                let line = highlighter.text(forLine: lineNumber)

                // Trim whitespace
                let prefix = line.trimmingCharacters(in: .whitespacesAndNewlines)

                // See if this is the start of a heading
                if !isHeading(prefix) {
                    return nil
                }

                // Get heading level
                let headingLevel = indexOfHeading(prefix)
                if headingLevel == NSNotFound { return nil }        // Not a heading
                if !autonumberHeading(prefix) {
                    return nil  // Don't try to auto number "---- DOCUMENTATION ----" heading, etc
                }

                // We've got a heading: auto-insert a number

                // Find the preceding heading
                let data = highlighter.intelligenceData
                var symbol = data.nearestSymbol(toLine: lineNumber)

                while let found = symbol, found.level > headingLevel { symbol = found.parent }

                // Work out the numeric value of the heading
                var lastHeadingNumber: Int32 = 0

                if let symbol {
                    if symbol.level != headingLevel {
                        lastHeadingNumber = 0           // No preceding items at this level
                    } else {
                        lastHeadingNumber = IFNaturalIntel.numberOfHeading(symbol.name ?? "")
                        if lastHeadingNumber == 0 {
                            lastHeadingNumber = -1      // There was a preceding heading, but we don't know the number
                        }
                    }
                }

                // Work out the result
                var res: String? = nil

                if lastHeadingNumber >= 0 {
                    // Insert a suitable new heading number
                    res = " \(lastHeadingNumber + 1) - "

                    highlighter.callback(forEditing: #selector(renumberSections(afterLine:)),
                                         withValue: NSNumber(value: lineNumber))
                }

                return res
            }
        }

        // No behaviour defined: just fall through
        return nil
    }

    @objc(renumberSectionsAfterLine:)
    private final func renumberSections(afterLine lineObject: NSNumber) {
        guard let highlighter else { return }

        // Gather some information about what we're about to do
        let lineNumber = lineObject.int32Value
        let data = highlighter.intelligenceData
        guard let firstSymbol = data.nearestSymbol(toLine: lineNumber) else { return }

        var currentSectionNumber = IFNaturalIntel.numberOfHeading(firstSymbol.name ?? "")

        if currentSectionNumber <= 0 { return }
        if firstSymbol.level == 0 { return }

        // Renumber the siblings at the same level (a heading of a higher level can be a sibling too,
        // such as a chapter after sections that aren't in one)
        var symbol = firstSymbol.sibling

        var todoList: [(line: Int32, text: String)] = []

        while let current = symbol, current.level == firstSymbol.level {
            currentSectionNumber += 1

            let symbolSectionNumber = IFNaturalIntel.numberOfHeading(current.name ?? "")

            if symbolSectionNumber != currentSectionNumber {
                // Get the data for the line this symbol is on
                let symbolLineNumber = data.line(for: current)
                let line = highlighter.text(forLine: Int32(truncatingIfNeeded: symbolLineNumber))

                // Renumber this symbol
                var words = line.components(separatedBy: " ")

                if words.count > 1 {
                    words[1] = "\(currentSectionNumber)"
                    let newString = words.joined(separator: " ")

                    // Add to our 'todo' list
                    todoList.append((line: Int32(truncatingIfNeeded: symbolLineNumber), text: newString))
                }
            }

            symbol = current.sibling
        }

        // Renumber everything in the todo list
        // (We put things in a todo list to avoid accidently stuffing up the symbol list while we're working on it)

        for todo in todoList {
            highlighter.replaceLine(todo.line, withLine: todo.text)
        }

        // We're done
    }
}
