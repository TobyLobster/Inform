//
//  IFSourceSections.swift
//  Inform
//
//  Moved out of IFSourcePage in November 2026.
//  Translated from Objective-C in November 2026. The interface is still IFSourceSections.h.
//

import Foundation

private let space: unichar          = 0x20      // ' '
private let tab: unichar            = 0x09      // \t
private let lineFeed: unichar       = 0x0A      // \n
private let carriageReturn: unichar = 0x0D      // \r

@objc @implementation extension IFSourceSections {
    @objc(sectionAfter:)
    class func section(after section: IFIntelSymbol?) -> IFIntelSymbol? {
        var nextSection = section?.sibling

        if nextSection == nil {
            var parentSection = section?.parent
            while let parent = parentSection, nextSection == nil {
                nextSection = parent.sibling
                parentSection = parent.parent
            }
        }

        return nextSection
    }

    @objc(sectionBefore:inFile:)
    class func section(before section: IFIntelSymbol?,
                       inFile intelFile: IFIntelFile?) -> IFIntelSymbol? {
        var previousSection = section?.previousSibling

        if previousSection == nil {
            previousSection = section?.parent
            if previousSection === intelFile?.firstSymbol { previousSection = nil }
        }

        return previousSection
    }

    @objc(sectionAbove:inFile:)
    class func section(above section: IFIntelSymbol,
                       inFile intelFile: IFIntelFile?) -> IFIntelSymbol? {
        let parentSection = section.parent
        if let parentSection, parentSection !== intelFile?.firstSymbol {
            return parentSection
        }
        return nil
    }

    @objc(sectionBelow:towards:)
    class func section(below currentSection: IFIntelSymbol?,
                       towards cursorSection: IFIntelSymbol?) -> IFIntelSymbol? {
        // Can't do anything if the cursor is in no section, or the currently selected section is the most specific we
        // can use
        if cursorSection == nil || currentSection === cursorSection {
            return nil
        }

        // Move up the sections until we find one which has the currentSection as a parent
        var lowerSection = cursorSection
        while let lower = lowerSection, lower.parent !== currentSection {
            lowerSection = lower.parent
        }

        return lowerSection
    }

    @objc(sectionAtCharacter:inFile:inString:)
    class func section(atCharacter charNum: UInt,
                       inFile intelFile: IFIntelFile?,
                       in store: String) -> IFIntelSymbol? {
        return intelFile?.nearestSymbol(toLine: IFSourceLines.line(forCharacter: charNum, in: store))
    }

    @objc(rangeOfSection:inFile:inString:)
    class func range(ofSection symbol: IFIntelSymbol,
                     inFile intelFile: IFIntelFile?,
                     in store: String) -> NSRange {
        let text = store as NSString
        let followingSymbol = section(after: symbol)

        // Get the range we need to limit to: from the start of the heading's line (the headings count lines from 0, and
        // IFSourceLines from 1)...
        var limitRange = NSRange(location: 0, length: 0)

        // (With no file, the line is 0, as when Objective-C asked nil for it)
        let symbolLine = intelFile?.line(for: symbol) ?? 0
        if symbolLine == UInt(NSNotFound) { return NSRange(location: NSNotFound, length: 0) }

        limitRange.location = Int(IFSourceLines.start(ofLine: Int(bitPattern: symbolLine) + 1, in: store))
        if limitRange.location == NSNotFound { return NSRange(location: NSNotFound, length: 0) }

        // ...to the start of the next section's heading's line, or the end of the text
        var finalLocation: Int
        if let followingSymbol {
            let followingLine = intelFile?.line(for: followingSymbol) ?? 0
            if followingLine == UInt(NSNotFound) { return NSRange(location: NSNotFound, length: 0) }
            finalLocation = Int(IFSourceLines.start(ofLine: Int(bitPattern: followingLine) + 1, in: store))
        } else {
            finalLocation = text.length
        }

        if finalLocation == NSNotFound { return NSRange(location: NSNotFound, length: 0) }

        // Move the start of the limitation to the first non-whitespace character
        while limitRange.location < finalLocation {
            let chr = text.character(at: limitRange.location)
            if chr != space && chr != tab && chr != lineFeed && chr != carriageReturn {
                break
            }
            limitRange.location += 1
        }

        // Leave out the white space before the next section's heading
        if followingSymbol != nil {
            while finalLocation > limitRange.location {
                let chr = text.character(at: finalLocation - 1)
                if chr != space && chr != tab && chr != lineFeed && chr != carriageReturn {
                    break
                }
                finalLocation -= 1
            }
        }

        limitRange.length = finalLocation - limitRange.location
        return limitRange
    }

    @objc(linesOfRange:inString:)
    class func lines(of restriction: NSRange, in store: String) -> NSRange {
        let store = store as NSString

        var firstLine = 0
        var finalLine = NSNotFound

        let length = store.length

        // (The end of the range with NSUInteger's arithmetic, as Objective-C's NSRange has)
        let restrictionEnd = UInt(bitPattern: restriction.location) &+ UInt(bitPattern: restriction.length)

        var lineno = 1

        var x = 0
        while x < length {
            let chr = store.character(at: x)

            if chr == lineFeed || chr == carriageReturn {
                let otherchar = chr == lineFeed ? carriageReturn : lineFeed

                lineno += 1
                var linepos = x + 1

                if x < restriction.location {
                    firstLine = lineno
                } else if UInt(x) < restrictionEnd {
                    finalLine = lineno
                } else {
                    break
                }

                // Deal with DOS line endings
                if linepos < length && store.character(at: linepos) == otherchar {
                    x += 1
                    linepos += 1
                }
            }
            x += 1
        }
        if finalLine == NSNotFound { finalLine = lineno }

        return NSRange(location: firstLine, length: finalLine - firstLine)
    }
}
