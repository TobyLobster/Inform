//
//  IFScanner.swift
//  Inform
//
//  Created by Toby Nelson in 2014
//  Translated from Objective-C in November 2026. The interface is still IFScanner.h.
//

import Cocoa

/// The regular expressions compiled recently
private let regexCache: NSCache<NSString, NSRegularExpression> = {
    let cache = NSCache<NSString, NSRegularExpression>()
    cache.countLimit = 16
    return cache
}()

/// The letters, accents and digits of any script, which make up a word
private let wordCharacters = CharacterSet.alphanumerics as NSCharacterSet

@objc @implementation
extension IFScanner {

    /// Compiles a regular expression (nil if the pattern isn't one). Recent ones are kept, since Find All
    /// and Find in Files search once for each match.
    private static func regularExpression(_ pattern: String,
                                          options: NSRegularExpression.Options) -> NSRegularExpression? {
        let key = "\(options.rawValue):\(pattern)" as NSString
        var regex = regexCache.object(forKey: key)
        if regex == nil {
            regex = try? NSRegularExpression(pattern: pattern,
                                             options: options)
            if let regex {
                regexCache.setObject(regex, forKey: key)
            }
        }
        return regex
    }

    class func findNextMatch(_ phrase: String,
                             storage: String,
                             position searchPosition: UInt,
                             options searchType: IFFindType,
                             regexFoundGroups foundGroupsOut: UnsafeMutablePointer<NSArray?>?) -> NSRange {
        let storage = storage as NSString
        var searchPosition = searchPosition
        var searchType = searchType

        let options: NSString.CompareOptions
        let regexOptions: NSRegularExpression.Options
        var range = NSRange(location: NSNotFound, length: 0)
        var found = false
        foundGroupsOut?.pointee = nil

        let storageLength = storage.length

        if searchType.rawValue & IFFindType.caseInsensitive.rawValue != 0 {
            options = [.literal, .caseInsensitive]
            regexOptions = .caseInsensitive
        }
        else {
            options = .literal
            regexOptions = []
        }

        // Remove case insensitive flag, to be left with just the search type proper
        searchType = IFFindType(rawValue: searchType.rawValue & ~IFFindType.caseInsensitive.rawValue)!

        // A pattern that isn't a regular expression gives nil, which finds nothing. ^ and $ match at the
        // start and end of each line, as the Find window's help says.
        var regex: NSRegularExpression? = nil
        if searchType == .regexp {
            regex = regularExpression(phrase, options: regexOptions.union(.anchorsMatchLines))
        }

        while !found {
            if searchPosition >= UInt(storageLength) {
                // Reached the end of the text - no more matches
                range = NSRange(location: NSNotFound, length: 0)
                break
            }

            if searchType == .regexp {
                //
                // Search for a regex match. ^ doesn't match where the search starts unless a line starts there,
                // and \b sees the text before it.
                //
                let match = regex?.firstMatch(in: storage as String,
                                              options: [.withoutAnchoringBounds, .withTransparentBounds],
                                              range: NSRange(location: Int(searchPosition), length: storageLength - Int(searchPosition)))
                range = match?.range ?? NSRange(location: NSNotFound, length: 0)
                //
                // Make array of any found groups, if required: the whole match, then each group
                // (an empty string if it took no part)
                //
                if let foundGroupsOut, let match {
                    var array: [String] = []
                    array.reserveCapacity(match.numberOfRanges)
                    for group in 0..<match.numberOfRanges {
                        let groupRange = match.range(at: group)
                        array.append((groupRange.location == NSNotFound) ? "" : storage.substring(with: groupRange))
                    }
                    foundGroupsOut.pointee = array as NSArray
                }
            } else {
                //
                // Standard, non-regex search
                //
                range = storage.range(of: phrase,
                                      options: options,
                                      range: NSRange(location: Int(searchPosition), length: storageLength - Int(searchPosition)))
            }

            if range.location == NSNotFound {
                // Not found
                break
            }

            //
            // We ignore any zero length results
            //
            if range.length > 0 {
                //
                // Check for start / end of word conditions, if required
                //
                var startOfWord = false
                var endOfWord = false

                switch searchType {
                case .beginsWith, .completeWord:
                    // Check if we are at the start of a word...
                    if range.location != 0 {
                        let chr = storage.character(at: range.location - 1)

                        if !wordCharacters.characterIsMember(chr) {
                            // Is preceded by a character that is not a letter, accent or digit, so is a word
                            startOfWord = true
                        }
                    } else {
                        // At start: is the start of a word
                        startOfWord = true
                    }

                    // Have we found a start of word match?
                    if searchType == .beginsWith {
                        if startOfWord {
                            found = true
                            break
                        }
                    }

                    if (searchType == .completeWord) && startOfWord {
                        // For a complete word match, we must check if we are also at the end of a word...
                        if (range.location + range.length) < storageLength {
                            let chr = storage.character(at: range.location + range.length)

                            if !wordCharacters.characterIsMember(chr) {
                                // Is followed by a character that is not a letter, accent or digit, so is a word
                                endOfWord = true
                            }
                        }
                        else {
                            endOfWord = true
                        }

                        // Have we found a whole word match?
                        if endOfWord {
                            found = true
                            break
                        }
                    }

                case .contains, .regexp:
                    fallthrough
                default:
                    // No extra checks required here, we have found a match
                    found = true
                }
            }
            searchPosition = UInt(range.location + 1)
            precondition(searchPosition <= storageLength, "Parsed too far in storage for search?")
        }

        // Not the groups of a match of no characters passed over on the way
        if let foundGroupsOut, range.location == NSNotFound {
            foundGroupsOut.pointee = nil
        }

        precondition(range.location == NSNotFound || range.length > 0, "Found match of length zero")
        return range
    }

    class func findPreviousMatch(_ phrase: String,
                                 storage: String,
                                 position searchPosition: UInt,
                                 options searchType: IFFindType,
                                 regexFoundGroups foundGroupsOut: UnsafeMutablePointer<NSArray?>?) -> NSRange {
        var lastResult = NSRange(location: NSNotFound, length: 0)
        var lastGroups: NSArray? = nil
        var result: NSRange
        var currentPosition: UInt = 0

        // Brute force: search from the start until we reach our search position, then use the last match found
        repeat {
            var groups: NSArray? = nil
            result = withUnsafeMutablePointer(to: &groups) { groupsPointer in
                findNextMatch(phrase,
                              storage: storage,
                              position: currentPosition,
                              options: searchType,
                              regexFoundGroups: (foundGroupsOut != nil) ? groupsPointer : nil)
            }

            if (result.location == NSNotFound) || (UInt(result.location) > searchPosition) {
                break
            }
            lastResult = result
            lastGroups = groups
            precondition(result.location == NSNotFound || result.length > 0, "Found match of length zero")
            currentPosition = UInt(result.location + 1)
        }
        while true

        // The groups of the match found, not of the one after it
        foundGroupsOut?.pointee = lastGroups

        precondition(lastResult.location == NSNotFound || lastResult.length > 0, "Found match of length zero")
        return lastResult
    }
}
