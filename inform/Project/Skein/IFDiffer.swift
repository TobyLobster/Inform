//
//  IFDiffer.swift
//  Inform
//
//  Created by Toby Nelson in 2015
//  Algorithm supplied by Graham Nelson
//  Translated from Objective-C in November 2026. The interface is still IFDiffer.h.
//

import Foundation

private let MINIMUM_SPLICE_WORTH_BOTHERING_WITH = 5
private let trace_diff = false

// *******************************************************************************************
@objc @implementation extension IFDiffEdit {

    let fragment: NSRange
    let formOfEdit: EFormOfEdit

    init(range: NSRange,
         form: EFormOfEdit) {
        fragment   = range
        formOfEdit = form
        super.init()
    }
}

/// The range of a typical I7 banner line in part of a text (NSNotFound if there isn't one). Banners
/// end like "Inform 7 build 6M62 (I6/v6.33 lib 6/12N) SD" up to 6M62, and like "Inform 7 v10.2.0 / D"
/// since, with "+6X97" after the version when the VERSION command asks for the build.
private let banner = try? NSRegularExpression(pattern: "(.*?)(Release \\d+ / Serial number \\d+ / Inform 7 (?:build .... .I6.+?lib .+?SD|v\\d\\S*(?: / D)?)).*",
                                              options: [])

private func bannerRange(_ text: NSString, _ range: NSRange) -> NSRange {
    let match = banner?.firstMatch(in: text as String, options: [], range: range)
    return (match != nil) ? match!.range(at: 2) : NSRange(location: NSNotFound, length: 0)
}

private func charAt(_ string: NSString, _ index: Int) -> unichar {
    // Report a zero terminator (a sentinal for the purposes of this algorithm)
    if index == string.length { return 0 }
    return string.character(at: index)
}

// The letterCharacterSet contains the Unicode categories "Letters" and "Marks".
// See eg. http://www.fileformat.info/info/unicode/category/index.htm
private let letterCharacterSet = NSCharacterSet.letters as NSCharacterSet

private func isWordBoundary(_ string: NSString, _ index: Int) -> Bool {
    let a = charAt(string, index)
    let b = charAt(string, index+1)

    // Never between the two halves of a character beyond 0xFFFF, such as an emoji
    if CFStringIsSurrogateHighCharacter(a) && CFStringIsSurrogateLowCharacter(b) { return false }

    let charSet = letterCharacterSet
    if charSet.characterIsMember(a) && charSet.characterIsMember(b) { return false }
    return true
}

// *******************************************************************************************
/*
 The Differ.

 Purpose: To provide text matching in the style of the Unix tool diff.

 Our task is to take two strings, "ideal" and "actual", and return a
 fairly minimal, fairly legible sequence of edits which would turn ideal
 into actual. We won't use Myers's algorithm because it's overkill for the
 text sizes we have here, and because we want to pay more attention to
 word boundaries so as to produce human-readable results; the running
 time below is worst-case quadratic in the number of words scanned, but
 plenty fast enough for IF transcript use in practice.
*/
@objc @implementation extension IFDiffer {

    var ideal: String?
    var actual: String?
    var differences: NSMutableArray

    override init() {
        differences = NSMutableArray()
        super.init()
    }

    private final func print() {
        let ideal = (self.ideal ?? "") as NSString
        let actual = (self.actual ?? "") as NSString
        let message = NSMutableString()
        for case let edit as IFDiffEdit in differences {
            switch edit.formOfEdit {
            case .DELETE_EDIT:          message.appendFormat("<delete>%@</delete>", ideal.substring(with: edit.fragment))
            case .PRESERVE_EDIT:        message.appendFormat("%@",                  ideal.substring(with: edit.fragment))
            case .PRESERVE_ACTUAL_EDIT: message.appendFormat("%@",                  actual.substring(with: edit.fragment))
            case .INSERT_EDIT:          message.appendFormat("<insert>%@</insert>", actual.substring(with: edit.fragment))
            @unknown default:           break
            }
        }
        NSLog("%@", message)
    }

    /*
     The diff algorithm.
     We do this in the simplest way possible. This outer routine, which is not
     recursively called, sets up the returned structure and sends it back.

     Note that a sequence of edits with no insertions or deletions means the
     match was in fact perfect, and is converted to the null edit list.
     */
    func diffIdeal(_ theIdeal: String?,
                   actual theActual: String?) -> Bool {
        let theIdeal = theIdeal ?? ""
        let theActual = theActual ?? ""

        ideal = theIdeal
        actual = theActual
        differences.removeAllObjects()

        diffOuterRangeA(NSRange(location: 0, length: (theIdeal as NSString).length),
                        rangeB: NSRange(location: 0, length: (theActual as NSString).length))

        for case let edit as IFDiffEdit in differences {
            if ( edit.formOfEdit != .PRESERVE_EDIT ) &&
               ( edit.formOfEdit != .PRESERVE_ACTUAL_EDIT ) {
                return true
            }
        }
        differences.removeAllObjects()
        return false
    }

    /*
     The first level down is also non-recursive and simply looks for a typical
     I7 banner line. Any correctly formed I7 banner matches any other; this
     ensures that transcripts of the same interaction, taken from builds on
     different days or with different compiler versions, continue to match.

     If text A (as we call the ideal version) and text B (the actual) both
     contain I7 banners, we split them into before, then the banner, then
     after. The result then consists of a diff of the before-texts, followed
     by preserving the actual banner, followed by a diff of the after-texts.
     */
    private final func diffOuterRangeA(_ rangeA: NSRange,
                                       rangeB: NSRange) {
        let ideal = (self.ideal ?? "") as NSString
        let actual = (self.actual ?? "") as NSString

        // Performance optimisation: Don't bother checking for the complex RegEx expression below
        // unless both strings are a good candidate, i.e. each string contains the words "Serial number".
        if ideal.containsSubstring("Serial number") &&
           actual.containsSubstring("Serial number") {
            let matchRangeA2 = bannerRange(ideal, rangeA)
            if matchRangeA2.location != NSNotFound {
                assert(matchRangeA2.location >= rangeA.location, "oops #1")
                let matchRangeA1 = NSRange(location: rangeA.location, length: matchRangeA2.location - rangeA.location)

                let A_pre_len  = matchRangeA1.length
                let A_ver_len  = matchRangeA2.length
                let A_post_len = rangeA.length - A_pre_len - A_ver_len

                let matchRangeB2 = bannerRange(actual, rangeB)
                if matchRangeB2.location != NSNotFound {
                    assert(matchRangeB2.location >= rangeB.location, "oops #2")
                    let matchRangeB1 = NSRange(location: rangeB.location, length: matchRangeB2.location - rangeB.location)

                    let B_pre_len  = matchRangeB1.length
                    let B_ver_len  = matchRangeB2.length
                    let B_post_len = rangeB.length - B_pre_len - B_ver_len

                    diffInnerRangeA(matchRangeA1, rangeB: matchRangeB1)
                    differences.add(IFDiffEdit(range: matchRangeB2, form: .PRESERVE_ACTUAL_EDIT))
                    diffInnerRangeA(NSRange(location: rangeA.location + A_pre_len + A_ver_len, length: A_post_len),
                                    rangeB: NSRange(location: rangeB.location + B_pre_len + B_ver_len, length: B_post_len))
                    return
                }
            }
        }

        diffInnerRangeA(rangeA, rangeB: rangeB)
    }

    /* The second level is at last recursive. */
    private final func diffInnerRangeA(_ rangeA: NSRange,
                                       rangeB: NSRange) {
        let ideal = (self.ideal ?? "") as NSString
        let actual = (self.actual ?? "") as NSString

        // If A is empty B must be inserted, if B is empty A must be deleted
        if (rangeA.length == 0) && (rangeB.length == 0) {
            return
        }
        if rangeA.length == 0 {
            differences.add(IFDiffEdit(range: rangeB, form: .INSERT_EDIT))
            return
        }
        if rangeB.length == 0 {
            differences.add(IFDiffEdit(range: rangeA, form: .DELETE_EDIT))
            return
        }

        /*
         We look for the longest common prefix consisting of a sequence of entire
         words, or at any rate, ending at a word boundary (in both texts).
         */
        // Any common prefix can be preserved
        var i = 0
        while (i < rangeA.length) && (i < rangeB.length) {
            if charAt(ideal, rangeA.location+i) != charAt(actual, rangeB.location+i) {
                break
            }
            i += 1
        }
        if i < rangeA.length {
            while (i > 0) && !isWordBoundary(ideal, rangeA.location+i-1) {
                i -= 1
            }
        }
        if i > 0 {
            differences.add(IFDiffEdit(range: NSRange(location: rangeA.location, length: i), form: .PRESERVE_EDIT))
            diffInnerRangeA(NSRange(location: rangeA.location+i, length: rangeA.length - i),
                            rangeB: NSRange(location: rangeB.location+i, length: rangeB.length - i))
            return
        }

        /*
         Similarly, we're only interested in a common suffix going back to the start
         of a whole word.
         */
        // Any common suffix can be preserved
        let rangeEndA = rangeA.location + rangeA.length
        let rangeEndB = rangeB.location + rangeB.length
        i = 0
        while (i < rangeA.length) && (i < rangeB.length) {
            if charAt(ideal, rangeEndA-1-i) != charAt(actual, rangeEndB-1-i) {
                break
            }
            i += 1
        }
        if i < rangeEndA {
            while (i > 0) && !isWordBoundary(ideal, rangeEndA-i-1) {
                i -= 1
            }
        }

        if i > 0 {
            diffInnerRangeA(NSRange(location: rangeA.location, length: rangeA.length - i),
                            rangeB: NSRange(location: rangeB.location, length: rangeB.length - i))
            differences.add(IFDiffEdit(range: NSRange(location: rangeEndA-i, length: i), form: .PRESERVE_EDIT))
            return
        }

        /*
         In the typical use case most of the strings will now be gone, and this is
         where the algorithm goes quadratic. We're going to look for the longest
         common substring between A and B, provided it occurs at word boundaries,
         and is not trivially short. If we find this, we'll recurse to diff the
         text before the substring, then preserve the substring, then recurse to
         diff the text afterwards.
         */
        // Splice around the longest common substring
        var max_i = -1
        var max_j = -1
        var max_len = 0

        for i in 0..<rangeA.length {
            if (i == 0) || isWordBoundary(ideal, rangeA.location + i-1) {
                for j in 0..<rangeB.length {
                    if (j == 0) || isWordBoundary(actual, rangeB.location + j-1) {
                        var k = 0
                        while (i+k < rangeA.length) && (j+k < rangeB.length) && (charAt(ideal, rangeA.location + i+k) == charAt(actual, rangeB.location + j+k)) {
                            k += 1
                        }
                        while (k > MINIMUM_SPLICE_WORTH_BOTHERING_WITH) &&
                              !isWordBoundary(ideal, rangeA.location + i+k-1) {
                            k -= 1
                        }
                        if k > max_len {
                            max_len = k
                            max_i = i
                            max_j = j
                        }
                    }
                }
            }
        }
        if max_len >= MINIMUM_SPLICE_WORTH_BOTHERING_WITH {
            if trace_diff { NSLog("substring: ") }
            for c in 0..<max_len {
                if trace_diff { NSLog("%c", charAt(ideal, rangeA.location + max_i+c)) }
                assert(charAt(ideal, rangeA.location + max_i+c) == charAt(actual, rangeB.location + max_j+c), "oops #3")
            }
            if trace_diff { NSLog("\n---\n") }

            diffInnerRangeA(NSRange(location: rangeA.location, length: max_i),
                            rangeB: NSRange(location: rangeB.location, length: max_j))
            differences.add(IFDiffEdit(range: NSRange(location: rangeA.location + max_i, length: max_len),
                                       form: .PRESERVE_EDIT))
            diffInnerRangeA(NSRange(location: rangeA.location + max_i + max_len, length: rangeA.length - max_i - max_len),
                            rangeB: NSRange(location: rangeB.location + max_j + max_len, length: rangeB.length - max_j - max_len))

            if trace_diff { self.print() }
            if trace_diff { NSLog("\n---\n") }
            return
        }

        /*
         If we can't find any good substring, all we can usefully do is say that
         the text has entirely changed, and we display this as cleanly as possible:
         */
        // If all else fails we can always just delete A and insert B
        differences.add(IFDiffEdit(range: rangeA,
                                   form: .DELETE_EDIT))
        differences.add(IFDiffEdit(range: rangeB,
                                   form: .INSERT_EDIT))
    }
}
