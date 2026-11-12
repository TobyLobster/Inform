//
//  IFTabStops.swift
//  Inform
//
//  Moved out of IFSyntaxData in November 2026. The interface is IFTabStops.h.
//

import Cocoa

@objc @implementation extension IFTabStops {

    class func standardTabStops(forTabWidth tabWidth: CGFloat) -> [NSTextTab] {
        // A standard set of tabs at the current width
        var stopWidth = tabWidth
        if stopWidth < 1.0 {
            stopWidth = 1.0
        }

        var newTabStops: [NSTextTab] = []
        for x in 0..<48 {
            let tabStop = NSTextTab(type: .leftTabStopType,
                                    location: stopWidth * CGFloat(x + 1))
            newTabStops.append(tabStop)
        }

        return newTabStops
    }

    // MARK: - Elastic tabs

    // See http://nickgravgaard.com/elastictabstops/ for more information on these

    // Given the cells of each line of a table, calculate the positions the 'elastic' tab stops should go at
    class func elasticTabStops(forCells lines: [[NSAttributedString]], tabWidth: CGFloat) -> [NSTextTab] {
        let numColumns = lines.map(\.count).max() ?? 0

        // Work out the widths for each column
        let margin: CGFloat = 8.0                           // size of column margin

        var columnWidths: [CGFloat] = []
        for _ in 0..<numColumns {
            columnWidths.append(tabWidth)
        }

        for line in lines {
            for colNum in 0..<line.count {
                // Get the size of the line
                let colString   = line[colNum]
                let thisSize    = colString.size()

                // Get the current width of this column
                let currentWidth = columnWidths[colNum]

                // Adjust as necessary
                if thisSize.width + margin > currentWidth {
                    columnWidths[colNum] = floor(thisSize.width + margin)
                }
            }
        }

        // Tab stops are currently widths: need to change them to NSTextTab objects locations
        var elasticTabStops: [NSTextTab] = []
        var lastPosition: CGFloat = 0
        for colNum in 0..<numColumns {
            let currentValue    = columnWidths[colNum]
            let newValue        = floor(currentValue + lastPosition)
            lastPosition = newValue

            elasticTabStops.append(NSTextTab(type: .leftTabStopType,
                                             location: newValue))
        }

        // elasticTabStops now contains the set of tab stops for this region
        return elasticTabStops
    }
}
