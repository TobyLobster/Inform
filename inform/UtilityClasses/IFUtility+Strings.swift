//
//  IFUtility+Strings.swift
//  Inform
//
//  Created by Toby Nelson, 2014
//  Translated from Objective-C in November 2026. The interface is IFUtility (Strings) in IFUtility.h.
//

import Foundation

/// The UTF-16 unit of a character
private func ch(_ scalar: Unicode.Scalar) -> unichar {
    return unichar(scalar.value)
}

private func valueForHexChar(_ c: unichar) -> Int32 {
    if c >= ch("0") && c <= ch("9") { return Int32(c - ch("0")) }
    if c >= ch("a") && c <= ch("f") { return Int32(c - ch("a") + 10) }
    if c >= ch("A") && c <= ch("F") { return Int32(c - ch("A") + 10) }

    return 0
}

// *******************************************************************************************
@objc(Strings) @implementation extension IFUtility {

    // MARK: - String handling
    class func localizedString(_ key: String) -> String {
        return Bundle.main.localizedString(forKey: key,
                                           value: key,
                                           table: nil)
    }

    class func localizedString(_ key: String,
                               default value: String?) -> String {
        return Bundle.main.localizedString(forKey: key,
                                           value: value,
                                           table: nil)
    }

    class func localizedString(_ key: String,
                               default value: String?,
                               table: String?) -> String {
        return Bundle.main.localizedString(forKey: key,
                                           value: value,
                                           table: table)
    }

    class func unescapeString(_ string: String) -> String {
        // Change '\n', '\t', etc marks in a string to newlines, tabs, etc
        let string = string as NSString
        let length = string.length
        if length == 0 { return "" }

        var newString = [unichar]()
        newString.reserveCapacity(256)

        var chNum = 0
        while chNum < length {
            // Get the next character
            let chr = string.character(at: chNum)
            var outChar = ch("?")

            // If it's an escape character, parse as appropriate
            if chr == ch("\\") && chNum+1 < length {
                // The result depends on the next character
                chNum += 1
                let nextChar = string.character(at: chNum)

                switch nextChar {
                case ch("n"):
                    // Newline
                    outChar = 10

                case ch("r"):
                    // Return
                    outChar = 13

                case ch("t"):
                    // Tab
                    outChar = 9

                default:
                    // Default behaviour is just to strip the '\'
                    outChar = nextChar
                }
            } else if chr == ch("[") && chNum+1 < length {
                // [=0xffff=] = exact character
                // (different versions of webkit treat the '\' character differently, so we need this to ensure that we get consistent results)
                let nextChar = string.character(at: chNum+1)
                if nextChar == ch("=") {
                    // [= matched: look for the matching =] after it
                    var previous: unichar = 0
                    var finalChNum = chNum+2
                    while finalChNum < length {
                        let mightBeLast = string.character(at: finalChNum)

                        if previous == ch("=") && mightBeLast == ch("]") {
                            break
                        }

                        previous = mightBeLast
                        finalChNum += 1
                    }

                    if finalChNum >= length {
                        // No =], so this isn't an escape
                        outChar = chr
                    } else {
                        // Get the character number from the string
                        let characterString = string.substring(with: NSRange(location: chNum+2, length: finalChNum-chNum-3)) as NSString

                        if characterString.hasPrefix("0x") {
                            // Is a hexidecimal character
                            var val: Int32 = 0
                            for pos in stride(from: 2, to: characterString.length, by: 1) {
                                val = val &* 16
                                val = val &+ valueForHexChar(characterString.character(at: pos))
                            }
                            outChar = unichar(truncatingIfNeeded: val)
                        } else if characterString.isEqual(to: "BACK") {
                            // Backslash
                            outChar = ch("\\")
                        } else {
                            outChar = ch("?")
                        }

                        // Move to the final character
                        chNum = finalChNum
                    }
                } else {
                    outChar = chr
                }
            } else {
                // Otherwise, just pass it through
                outChar = chr
            }

            // Add to the output string
            newString.append(outChar)
            chNum += 1
        }

        // Turn newString into an NSString
        return NSString(characters: newString, length: newString.count) as String
    }

    class func findMatch(_ pattern: String, inText text: String) -> NSTextCheckingResult? {
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern,
                                            options: [])
        } catch {
            NSLog("Warning: Runtime error parser. Regex pattern error: %@", (error as NSError).description)
            return nil
        }
        let match = regex.firstMatch(in: text,
                                     options: [],
                                     range: NSRange(location: 0, length: (text as NSString).length))
        return match
    }
}
