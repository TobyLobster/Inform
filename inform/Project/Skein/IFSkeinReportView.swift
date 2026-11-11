//
//  IFSkeinReportView.swift
//  Inform
//
//  Created by Toby Nelson in 2015
//

import AppKit

// The text's attributes. Made when first used, as the Objective-C's +initialize made them when the class was first
// used, at the size adjustAttributesToFontSize gives them.
@MainActor private var commandAttr: [NSAttributedString.Key: Any] = sizedToFont(
    [ .font: NSFont.boldSystemFont(ofSize: kSkeinDefaultReportFontSize) ])
@MainActor private var normalAttr: [NSAttributedString.Key: Any] = sizedToFont(
    [ .font: NSFont.systemFont(ofSize: kSkeinDefaultReportFontSize) ])
@MainActor private var insertAttr: [NSAttributedString.Key: Any] = sizedToFont(
    [ .font: NSFont.systemFont(ofSize: kSkeinDefaultReportFontSize),
      .backgroundColor: NSColor(calibratedRed: 0.0, green: 0.75, blue: 0.0, alpha: 0.45) ])
@MainActor private var deleteAttr: [NSAttributedString.Key: Any] = sizedToFont(
    [ .font: NSFont.systemFont(ofSize: kSkeinDefaultReportFontSize),
      .backgroundColor: NSColor(calibratedRed: 1.0, green: 0.0, blue: 0.1, alpha: 0.45),
      .strikethroughStyle: NSUnderlineStyle.single.rawValue,
      .strikethroughColor: NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.0, alpha: 1.0) ])

/// The attributes with their font at the report's size, times the app's font size multiplier
@MainActor private func sizedToFont(_ attributes: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
    let fontSize = kSkeinDefaultReportFontSize * IFPreferences.shared.appFontSizeMultiplier
    return IFUtility.adjustAttributesFontSize(attributes, size: fontSize)
}

@objc @implementation extension IFSkeinReportView {
    private final var itemViews: [IFSkeinReportItemView] = []
    private final var treeHash: UInt = 0
    private final var viewTrackingArea: NSTrackingArea?

    var reportDetails = NSMutableArray()
    var rootTree: IFSkeinLayoutItem?
    weak var delegate: (any IFSkeinReportBlessDelegate)?
    var forceResizeDueToFontSizeChange = true

    class func adjustAttributesToFontSize() {
        commandAttr = sizedToFont(commandAttr)
        normalAttr  = sizedToFont(normalAttr)
        insertAttr  = sizedToFont(insertAttr)
        deleteAttr  = sizedToFont(deleteAttr)
    }

    public override init(frame: NSRect) {
        super.init(frame: frame)

        wantsLayer = true
    }

    /// Swift requires this, as `init(frame:)` is overridden. The Objective-C didn't override `initWithCoder:`, so
    /// this doesn't set the view up either.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private final func reportForItem(_ item: IFSkeinItem) -> NSAttributedString {
        let diffResult = item.differences
        // The differ has always compared the two by now, so neither is nil
        let ideal = (diffResult.ideal ?? "") as NSString
        let actual = (diffResult.actual ?? "") as NSString

        let output: NSMutableAttributedString
        if diffResult.differences.count == 0 {
            output = NSMutableAttributedString(string: ideal as String, attributes: normalAttr)
        }
        else {
            output = NSMutableAttributedString(string: "", attributes: normalAttr)
            for case let edit as IFDiffEdit in diffResult.differences {
                switch edit.formOfEdit {
                case .DELETE_EDIT:
                    let substring = ideal.substring(with: edit.fragment)
                    output.append(NSAttributedString(string: substring,
                                                     attributes: deleteAttr))
                case .PRESERVE_EDIT:
                    let substring = ideal.substring(with: edit.fragment)
                    output.append(NSAttributedString(string: substring,
                                                     attributes: normalAttr))
                case .PRESERVE_ACTUAL_EDIT:
                    let substring = actual.substring(with: edit.fragment)
                    output.append(NSAttributedString(string: substring,
                                                     attributes: normalAttr))
                case .INSERT_EDIT:
                    let substring = actual.substring(with: edit.fragment)
                    output.append(NSAttributedString(string: substring,
                                                     attributes: insertAttr))
                @unknown default:
                    break
                }
            }
        }

        let result = NSMutableAttributedString()

        if let parent = item.parent {
            let prompt = IFSkeinItem.prompt(for: parent.actual)
            if prompt != ">" {
                let promptAttr = NSMutableAttributedString(string: String(format: "%@", prompt),
                                                           attributes: normalAttr)
                result.append(promptAttr)
            }
            let command = NSMutableAttributedString(string: String(format: "%@\n", item.command),
                                                    attributes: commandAttr)
            result.append(command)
        }

        result.append(output)

        return result
    }

    private final func treeHashFromLeaf(_ leaf: IFSkeinItem?) -> UInt {
        var item = leaf
        var result: UInt = 0
        var count: UInt = 0
        while let current = item {
            result ^= current.reportStateHash &+ (count << 7)
            item = current.parent
            count += 1
        }
        result ^= count
        return result
    }

    func updateReportDetails() {
        // Find leaf node of the selected line
        let leafItem = rootTree?.leafSelectedLine

        let newTreeHash = treeHashFromLeaf(leafItem?.item)

        if forceResizeDueToFontSizeChange || ((treeHash == 0) || (newTreeHash != treeHash)) {
            // Remove all details
            reportDetails.removeAllObjects()

            // Create and position new subviews
            var layoutItem = leafItem
            var totalHeight: CGFloat = 0.0
            var itemViewsIndex = 0
            let maxLevel = Int(layoutItem?.level ?? 0)

            // Create any subviews required
            while itemViews.count <= maxLevel {
                let reportItemView = IFSkeinReportItemView()
                itemViews.append(reportItemView)
            }

            // Remove subviews that are not needed
            for i in maxLevel..<itemViews.count {
                itemViews[i].removeFromSuperview()
            }

            while let item = layoutItem, item.onSelectedLine {
                let report = reportForItem(item.item)

                let reportItemView = itemViews[maxLevel - itemViewsIndex]
                reportItemView.uniqueId = item.item.uniqueId

                if reportItemView.superview == nil {
                    addSubview(reportItemView)
                }
                reportItemView.blessButton.target = self
                reportItemView.blessButton.action = #selector(blessButtonPressed(_:))
                reportItemView.blessButton.tag = Int(bitPattern: item.item.uniqueId)
                reportItemView.blessButton.blessState = item.item.hasDifferences

                // Set the top border height for the item
                if itemViewsIndex == maxLevel {
                    reportItemView.topBorderHeight = kSkeinReportInsideTopBorder
                } else {
                    reportItemView.topBorderHeight = kDottedSeparatorGapBelowLine
                }

                // Set the text
                reportItemView.setAttributedString(report,
                                                   forceChange: forceResizeDueToFontSizeChange)

                // Resize based on size of text. Includes borders and ensures a minimum height for each item.
                var viewHeight = reportItemView.textHeight

                // Work out height between items
                var fullStrideHeight = reportItemView.topBorderHeight + viewHeight
                if itemViewsIndex == 0 {
                    fullStrideHeight += kSkeinReportInsideBottomBorder
                } else {
                    fullStrideHeight += kDottedSeparatorGapAboveLine + kDottedSeparatorLineThickness
                }

                // Height between items has a minimum value
                fullStrideHeight = max(kSkeinMinLevelHeight, fullStrideHeight)

                // Resize the view height based on our calculated stride height
                viewHeight           = fullStrideHeight - kDottedSeparatorLineThickness
                reportItemView.frame = NSRect(x: 0, y: totalHeight, width: reportItemView.frame.size.width, height: viewHeight)

                // Move to next item
                totalHeight += fullStrideHeight

                // Adjust height of the last item
                if itemViewsIndex == maxLevel {
                    fullStrideHeight -= kSkeinReportInsideTopBorder
                    fullStrideHeight += kDottedSeparatorGapBelowLine
                }

                // Record the heights
                reportDetails.insert(NSNumber(value: Double(fullStrideHeight)), at: 0)

                // Move on to next entry
                layoutItem = item.parent
                itemViewsIndex += 1
            }
            // Don't need a separator after the last item, so take off it's height
            totalHeight = max(0.0, totalHeight)

            // remove any extra views at the end
            while itemViews.count > itemViewsIndex {
                itemViews.last?.removeFromSuperview()
                itemViews.removeLast()
            }

            setFrameSize(NSSize(width: kSkeinReportWidth, height: totalHeight))
            needsDisplay = true

            treeHash = newTreeHash
            forceResizeDueToFontSizeChange = false
        }
    }

    // MARK: - Drawing

    public override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed: 243.0 / 255.0,
                green: 216.0 / 255.0,
                blue: 101.0 / 255.0,
                alpha: 1.0).set()
        // Views don't clip to their bounds by default (macOS 14 SDK on), and dirtyRect can extend beyond them
        NSIntersectionRect(dirtyRect, bounds).fill(using: .copy)

        NSColor(calibratedRed: 0.0,
                green: 0.0,
                blue: 0.0,
                alpha: 0.25).set()
        let path = NSBezierPath()
        path.lineWidth = kDottedSeparatorLineThickness
        let dashArray: [CGFloat] = [ 8.0, 6.0 ]
        path.setLineDash(dashArray, count: 2, phase: 0.0)

        var totalHeight: CGFloat = 0
        for index in stride(from: reportDetails.count - 1, to: 0, by: -1) {
            let height = CGFloat((reportDetails[index] as! NSNumber).doubleValue)
            totalHeight += height

            let y = floor(totalHeight) - (kDottedSeparatorLineThickness * 0.5)
            path.move(to: NSPoint(x: 0.0, y: y))
            path.line(to: NSPoint(x: frame.size.width, y: y))
        }
        path.stroke()
    }

    @objc(rectForItem:)
    func rect(for layoutItem: IFSkeinLayoutItem) -> NSRect {
        for itemView in itemViews {
            if itemView.uniqueId == layoutItem.item.uniqueId {
                return NSRect(x: itemView.frame.origin.x,
                              y: frame.size.height - itemView.frame.origin.y - itemView.frame.size.height,
                              width: itemView.frame.size.width,
                              height: itemView.frame.size.height)
            }
        }
        return NSZeroRect
    }

    public override func cursorUpdate(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    public override func mouseDown(with theEvent: NSEvent) {
        // Do nothing. Stops the parent view from capturing the mouse events
    }

    public override func mouseUp(with theEvent: NSEvent) {
        // Do nothing. Stops the parent view from capturing the mouse events
    }

    public override func mouseDragged(with theEvent: NSEvent) {
        // Do nothing. Stops the parent view from capturing the mouse events
    }

    public override func updateTrackingAreas() {
        // Track the current view rect, so we can change it's mouse cursor
        if let viewTrackingArea {
            removeTrackingArea(viewTrackingArea)
            self.viewTrackingArea = nil
        }

        var currentMousePos = window?.mouseLocationOutsideOfEventStream ?? NSZeroPoint
        currentMousePos = convert(currentMousePos, from: nil)
        let visibleRect = self.visibleRect

        if !NSIsEmptyRect(visibleRect) {
            // Do we start inside the rectangle?
            var options: NSTrackingArea.Options = []
            if NSPointInRect(currentMousePos, visibleRect) {
                options = .assumeInside
            }

            let viewTrackingArea = NSTrackingArea(rect: visibleRect,
                                                  options: [.cursorUpdate,
                                                            .activeInKeyWindow, options],
                                                  owner: self,
                                                  userInfo: nil)
            self.viewTrackingArea = viewTrackingArea
            addTrackingArea(viewTrackingArea)
        }

        super.updateTrackingAreas()
    }

    @objc private final func blessButtonPressed(_ sender: Any?) {
        if let button = sender as? IFSkeinBlessButton {
            button.toggleBlessState()
            let uniqueId = UInt(bitPattern: button.tag)

            var layoutItem = rootTree?.leafSelectedLine
            while let item = layoutItem {
                if item.item.uniqueId == uniqueId {
                    if delegate?.responds(to: #selector(IFSkeinReportBlessDelegate.setItemBlessed(_:bless:))) ?? false {
                        delegate?.setItemBlessed(item.item, bless: !button.blessState)
                    }
                    break
                }
                layoutItem = item.parent
            }
        }
    }
}
