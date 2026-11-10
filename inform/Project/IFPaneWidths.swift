//
//  IFPaneWidths.swift
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//  Translated from Objective-C in November 2026. The interface is still IFPaneWidths.h.
//

import Foundation

private let minDividerWidth: CGFloat = 75.0

//
// The proportions are read from the preferences, so each is read as `AnyObject`, and asked for its `doubleValue` as
// Objective-C did: text answers as a number does.
//

@objc @implementation extension IFPaneWidths {
    @objc(widthsOfPanes:inWidth:dividerWidth:proportions:)
    class func widths(ofPanes nviews: Int,
                      inWidth fullWidth: CGFloat,
                      dividerWidth: CGFloat,
                      proportions: [Any]?) -> [NSNumber] {
        var widths: [NSNumber] = []

        // Remaining space for other dividers
        let remaining        = fullWidth - dividerWidth * CGFloat(nviews - 1)
        var totalRemaining   = fullWidth

        // Work out the widths of the dividers using the preferences
        var realDividerWidths: [CGFloat] = []

        // (Being typed, the proportions can only be an array, or nil)
        var dividerProportions = proportions ?? []
        if dividerProportions.count <= 0 {
            dividerProportions = [NSNumber(value: Float(1.0))]
        }

        var totalWidth: CGFloat = 0
        for view in 0..<max(nviews, 0) {
            var width: CGFloat

            if view >= dividerProportions.count {
                width = CGFloat((dividerProportions[dividerProportions.count - 1] as AnyObject).doubleValue!)
            } else {
                width = CGFloat((dividerProportions[view] as AnyObject).doubleValue!)
            }

            if width <= 0 {
                width = 1.0
            }
            realDividerWidths.append(width)

            totalWidth += width
        }

        // Work out the actual widths to use
        let proportion = remaining / totalWidth

        for view in 0..<max(nviews - 1, 0) {
            let viewWidth = floor(proportion * realDividerWidths[view])
            widths.append(NSNumber(value: Double(viewWidth)))

            // Update the amount of space remaining
            totalRemaining -= viewWidth + dividerWidth
        }

        // The final pane has what's left
        widths.append(NSNumber(value: Double(totalRemaining)))

        return widths
    }

    @objc(proportionsOfWidths:inWindowWidth:)
    class func proportions(ofWidths widths: [NSNumber],
                           inWindowWidth totalWidth: CGFloat) -> [NSNumber] {
        var viewSizes: [NSNumber] = []

        for width in widths {
            viewSizes.append(NSNumber(value: Double(CGFloat(width.doubleValue) / totalWidth)))
        }

        return viewSizes
    }

    @objc(leastDividerPosition:)
    class func leastDividerPosition(_ proposedMinimumPosition: CGFloat) -> CGFloat {
        var proposedMinimumPosition = proposedMinimumPosition
        if proposedMinimumPosition < minDividerWidth {
            proposedMinimumPosition = minDividerWidth
        }

        return proposedMinimumPosition
    }

    @objc(greatestDividerPosition:inWidth:)
    class func greatestDividerPosition(_ proposedMaximumPosition: CGFloat,
                                       inWidth width: CGFloat) -> CGFloat {
        var proposedMaximumPosition = proposedMaximumPosition
        let limit = max(minDividerWidth, width - minDividerWidth)
        if proposedMaximumPosition > limit {
            proposedMaximumPosition = limit
        }

        return proposedMaximumPosition
    }
}
