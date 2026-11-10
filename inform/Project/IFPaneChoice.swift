//
//  IFPaneChoice.swift
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//  Translated from Objective-C in November 2026. The interface is still IFPaneChoice.h.
//

import Foundation

@objc @implementation extension IFPaneChoice {
    @objc(sourcePaneForViews:)
    class func sourcePane(forViews views: [NSNumber]) -> Int {
        // Returns the current pane containing the source code (or an appropriate pane that source code can be displayed
        // in)
        var paneToUse = 0

        for x in 0..<views.count {
            let thisView = IFProjectPaneType(rawValue: views[x].int32Value)

            if thisView == .sourcePane {
                // Always use the first source pane found
                paneToUse = x
                break
            }

            if thisView == .errorPane {
                // Avoid a pane showing error messages
                paneToUse = x + 1
            }
        }

        if paneToUse >= views.count {
            // All error views?
            paneToUse = 0
        }

        return paneToUse
    }

    @objc(auxPaneForViews:)
    class func auxPane(forViews views: [NSNumber]) -> Int {
        // Returns the auxiliary pane: the one to use for displaying documentation, etc
        var paneToUse = -1

        for x in 0..<views.count {
            let thisView = IFProjectPaneType(rawValue: views[x].int32Value)

            if thisView == .documentationPane {
                // Doc pane has priority
                paneToUse = x
                break
            }
        }

        // If no documentation pane available, choose something else.
        if paneToUse == -1 {
            paneToUse = 1
            for x in (0..<views.count).reversed() {
                let thisView = IFProjectPaneType(rawValue: views[x].int32Value)

                if thisView != .sourcePane &&
                    thisView != .gamePane {
                    // Anything but the source or game...
                    paneToUse = x
                    break
                }

                if thisView == .sourcePane {
                    // Avoid a pane showing the source code
                    paneToUse = x + 1
                }
            }
        }

        if paneToUse >= views.count {
            // All source views?
            paneToUse = 0
        }

        return paneToUse
    }

    @objc(indexPaneForViews:)
    class func indexPane(forViews views: [NSNumber]) -> Int {
        // Returns the current pane containing the index
        for x in 0..<views.count {
            let thisView = IFProjectPaneType(rawValue: views[x].int32Value)

            if thisView == .indexPane {
                // This is the index pane
                return x
            }
        }

        // No index pane showing: use the aux pane
        return auxPane(forViews: views)
    }

    @objc(paneOppositePane:count:)
    class func paneOppositePane(_ index: Int,
                                count: Int) -> Int {
        // Get it's 'opposite'
        var opposite = index - 1
        if opposite < 0 { opposite = count - 1 }

        return opposite
    }
}
