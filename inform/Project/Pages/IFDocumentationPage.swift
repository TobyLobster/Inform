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

    private final var inhibitAddToHistory = 0

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

        // Static dictionary mapping tab names to cells
        tabDictionary = ["inform:/index.html": contentsCell,
                         "inform:/examples_alphabetical.html": examplesCell,
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
        inhibitAddToHistory += 1
        let url = URL(string: "inform:/index.html")!
        let urlRequest = URLRequest(url: url)
        wView.load(urlRequest)

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
        inhibitAddToHistory += 1
        // Force the documentation view to reload (the 'installed extensions' page may be updated)
        wView.reload(self)
    }

    // MARK: - Preferences

    @objc private final func fontSizePreferenceChanged(_ not: Notification) {
        helper.fontSizePreferenceChanged(wView)
    }

    // MARK: - Documentation

    @objc(openURL:)
    func open(_ url: URL) {
        switchToPage()

        wView.load(URLRequest(url: url))
    }

    func openHistoricalURL(_ url: URL?) {
        guard let url else {
            return
        }

        // Because we are opening this URL as part of replaying history, we don't add it to the history itself.
        inhibitAddToHistory += 1
        open(url)
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

    /// The history, as the page: what's sent to it is recorded, and sent to the page when the history is replayed.
    /// The history is a proxy, which records any message it's sent, so it isn't cast, as a cast sends it one.
    private final var historicalPage: IFDocumentationPage? {
        guard let history else {
            return nil
        }
        return unsafeBitCast(history as AnyObject, to: IFDocumentationPage.self)
    }

    public override func didSwitchToPage() {
        let url = wView.url

        NSLog("HISTORY: Documentation Page: (didSwitchToPage) URL %@", url?.absoluteString ?? "(null)")
        historicalPage?.openHistoricalURL(url)
        wView.reload(self)
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

        // Add to history...
        // ... except when reloading after the census
        // ... except on initial load
        // ... except when clicking the forward or back arrows

        // Each time we get here will remove one of these exceptions if present.

        if pageIsVisible {
            if inhibitAddToHistory <= 0 {
                NSLog("HISTORY: Documentation Page: (didStartProvisionalNavigation) URL %@",
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
