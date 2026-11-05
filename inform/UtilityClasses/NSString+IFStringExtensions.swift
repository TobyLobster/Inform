//
//  NSString+IFStringExtensions.swift
//  Inform
//
//  Created by Toby Nelson on 05/02/2014.
//  Translated from Objective-C in November 2026. The interface is still NSString+IFStringExtensions.h.
//

import Foundation

private let whitespace    = CharacterSet.whitespacesAndNewlines as NSCharacterSet
private let nonWhitespace = CharacterSet.whitespacesAndNewlines.inverted

// *******************************************************************************************
@objc(IFStringAdditions) @implementation extension NSString {

    func containsSubstring(_ string: String, options: NSString.CompareOptions) -> Bool {
        let range = self.range(of: string, options: options)
        return range.location != NSNotFound
    }

    func containsSubstring(_ string: String) -> Bool {
        return containsSubstring(string, options: [])
    }

    func ends(with string: String) -> Bool {
        return hasSuffix(string)
    }

    func ends(withCaseInsensitive string: String) -> Bool {
        return (lowercased as NSString).hasSuffix((string as NSString).lowercased)
    }

    func starts(with string: String) -> Bool {
        return hasPrefix(string)
    }

    func starts(withCaseInsensitive string: String) -> Bool {
        return (lowercased as NSString).hasPrefix((string as NSString).lowercased)
    }

    func isEqual(toStringCaseInsensitive string: String) -> Bool {
        return caseInsensitiveCompare(string) == .orderedSame
    }

    @objc(stringByTrimmingWhitespace)
    var trimmingWhitespace: String {
        return trimmingCharacters(in: whitespace as CharacterSet)
    }

    var trailingWhitespace: String {
        // Search backwards from the end of the string for a non-whitespace character
        for i in stride(from: length - 1, through: 0, by: -1) {
            if !whitespace.characterIsMember(character(at: i)) {
                return substring(from: i + 1)
            }
        }
        return self as String
    }

    var leadingWhitespace: String {
        // Find the first non-whitespace character
        let first = rangeOfCharacter(from: nonWhitespace)
        if first.location == NSNotFound {
            return self as String
        }
        return substring(to: first.location)
    }

    @objc(stringByRemovingTrailingWhitespace)
    var removingTrailingWhitespace: String {
        let trailing = trailingWhitespace
        return substring(to: length - trailing.utf16.count)
    }

    @objc(stringByRemovingLeadingWhitespace)
    var removingLeadingWhitespace: String {
        let leading = leadingWhitespace
        return substring(from: leading.utf16.count)
    }

    @objc(stringByTrimmingCharactersInString:)
    func trimmingCharacters(in charactersToTrim: String) -> String {
        return trimmingCharacters(in: NSCharacterSet(charactersIn: charactersToTrim) as CharacterSet)
    }

    @objc(stringByReplacing:with:)
    func replacing(_ lpFind: String, with lpReplace: String) -> String {
        let lpMutableString = NSMutableString(string: self as String)
        let lWholeRange = NSRange(location: 0, length: lpMutableString.length)

        lpMutableString.replaceOccurrences(of: lpFind,
                                           with: lpReplace,
                                           options: [],
                                           range: lWholeRange)

        return lpMutableString as String
    }

    func index(of text: String) -> Int {
        let range = self.range(of: text)
        if range.length > 0 {
            return range.location
        } else {
            return NSNotFound
        }
    }

    func lastIndex(of text: String) -> Int {
        let range = self.range(of: text, options: .backwards)
        if range.length > 0 {
            return range.location
        } else {
            return NSNotFound
        }
    }

    @objc(stringByAppendingPathComponents:)
    func appendingPathComponents(_ strComponents: String?) -> String {
        guard let strComponents = strComponents else {
            return self as String
        }
        let strArray = (strComponents as NSString).components(separatedBy: "/")

        var work = self as String
        for component in strArray {
            work = (work as NSString).appendingPathComponent(component)
        }
        return work
    }
}
