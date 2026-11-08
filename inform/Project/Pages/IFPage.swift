//
//  IFPage.swift
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

import Cocoa

@objc @implementation extension IFPage {
    /// The project controller that 'owns' this page, which the page doesn't keep
    private final weak var _parent: IFProjectController?
    /// The view to display for this page, which its nib sets
    private final var _view: NSView?

    weak var otherPane: IFProjectPane?
    weak var thisPane: IFProjectPane?

    /// Object used for recording any history events for this object
    weak var recorder: IFHistoryRecorder?

    /// Whether this page is currently displayed
    var pageIsVisible = false

    var parent: IFProjectController? {
        return _parent
    }

    var view: NSView {
        return _view!
    }

    // MARK: - Initialisation

    init(nibName nib: String, projectController controller: IFProjectController?) {
        super.init()

        // Load the nib file
        _ = Bundle.customLoadNib(nib, owner: self)

        // Set the parent
        _parent = controller
    }

    func finished() {
        _parent = nil
        otherPane = nil
    }

    // MARK: - Details about this view

    var title: String {
        return "Untitled"
    }

    var activeView: NSView {
        return view
    }

    /// The nib sets the view through this
    @objc(setView:)
    private final func setView(_ newView: NSView) {
        _view = newView
    }

    var identifier: String {
        return type(of: self).description()
    }

    // MARK: - Page validation

    var shouldShowPage: Bool {
        return true
    }

    // MARK: - Page actions

    func switchToPage() {
        switchToPage(withIdentifier: identifier,
                     fromPage: nil)
    }

    func switchToPage(withIdentifier identifier: String,
                      fromPage oldPageIdentifier: String?) {
        let userInfo: [String: String]
        if let oldPageIdentifier {
            userInfo = ["Identifier": identifier,
                        "OldPageIdentifier": oldPageIdentifier]
        }
        else {
            userInfo = ["Identifier": identifier]
        }
        // Post a notification that this page wants to be the frontmost
        NotificationCenter.default.post(name: .IFSwitchToPage,
                                        object: self,
                                        userInfo: userInfo)
    }

    // MARK: - Dealing with the page bar

    var toolbarCells: [IFPageBarCell] {
        return []
    }

    func toolbarCellsHaveUpdated() {
        NotificationCenter.default.post(name: .IFUpdatePageBarCells,
                                        object: self)
    }

    // MARK: - History

    var history: Any? {
        var event: IFHistoryEvent? = nil

        if let recorder {
            event = recorder.historyEvent
        }

        if let event {
            event.target = self
            return event.proxy
        }

        return nil
    }

    func didSwitchToPage() {
        // Do nothing
    }

    func didSwitchAwayFromPage() {
        // Called when this page is no longer active
    }

    func willClose() {
    }
}
