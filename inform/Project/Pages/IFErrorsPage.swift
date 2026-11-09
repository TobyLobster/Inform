//
//  IFErrorsPage.swift
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

import Cocoa
import WebKit

@objc @implementation extension IFErrorsPage {
    /// The compiler controller object, which the nib sets
    private final var _compilerController: IFCompilerController?
    private final var inhibitAddToHistory = 0

    /// Cells used to select the pages in the compiler controller
    private final var pageCells: [IFPageBarCell]?

    var compilerController: IFCompilerController {
        return _compilerController!
    }

    // MARK: - Initialisation

    @objc(initWithProjectController:withPane:)
    init(projectController controller: IFProjectController,
         with thePane: IFProjectPane) {
        super.init(nibName: "Errors",
                   projectController: controller)
    }

    // MARK: - Details about this view

    public override var title: String {
        return IFUtility.localizedString("Errors Page Title",
                                         default: "Errors")
    }

    @objc(switchToPageWithTabId:)
    func switchToPage(with tabId: IFCompilerTabId) {
        switchToPage()
        compilerController.switchToView(with: tabId)
    }

    @objc private final func switchToErrorPage(_ sender: Any?) {
        // Get the cell that was clicked on
        var cell: IFPageBarCell? = nil

        if let sender = sender as? IFPageBarCell {
            cell = sender
        }
        else if let sender = sender as? IFPageBarView {
            cell = sender.lastTrackedCell as? IFPageBarCell
        }

        // Order the compiler controller to switch to the specified page
        let tabId = IFCompilerTabId(rawValue: UInt32(bitPattern: (cell?.representedObject as? NSNumber)?.int32Value ?? 0))!
        compilerController.switchToView(with: tabId)
    }

    // MARK: - Setting some interface building values

    /// The nib sets the compiler controller through this
    @objc(setCompilerController:)
    private final func setCompilerController(_ newController: IFCompilerController) {
        _compilerController = newController
    }

    private final func open(_ url: URL) {
        switchToPage()

        compilerController.currentWebView?.load(URLRequest(url: url))
    }

    func openHistoricalURL(_ url: URL?) {
        guard let url else {
            return
        }

        // Because we are opening this URL as part of replaying history, we don't add it to the history itself.
        inhibitAddToHistory += 1
        open(url)
    }

    // MARK: - History

    /// The history, as the page: what's sent to it is recorded, and sent to the page when the history is replayed.
    /// The history is a proxy, which records any message it's sent, so it isn't cast, as a cast asks it its class.
    private final var historicalPage: IFErrorsPage? {
        guard let history else {
            return nil
        }
        return unsafeBitCast(history as AnyObject, to: IFErrorsPage.self)
    }

    public override func didSwitchToPage() {
        NSLog("HISTORY: Errors Page: (didSwitchToPage) tab %d", Int32(bitPattern: compilerController.selectedTabId.rawValue))
        historicalPage?.switchToPage(with: compilerController.selectedTabId)
        super.didSwitchToPage()
    }

    // MARK: - The page bar

    public override var toolbarCells: [IFPageBarCell] {
        return pageCells ?? []
    }
}

// The page's header conforms to IFCompilerControllerDelegate, whose methods an @implementation doesn't take
extension IFErrorsPage {
    // MARK: - IFCompilerController delegate methods

    @objc(errorMessageHighlighted:atLine:inFile:)
    public func errorMessageHighlighted(_ sender: IFCompilerController,
                                        atLine line: Int32,
                                        inFile file: String) {
        if !(parent?.selectSourceFile(file) ?? false) {
            // Maybe implement me: show an error alert?
            return
        }

        parent?.move(toSourceFileLine: Int(line))
        parent?.removeHighlights(of: .error)
        parent?.highlightSourceFileLine(Int(line),
                                        inFile: file,
                                        style: .error)
    }

    @objc(viewSetHasUpdated:)
    public func viewSetHasUpdated(_ sender: IFCompilerController) {
        // While the nib is loaded, the compiler controller may say so before the page has it
        if sender !== _compilerController {
            return
        }

        // Clear out the current set of cells
        let cells = NSMutableArray()
        pageCells = []

        let tabs = compilerController.viewTabs

        // Show no pages if there are none
        if tabs.isEmpty {
            toolbarCellsHaveUpdated()
            return
        }

        // Rebuild the set of cells for this compiler
        for tab in tabs.reversed() {
            // Create the cell for this name
            let newCell = IFPageBarCell(textCell: tab.name)

            newCell.target = self
            newCell.action = #selector(switchToErrorPage(_:))
            newCell.representedObject = NSNumber(value: Int32(bitPattern: tab.tabId.rawValue))
            newCell.radioGroup = 128

            if compilerController.selectedTabId == tab.tabId {
                newCell.state = .on
            }

            cells.add(newCell)
        }

        // Sort pageCells based on ids
        let sort = NSSortDescriptor(key: "representedObject", ascending: false)
        cells.sort(using: [sort])
        pageCells = cells as? [IFPageBarCell]

        // Update the cells being displayed
        toolbarCellsHaveUpdated()
    }

    @objc(compiler:switchedToView:)
    public func compiler(_ sender: IFCompilerController,
                         switchedToView viewIndex: Int32) {
        if sender !== _compilerController {
            return
        }

        // Remember this in the history
        let tabId = IFCompilerTabId(rawValue: UInt32(bitPattern: compilerController.tabId(withTabIndex: viewIndex)))!
        NSLog("HISTORY: Errors Page: (switchedToView) tab %d", Int32(bitPattern: tabId.rawValue))
        historicalPage?.switchToPage(with: tabId)

        // Turn the newly selected cell on
        guard let pageCells, !pageCells.isEmpty else {
            return
        }

        for cell in pageCells {
            let cellTabId = UInt32(bitPattern: (cell.representedObject as? NSNumber)?.int32Value ?? 0)
            if compilerController.selectedTabId.rawValue == cellTabId {
                cell.state = .on
            }
            else {
                cell.state = .off
            }
        }
    }

    // MARK: - WKNavigationDelegate

    @objc(webView:decidePolicyForNavigationAction:decisionHandler:)
    public func webView(_ webView: WKWebView,
                        decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        // Allow everything for now
        decisionHandler(.allow)
    }

    @objc(webView:didStartProvisionalNavigation:)
    public func webView(_ webView: WKWebView,
                        didStartProvisionalNavigation navigation: WKNavigation!) {
        // Add to history...
        // ... except when reloading after the census
        // ... except on initial load
        // ... except when clicking the forward or back arrows

        // Each time we get here will remove one of these exceptions if present.

        if pageIsVisible {
            if inhibitAddToHistory <= 0 {
                NSLog("HISTORY: Compiler Controller Page: (didStartProvisionalNavigation) URL %@",
                      webView.url?.absoluteString ?? "(null)")
                historicalPage?.switchToPage()
                historicalPage?.openHistoricalURL(webView.url)
            }
        }

        // reduce the number of reasons to inhibit adding to history
        if inhibitAddToHistory > 0 {
            inhibitAddToHistory -= 1
        }
        else {
            inhibitAddToHistory = 0
        }
    }
}
