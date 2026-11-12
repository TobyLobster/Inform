//
//  IFSkeinViewChildren.swift
//  Inform
//
//  Created by Toby Nelson in 2015
//

import AppKit
import QuartzCore

private let kAnimationSteps             = 30
/// Link view thickness (include one pixel transparent border)
private let kSkeinLinkViewThickness     = kSkeinLinkThickness + 2.0

private let kSkeinLinkViewHalfThickness = kSkeinLinkViewThickness * 0.5
/// Height of the arrow view
private let kSkeinArrowViewHeight       = kSkeinArrowHeadHeight + 2.0
/// Move link lines below the top of the lozenge
private let kSkeinLinkFromOffsetY       = kSkeinLinkThickness * 0.5

private let kAngleEpsilon: CGFloat      = 0.001
private let kPositionEpsilon: CGFloat   = 0.01

@objc @implementation extension IFSkeinViewChildren {
    /// Dictionary of 'IFSkeinItemView's keyed on item's uniqueId.
    private final var itemViews: [UInt: IFSkeinItemView]
    /// Dictionary of 'IFSkeinLinkView's keyed on item's uniqueId.
    private final var linkViews: [UInt: IFSkeinLinkView]
    /// Dictionary of 'IFSkeinArrowView's keyed on item's uniqueId.
    private final var arrowViews: [UInt: IFSkeinArrowView]
    /// The skein view, which keeps the children
    private final weak var skeinView: IFSkeinView?
    private final let reportView: IFSkeinReportView
    private final var currentTimeInterval: CFTimeInterval

    init(skeinView theSkeinView: IFSkeinView) {
        itemViews  = [:]
        linkViews  = [:]
        arrowViews = [:]
        reportView = IFSkeinReportView()
        skeinView  = theSkeinView
        currentTimeInterval = CACurrentMediaTime()

        super.init()

        reportView.delegate = self

        skeinView?.addSubview(reportView)
    }

    private final func addSubtreeItems(_ root: IFSkeinLayoutItem,
                                       to array: inout [UInt: IFSkeinLayoutItem]) {
        array[root.item.uniqueId] = root
        for child in root.children ?? [] {
            addSubtreeItems(child, to: &array)
        }
    }

    private final func allItemsFromLayout(_ layout: IFSkeinLayout) -> [UInt: IFSkeinLayoutItem] {
        var layoutItems: [UInt: IFSkeinLayoutItem] = [:]
        if let rootLayoutItem = layout.rootLayoutItem {
            addSubtreeItems(rootLayoutItem, to: &layoutItems)
        }
        return layoutItems
    }

    private final func createItemView(fromLayoutItem layoutItem: IFSkeinLayoutItem,
                                      key: UInt) {
        let resultView = IFSkeinItemView(frame: layoutItem.boundingRect)
        skeinView?.addSubview(resultView)   // Add item to skein view
        itemViews[key] = resultView         // Add item to dictionary

        updateItemView(resultView, fromLayoutItem: layoutItem, animate: false, fadeIn: true)
    }

    private final func createLinkView(fromLayoutItem layoutItem: IFSkeinLayoutItem,
                                      key: UInt) {
        if layoutItem.item.parent == nil {
            return
        }
        let newLink = IFSkeinLinkView()
        skeinView?.addSubview(newLink)      // Add link to skein view
        linkViews[key] = newLink            // Add link to dictionary

        updateLinkView(newLink,
                       fromLayoutItem: layoutItem,
                       animate: false,
                       fadeIn: true)
    }

    private final func createArrowView(fromLayoutItem layoutItem: IFSkeinLayoutItem,
                                       key: UInt,
                                       layout: IFSkeinLayout) {
        let newArrow = IFSkeinArrowView()
        skeinView?.addSubview(newArrow)     // Add link to skein view
        arrowViews[key] = newArrow          // Add link to dictionary

        updateArrowView(newArrow,
                        layout: layout,
                        fromLayoutItem: layoutItem,
                        animate: false)
    }

    private final func updateItemView(_ itemView: IFSkeinItemView,
                                      fromLayoutItem layoutItem: IFSkeinLayoutItem,
                                      animate: Bool,
                                      fadeIn: Bool) {
        var animate = animate

        let thePositionAnimation = CAKeyframeAnimation(keyPath: "position")
        var positionValues: [NSValue] = []
        positionValues.reserveCapacity(kAnimationSteps + 1)
        var startPosition = itemView.frame.origin
        var finalPosition = layoutItem.boundingRect.origin

        if let actualLayer = itemView.layer?.presentation() {
            startPosition = actualLayer.frame.origin
        }

        if !(itemView.layer?.isGeometryFlipped ?? false) {
            finalPosition.y = (itemView.superview?.bounds.size.height ?? 0) - finalPosition.y
        }

        // Performance optimisation. If it's not moving, don't animate it.
        if (abs(startPosition.x - finalPosition.x) < kPositionEpsilon) &&
           (abs(startPosition.y - finalPosition.y) < kPositionEpsilon) {
            animate = false
        }

        if animate {
            for step in 0...kAnimationSteps {
                var t = CGFloat(step) / CGFloat(kAnimationSteps)
                t = easeOutCubic(t)
                let pos = NSPoint(x: lerp(t, startPosition.x, finalPosition.x),
                                  y: lerp(t, startPosition.y, finalPosition.y))
                positionValues.append(NSValue(point: pos))
            }
            thePositionAnimation.values = positionValues
            thePositionAnimation.calculationMode = .linear

            itemView.layer?.add(thePositionAnimation,
                                forKey: "positionItemAnimation")
        }

        if fadeIn {
            let delay = kSkeinAnimationDuration
            fadeInView(itemView,
                       delay: delay,
                       duration: kSkeinAnimationItemFadeIn,
                       animate: animate,
                       fromCurrent: false)
        }

        itemView.frame      = layoutItem.boundingRect
        itemView.layoutItem = layoutItem

        // Only redraw if state hash has changed
        let hash = itemView.drawnStateHash
        if (hash == 0) || (hash != layoutItem.drawStateHash) {
            itemView.needsDisplay = true
            itemView.display()
        }
    }

    private final func layerAngle(_ layer: CALayer?) -> CGFloat {
        return atan2(layer?.transform.m12 ?? 0, layer?.transform.m11 ?? 0)
    }

    private final func updateLinkView(_ linkView: IFSkeinLinkView?,
                                      fromLayoutItem layoutItem: IFSkeinLayoutItem,
                                      animate: Bool,
                                      fadeIn: Bool) {
        var animate = animate

        if layoutItem.item.parent == nil {
            return
        }
        // With no link, there's nothing to update, as messages to nil did nothing
        guard let linkView else {
            return
        }
        let childRect    = layoutItem.lozengeRect
        let parentRect   = layoutItem.parent?.lozengeRect ?? NSZeroRect

        // We draw a line FROM->TO.
        //  FROM = The top centre of the child lozenge
        //    TO = The middle of the parent lozenge
        // The line animates over time from 'Start' (the current position) to 'Final' the final desired position

        // Get current position and end point
        var startLength = linkView.frame.size.width
        var startAngle  = layerAngle(linkView.layer)

        var startFrom = linkView.frame.origin

        if let actualLayer = linkView.layer?.presentation() {
            startFrom   = actualLayer.position
            startLength = actualLayer.bounds.size.width
            startAngle  = layerAngle(actualLayer)
        }

        if !(linkView.layer?.isGeometryFlipped ?? false) {
            startAngle = -startAngle
        }

        let startTo   = NSPoint(x: startFrom.x + startLength * cos(startAngle),
                                y: startFrom.y + startLength * sin(startAngle))

        // Get desired final point
        var finalFrom  = NSPoint(x: NSMidX(childRect),
                                 y: NSMinY(childRect) + kSkeinLinkFromOffsetY)
        var finalTo    = NSPoint(x: NSMidX(parentRect),
                                 y: NSMidY(parentRect))
        let finalDelta = NSPoint(x: finalTo.x - finalFrom.x, y: finalTo.y - finalFrom.y)
        let finalLength       = round(sqrt((finalDelta.x * finalDelta.x) + (finalDelta.y * finalDelta.y)))
        // Used for frameRotation, which is in the superview's coordinates whatever the layer's geometry.
        // (A new link's layer isn't geometryFlipped yet, so adjusting for that mirrored new links.)
        let finalAngleRadians = atan2(finalDelta.y, finalDelta.x)

        // Adjust final points from centre of line to edge of view (by moving a short distance along the normal).
        if finalLength > 0.001 {
            let normal = NSPoint(x: -finalDelta.y * kSkeinLinkViewHalfThickness / finalLength,
                                 y:  finalDelta.x * kSkeinLinkViewHalfThickness / finalLength)
            finalFrom.x -= normal.x
            finalFrom.y -= normal.y
            finalTo.x -= normal.x
            finalTo.y -= normal.y
        }

        finalFrom = NSPoint(x: round(finalFrom.x), y: round(finalFrom.y))
        finalTo   = NSPoint(x: round(finalTo.x), y: round(finalTo.y))

        // Performance optimisation. If it's not moving, don't animate it.
        if (abs(startFrom.x - finalFrom.x) < kPositionEpsilon) &&
           (abs(startFrom.y - finalFrom.y) < kPositionEpsilon) &&
           (abs(startTo.x - finalTo.x) < kPositionEpsilon) &&
           (abs(startTo.y - finalTo.y) < kPositionEpsilon) {
            animate = false
        }

        if animate {
            // Create a key frame animation
            let theGroupAnimation     = CAAnimationGroup()
            let thePositionAnimation  = CAKeyframeAnimation(keyPath: "position")
            let theSizeAnimation      = CAKeyframeAnimation(keyPath: "bounds.size.width")
            let theAngleAnimation     = CAKeyframeAnimation(keyPath: "transform.rotation")

            var positionValues: [NSValue]  = []
            var sizeValues: [NSNumber]     = []
            var angleValues: [NSNumber]    = []
            positionValues.reserveCapacity(kAnimationSteps + 1)
            sizeValues.reserveCapacity(kAnimationSteps + 1)
            angleValues.reserveCapacity(kAnimationSteps + 1)

            var length: CGFloat = 0.0
            var angleRadians: CGFloat = 0.0
            for step in 0...kAnimationSteps {
                var t = CGFloat(step) / CGFloat(kAnimationSteps)
                t = easeOutCubic(t)
                var from = NSPoint(x: lerp(t, startFrom.x, finalFrom.x),
                                   y: lerp(t, startFrom.y, finalFrom.y))
                var to = NSPoint(x: lerp(t, startTo.x, finalTo.x),
                                 y: lerp(t, startTo.y, finalTo.y))

                if !(linkView.layer?.isGeometryFlipped ?? false) {
                    from.y = (linkView.superview?.frame.size.height ?? 0) - from.y
                    to.y   = (linkView.superview?.frame.size.height ?? 0) - to.y
                }

                let delta = NSPoint(x: to.x - from.x, y: to.y - from.y)

                length       = sqrt((delta.x * delta.x) + (delta.y * delta.y))
                angleRadians = atan2(delta.y, delta.x)

                let frame = NSRect(x: from.x, y: from.y, width: length, height: round(kSkeinLinkViewThickness))
                positionValues.append(NSValue(point: frame.origin))
                sizeValues.append(NSNumber(value: Double(length)))
                angleValues.append(NSNumber(value: Double(angleRadians)))
            }

            thePositionAnimation.values = positionValues
            thePositionAnimation.calculationMode = .linear

            theSizeAnimation.values = sizeValues
            theSizeAnimation.calculationMode = .linear

            theAngleAnimation.values = angleValues
            theAngleAnimation.calculationMode = .linear

            theGroupAnimation.animations = [thePositionAnimation, theSizeAnimation, theAngleAnimation]

            linkView.layer?.add(theGroupAnimation,
                                forKey: "groupLinkAnimation")
        }

        if fadeIn {
            let delay = kSkeinAnimationDuration
            fadeInView(linkView,
                       delay: delay,
                       duration: kSkeinAnimationItemFadeIn,
                       animate: animate,
                       fromCurrent: false)
        }

        linkView.frame = NSRect(x: finalFrom.x, y: finalFrom.y, width: round(finalLength), height: round(kSkeinLinkViewThickness))

        // Radians to degrees
        let rot = finalAngleRadians * (180.0 / CGFloat.pi)

        // Set final frame rotation (but for performance - only if it's changed)
        if abs(linkView.frameRotation - rot) > kAngleEpsilon {
            linkView.frameRotation = rot
        }
    }

    private final func fadeOutView(_ view: NSView,
                                   delay: TimeInterval,
                                   duration: TimeInterval,
                                   animate: Bool,
                                   fromCurrent: Bool) {
        if animate {
            var startOpacity: CGFloat = 1.0
            if fromCurrent {
                // Get current opacity, even when in mid animation
                if let actualLayer = view.layer?.presentation() {
                    startOpacity = CGFloat(actualLayer.opacity)
                } else {
                    startOpacity = CGFloat(view.layer?.opacity ?? 0)
                }
            }

            if startOpacity > 0.0 {
                let fadeAnim = CABasicAnimation(keyPath: "opacity")
                fadeAnim.fromValue  = NSNumber(value: Float(startOpacity))
                fadeAnim.toValue    = NSNumber(value: Float(0.0))
                fadeAnim.duration   = duration
                let localLayerTime = view.layer?.convertTime(currentTimeInterval, from: nil) ?? 0
                fadeAnim.beginTime  = localLayerTime + delay
                if delay > 0.0 {
                    fadeAnim.fillMode = .backwards
                }
                view.layer?.add(fadeAnim, forKey: "opacity")
            }
        }

        view.layer?.opacity = 0.0
    }

    private final func fadeInView(_ view: NSView,
                                  delay: TimeInterval,
                                  duration: TimeInterval,
                                  animate: Bool,
                                  fromCurrent: Bool) {
        if animate {
            var startOpacity: CGFloat = 0.0

            // Get current opacity
            if fromCurrent {
                // Get current opacity, even when in mid animation
                if let actualLayer = view.layer?.presentation() {
                    startOpacity = CGFloat(actualLayer.opacity)
                } else {
                    startOpacity = CGFloat(view.layer?.opacity ?? 0)
                }
            }

            if startOpacity < 1.0 {
                let fadeAnim = CABasicAnimation(keyPath: "opacity")
                fadeAnim.fromValue  = NSNumber(value: Double(startOpacity))
                fadeAnim.toValue    = NSNumber(value: 1.0)
                fadeAnim.duration   = duration
                let localLayerTime = view.layer?.convertTime(currentTimeInterval, from: nil) ?? 0
                fadeAnim.beginTime  = localLayerTime + delay
                if delay > 0.0 {
                    fadeAnim.fillMode = .backwards
                }
                view.layer?.add(fadeAnim, forKey: "opacity")
            }
        }

        view.layer?.opacity = 1.0
    }

    private final func updateArrowView(_ arrowView: IFSkeinArrowView?,
                                       layout: IFSkeinLayout,
                                       fromLayoutItem layoutItem: IFSkeinLayoutItem,
                                       animate: Bool) {
        guard let arrowView else {
            return
        }

        if layoutItem.onSelectedLine == false {
            fadeOutView(arrowView,
                        delay: 0.0,
                        duration: kSkeinAnimationArrowFadeOut,
                        animate: animate,
                        fromCurrent: true)
            return
        }

        let rect = layoutItem.lozengeRect

        // Get desired final point
        let finalFrom  = NSPoint(x: NSMaxX(rect), y: NSMidY(rect))
        let finalTo    = NSPoint(x: layout.reportPosition.x, y: finalFrom.y)

        let newFrame = NSRect(x: finalFrom.x,
                              y: floor(finalFrom.y - kSkeinArrowViewHeight * 0.5),
                              width: finalTo.x - finalFrom.x,
                              height: kSkeinArrowViewHeight)

        // Does arrow move?
        if !NSEqualRects(arrowView.frame, newFrame) {
            // Arrow moves - fade out at old position and fade back in at new position
            fadeOutView(arrowView,
                        delay: 0.0,
                        duration: kSkeinAnimationArrowFadeOut,
                        animate: animate,
                        fromCurrent: true)

            fadeInView(arrowView,
                       delay: kSkeinAnimationDuration - kSkeinAnimationReportFadeIn,
                       duration: kSkeinAnimationReportFadeIn,
                       animate: animate,
                       fromCurrent: false)

            arrowView.frame = newFrame
            arrowView.needsDisplay = true
            arrowView.display()
        }
        else {
            // Arrow does not move - just fade in if needed
            fadeInView(arrowView,
                       delay: kSkeinAnimationDuration - kSkeinAnimationReportFadeIn,
                       duration: kSkeinAnimationReportFadeIn,
                       animate: animate,
                       fromCurrent: true)
        }
    }

    @objc(updateChildrenWithLayout:animate:)
    func update(with layout: IFSkeinLayout,
                animate: Bool) {
        // Preliminaries: Gather layout items into an array
        let layoutItems = allItemsFromLayout(layout)

        // Preliminaries: Store current time (used for animation)
        currentTimeInterval = CACurrentMediaTime()

        // 1. Remove views no longer in the layout
        for key in Array(itemViews.keys) {
            if layoutItems[key] == nil {
                itemViews[key]?.removeFromSuperview()       // Remove item  from skein view
                linkViews[key]?.removeFromSuperview()       // Remove link  from skein view
                arrowViews[key]?.removeFromSuperview()      // Remove arrow from skein view
                itemViews.removeValue(forKey: key)          // Remove item  from dictionary
                linkViews.removeValue(forKey: key)          // Remove link  from dictionary
                arrowViews.removeValue(forKey: key)         // Remove arrow from dictionary
            }
        }

        // 2. Add any new views found in the layout
        for (key, layoutItem) in layoutItems {
            if itemViews[key] == nil {
                // Create new view
                createItemView(fromLayoutItem: layoutItem, key: key)
                createLinkView(fromLayoutItem: layoutItem, key: key)
                createArrowView(fromLayoutItem: layoutItem, key: key, layout: layout)
            }
            else {
                // Update view based on layout item
                updateItemView(itemViews[key]!, fromLayoutItem: layoutItem, animate: animate, fadeIn: false)
                updateLinkView(linkViews[key], fromLayoutItem: layoutItem, animate: animate, fadeIn: false)
                updateArrowView(arrowViews[key], layout: layout, fromLayoutItem: layoutItem, animate: animate)
            }
        }

        precondition(layoutItems.count == itemViews.count, "updateChildrenWithLayout failed to match items")
        precondition(layoutItems.count == (linkViews.count + 1) ||
                     ((layoutItems.count == 0) && (linkViews.count == 0)), "updateChildrenWithLayout failed to match links")

        // 3. Position report subView
        if layout.selectedItem == nil {
            fadeOutView(reportView,
                        delay: 0.0,
                        duration: kSkeinAnimationReportFadeOut,
                        animate: animate,
                        fromCurrent: true)
            reportView.frame = NSZeroRect
        }
        else {
            let reportFrame = NSRect(x: layout.reportPosition.x,
                                     y: layout.reportPosition.y,
                                     width: reportView.frame.size.width,
                                     height: reportView.frame.size.height)

            let reportChangedPosition = !NSEqualPoints(reportView.frame.origin, reportFrame.origin)
            if reportChangedPosition {
                fadeInView(reportView,
                           delay: kSkeinAnimationDuration - kSkeinAnimationReportFadeIn,
                           duration: kSkeinAnimationReportFadeIn,
                           animate: animate,
                           fromCurrent: false)
            }
            reportView.frame = reportFrame
        }

        // 4. Sort subviews z-order so that all the links appear below all the items
        skeinView?.sortSubviews(compareViewOrder,
                                context: nil)
    }

    func updateReportDetails() {
        reportView.rootTree = skeinView?.layoutTree.rootLayoutItem
        reportView.updateReportDetails()
    }

    var reportDetails: [NSNumber] {
        return reportView.reportDetails as! [NSNumber]
    }

    @objc(layoutItemForItem:)
    func layoutItem(for item: IFSkeinItem) -> IFSkeinLayoutItem? {
        let itemView = itemViews[item.uniqueId]
        return itemView?.layoutItem
    }

    @objc(itemViewForItem:)
    func itemView(for item: IFSkeinItem) -> IFSkeinItemView? {
        return itemViews[item.uniqueId]
    }

    @objc(rectForItem:)
    func rect(for item: IFSkeinItem) -> NSRect {
        let itemView = itemViews[item.uniqueId]
        var result = NSZeroRect
        if let itemView {
            result = itemView.frame

            if let layoutItem = itemView.layoutItem, layoutItem.onSelectedLine {
                var reportRect = reportView.rect(for: layoutItem)
                reportRect = NSRect(x: reportRect.origin.x + reportView.frame.origin.x,
                                    y: reportRect.origin.y + reportView.frame.origin.y,
                                    width: reportRect.size.width,
                                    height: reportRect.size.height)
                result = NSUnionRect(reportRect, result)
            }
        }
        return result
    }

    func setItemBlessed(_ item: IFSkeinItem, bless: Bool) {
        skeinView?.setItemBlessed(item, bless: bless)
    }

    func fontSizePreferenceChanged() {
        // Adjust attributes of the items to the new text size
        IFSkeinItemView.adjustAttributesToFontSize()
        IFSkeinReportView.adjustAttributesToFontSize()

        reportView.forceResizeDueToFontSizeChange = true
    }
}

/// Orders the subviews so that all links (IFSkeinLinkView) appear below all items (IFSkeinItemView)
private func compareViewOrder(_ viewA: NSView,
                              _ viewB: NSView,
                              _ context: UnsafeMutableRawPointer?) -> ComparisonResult {
    var kindA = 0
    kindA    += viewA is IFSkeinReportView ? 4 : 0
    kindA    += viewA is IFSkeinItemView   ? 2 : 0
    kindA    += viewA is IFSkeinArrowView  ? 1 : 0
    var kindB = 0
    kindB    += viewB is IFSkeinReportView ? 4 : 0
    kindB    += viewB is IFSkeinItemView   ? 2 : 0
    kindB    += viewB is IFSkeinArrowView  ? 1 : 0

    if kindA > kindB {
        return .orderedDescending
    }
    if kindA < kindB {
        return .orderedAscending
    }

    return .orderedSame
}
