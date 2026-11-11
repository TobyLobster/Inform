//
//  IFInform7MutableString.swift
//  Inform
//
//  Created by Andrew Hunter on 04/10/2009.
//  Copyright 2009 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFInform7MutableString.h.
//

import Foundation

private let quotationMark: unichar      = 0x22      // "
private let leftQuotationMark: unichar  = 0x201C    // “
private let rightQuotationMark: unichar = 0x201D    // ”
private let openBracket: unichar        = 0x5B      // [
private let closeBracket: unichar       = 0x5D      // ]

@objc(IFInform7MutableString) @implementation extension NSMutableString {

    // Given a range, is it valid for commenting / uncommenting code?
    private final func checkValidRangeForChangingCommenting(_ range: UnsafeMutablePointer<NSRange>,
                                                            commentDepth commentDepthOut: inout Int) -> Bool {
        // Make sure we are in range
        range.pointee = NSIntersectionRange(range.pointee, NSRange(location: 0, length: length))

        // Make sure something is selected
        if range.pointee.length == 0 {
            return false
        }

        var commentDepth    = 0
        var inString        = false

        // Parse up to the starting point...
        for index in 0..<range.pointee.location {
            let chr = character(at: index)

            // Check for start or end of string (a quotation mark in a comment is part of the comment)
            if ((chr == quotationMark) || (chr == leftQuotationMark) || (chr == rightQuotationMark)) && (commentDepth == 0) {
                inString = !inString
            } else if !inString {
                // Check for start or end comment
                if chr == openBracket {
                    commentDepth += 1
                } else if (chr == closeBracket) && (commentDepth > 0) {
                    commentDepth -= 1
                }
            }
        }

        // If we are in a string, don't try to comment out code
        if inString {
            return false
        }

        // Scan the range to make sure we are not spanning different comment levels...
        var rangeCommentDepth = commentDepth
        for index in range.pointee.location..<(range.pointee.location + range.pointee.length) {
            let chr = character(at: index)

            if ((chr == quotationMark) || (chr == leftQuotationMark) || (chr == rightQuotationMark)) && (rangeCommentDepth == 0) {
                inString = !inString
            } else if !inString {
                // Check for start or end comment
                if chr == openBracket {
                    rangeCommentDepth += 1
                } else if (chr == closeBracket) && (rangeCommentDepth > 0) {
                    rangeCommentDepth -= 1

                    // If we close a comment so the depth goes below the start depth, don't try to comment it out.
                    if rangeCommentDepth < commentDepth {
                        return false
                    }
                }
            }
        }

        // If we are in a string, don't try to comment out code
        if inString {
            return false
        }

        // If the comment depth changes, don't try to comment out code
        if rangeCommentDepth != commentDepth {
            return false
        }

        commentDepthOut = commentDepth
        return true
    }

    /// Where the brackets of the outermost comments in a range are, for a range that starts at this comment depth and
    /// doesn't leave it. Brackets in a string aren't comments.
    private final func outermostCommentBrackets(in range: NSRange, commentDepth: Int) -> [Int] {
        var brackets: [Int] = []
        var depth = 0           // In the range
        var inString = false

        for index in range.location..<(range.location + range.length) {
            let chr = character(at: index)

            let isQuotationMark = (chr == quotationMark) || (chr == leftQuotationMark) || (chr == rightQuotationMark)
            if isQuotationMark && (commentDepth + depth == 0) {
                inString = !inString
            } else if !inString {
                if chr == openBracket {
                    if depth == 0 { brackets.append(index) }
                    depth += 1
                } else if (chr == closeBracket) && (depth > 0) {
                    depth -= 1
                    if depth == 0 { brackets.append(index) }
                }
            }
        }

        return brackets
    }

    func commentOutInform7(_ range: UnsafeMutablePointer<NSRange>) -> Bool {
        // Make sure we are in a valid range
        var commentDepth = 0
        let isValidRange = checkValidRangeForChangingCommenting(range,
                                                                commentDepth: &commentDepth)
        if !isValidRange {
            return false
        }

        // All clear to make the change - comment out
        insert("]", at: range.pointee.location + range.pointee.length)
        insert("[", at: range.pointee.location)
        range.pointee.length += 2

        return true
    }

    ///
    /// Removes I7 comments from the specified range
    ///
    func removeCommentsInform7(_ range: UnsafeMutablePointer<NSRange>) -> Bool {
        // Make sure we are in a valid range
        var commentDepth = 0
        let isValidRange = checkValidRangeForChangingCommenting(range,
                                                                commentDepth: &commentDepth)
        if !isValidRange {
            return false
        }

        // All clear to make the change - uncomment. Each comment in the selection loses its brackets, but in a
        // comment, only a selection that's one comment does.
        let brackets = outermostCommentBrackets(in: range.pointee, commentDepth: commentDepth)
        let end = range.pointee.location + range.pointee.length - 1
        if commentDepth == 0 || brackets == [range.pointee.location, end] {
            if brackets.isEmpty {
                return false
            }
            for index in brackets.reversed() {
                deleteCharacters(in: NSRange(location: index, length: 1))
            }
            range.pointee.length -= brackets.count
            return true
        }

        // Otherwise the comment it's in is closed before it and opened again after it
        insert("[", at: range.pointee.location + range.pointee.length)
        insert("]", at: range.pointee.location)
        range.pointee.length += 2

        return true
    }
}
