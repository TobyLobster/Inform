//
//  IFElasticTabs.swift
//  Inform
//
//  Moved out of IFSyntaxData in November 2026. The interface is IFElasticTabs.h.
//

import Foundation

private let tab: unichar            = 0x09      // \t
private let lineFeed: unichar       = 0x0A      // \n
private let carriageReturn: unichar = 0x0D      // \r
private let space: unichar          = 0x20      // ' '

private func isWhitespace(_ c: unichar) -> Bool {
    if c == space || c == tab {
        return true
    } else {
        return false
    }
}

private func isLineEnd(_ c: unichar) -> Bool {
    return c == lineFeed || c == carriageReturn
}

// See http://nickgravgaard.com/elastictabstops/ for more information on these

@objc @implementation extension IFElasticTabs {
    /// The text the tables are in
    private final let text: NSString

    init(string text: String) {
        self.text = text as NSString
        super.init()
    }

    // Given a character index, returns the range of the line it is on
    private final func lineRange(at charIndex: Int) -> NSRange {
        // Start and end of this line are initially the same
        var start   = charIndex
        var end     = charIndex

        let text = self.text

        // Move backwards to the beginning of the line
        start -= 1
        while start >= 0 && !isLineEnd(text.character(at: start)) {
            start -= 1
        }

        // Move forwards to the end of the line
        let len = text.length
        var lastChr: unichar = 0
        while end < len {
            lastChr = text.character(at: end)
            if isLineEnd(lastChr) {
                break
            }
            end += 1
        }

        // Include the line ending characters
        if end + 1 < len && lastChr == carriageReturn && text.character(at: end + 1) == lineFeed {
            end += 1
        }

        if end >= len {
            end = len - 1
        }

        // Start now points to the newline preceeding this line, end to the final newline character, which we want to include in the result
        return NSRange(location: start + 1, length: end - start)
    }

    //
    // Given a range, returns YES if it contains no tabs, or has a tab at the start (before any
    // non-whitespace character).
    //
    private final func isTabLess(_ range: NSRange) -> Bool {
        let text = self.text
        var isBlank = true

        var chrPos = range.location
        while chrPos < range.location + range.length {
            let chr = text.character(at: chrPos)
            if chr == tab {
                // Don't apply elastic tabs to lines that already begin with a tab
                if isBlank {
                    return true
                }
                return false
            }

            if !isWhitespace(chr) && !isLineEnd(chr) {
                isBlank = false
            }
            chrPos += 1
        }

        return true
    }

    // Given a character index, work out the corresponding range where elastic tabs must apply
    @objc(rangeOfRegionAtIndex:)
    func rangeOfRegion(at charIndex: UInt) -> NSRange {
        // Hunt backwards for the beginning of the file, or the first blank line that preceeds this index
        var firstLine   = lineRange(at: Int(charIndex))
        var lastLine    = firstLine

        // Lines without tabs never use elastic tabs
        if isTabLess(firstLine) {
            return NSRange(location: NSNotFound, length: 0)
        }

        // Look backwards through the lines, looking for the first one without tabs
        while firstLine.location > 0 {
            // Get the range of the preceeding line
            let previousLine = lineRange(at: firstLine.location - 1)

            // Give up if we've found a tabless line
            if isTabLess(previousLine) {
                break
            }

            // Continue searching from this line
            firstLine = previousLine
        }

        // Hunt forwards for the end of the file or the next tabless line that follows this index
        let len = text.length
        while lastLine.location + lastLine.length < len {
            // Get the range of the following line
            let nextLine = lineRange(at: lastLine.location + lastLine.length)

            // Give up if we've found a tabless line
            if isTabLess(nextLine) {
                break
            }

            // Continue searching from this line
            lastLine = nextLine
        }

        // If the first and last lines are different then this defines the region
        if firstLine.location != lastLine.location {
            return NSRange(location: firstLine.location, length: (lastLine.location + lastLine.length) - firstLine.location)
        }

        // By default, elastic tabs do not apply to a character range
        return NSRange(location: NSNotFound, length: 0)
    }

    // Given a character range, chop it up into lines and columns
    func cells(inRegion region: NSRange) -> [[NSValue]] {
        // Columns are separated by tabs. The last of the lines is the current line.
        var lines: [[NSValue]] = [[]]

        var lastTabPos = region.location
        var tabsAtStart = true
        var chrPos = region.location
        while chrPos < region.location + region.length {
            // Read the next character
            let chr = text.character(at: chrPos)

            // Skip the next character to deal with DOS line endings
            if chr == carriageReturn && chrPos + 1 < region.location + region.length {
                if text.character(at: chrPos + 1) == lineFeed {
                    chrPos += 1
                }
            }

            // Specify that we ignore tabs at the start of the line
            if chr != tab {
                tabsAtStart = false
            }
            if chr == carriageReturn || chr == lineFeed {
                tabsAtStart = true
            }

            // If this is a newline or a tab, add a new column. We ignore tabs at the start of the line
            if (chr == tab && !tabsAtStart) || chr == lineFeed || chr == carriageReturn {
                // Store this column
                lines[lines.count - 1].append(NSValue(range: NSRange(location: lastTabPos,
                                                                     length: chrPos - lastTabPos)))

                // Start the next column on the character after this one
                lastTabPos = chrPos + 1
            } else if chrPos + 1 == region.location + region.length {
                // At the end of a region that doesn't end its last line, store the last column, with this character
                lines[lines.count - 1].append(NSValue(range: NSRange(location: lastTabPos,
                                                                     length: chrPos + 1 - lastTabPos)))
            }

            // Add a new line if necessary
            if chr == lineFeed || chr == carriageReturn {
                lines.append([])
            }

            chrPos += 1
        }

        return lines
    }
}
