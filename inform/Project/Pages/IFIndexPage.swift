//
//  IFIndexPage.swift
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

import Cocoa
import WebKit

@objc @implementation extension IFIndexPage {
    /// `true` if the index tab should be active
    private final var indexAvailable = false

    /// IFPageBarCells used to select index pages
    private final var indexCells: [IFPageBarCell]?
    /// Dictionary of tab ids and their string names
    private final let tabDictionary: [String: Int32]

    private final var webView: WKWebView!
    private final let helper: IFWebViewHelper
    /// The loads that aren't recorded in the history as they start, each by its navigation: a page from the history,
    /// and the reload as the index is updated. (A load that another overtakes before it starts is left here, never
    /// matched.)
    private final var unrecordedNavigations: [WKNavigation] = []

    // MARK: - Initialisation

    @objc(initWithProjectController:withPane:)
    init(projectController controller: IFProjectController,
         with pane: IFProjectPane) {
        // Static dictionary mapping tab names to enum values
        tabDictionary = ["actions.html":    IFIndexTabType.actions.rawValue,
                         "phrasebook.html": IFIndexTabType.phrasebook.rawValue,
                         "scenes.html":     IFIndexTabType.scenes.rawValue,
                         "contents.html":   IFIndexTabType.contents.rawValue,
                         "kinds.html":      IFIndexTabType.kinds.rawValue,
                         "rules.html":      IFIndexTabType.rules.rawValue,
                         "world.html":      IFIndexTabType.world.rawValue,
                         "welcome.html":    IFIndexTabType.welcome.rawValue]

        helper = IFWebViewHelper(projectController: controller, with: pane)

        super.init(nibName: "Index",
                   projectController: controller)

        // Create the webview
        webView = helper.createWebView(withFrame: view.bounds)

        // Set delegates
        webView.navigationDelegate = self

        // Add the webview as a subview of the index page
        view.addSubview(webView)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(fontSizePreferenceChanged(_:)),
                                               name: .IFPreferencesAppFontSizeDidChange,
                                               object: IFPreferences.shared)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Notifications

    @objc private final func fontSizePreferenceChanged(_ not: Notification) {
        helper.fontSizePreferenceChanged(webView)
    }

    // MARK: - Details about this view

    public override var title: String {
        return IFUtility.localizedString("Index Page Title",
                                         default: "Index")
    }

    // MARK: - Page validation

    public override var shouldShowPage: Bool {
        return indexAvailable
    }

    // MARK: - Helper functions

    private final func indexOfItem(withTabId tabIdentifier: Int32) -> Int {
        let identifier = NSNumber(value: tabIdentifier)
        var index = 0
        for cell in indexCells ?? [] {
            if let cellIdentifier = cell.representedObject as? NSObject, cellIdentifier.isEqual(identifier) {
                return index
            }
            index += 1
        }

        return NSNotFound
    }

    func canSelectIndexTab(_ tabIdentifier: Int32) -> Bool {
        if indexOfItem(withTabId: tabIdentifier) == NSNotFound {
            return false
        }
        return true
    }

    private final func tabIdOfItem(withFilename theFile: String) -> Int {
        let lowerFile = theFile.lowercased()

        guard let integer = tabDictionary[lowerFile] else {
            return NSNotFound
        }
        return Int(integer)
    }

    private final func filenameOfItem(withTabId tabId: Int32) -> String? {
        for (key, value) in tabDictionary where value == tabId {
            return key
        }
        return nil
    }

    @discardableResult
    private final func requestRelativePath(_ relativePath: String) -> WKNavigation? {
        let indexDirURL = (parent?.document as? IFProject)?.indexDirectoryURL

        var isDir: ObjCBool = false

        // Check that it exists and is a directory
        guard let indexDirURL else {
            return nil
        }
        if !FileManager.default.fileExists(atPath: indexDirURL.path,
                                           isDirectory: &isDir) {
            return nil
        }
        if !isDir.boolValue {
            return nil
        }

        let fullFileURL = indexDirURL.appendingPathComponent(relativePath)
        let aRequest = URLRequest(url: fullFileURL)
        return webView.load(aRequest)
    }

    func openHistoricalURL(_ url: URL?) {
        guard let url else {
            return
        }

        // Because we are opening this URL as part of replaying history, we don't add it to the history itself.
        let aRequest = URLRequest(url: url)
        leaveOutOfHistory(webView.load(aRequest))
    }

    func `switch`(toTab tabIdentifier: Int32) {
        showTab(tabIdentifier)
    }

    /// Shows a tab's page, if the index has it
    @discardableResult
    private final func showTab(_ tabIdentifier: Int32) -> WKNavigation? {
        let tabIndex = indexOfItem(withTabId: tabIdentifier)
        if tabIndex != NSNotFound {
            // Set a URL request going
            if let filename = filenameOfItem(withTabId: tabIdentifier) {
                return requestRelativePath(filename)
            }
        }
        return nil
    }

    @objc(switchToTabWithObject:)
    private final func switchToTab(withObject sender: Any?) {
        // Get the cell that was clicked on
        var cell: IFPageBarCell? = nil

        if let sender = sender as? IFPageBarCell {
            cell = sender
        }
        else if let sender = sender as? IFPageBarView {
            cell = sender.lastTrackedCell as? IFPageBarCell
        }

        let tabIdentifier = (cell?.representedObject as? NSNumber)?.int32Value ?? 0
        self.switch(toTab: tabIdentifier)
    }

    func updateIndexView() {
        indexAvailable = false

        let project = parent?.document as? IFProject

        // Refresh the copies of the index files in memory
        project?.reloadIndexDirectory()

        // The index path
        let indexPath = String(format: "%@/Index", project?.fileURL?.path ?? "(null)")
        var isDir: ObjCBool = false

        indexCells = []

        // Check that it exists and is a directory
        if !FileManager.default.fileExists(atPath: indexPath,
                                           isDirectory: &isDir) {
            return
        }
        if !isDir.boolValue {
            return
        }

        // Iterate through the files
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: indexPath)) as NSArray?
        let files = contents?.sortedArray(using: #selector(NSString.caseInsensitiveCompare(_:))) as? [String] ?? []
        let cells = NSMutableArray()
        for theFile in files {
            let fileExtension = (theFile as NSString).pathExtension.lowercased()

            if fileExtension == "htm" || fileExtension == "html" {
                // Create the tab
                let newTab = IFPageBarCell()
                newTab.radioGroup = 128

                // Choose an ID for this tab based on the filename
                let tabId = tabIdOfItem(withFilename: theFile)
                if tabId == Int(IFIndexTabType.welcome.rawValue) {
                    newTab.image = NSImage(named: NSImage.homeTemplateName)
                }
                else {
                    let label = IFUtility.localizedString(theFile,
                                                          default: (theFile as NSString).deletingPathExtension,
                                                          table: "CompilerOutput")
                    newTab.stringValue = label
                }

                if tabId != NSNotFound {
                    newTab.representedObject = NSNumber(value: tabId)
                    newTab.target = self
                    newTab.action = #selector(switchToTab(withObject:))

                    // Add the tab
                    cells.insert(newTab, at: 0)
                    indexAvailable = true
                }
            }
        }

        // Sort tabs by ID
        let sort = NSSortDescriptor(key: "representedObject", ascending: false)
        cells.sort(using: [sort])
        indexCells = cells as? [IFPageBarCell]

        // Once they're in order, as the page bar copies them
        toolbarCellsHaveUpdated()

        // The same page, with the index updated, so it isn't recorded again. With nothing shown, as when there was
        // no index before the project's first translation, the welcome page, which the pane asked for as it was set up.
        if webView.url == nil {
            leaveOutOfHistory(showTab(IFIndexTabType.welcome.rawValue))
        } else {
            leaveOutOfHistory(webView.reload())
        }
    }

    // MARK: - History

    /// Leaves a load out of the history
    private final func leaveOutOfHistory(_ navigation: WKNavigation?) {
        if let navigation {
            unrecordedNavigations.append(navigation)
        }
    }

    /// The history, as the page: what's sent to it is recorded, and sent to the page when the history is replayed.
    /// The history is a proxy, which records any message it's sent, so it isn't cast, as a cast asks it its class.
    private final var historicalPage: IFIndexPage? {
        guard let history else {
            return nil
        }
        return unsafeBitCast(history as AnyObject, to: IFIndexPage.self)
    }

    // MARK: - Switching cells

    public override func didSwitchToPage() {
        let url = webView.url
        NSLog("HISTORY: Index Page: (didSwitchToPage) requestURL %@", url?.absoluteString ?? "(null)")
        historicalPage?.openHistoricalURL(url)

        // Highlight the indexCell to something appropriate for the new URL
        highlightAppropriateIndexCell(for: url)
        super.didSwitchToPage()
    }

    private final func highlightAppropriateIndexCell(for url: URL?) {
        let lowerURL = url?.absoluteString.lowercased()

        // Highlight the pane tab to something appropriate for the new URL
        for cell in indexCells ?? [] {
            cell.state = .off
        }

        // With no URL, nothing is shown, so no cell is highlighted
        guard let lowerURL else {
            return
        }

        for (tabName, tabIdentifier) in tabDictionary {
            // is the string we are looking for
            if lowerURL.range(of: tabName) != nil {
                // Highlight the appropriate tab, if it has a cell
                let tabIndex = indexOfItem(withTabId: tabIdentifier)

                if tabIndex != NSNotFound {
                    indexCells?[tabIndex].state = .on
                }
            }
        }
    }

    // MARK: - The page bar

    public override var toolbarCells: [IFPageBarCell] {
        return indexCells ?? []
    }
}

// The page's header conforms to WKNavigationDelegate, whose methods an @implementation doesn't take
extension IFIndexPage {
    // MARK: - WKNavigationDelegate methods

    @objc(webView:decidePolicyForNavigationAction:decisionHandler:)
    public func webView(_ webView: WKWebView,
                        decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        // Allow everything for now
        decisionHandler(.allow)
    }

    @objc(webView:didStartProvisionalNavigation:)
    public func webView(_ theWebView: WKWebView,
                        didStartProvisionalNavigation navigation: WKNavigation!) {
        let url = theWebView.url
        NSLog("HISTORY: Index Page: (didStartProvisionalLoadForFrame) requestURL %@", url?.absoluteString ?? "(null)")
        if let index = unrecordedNavigations.firstIndex(where: { $0 === navigation }) {
            unrecordedNavigations.remove(at: index)
        } else if pageIsVisible {
            historicalPage?.switchToPage()
            historicalPage?.openHistoricalURL(url)
        }

        // Highlight the indexCell to something appropriate for the new URL
        highlightAppropriateIndexCell(for: url)
    }
}
