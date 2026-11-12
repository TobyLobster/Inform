//
//  IFLineStarts.swift
//  Inform
//
//  Moved out of IFSyntaxData in November 2026. The interface is IFLineStarts.h.
//

import Foundation

private let lineFeed: unichar       = 0x0A      // \n
private let carriageReturn: unichar = 0x0D      // \r

@objc @implementation extension IFLineStarts {
    private final var nLines: Int                                     // Number of lines
    private final var lineStarts: [Int]                               // Start positions of each line

    override init() {
        lineStarts = [0]
        nLines = 1
        super.init()
    }

    var count: Int {
        return nLines
    }

    func start(ofLine line: Int) -> Int {
        return lineStarts[line]
    }

    //
    // Which line of text does the character index occur on?
    //
    func line(forIndex index: Int) -> Int {
        // Yet Another Binary Search
        var low = 0
        var high = nLines - 1

        while low <= high {
            let middle = (low + high) >> 1

            let lineStart = lineStarts[middle]

            if index < lineStart {
                // Not this line: search the lower half
                high = middle - 1
                continue
            }

            // The last line runs on to the end of the text
            let lineEnd = middle < (nLines - 1) ? lineStarts[middle + 1] : Int.max

            if index >= lineEnd {
                // Not this line: search the upper half
                low = middle + 1
                continue
            }

            // Must be this line
            return middle
        }

        // If we fell off, must be the last line (lines are unsigned, so we can't fall off the bottom)
        return nLines - 1
    }

    @objc(replaceLinesAfter:through:withLinesIn:atLocation:changeInLength:)
    func replaceLines(after firstLine: Int,
                      through lastLine: Int,
                      withLinesIn newText: String,
                      at location: Int,
                      changeInLength: Int) -> Int {
        let newString = newText as NSString

        //
        // Build the array of new lines: newLineStarts holds the start character index of each line.
        //
        var newLineStarts: [Int] = []
        var nNewLines = 0

        var x = 0
        while x < newString.length {
            let thisChar = newString.character(at: x)

            if thisChar == lineFeed || thisChar == carriageReturn {
                nNewLines += 1
                newLineStarts.append(x + location + 1)
            }
            x += 1
        }

        // Number of lines that have been added or taken away
        let lineDifference = nNewLines - (lastLine - firstLine)

        // Replace the line start positions (first line is still at the same position, of course)
        if nNewLines < (lastLine - firstLine) {
            // Update first
            for x in 0..<nNewLines {
                lineStarts[firstLine + 1 + x] = newLineStarts[x]
            }

            // Move lines down
            lineStarts.removeSubrange((firstLine + nNewLines + 1)..<(lastLine + 1))
        } else {
            // Move lines up
            lineStarts.insert(contentsOf: repeatElement(0, count: lineDifference), at: lastLine + 1)

            // Update last
            for x in 0..<nNewLines {
                lineStarts[firstLine + 1 + x] = newLineStarts[x]
            }
        }

        // Update the remaining line start positions
        nLines += lineDifference

        x = firstLine + nNewLines + 1
        while x < nLines {
            lineStarts[x] += changeInLength
            x += 1
        }

        return nNewLines
    }
}
