//
//  IFRestrictedRanges.swift
//  Inform
//
//  Moved out of IFSyntaxData in November 2026. The interface is IFRestrictedRanges.h.
//

import Foundation

@objc @implementation extension IFRestrictedRanges {
    //
    // When a change occurs to the main text, a restricted range may well change position as a
    // result. This method carefully calculates how to adjust the restricted range based on a
    // change specified by the edited range and changeInLength.
    //
    @objc(adjustRange:editedRange:changeInLength:)
    class func adjust(_ range: NSRange,
                      editedRange newRange: NSRange,
                      changeInLength: Int) -> NSRange {
        let oldRange = NSRange(location: newRange.location, length: newRange.length - changeInLength)

        // An edit consists of removing the oldRange of characters, then adding a newRange.

        // Work out what we need to remove
        var charactersToRemoveFromLocation = 0
        var charactersToRemoveFromLength = 0

        // Removing characters from before the start of the range changes the location
        if oldRange.location < range.location {
            charactersToRemoveFromLocation = min(range.location - oldRange.location, oldRange.length)
        }

        // Removing characters within the range changes the length
        if ((oldRange.location + oldRange.length) > range.location) &&
            (oldRange.location <= (range.location + range.length)) {
            let start = (oldRange.location > range.location) ? (oldRange.location - range.location) : 0
            var end   = min((oldRange.location + oldRange.length) - range.location, oldRange.location + oldRange.length)
            end       = min(end, range.length)

            charactersToRemoveFromLength = max(end - start, 0)
        }

        // Work out how much we need to add
        var charactersToAddToLocation = 0
        var charactersToAddToLength = 0

        // Adding characters before the range changes the location
        if newRange.location < range.location {
            charactersToAddToLocation = newRange.length
        }

        // Adding characters within the range changes the length
        if (newRange.location >= range.location) &&
            (newRange.location <= (range.location + range.length)) {
            charactersToAddToLength = min(newRange.location + newRange.length - range.location, newRange.length)
        }

        precondition((range.location - charactersToRemoveFromLocation + charactersToAddToLocation) >= 0, "Bad location for adjusting range")
        precondition((range.length - charactersToRemoveFromLength + charactersToAddToLength) >= 0, "Bad length for adjusting range")

        return NSRange(location: range.location - charactersToRemoveFromLocation + charactersToAddToLocation,
                       length: range.length - charactersToRemoveFromLength + charactersToAddToLength)
    }

    //
    // Given an edited range within the full text and a restricted range, this carefully works
    // out how much of the edit lies within that restricted range.
    //
    @objc(intersectRange:withRestrictedRange:)
    class func intersect(_ range: NSRange,
                         withRestrictedRange restrictedRange: NSRange) -> NSRange {
        var start = range.location
        var end   = start + range.length

        // Clip the start and end to the restrictedRange
        if start < restrictedRange.location {
            start = restrictedRange.location
        }
        if end > (restrictedRange.location + restrictedRange.length) {
            end = restrictedRange.location + restrictedRange.length
        }

        // If we don't have a (start -> end) range left, there is no intersection
        if start > end {
            return NSRange(location: NSNotFound, length: 0)
        }

        // If our new range has length > 0 and ends exactly at the start of the location,
        // this doesn't count as an intersection.
        if (start < end) && end == restrictedRange.location {
            return NSRange(location: NSNotFound, length: 0)
        }

        return NSRange(location: start, length: end - start)
    }
}
