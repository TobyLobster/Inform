//
//  IFDocumentationPage.swift
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

import Cocoa
import WebKit

@objc @implementation extension IFDocumentationPage {
    // The documentation view
    /// The web view that displays the documentation
    private final var wView: WKWebView!
    private final let helper: IFWebViewHelper

    // Page cells
    /// The 'table of contents' cell
    private final let contentsCell: IFPageBarCell
    /// The 'Examples' cell
    private final let examplesCell: IFPageBarCell
    /// The 'General Index' cell
    private final let generalIndexCell: IFPageBarCell
    /// Maps URL paths to cells
    private final let tabDictionary: [String: IFPageBarCell]

    /// The loads that aren't recorded in the history as they start, each by its navigation: the first page, a census's
    /// reload, the reload as the page is switched to, and a page from the history. (A load that another overtakes
    /// before it starts is left here, never matched.)
    private final var unrecordedNavigations: [WKNavigation] = []

    // MARK: - Initialisation

    @objc(initWithProjectController:withPane:)
    init(projectController controller: IFProjectController,
         with pane: IFProjectPane) {
        helper = IFWebViewHelper(projectController: controller,
                                 with: controller.oppositePane(pane))

        // UI tabs
        contentsCell = IFPageBarCell(imageCell: NSImage(named: NSImage.homeTemplateName))
        examplesCell = IFPageBarCell(textCell: IFUtility.localizedString("Example Docs",
                                                                         default: "Examples"))
        generalIndexCell = IFPageBarCell(textCell: IFUtility.localizedString("General Index Docs",
                                                                             default: "General Index"))

        // Static dictionary mapping tab names to cells. (Until 2024 the examples' index was
        // examples_alphabetical.html, which the app still has, linking to the old documentation.)
        tabDictionary = ["inform:/index.html": contentsCell,
                         "inform:/alphabetical_index.html": examplesCell,
                         "inform:/general_index.html": generalIndexCell]

        super.init(nibName: "Documentation",
                   projectController: controller)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(fontSizePreferenceChanged(_:)),
                                               name: .IFPreferencesAppFontSizeDidChange,
                                               object: IFPreferences.shared)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(censusCompleted(_:)),
                                               name: .IFCensusFinished,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(censusCompleted(_:)),
                                               name: .IFCensusFinishedButDontUpdateExtensionsWebPage,
                                               object: nil)

        wView = helper.createWebView(withFrame: view.bounds)

        // Set delegates
        wView.navigationDelegate = self

        // Add to view hierarchy
        view.addSubview(wView)

        // Go to initial page
        let url = URL(string: "inform:/index.html")!
        let urlRequest = URLRequest(url: url)
        leaveOutOfHistory(wView.load(urlRequest))

        contentsCell.target = self
        contentsCell.action = #selector(showToc(_:))

        examplesCell.target = self
        examplesCell.action = #selector(showExamples(_:))

        generalIndexCell.target = self
        generalIndexCell.action = #selector(showGeneralIndex(_:))
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Details about this view

    public override var title: String {
        return IFUtility.localizedString("Documentation Page Title",
                                         default: "Documentation")
    }

    // MARK: - Updating extensions

    @objc private final func censusCompleted(_ not: Notification) {
        // Force the documentation view to reload (the 'installed extensions' page may be updated)
        leaveOutOfHistory(wView.reload())
    }

    // MARK: - Preferences

    @objc private final func fontSizePreferenceChanged(_ not: Notification) {
        helper.fontSizePreferenceChanged(wView)
    }

    // MARK: - Documentation

    @objc(openURL:)
    func open(_ url: URL) {
        load(url)
    }

    @discardableResult
    private final func load(_ url: URL) -> WKNavigation? {
        switchToPage()

        return wView.load(URLRequest(url: url))
    }

    func openHistoricalURL(_ url: URL?) {
        guard let url else {
            return
        }

        // Because we are opening this URL as part of replaying history, we don't add it to the history itself.
        leaveOutOfHistory(load(url))
    }

    private final func highlightTab(forURL urlString: String?) {
        for (key, cell) in tabDictionary {
            if let urlString, key.caseInsensitiveCompare(urlString) == .orderedSame {
                cell.state = .on
            }
            else {
                cell.state = .off
            }
        }
    }

    // MARK: - History

    /// Leaves a load out of the history
    private final func leaveOutOfHistory(_ navigation: WKNavigation?) {
        if let navigation {
            unrecordedNavigations.append(navigation)
        }
    }

    public override func didSwitchToPage() {
        let url = wView.url

        NSLog("HISTORY: Documentation Page: (didSwitchToPage) URL %@", url?.absoluteString ?? "(null)")
        recordInHistory { self.openHistoricalURL(url) }
        leaveOutOfHistory(wView.reload())
    }

    // MARK: - Page bar cells

    public override var toolbarCells: [IFPageBarCell] {
        return [generalIndexCell, examplesCell, contentsCell]
    }

    private final func urlString(for cell: IFPageBarCell) -> String? {
        for (key, value) in tabDictionary where value === cell {
            return key
        }
        return nil
    }

    func showToc(_ sender: Any?) {
        open(URL(string: urlString(for: contentsCell)!)!)
    }

    @objc private final func showExamples(_ sender: Any?) {
        open(URL(string: urlString(for: examplesCell)!)!)
    }

    @objc private final func showGeneralIndex(_ sender: Any?) {
        open(URL(string: urlString(for: generalIndexCell)!)!)
    }

    public override func willClose() {
        NotificationCenter.default.removeObserver(self)
    }
}

// The page's header conforms to WKNavigationDelegate, whose methods an @implementation doesn't take
extension IFDocumentationPage {
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
        // Highlight appropriate tab
        highlightTab(forURL: webView.url?.absoluteString)

        // Add to history, except for the loads left out of it
        if let index = unrecordedNavigations.firstIndex(where: { $0 === navigation }) {
            unrecordedNavigations.remove(at: index)
        } else if pageIsVisible {
            NSLog("HISTORY: Documentation Page: (didStartProvisionalNavigation) URL %@",
                  webView.url?.absoluteString ?? "(null)")
            let url = webView.url
            recordInHistory { self.switchToPage() }
            recordInHistory { self.openHistoricalURL(url) }
        }
    }
}
