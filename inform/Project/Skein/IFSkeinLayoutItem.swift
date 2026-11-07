//
//  IFSkeinLayoutItem.swift
//  Inform
//
//  Created by Toby Nelson in 2015
//

import Cocoa

@objc @implementation extension IFSkeinLayoutItem {
    var item: IFSkeinItem
    var commandWidth: CGFloat
    var subtreeWidth: CGFloat
    weak var parent: IFSkeinLayoutItem?
    var level: Int32
    var onSelectedLine: Bool = false
    var recentlyPlayed: Bool = false

    // The layout moves each item many times, so moveRight(by:recursively:) reads and writes these directly, as the
    // Objective-C read its instance variables. Through the properties, each access is an Objective-C message.
    private final var _boundingRect: NSRect = .zero
    private final var _children: [IFSkeinLayoutItem]?

    var boundingRect: NSRect {
        get {
            return _boundingRect
        }
        set {
            _boundingRect = newValue
        }
    }

    var children: [IFSkeinLayoutItem]? {
        get {
            return _children
        }
        set {
            _children = newValue
        }
    }

    /// The children, for Swift. Swift reaches children through Objective-C, which converts the array to an NSArray
    /// and back each time.
    final var childItems: [IFSkeinLayoutItem]? {
        get {
            return _children
        }
        set {
            _children = newValue
        }
    }

    // MARK: - Initialisation

    init(item newItem: IFSkeinItem,
         subtreeWidth newSubtreeWidth: CGFloat,
         level newLevel: Int32) {
        item = newItem
        subtreeWidth = newSubtreeWidth
        level = newLevel
        commandWidth = 0
        super.init()
        commandWidth = IFSkeinItemView.commandSize(self).width
    }

    // MARK: - Getting properties

    var visibleWidth: CGFloat {
        return 20.0 + self.commandWidth
    }

    // MARK: - Setting properties

    func moveRight(by deltaX: CGFloat,
                   recursively: Bool) {
        // Update bounding rect
        var newBounds = _boundingRect
        newBounds.origin.x = floor(newBounds.origin.x + deltaX)
        _boundingRect = newBounds

        // Move children by the same amount
        if recursively {
            for item2 in _children ?? [] {
                item2.moveRight(by: deltaX, recursively: true)
            }
        }
    }

    var lozengeRect: NSRect {
        var itemRect = self.boundingRect

        // Adjust bounding rectangle inwards to give the lozenge rectangle
        itemRect.origin.x += kSkeinItemImageLeftBorder
        itemRect.origin.y += itemRect.size.height - kSkeinItemImageHeight + kSkeinItemImageTopBorder
        itemRect.size.width  -= kSkeinItemImageLeftBorder + kSkeinItemImageRightBorder + kSkeinItemFrameWidthExtension
        itemRect.size.height -= kSkeinItemImageTopBorder + kSkeinItemImageBottomBorder
        return itemRect
    }

    var localSpaceLozengeRect: NSRect {
        let rect = self.lozengeRect
        // lozengeRect is in the IFSkeinView coordinate space, which is measured from the top-left (isFlipped=YES).
        // We convert the lozengeRect to our local (IFSkeinItemView) space, which is measured from the bottom-left (isFlipped=NO).
        return NSMakeRect(rect.origin.x - boundingRect.origin.x,
                          boundingRect.size.height - (rect.origin.y - boundingRect.origin.y) - rect.size.height,
                          rect.size.width,
                          rect.size.height)
    }

    var textRect: NSRect {
        var itemRect = self.lozengeRect

        let width = self.commandWidth

        // Adjust the lozenge width to just include the text area
        itemRect.origin.x += 15.0
        itemRect.size.width = width

        return itemRect
    }

    var centreX: CGFloat {
        return NSMidX(self.lozengeRect)
    }

    var selectedLineChild: IFSkeinLayoutItem? {
        for child in self.children ?? [] {
            if child.onSelectedLine {
                return child
            }
        }
        return nil
    }

    @objc(leafSelectedLineItem)
    var leafSelectedLine: IFSkeinLayoutItem? {
        // Find leaf node
        var leafItem: IFSkeinLayoutItem = self
        while leafItem.onSelectedLine {
            guard let childItem = leafItem.selectedLineChild else {
                return leafItem
            }
            leafItem = childItem
        }
        return nil
    }

    /// Calculate a hash based on the current state. We only redraw when the stateHash changes.
    var drawStateHash: UInt {
        let command: String = item.command
        var hash = UInt(bitPattern: (command as NSString).hash)
        hash ^= recentlyPlayed      ? 1 : 0
        hash ^= onSelectedLine      ? 2 : 0
        hash ^= item.hasBadge       ? 4 : 0
        hash ^= item.isTestSubItem  ? 8 : 0
        hash ^= UInt(10 * IFSkeinView.fontSize) << 4

        return hash
    }
}
