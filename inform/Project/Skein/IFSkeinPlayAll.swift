//
//  IFSkeinPlayAll.swift
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//  Translated from Objective-C in November 2026. The interface is still IFSkeinPlayAll.h.
//

import Foundation

@objc @implementation extension IFSkeinPlayAll {
    /// Stack of skein items, the next last
    private final var skeinNodeStack: [IFSkeinItem] = []

    init(rootItem: IFSkeinItem) {
        super.init()

        fillNode(rootItem)
    }

    private final func fillNode(_ item: IFSkeinItem) {
        if item.children.count > 0 {
            for child in item.children.reversed() {
                fillNode(child)
            }
            return
        }

        // Add to the stack
        var item: IFSkeinItem? = item
        while let testSubItem = item, testSubItem.isTestSubItem {
            item = testSubItem.parent
        }
        if let item {
            skeinNodeStack.append(item)
        }
    }

    var nextItem: IFSkeinItem? {
        return skeinNodeStack.last
    }

    func removeNextItem() {
        _ = skeinNodeStack.popLast()
    }
}
