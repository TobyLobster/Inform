//
//  IFHeaderPage.swift
//  Inform
//
//  Created by Andrew Hunter on 02/01/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

import Cocoa

@objc @implementation extension IFHeaderPage {
    private final var _pageView: NSView?
    /// The scroll view
    @IBOutlet private final var scrollView: NSScrollView?

    private final var _headerView: IFHeaderView?
    @IBOutlet private final var depthButton: NSPopUpButton?

    /// The highlight range to use
    private final var highlightLines = NSRange(location: 0, length: 0)
    /// The currently selected header node
    private final var selectedNode: IFHeaderNode?
    /// The preferences whose colours the page shows
    private final var preferences: IFPreferences

    private final var _controller: IFHeaderController?

    weak var delegate: IFHeaderPageDelegate?

    // MARK: - Initialisation

    override convenience init() {
        self.init(preferences: IFPreferences.shared)
    }

    init(preferences thePreferences: IFPreferences) {
        preferences = thePreferences

        super.init()

        // Load the nib file
        _ = Bundle.customLoadNib("Headers",
                                 owner: self)

        _headerView?.delegate = self

        // Notification
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(preferencesChanged(_:)),
                                               name: .IFPreferencesEditingDidChange,
                                               object: preferences)

        setColours()

        // Set the view depth
        if let depthButton, depthButton.numberOfItems > 0 {
            depthButton.selectItem(at: depthButton.numberOfItems - 1)
        }
        updateDepthPopup(self)
    }

    deinit {
        if let controller = _controller, let headerView = _headerView {
            controller.removeHeaderView(headerView)
        }
    }

    private final func setColours() {
        scrollView?.backgroundColor = preferences.extensionPaper.colour
        scrollView?.needsDisplay = true
        _headerView?.setColours(preferences.extensionPaper.colour)
        _headerView?.needsDisplay = true
    }

    @objc private func preferencesChanged(_ not: Notification) {
        setColours()
    }

    // MARK: - KVC stuff for the page view/header view

    /// The page's view, from its nib
    var pageView: NSView {
        get {
            return _pageView!
        }
        set {
            _pageView = newValue
        }
    }

    /// The header view, from the page's nib
    var headerView: IFHeaderView {
        get {
            return _headerView!
        }
        set {
            if let controller = _controller, let headerView = _headerView {
                controller.removeHeaderView(headerView)
            }

            _headerView = newValue

            if let controller = _controller {
                controller.addHeaderView(newValue)
            }
        }
    }

    // MARK: - Managing the controller

    var controller: IFHeaderController? {
        get {
            return _controller
        }
        set {
            if let controller = _controller {
                if let headerView = _headerView {
                    controller.removeHeaderView(headerView)
                }
                _controller = nil
            }

            if let newController = newValue {
                _controller = newController
                if let headerView = _headerView {
                    newController.addHeaderView(headerView)
                }
            }
        }
    }

    // MARK: - Controller delegate messages (relayed via the view)

    func refreshHeaders(_ control: IFHeaderController) {
        if highlightLines.location != NSNotFound {
            highlightNode(withLines: highlightLines)
        }

        delegate?.refreshHeaders?(control)
    }

    // MARK: - Choosing objects

    @objc(selectNode:)
    func select(_ node: IFHeaderNode?) {
        highlightLines.location = NSNotFound
        if node === selectedNode {
            return
        }

        selectedNode?.selectionStyle = .unselected

        selectedNode = node
        selectedNode?.selectionStyle = .selected
        _headerView?.needsDisplay = true
    }

    func highlightNode(withLines lines: NSRange) {
        var lineNode = _headerView?.rootHeaderNode.withLines(lines,
                                                             intelFile: _controller?.intelFile)
        if lineNode === _headerView?.rootHeaderNode {
            lineNode = nil
        }

        select(lineNode)
        highlightLines = lines
    }

    // MARK: - User actions

    @IBAction func updateDepthPopup(_ sender: Any?) {
        let depth = Int32(truncatingIfNeeded: 1 + (depthButton?.indexOfSelectedItem ?? 0))
        _headerView?.displayDepth = depth

        if highlightLines.location != NSNotFound {
            highlightNode(withLines: highlightLines)
        }
    }

    // MARK: - Header view delegate methods

    @objc(headerView:clickedOnNode:)
    func headerView(_ view: IFHeaderView,
                    clickedOn node: IFHeaderNode) {
        delegate?.headerPage?(self,
                              limitTo: node.header)
    }

    @objc(headerView:updateNode:withNewTitle:)
    func headerView(_ view: IFHeaderView,
                    update node: IFHeaderNode,
                    withNewTitle newTitle: String) {
        delegate?.headerView?(view,
                              update: node,
                              withNewTitle: newTitle)
    }
}
