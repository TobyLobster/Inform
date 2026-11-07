//
//  IFHeaderController.swift
//  Inform
//
//  Created by Andrew Hunter on 19/12/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFHeaderController.h.
//

import Cocoa

@objc @implementation extension IFHeaderController {
    /// The root of the headers being managed by this object
    private final var _rootHeader: IFHeader?
    /// The most recent intel file object
    private final var _intelFile: IFIntelFile?

    /// The header views being managed by this controller
    private final var headerViews: [NSView & IFHeaderViewProtocol] = []

    var rootHeader: IFHeader? {
        return _rootHeader
    }

    var intelFile: IFIntelFile? {
        return _intelFile
    }

    // MARK: - Sending messages to the views

    private final func refreshHeaders() {
        // Send the refreshHeaders message to all of the views that support it
        for headerView in headerViews {
            headerView.refreshHeaders?(self)
        }
    }

    // MARK: - Managing the collection of headings being maintained by this object

    private final func setChildren(for root: IFHeader,
                                   symbol: IFIntelSymbol,
                                   recurse: Bool) {
        var child = symbol.child

        // If the symbol has no children then don't add it to the list
        if child == nil {
            root.children = []
            return
        }

        // Otherwise, build up the set of symbols from the children of this item
        var newChildren: [IFHeader] = []
        while let currentChild = child {
            // Build the new header
            let newChild = IFHeader(name: currentChild.name ?? "",
                                    parent: root,
                                    children: nil)
            newChild.symbol = currentChild

            // Add it to the array
            newChildren.append(newChild)

            // Recurse if necessary
            if recurse {
                setChildren(for: newChild,
                            symbol: currentChild,
                            recurse: true)
            }

            // Done with this item

            // Move onto the sibling for this header
            child = currentChild.sibling
        }

        // Set the children for this symbol
        root.children = newChildren
    }

    func update(fromIntelligence intel: IFIntelFile?) {
        // Change the intel file object
        _intelFile = intel
        guard let firstSymbol = intel?.firstSymbol else {
            return
        }

        // Firstly, build up a header structure from the intelligence object

        // "Story"
        let storyRoot = IFHeader(name: firstSymbol.name ?? "",
                                 parent: nil,
                                 children: nil)
        setChildren(for: storyRoot,
                    symbol: firstSymbol,
                    recurse: true)

        // "---- DOCUMENTATION ----"
        var documentationRootSymbol: IFIntelSymbol? = firstSymbol
        while let symbol = documentationRootSymbol {
            documentationRootSymbol = symbol.next
            if documentationRootSymbol?.level == 0 {
                break
            }
        }

        let newRoot: IFHeader
        if let documentationRootSymbol {
            storyRoot.headingName = IFUtility.localizedString("HeaderExtensionTitle")

            // Create documentation header
            let docRoot = IFHeader(name: IFUtility.localizedString("HeaderDocumentationTitle"),
                                   parent: nil,
                                   children: nil)
            docRoot.symbol = documentationRootSymbol
            setChildren(for: docRoot,
                        symbol: documentationRootSymbol,
                        recurse: true)

            newRoot = IFHeader(name: IFUtility.localizedString("HeaderPage"),
                               parent: nil,
                               children: [storyRoot, docRoot])
        } else {
            newRoot = IFHeader(name: IFUtility.localizedString("HeaderPage"),
                               parent: nil,
                               children: [storyRoot])
        }

        _rootHeader = newRoot

        // Cause a general update of the header list
        refreshHeaders()
    }

    // MARK: - Managing the views being controlled

    func addHeaderView(_ newHeaderView: NSView & IFHeaderViewProtocol) {
        if headerViews.contains(where: { $0 === newHeaderView }) {
            // Do nothing if this view has already been added to this controller
            return
        }

        // Add the object to the controller
        headerViews.append(newHeaderView)

        // Notify that it should update its list of headers from this controller
        newHeaderView.refreshHeaders?(self)
    }

    func removeHeaderView(_ oldHeaderView: NSView & IFHeaderViewProtocol) {
        // Remove the old header view from the list of headers
        headerViews.removeAll { $0 === oldHeaderView }
    }
}
