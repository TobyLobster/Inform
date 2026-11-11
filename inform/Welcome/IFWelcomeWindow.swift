//
//  IFWelcomeWindow.swift
//  Inform
//
//  Created by Andrew Hunter on 05/10/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//  Rewritten by Toby Nelson, 2014.
//  Translated from Objective-C in November 2026. The interface is still IFWelcomeWindow.h.
//

import Cocoa
import WebKit
import UniformTypeIdentifiers

private let maxItemsInRecentMenu = 8

/// Shared welcome window
@MainActor private var sharedWindow: IFWelcomeWindow?

@objc @implementation extension IFWelcomeWindow {
    /// Progress indicator that shows when a background process is running
    @IBOutlet private final var backgroundProgress: NSProgressIndicator?

    /// News web view
    private final var newsWebView: WKWebView?
    @IBOutlet private final var newsWebParent: NSView?
    private final var newsWebConfiguration: WKWebViewConfiguration?

    /// Recent document Table View
    @IBOutlet private final var recentDocumentsTableView: NSTableView?
    /// Create document Table View
    @IBOutlet private final var createDocumentsTableView: NSTableView?
    /// Sample document Table View
    @IBOutlet private final var sampleDocumentsTableView: NSTableView?
    /// Show a web page (for advice)
    @IBOutlet private final var webViewParent: NSView?
    /// Web View Helper for advice
    private final var helper: IFWebViewHelper?

    /// Show the middle section
    @IBOutlet private final var middleView: NSView?
    /// Top banner image, as a button
    @IBOutlet private final var imageButton: NSButton?

    /// Array of recent file info
    private final var recentInfoArray: [IFRecentFileCellInfo] = []
    /// Array of create file info
    private final var createInfoArray: [IFRecentFileCellInfo] = []
    /// Array of sample file info
    private final var sampleInfoArray: [IFRecentFileCellInfo] = []

    private final var adviceWebView: WKWebView?

    // MARK: - Initialisation

    @objc(sharedWelcomeWindow) class func shared() -> IFWelcomeWindow {
        if let sharedWindow {
            return sharedWindow
        }

        let welcome = IFWelcomeWindow(windowNibName: "Launcher")
        sharedWindow = welcome
        return welcome
    }

    @objc(hideWelcomeWindow) class func hide() {
        if sharedWindow != nil {
            IFWelcomeWindow.shared().window?.close()
        }
    }

    @objc(showWelcomeWindow) class func show() {
        let welcome = IFWelcomeWindow.shared()

        welcome.showWelcomeWindow()
    }

    private final func showWelcomeWindow() {
        refreshRecentItems()

        // Hide web view
        hideWebView()

        // Show window
        showWindow(self)
        window?.orderFront(self)

        if #available(macOS 11.0, *) {
            recentDocumentsTableView?.style = .plain
            createDocumentsTableView?.style = .plain
            sampleDocumentsTableView?.style = .plain
        }
        // By default the enclosing scrollview has a bezelled border, but we set
        // it to no border here after the tableview style has been set to plain.
        recentDocumentsTableView?.enclosingScrollView?.borderType = .noBorder
        createDocumentsTableView?.enclosingScrollView?.borderType = .noBorder
        sampleDocumentsTableView?.enclosingScrollView?.borderType = .noBorder


        // create news web view (if not already created)
        if newsWebConfiguration == nil {
            let configuration = WKWebViewConfiguration()
            newsWebConfiguration = configuration
            // Set the navigation delegate
            let appDelegate = NSApp.delegate as? IFAppDelegate
            configuration.setURLSchemeHandler(appDelegate?.newsManager?.newsSchemeHandler,
                                              forURLScheme: "inform")
            newsWebView = WKWebView(frame: newsWebParent?.bounds ?? .zero,
                                    configuration: configuration)
        }

        // Set the navigation delegate
        newsWebView?.navigationDelegate = self

        // Give the news web view a transparent background
        newsWebView?.setValue(false, forKey: "drawsBackground")

        // Add web view to parent
        if let newsWebView {
            newsWebParent?.addSubview(newsWebView)
        }

        // Refresh news if needed
        checkIfNewsRefreshIsNeeded()

        let helper = IFWebViewHelper(projectController: nil,
                                     with: nil)
        self.helper = helper
        let adviceWebView = helper.createWebView(withFrame: webViewParent?.bounds ?? .zero)
        self.adviceWebView = adviceWebView

        // Set delegates
        adviceWebView.navigationDelegate = self

        // Add to view hieracrchy
        webViewParent?.addSubview(adviceWebView)

    }

    func hideWebView() {
        webViewParent?.isHidden = true
        middleView?.isHidden = false
    }

    func showWebView() {
        webViewParent?.isHidden = false
        middleView?.isHidden = true
    }

    private final func checkIfNewsRefreshIsNeeded() {
        // Get the news from the news manager
        // when done, call the completion handler
        let appDelegate = NSApp.delegate as? IFAppDelegate

        appDelegate?.newsManager?.getNewsWithCompletionHandler { latestNews, response, error in
            // When finished, refreshNews on main thread
            self.performSelector(onMainThread: #selector(self.refreshNews(_:)), with: latestNews, waitUntilDone: false)
        }
    }

    private final func encodeForHTML(_ myStr: String) -> String {
        return myStr.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "<", with: "&lt;")
    }

    func newsPage(forNews latestNews: String?) -> String? {
        // Load template file
        var news: String
        do {
            news = try String(contentsOf: URL(string: "inform:/NewsTemplate.html")!,
                              encoding: .utf8)
        } catch {
            NSLog("%@", error as NSError)
            return nil
        }

        let outputFormatter = DateIntervalFormatter()
        outputFormatter.dateStyle = .medium
        outputFormatter.timeStyle = .none
        // The calendar's dates are read as midnight GMT, so they're shown in GMT, or west of it they'd be the day before
        outputFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        // parse data
        let format = ISO8601DateFormatter()
        format.formatOptions = .withFullDate

        let data = latestNews?.components(separatedBy: .newlines) ?? []
        var str = ""
        for line in data {
            // Parse line
            let lineParts = line.components(separatedBy: "\t")
            if lineParts.count >= 3 {
                let startDate = format.date(from: lineParts[0])
                var endDate = format.date(from: lineParts[1])
                let headline = encodeForHTML(lineParts[2])
                var link = ""

                if lineParts.count >= 4 {
                    link = encodeForHTML(lineParts[3])
                }

                if endDate == nil {
                    endDate = startDate
                }

                // Use the output formatter to generate the string. It raises if there's no date, so an
                // event whose start date can't be read is left out.
                if let startDate, let endDate {
                    let dateStr = outputFormatter.string(from: startDate, to: endDate)
                    //        <tr><td>17th June 2022</td><td><a href="http://www.inform7.com">News Item 1</a></td></tr>
                    str += "<tr><td>\(dateStr)</td><td><a href=\"\(link)\">\(headline)</a></td></tr>\n"
                }
            }
        }

        // replace <!-- CONTENT HERE -->
        news = news.replacingOccurrences(of: "<!-- CONTENT HERE -->", with: str)
        return news
    }

    @objc private func refreshNews(_ latestNews: String?) {
        guard let newsWebView else {
            // Early out if no web view to change
            return
        }

        if let news = newsPage(forNews: latestNews) {
            newsWebView.loadHTMLString(news,
                                       baseURL: URL(string: "inform:/"))
        }
    }

    private final func refreshRecentItems() {
        recentInfoArray = []

        var index = 0
        for url in NSDocumentController.shared.recentDocumentURLs {
            var icon: AnyObject?
            do {
                try (url as NSURL).getResourceValue(&icon, forKey: .effectiveIconKey)
            } catch {
                icon = NSWorkspace.shared.icon(forFile: url.path)
            }

            let info = IFRecentFileCellInfo(title: url.lastPathComponent,
                                            image: icon as? NSImage,
                                            url: url as NSURL,
                                            type: .File)
            recentInfoArray.append(info)
            index += 1

            if index >= maxItemsInRecentMenu {
                break
            }
        }

        // Item for "Open..."
        let icon = NSImage(named: NSImage.folderName)
        let info = IFRecentFileCellInfo(title: IFUtility.localizedString("Open..."),
                                        image: icon,
                                        url: nil,
                                        type: .Open)
        recentInfoArray.append(info)
        recentDocumentsTableView?.reloadData()
    }

    override init(window: NSWindow?) {
        super.init(window: window)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(startedMaintaining(_:)),
                                               name: .IFMaintenanceTasksStarted,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(finishedMaintaining(_:)),
                                               name: .IFCensusFinished,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(finishedMaintaining(_:)),
                                               name: .IFCensusFinishedButDontUpdateExtensionsWebPage,
                                               object: nil)

        // --- Items that refer to recent documents ---
        refreshRecentItems()

        // --- Items that create documents ---
        createInfoArray = []

        var icon = NSImage(named: "informfile")
        var info = IFRecentFileCellInfo(title: IFUtility.localizedString("Create Project..."),
                                        image: icon,
                                        url: nil,
                                        type: .CreateProject)
        createInfoArray.append(info)

        icon = NSImage(named: "i7xfile")
        info = IFRecentFileCellInfo(title: IFUtility.localizedString("Create Extension..."),
                                    image: icon,
                                    url: nil,
                                    type: .CreateExtension)
        createInfoArray.append(info)

        icon = NSImage(named: NSImage.folderName)
        info = IFRecentFileCellInfo(title: IFUtility.localizedString("Save Documentation as eBooks"),
                                    image: icon,
                                    url: nil,
                                    type: .SaveEPubs)
        createInfoArray.append(info)

        // --- Items that copy sample documents ---
        let sampleArray = ["Copy Onyx",                  "Onyx.inform",
                           "Copy Disenchantment Bay",    "Disenchantment Bay.inform"]

        sampleInfoArray = []
        icon = NSImage(named: "informfile")

        var pathStart = (Bundle.main.resourcePath ?? "") as NSString
        pathStart = pathStart.appendingPathComponent("App") as NSString
        pathStart = pathStart.appendingPathComponent("Samples") as NSString

        for index in stride(from: 0, to: sampleArray.count, by: 2) {
            let path = pathStart.appendingPathComponent(sampleArray[index + 1])
            info = IFRecentFileCellInfo(title: IFUtility.localizedString(sampleArray[index]),
                                        image: icon,
                                        url: NSURL(fileURLWithPath: path,
                                                   isDirectory: true),
                                        type: .CopySample)
            sampleInfoArray.append(info)
        }

        // Link to IFDB
        icon = NSWorkspace.shared.icon(for: .data)
        info = IFRecentFileCellInfo(title: IFUtility.localizedString("Link to IFDB"),
                                    image: icon,
                                    url: NSURL(string: "http://ifdb.tads.org/search?sortby=new&newSortBy.x=0&newSortBy.y=0&searchfor=tag%3A+i7+source+available"),
                                    type: .WebsiteLink)
        sampleInfoArray.append(info)
    }

    // Swift needs this, as NSWindowController's is required. The Objective-C inherited it, setting nothing up.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public override func windowDidLoad() {
        // Center the window on whichever screen it will appear on
        var winFrame = window?.frame ?? .zero

        let winScreen = window?.screen
        let screenFrame = winScreen?.frame ?? .zero

        winFrame.origin.x = (screenFrame.size.width - winFrame.size.width)/2 + screenFrame.origin.x
        winFrame.origin.y = (screenFrame.size.height - winFrame.size.height)/2 + screenFrame.origin.y

        window?.setFrame(winFrame,
                         display: false)

        // This window shouldn't 'float' above the other windows like most panels
        window?.level = .normal

        // Don't darken the image when clicked, show the alternate image
        (imageButton?.cell as? NSButtonCell)?.highlightsBy = .contentsCellMask
    }

    // MARK: - Actions

    @objc private func startedMaintaining(_ not: Notification) {
        backgroundProgress?.startAnimation(self)
    }

    @objc private func finishedMaintaining(_ not: Notification) {
        backgroundProgress?.stopAnimation(self)
    }

    @IBAction func clickImage(_ sender: Any?) {
        hideWebView()
    }

    @IBAction private func clickedWebLink(_ sender: Any?) {
        let linkArray = ["http://www.inform7.com",
                         "http://ifdb.tads.org/search?sortby=ratu&newSortBy.x=0&newSortBy.y=0&searchfor=system%3AInform+7",
                         "http://www.intfiction.org/forum",
                         "https://github.com/ganelson/inform",
                         "http://ifwiki.org/index.php/Main_Page",
                         "http://planet-if.com/",
                         "http://ifcomp.org"]
        let adviceLinkArray = ["inform:/AdviceNewToInform.html",
                               "inform:/AdviceUpgrading.html",
                               "inform:/AdviceKeyboardShortcuts.html",
                               "inform:/AdviceMaterialsFolder.html",
                               "inform:/AdviceCredits.html"]

        var index = (sender as? NSView)?.tag ?? 0
        if (index >= 0) && (index < linkArray.count) {
            if let url = URL(string: linkArray[index]) {
                NSWorkspace.shared.open(url)
            }
        } else {
            index -= linkArray.count
            // Is it a link for advice?
            if (index >= 0) && (index < adviceLinkArray.count) {
                if let url = URL(string: adviceLinkArray[index]) {
                    adviceWebView?.load(URLRequest(url: url))
                }
                showWebView()
            }
        }
    }

    // MARK: - NSTableViewDataSource methods

    @objc(numberOfRowsInTableView:)
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === recentDocumentsTableView {
            return recentInfoArray.count
        }
        if tableView === createDocumentsTableView {
            return createInfoArray.count
        }
        if tableView === sampleDocumentsTableView {
            return sampleInfoArray.count
        }

        return 0
    }

    @objc(tableView:objectValueForTableColumn:row:)
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if tableView === recentDocumentsTableView {
            return recentInfoArray[row]
        }
        if tableView === createDocumentsTableView {
            return createInfoArray[row]
        }
        if tableView === sampleDocumentsTableView {
            return sampleInfoArray[row]
        }
        return nil
    }

    @objc(tableView:willDisplayCell:forTableColumn:row:)
    func tableView(_ tableView: NSTableView,
                   willDisplayCell cell: Any,
                   for tableColumn: NSTableColumn?,
                   row: Int) {
        var info: IFRecentFileCellInfo? = nil
        if tableView === recentDocumentsTableView {
            info = recentInfoArray[row]
        } else if tableView === createDocumentsTableView {
            info = createInfoArray[row]
        } else if tableView === sampleDocumentsTableView {
            info = sampleInfoArray[row]
        }
        let cCell = cell as? IFRecentFileCell
        cCell?.title = info?.title ?? ""
        cCell?.image = info?.image
    }

    func tableViewSelectionDidChange(_ aNotification: Notification) {
        let table = aNotification.object as? NSTableView
        if let recentDocumentsTableView, table === recentDocumentsTableView {
            let row = recentDocumentsTableView.selectedRow

            if row >= 0 {
                recentDocumentsTableView.deselectAll(self)

                let info = recentInfoArray[row]
                if info.type == .Open {
                    NSApp.sendAction(#selector(NSDocumentController.openDocument(_:)),
                                     to: nil,
                                     from: self)
                } else if info.type == .File, let url = info.url {
                    let docControl = NSDocumentController.shared
                    docControl.openDocument(withContentsOf: url as URL,
                                            display: true) { document, documentWasAlreadyOpen, error in
                        //Do nothing
                    }
                }
            }
        } else if let createDocumentsTableView, table === createDocumentsTableView {
            let row = createDocumentsTableView.selectedRow

            if row >= 0 {
                createDocumentsTableView.deselectAll(self)

                let info = createInfoArray[row]
                if info.type == .CreateProject {
                    // Create new project
                    NSApp.sendAction(#selector(IFAppDelegate.newProject(_:)),
                                     to: nil,
                                     from: self)
                } else if info.type == .CreateExtension {
                    // Create new extension
                    NSApp.sendAction(#selector(IFAppDelegate.newExtension(_:)),
                                     to: nil,
                                     from: self)
                    type(of: self).hide()
                } else if info.type == .SaveEPubs {
                    // Save epubs
                    NSApp.sendAction(#selector(IFAppDelegate.exportToEPub(_:)),
                                     to: nil,
                                     from: self)
                }
            }
        } else if let sampleDocumentsTableView, table === sampleDocumentsTableView {
            let row = sampleDocumentsTableView.selectedRow

            if row >= 0 {
                sampleDocumentsTableView.deselectAll(self)

                let info = sampleInfoArray[row]
                if info.type == .CopySample, let source = info.url {
                    let chooseDirectoryPanel = NSOpenPanel()
                    chooseDirectoryPanel.canChooseFiles = false
                    chooseDirectoryPanel.canChooseDirectories = true
                    chooseDirectoryPanel.canCreateDirectories = true
                    chooseDirectoryPanel.allowsMultipleSelection = false
                    chooseDirectoryPanel.title = IFUtility.localizedString("Choose a directory to save into")
                    chooseDirectoryPanel.prompt = IFUtility.localizedString("Choose Directory")

                    // With no window, this is an app-modal panel, as it was when Objective-C began a sheet on nil
                    IFUtility.begin(chooseDirectoryPanel, for: sharedWindow?.window) { result in
                        if result == .OK, var destination = chooseDirectoryPanel.url {
                            // Append last path component of source onto destination
                            destination = destination.appendingPathComponent(source.lastPathComponent ?? "")
                            (NSApp.delegate as? IFAppDelegate)?.doCopyProject(source as URL,
                                                                             to: destination)
                        }
                    }
                } else if info.type == .WebsiteLink, let url = info.url {
                    NSWorkspace.shared.open(url as URL)
                }
            }
        }
    }

    // MARK: - News policy delegate

    @objc(webView:decidePolicyForNavigationAction:decisionHandler:)
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated {
            let url = navigationAction.request.url

            // Open extenal links in separate default browser app
            if let url, (url.scheme == "http") || (url.scheme == "https") {
                decisionHandler(.cancel)
                NSWorkspace.shared.open(url)
                return
            }
        }

        // default action
        decisionHandler(.allow)
    }
}
