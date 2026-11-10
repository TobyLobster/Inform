//
//  IFSourceLines.swift
//  Inform
//
//  Moved out of IFSourcePage in November 2026.
//  Translated from Objective-C in November 2026. The interface is still IFSourceLines.h.
//

import Foundation

private let lineFeed: unichar       = 0x0A      // \n
private let carriageReturn: unichar = 0x0D      // \r

@objc @implementation extension IFSourceLines {
    @objc(startOfLine:inString:)
    class func start(ofLine line: Int, in store: String) -> UInt {
        let store = store as NSString
        let length = store.length

        var linepos = 0
        var lineno = 1

        if line > lineno {
            var x = 0
            while x < length {
                let chr = store.character(at: x)

                if chr == lineFeed || chr == carriageReturn {
                    let otherchar = chr == lineFeed ? carriageReturn : lineFeed

                    lineno += 1
                    linepos = x + 1

                    // Deal with DOS line endings
                    if linepos < length && store.character(at: linepos) == otherchar {
                        x += 1
                        linepos += 1
                    }

                    if lineno == line {
                        break
                    }
                }
                x += 1
            }
        }

        if lineno != line {
            return UInt(NSNotFound)
        }

        return UInt(linepos)
    }

    /// Where the line starting at an index ends: the index of the character that ends it, or the length of the text
    private static func endOfLine(startingAt linepos: Int, in store: NSString) -> Int {
        let length = store.length

        var x = linepos
        while x < length {
            let chr = store.character(at: x)

            if chr == lineFeed || chr == carriageReturn {
                break
            }
            x += 1
        }

        return x
    }

    @objc(rangeOfTextOnLine:inString:)
    class func rangeOfText(onLine line: Int32, in store: String) -> NSRange {
        let linepos = start(ofLine: Int(line), in: store)

        if linepos == UInt(NSNotFound) {
            return NSRange(location: NSNotFound, length: 0)
        }

        let lineEnd = endOfLine(startingAt: Int(linepos), in: store as NSString)

        return NSRange(location: Int(linepos), length: lineEnd - Int(linepos))
    }

    @objc(rangeOfLine:inString:)
    class func range(ofLine line: UInt, in store: String) -> NSRange {
        let linepos = start(ofLine: Int(bitPattern: line), in: store)

        if linepos == UInt(NSNotFound) {
            return NSRange(location: NSNotFound, length: 0)
        }

        // Find the end of this line
        var lineEnd = endOfLine(startingAt: Int(linepos), in: store as NSString)

        // With the character that ends it, if something does
        if lineEnd < (store as NSString).length {
            lineEnd += 1
        }

        return NSRange(location: Int(linepos), length: lineEnd - Int(linepos))
    }

    @objc(indexOfLine:inString:)
    class func index(ofLine line: UInt, in store: String) -> UInt {
        let linepos = start(ofLine: Int(bitPattern: line), in: store)

        if linepos == UInt(NSNotFound) {
            return UInt(NSNotFound)
        }

        // The first line has no line before it
        if linepos == 0 {
            return 0
        }

        // The character before the line's start is the last of what ends the line before
        return linepos - 1
    }

    @objc(lineForCharacter:inString:)
    class func line(forCharacter charNum: UInt, in store: String) -> Int32 {
        var line: Int32 = 0

        let store = store as NSString
        let length = store.length
        let charNum = Int(clamping: charNum)

        // Count what ends the lines before the character
        var x = 0
        while x < charNum && x < length {
            let chr = store.character(at: x)

            if chr == lineFeed || chr == carriageReturn {
                let otherchar = chr == lineFeed ? carriageReturn : lineFeed

                // Deal with DOS line endings
                if x + 1 < length && store.character(at: x + 1) == otherchar {
                    x += 1
                }

                // (The character may be part of what ends its own line)
                if x < charNum {
                    line += 1
                }
            }
            x += 1
        }

        return line
    }
}
