//
//  IFExtensionsPage.swift
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

import Cocoa
import WebKit

@objc @implementation extension IFExtensionsPage {
    // The documentation view
    /// The web view that displays the documentation
    private final var wView: WKWebView!
    private final let helper: IFWebViewHelper

    // Page cells
    /// The 'Home' cell
    private final let homeCell: IFPageBarCell
    /// The 'Public Library' cell
    private final let publicLibraryCell: IFPageBarCell
    /// Maps URL paths to cells
    private final var tabDictionary: [String: IFPageBarCell] = [:]

    private final var loadingFailureWebPage = false
    /// The page that failed to load, while the failure page is shown in its place
    private final var failedURL: NSURL?

    /// The loads that aren't recorded in the history as they start, each by its navigation: a census's reload, the
    /// reload as the page is switched to, a page from the history, and the failure page. (A load that another
    /// overtakes before it starts is left here, never matched.)
    private final var unrecordedNavigations: [WKNavigation] = []

    // MARK: - Initialisation

    @objc(initWithProjectController:withPane:)
    init(projectController controller: IFProjectController,
         with pane: IFProjectPane) {
        homeCell = IFPageBarCell(imageCell: NSImage(named: NSImage.homeTemplateName))
        publicLibraryCell = IFPageBarCell(textCell: IFUtility.localizedString("ExtensionPublicLibrary",
                                                                              default: "Public Library"))
        helper = IFWebViewHelper(projectController: controller,
                                 with: controller.oppositePane(pane))

        super.init(nibName: "Documentation",
                   projectController: controller)

        homeCell.target = self
        homeCell.action = #selector(showHome(_:))

        publicLibraryCell.target = self
        publicLibraryCell.action = #selector(showPublicLibrary(_:))

        // Static dictionary mapping tab names to cells
        let project = parent?.document as? IFProject
        let extensions: String
        if project?.useNewExtensions ?? false {
            extensions = "inform://Extensions/Reserved/Documentation/Extensions.html"
        }
        else {
            extensions = "inform://Extensions/Extensions.html"
        }
        tabDictionary = [extensions: homeCell,
                         IFUtility.publicLibraryURL()!.absoluteString: publicLibraryCell]

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(fontSizePreferenceChanged(_:)),
                                               name: .IFPreferencesAppFontSizeDidChange,
                                               object: IFPreferences.shared)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(censusCompleted(_:)),
                                               name: .IFCensusFinished,
                                               object: nil)

        wView = helper.createWebView(withFrame: view.bounds)

        // Set delegates
        wView.navigationDelegate = self

        // Add to view hierarchy
        view.addSubview(wView)

        let url = URL(string: extensions)!
        let urlRequest = URLRequest(url: url)
        wView.load(urlRequest)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Details about this view

    public override var title: String {
        return IFUtility.localizedString("Extensions Page Title",
                                         default: "Extensions")
    }

    // MARK: - Updating extensions

    @objc private final func censusCompleted(_ not: Notification) {
        // Force the documentation view to reload (the 'installed extensions' page may be updated)
        leaveOutOfHistory(reloadPage())
    }

    /// Reloads the page. If the failure page is showing, tries the page that failed again instead,
    /// as it may exist now (the project's catalogue of extensions is made when it is translated).
    private final func reloadPage() -> WKNavigation? {
        if let failedURL {
            let urlRequest = URLRequest(url: failedURL as URL)
            return wView.load(urlRequest)
        }
        else {
            return wView.reload()
        }
    }

    // MARK: - Documentation

    @objc(openURL:)
    func open(_ url: URL) {
        load(url)
    }

    @discardableResult
    private final func load(_ url: URL) -> WKNavigation? {
        switchToPage()

        failedURL = nil

        let urlRequest = URLRequest(url: url)
        return wView.load(urlRequest)
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

    private final func loadFailurePage(_ urlString: String?) {
        if loadingFailureWebPage {
            return
        }
        var url: URL

        // Default to public library error
        let project = parent?.document as? IFProject
        url = URL(string: "inform:/pl404.html")!

        if urlString == nil || urlString != IFUtility.publicLibraryURL()?.absoluteString {
            if project?.useNewExtensions ?? false {
                // If the file doesn't exist, then show a default error page
                url = URL(string: "inform:/NoExtensions.html")!
            }
        }

        failedURL = urlString.flatMap { NSURL(string: $0) }

        let urlRequest = URLRequest(url: url)

        leaveOutOfHistory(wView.load(urlRequest))
        loadingFailureWebPage = true
    }

    // MARK: - History

    /// Leaves a load out of the history
    private final func leaveOutOfHistory(_ navigation: WKNavigation?) {
        if let navigation {
            unrecordedNavigations.append(navigation)
        }
    }

    public override func didSwitchToPage() {
        let url = (failedURL as URL?) ?? wView.url

        NSLog("HISTORY: Extensions Page: (didSwitchToPage) URL %@", url?.absoluteString ?? "(null)")
        recordInHistory { self.openHistoricalURL(url) }
        leaveOutOfHistory(reloadPage())
    }

    // MARK: - Preferences

    @objc private final func fontSizePreferenceChanged(_ not: Notification) {
        helper.fontSizePreferenceChanged(wView)
    }

    // MARK: - Page bar cells

    public override var toolbarCells: [IFPageBarCell] {
        return [publicLibraryCell, homeCell]
    }

    private final func urlString(for cell: IFPageBarCell) -> String? {
        for (key, value) in tabDictionary where value === cell {
            return key
        }
        return nil
    }

    func showHome(_ sender: Any?) {
        open(URL(string: urlString(for: homeCell)!)!)
    }

    func showPublicLibrary(_ sender: Any?) {
        open(URL(string: urlString(for: publicLibraryCell)!)!)
    }

    func extensionUpdated(_ javascriptId: String?) {
        let js = String(format: "window.downloadSucceeded(%@);", javascriptId ?? "(null)")
        wView.evaluateJavaScript(js, completionHandler: nil)
    }

    public override func willClose() {
        NotificationCenter.default.removeObserver(self)
    }
}

// The page's header conforms to WKNavigationDelegate, whose methods an @implementation doesn't take
extension IFExtensionsPage {
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

        // Add to history, except for the loads left out of it, and links that do something rather than show a page,
        // as downloads from the Public Library do
        if let index = unrecordedNavigations.firstIndex(where: { $0 === navigation }) {
            unrecordedNavigations.remove(at: index)
        } else if pageIsVisible && IFWebViewHelper.showsPage(webView.url) {
            NSLog("HISTORY: Extensions Page: (didStartProvisionalLoadForFrame) URL %@",
                  webView.url?.absoluteString ?? "(null)")
            let url = webView.url
            recordInHistory { self.switchToPage() }
            recordInHistory { self.openHistoricalURL(url) }
        }
    }

    @objc(webView:didFailProvisionalNavigation:withError:)
    public func webView(_ webView: WKWebView,
                        didFailProvisionalNavigation navigation: WKNavigation!,
                        withError error: Error) {
        let error = error as NSError
        var urlString: String? = nil

        if let url = error.userInfo[NSURLErrorFailingURLErrorKey] as? URL {
            urlString = url.absoluteString
        }
        else {
            urlString = error.userInfo[NSURLErrorFailingURLStringErrorKey] as? String
        }
        NSLog("didFail for webview %@, wView:%@, url:%@", webView, wView, urlString ?? "(null)")

        if error.code == NSURLErrorCancelled {
            loadingFailureWebPage = false
            return
        }
        if error.domain != INFORM_ERROR_DOMAIN {
            NSLog("IFExtensionsPage: failed to load URL %@ (provisional) with error: %@",
                  urlString ?? "(null)", error.localizedDescription)
            loadFailurePage(urlString)
        }
    }

    @objc(webView:didFailNavigation:withError:)
    public func webView(_ webView: WKWebView,
                        didFail navigation: WKNavigation!,
                        withError error: Error) {
        let error = error as NSError
        var urlString: String? = nil

        if let url = error.userInfo[NSURLErrorFailingURLErrorKey] as? URL {
            urlString = url.absoluteString
        }
        else {
            urlString = error.userInfo[NSURLErrorFailingURLStringErrorKey] as? String
        }

        if error.code == NSURLErrorCancelled {
            loadingFailureWebPage = false
            return
        }
        NSLog("IFExtensionsPage: failed to load URL %@ with error: %@",
              urlString ?? "(null)", error.localizedDescription)
        loadFailurePage(urlString)
    }

    @objc(webView:didFinishNavigation:)
    public func webView(_ webView: WKWebView,
                        didFinish navigation: WKNavigation!) {
        if !loadingFailureWebPage {
            // A page other than the failure page has loaded
            failedURL = nil
        }
        loadingFailureWebPage = false
    }
}
