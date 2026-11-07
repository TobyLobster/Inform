//
//  IFSkeinLayout.swift
//  Inform
//
//  Created by Toby Nelson 2015
//

import Cocoa

@objc @implementation extension IFSkeinLayout {
    // The layout
    private final var treeRoot: IFSkeinLayoutItem?
    private final var levels: [[IFSkeinLayoutItem]] = []
    private final var levelWidths: [CGFloat] = []
    private final var levelYs: [CGFloat]?
    private final var levelArray: [[IFSkeinLayoutItem]] = []
    private final var _activeLayoutItem: IFSkeinLayoutItem?

    private final var shiftRightForReportOffsetX: CGFloat

    private final var _rootLayoutItem: IFSkeinLayoutItem?
    private final var _selectedLayoutItem: IFSkeinLayoutItem?
    private final var _reportPosition: NSPoint

    var rootItem: IFSkeinItem?
    var activeItem: IFSkeinItem?
    var selectedItem: IFSkeinItem?

    var rootLayoutItem: IFSkeinLayoutItem? {
        return _rootLayoutItem
    }

    var selectedLayoutItem: IFSkeinLayoutItem? {
        return _selectedLayoutItem
    }

    var reportPosition: NSPoint {
        return _reportPosition
    }

    // MARK: - Initialisation

    override convenience init() {
        self.init(rootItem: nil)
    }

    init(rootItem item: IFSkeinItem?) {
        rootItem         = item
        _reportPosition  = NSMakePoint(0.0, 0.0)
        shiftRightForReportOffsetX = 0.0
        super.init()
    }

    // MARK: - Setting skein data

    private final func setRecentlyPlayedItems() {
        // Mark everything upwards of the active item as played
        var layoutItem = _activeLayoutItem
        while let item = layoutItem {
            item.recentlyPlayed = true
            layoutItem = item.parent
        }
    }

    private final func clearOnSelectedLine(_ root: IFSkeinLayoutItem?) {
        root?.onSelectedLine = false
        for child in root?.childItems ?? [] {
            clearOnSelectedLine(child)
        }
    }

    private final func setSelectedLineItems() {
        // Update the set of items that use the 'transcript line' style

        // Clear the items that are currently marked as highlighted
        clearOnSelectedLine(treeRoot)

        // Iterate up from the highlighted item
        var layoutItem = _selectedLayoutItem

        while let item = layoutItem {
            // Store this item
            item.onSelectedLine = true

            // Up the tree
            layoutItem = item.parent
        }

        // Iterate down from the highlighted item, so long as there is only one child item
        layoutItem = _selectedLayoutItem

        while let children = layoutItem?.childItems, children.count > 0 {
            // Move down the tree
            layoutItem = children[0]

            // Store this item
            layoutItem?.onSelectedLine = true
        }
    }

    // MARK: - Item positioning data

    private final func levelAtViewPosY(_ viewPosY: CGFloat) -> Int {
        let viewPosY = viewPosY - kSkeinTopBorder

        for level in 0..<levels.count {
            // There are no positions until the report's details are given
            if viewPosY < (levelYs?[level + 1] ?? 0.0) {
                return level
            }
        }
        return levels.count
    }

    @objc(itemAtPoint:)
    func item(at point: NSPoint) -> IFSkeinItem? {
        // Searches for the item that is under the given point

        // Check for level
        let level = levelAtViewPosY(point.y)
        if level < 0 || level >= levels.count { return nil }

        for layoutItem in levels[level] {
            if NSPointInRect(point, layoutItem.lozengeRect) {
                return layoutItem.item
            }
        }

        // Nothing found
        return nil
    }

    var size: NSSize {
        if let treeRoot {
            var res = NSSize()

            res.width = treeRoot.subtreeWidth + shiftRightForReportOffsetX + kSkeinRightBorder
            var treeHeight: CGFloat = 0.0
            if levels.count > 0 {
                treeHeight = levelYs?[levels.count] ?? 0.0
            }
            res.height = treeHeight + kSkeinTopBorder + kSkeinBottomBorder

            return res
        } else {
            return NSMakeSize(0, 0)
        }
    }

    // MARK: - Packing

    func layoutSkein() {
        // 'Best Fit' packing style
        levels       = []
        levelWidths  = []
        levelYs      = nil
        _activeLayoutItem = nil
        _selectedLayoutItem = nil
        _rootLayoutItem = nil

        // Create the tree of layout nodes
        treeRoot = layoutSkeinCreateLayoutTree(rootItem,
                                               withLevel: 0)

        // Mark everything upwards of the active item as recently played, and set the highlighted line
        setRecentlyPlayedItems()
        setSelectedLineItems()

        // Align all layout items to the left
        layoutSkeinItemAlignLeft(treeRoot,
                                 withLevel: 0)

        // Run the best fit algorithm
        layoutSkeinItemBestFit(treeRoot)

        // Work out the subtree width of each node
        _ = layoutSkeinCalculateSubtreeWidth(treeRoot)

        // Clear out levelWidths, since it is only used while laying out
        levelWidths = []
    }

    private final func currentLevelWidth(_ level: Int) -> CGFloat {
        // Make sure we have enough levels
        while levelWidths.count <= level {
            levelWidths.append(0.0)
        }
        // Read as a float, as the Objective-C read it from an NSNumber
        return CGFloat(Float(levelWidths[level]))
    }

    private final func layoutSkeinCreateLayoutTree(_ item: IFSkeinItem?,
                                                   withLevel level: Int32) -> IFSkeinLayoutItem? {
        guard let item else {
            return nil
        }

        let result = IFSkeinLayoutItem(item: item,
                                       subtreeWidth: 1.0,
                                       level: level)

        if item === activeItem {
            _activeLayoutItem = result
        }
        if item === selectedItem {
            _selectedLayoutItem = result
        }
        if item === rootItem {
            _rootLayoutItem = result
        }

        var children: [IFSkeinLayoutItem] = []

        // Create layout tree, recursively
        for child in item.children {
            let childItem = layoutSkeinCreateLayoutTree(child,
                                                        withLevel: level + 1)!
            childItem.parent = result
            children.append(childItem)
        }
        result.childItems = children

        // Add to the 'levels' array, which contains the items to draw at each level
        while Int(level) >= levels.count {
            levels.append([])
        }
        levels[Int(level)].append(result)

        return result
    }

    private final func layoutSkeinItemAlignLeft(_ layoutItem: IFSkeinLayoutItem?,
                                                withLevel level: Int) {
        guard let layoutItem else {
            return
        }

        // Align items to the left edge (DFS)
        for child in layoutItem.childItems ?? [] {
            layoutSkeinItemAlignLeft(child,
                                     withLevel: level + 1)
        }

        var currentLevelWidth = self.currentLevelWidth(level)

        // Set initial rectangle
        var itemRect = NSRect()
        itemRect.origin.x   = floor(kSkeinLeftBorder - kSkeinItemImageLeftBorder + currentLevelWidth)
        itemRect.origin.y   = floor(CGFloat(layoutItem.level) * kSkeinMinLevelHeight + kSkeinTopBorder)

        itemRect.size.width  = kSkeinItemImageCommandLeftBorder + layoutItem.commandWidth + kSkeinItemImageCommandRightBorder + kSkeinItemFrameWidthExtension
        itemRect.size.height = kSkeinItemFrameHeight

        itemRect = NSIntegralRect(itemRect)

        layoutItem.boundingRect = itemRect

        currentLevelWidth += layoutItem.visibleWidth + kSkeinItemPadding

        levelWidths[level] = currentLevelWidth
    }

    private final func moveRemainingItemsRightAfter(_ item: IFSkeinLayoutItem,
                                                    onLevel levelIndex: Int,
                                                    by deltaX: CGFloat,
                                                    recursively: Bool) {
        // Move remaining items at this level right
        var found = false
        let level = levelArray[levelIndex]
        for item2 in level {
            if item2 === item {
                found = true
            }
            if found {
                item2.moveRight(by: deltaX,
                                recursively: recursively)
            }
        }
    }

    private final func layoutSkeinItemBestFit(_ startItem: IFSkeinLayoutItem?) {
        guard let startItem else {
            return
        }

        var queue: [IFSkeinLayoutItem] = [startItem]
        levelArray = [[startItem]]

        // Create a queue - each item, from the top to the bottom, left to right (BFS). It's read from the front
        // by index, as removing an array's first element moves all the rest.
        var queueIndex = 0
        while queueIndex < queue.count {
            let itemQ = queue[queueIndex]

            for childItem in itemQ.childItems ?? [] {
                // Add to queue
                queue.append(childItem)

                // Add to levels
                while levelArray.count <= Int(childItem.level) {
                    levelArray.append([])
                }
                levelArray[Int(childItem.level)].append(childItem)
            }
            queueIndex += 1
        }

        // Visit each level, from the bottom to the top, left to right
        for level in levelArray.reversed() {
            for layoutItem in level {
                if !layoutItem.onSelectedLine {
                    // We are not on the selected line
                    // If we are a parent, centre the parent between it's children
                    let children = layoutItem.childItems ?? []
                    if children.count > 0 {
                        let parentx = layoutItem.centreX

                        // Find centre of all children
                        var minx = CGFloat.greatestFiniteMagnitude
                        var maxx = -CGFloat.greatestFiniteMagnitude
                        for item2 in children {
                            minx = min(minx, NSMidX(item2.lozengeRect))
                            maxx = max(maxx, NSMidX(item2.lozengeRect))
                        }
                        let centreChildrenX = (minx + maxx)/2
                        let deltaX: CGFloat

                        if parentx < centreChildrenX {
                            // Move parent right to centre under children
                            deltaX = centreChildrenX - parentx

                            // Move remaining items at this level right
                            moveRemainingItemsRightAfter(layoutItem,
                                                         onLevel: Int(layoutItem.level),
                                                         by: deltaX,
                                                         recursively: false)
                        } else if parentx > centreChildrenX {
                            deltaX = parentx - centreChildrenX

                            // Move the first child right to align under parent, and all remaining
                            // items on that level, and any of their children by the same amount
                            moveRemainingItemsRightAfter(children[0],
                                                         onLevel: Int(layoutItem.level) + 1,
                                                         by: deltaX,
                                                         recursively: true)
                        }
                    }
                }
                else {
                    // We are on the selected line. Arrange in a straight line.
                    let parentx = layoutItem.centreX

                    // Find child's centre point
                    if let selectedLineChild = layoutItem.selectedLineChild {
                        let centreChildrenX = selectedLineChild.centreX
                        let deltaX: CGFloat

                        if parentx < centreChildrenX {
                            // Move parent right to centre under children
                            deltaX = centreChildrenX - parentx

                            // Move remaining items at this level right
                            moveRemainingItemsRightAfter(layoutItem,
                                                         onLevel: Int(layoutItem.level),
                                                         by: deltaX,
                                                         recursively: false)
                        } else if parentx > centreChildrenX {
                            deltaX = parentx - centreChildrenX

                            // Move the first child right to align under parent, and all remaining
                            // items on that level, and any of their children by the same amount
                            moveRemainingItemsRightAfter(layoutItem.childItems![0],
                                                         onLevel: Int(layoutItem.level) + 1,
                                                         by: deltaX,
                                                         recursively: true)
                        }
                    }
                }
            }
        }

        // We are done with the level arrays now... only used while laying out.
        levelArray = []
    }

    private final func layoutSkeinCalculateSubtreeWidth(_ layoutItem: IFSkeinLayoutItem?) -> CGFloat {
        guard let layoutItem else {
            return 0.0
        }

        // DFS
        var furthestRightX: CGFloat = 0.0
        for child in layoutItem.childItems ?? [] {
            let childFurthestRightX = layoutSkeinCalculateSubtreeWidth(child)
            furthestRightX = max(furthestRightX, childFurthestRightX)
        }

        furthestRightX = max(NSMaxX(layoutItem.lozengeRect), furthestRightX)
        layoutItem.subtreeWidth = furthestRightX
        return furthestRightX
    }

    private final func itemClosestBeyondX(_ minX: CGFloat,
                                          root layoutItem: IFSkeinLayoutItem) -> IFSkeinLayoutItem? {
        var result: IFSkeinLayoutItem? = nil
        var bestX = CGFloat.greatestFiniteMagnitude

        let x = NSMinX(layoutItem.boundingRect)
        if x > minX {
            bestX = x
            result = layoutItem
        }

        for child in layoutItem.childItems ?? [] {
            if let childResult = itemClosestBeyondX(minX, root: child) {
                let childX = NSMinX(childResult.boundingRect)
                if childX < bestX {
                    result = childResult
                    bestX = childX
                }
            }
        }

        return result
    }

    private final func expandTreeVertically(_ root: IFSkeinLayoutItem) {
        // Adjust Y position only (the level's position is read as a float, as the Objective-C read it from an NSNumber)
        root.boundingRect = NSMakeRect(root.boundingRect.origin.x,
                                       kSkeinTopBorder + CGFloat(Float(levelYs![Int(root.level)])),
                                       root.boundingRect.size.width,
                                       root.boundingRect.size.height)
        for child in root.childItems ?? [] {
            expandTreeVertically(child)
        }
    }

    @objc(updateLayoutWithReportDetails:)
    func update(withReportDetails array: [NSNumber]) {

        // Set the level Y positions based on the report details
        var newLevelYs: [CGFloat] = [0.0]

        var totalHeight: CGFloat = 0.0
        for i in 0..<levels.count {
            var levelHeight = kSkeinMinLevelHeight
            if i < array.count {
                levelHeight = CGFloat(array[i].doubleValue)
            }
            totalHeight += levelHeight
            newLevelYs.append(totalHeight)
        }
        levelYs = newLevelYs

        // We move the tree that exists to the right of the selected line further right to make room for the report
        // (none if there's no selected line)
        shiftRightForReportOffsetX = 0.0

        // Find the right position for the report frame
        if let treeRoot, treeRoot.onSelectedLine {
            var selectedLineItem: IFSkeinLayoutItem? = treeRoot

            _reportPosition.x = 0.0
            _reportPosition.y = kSkeinTopBorder + kSkeinItemImageTopBorder + kSkeinItemImageHeight * 0.5 - kSkeinReportInsideTopBorder - kSkeinReportOffsetY

            // Traverse down the selected line to find the ideal x position for the report
            while let item = selectedLineItem, item.onSelectedLine {
                _reportPosition.x = max(_reportPosition.x,
                                        floor(NSMaxX(item.lozengeRect) + kSkeinReportLeftBorder))

                // Move on to next level down
                selectedLineItem = item.selectedLineChild
            }

            // Traverse the tree, looking for the item furthest left on the right hand side of the selected line
            let selectedLineX = treeRoot.centreX
            let bestItem = itemClosestBeyondX(selectedLineX, root: treeRoot)
            if let bestItem {
                let closestBeyondX = NSMinX(bestItem.boundingRect)
                shiftRightForReportOffsetX = _reportPosition.x - closestBeyondX
            }
            shiftRightForReportOffsetX += kSkeinReportWidth + kSkeinReportRightBorder - kSkeinItemImageLeftBorder

            // Traverse down the selected line
            selectedLineItem = treeRoot
            while let item = selectedLineItem, item.onSelectedLine {
                var foundSelectedLine = false
                for child in item.childItems ?? [] {
                    // Find any child to the right of the selected line...
                    if child.onSelectedLine {
                        foundSelectedLine = true
                    }
                    else if foundSelectedLine {
                        // ...and move it to the right
                        child.moveRight(by: shiftRightForReportOffsetX,
                                        recursively: true)
                    }
                }

                // Move on to next level down
                selectedLineItem = item.selectedLineChild
            }
        }

        // Expand the tree vertically
        if let treeRoot {
            expandTreeVertically(treeRoot)
        }
    }
}
