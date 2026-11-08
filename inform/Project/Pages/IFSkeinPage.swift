//
//  IFSkeinPage.swift
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

import Cocoa
import WebKit

private let webViewHeight: CGFloat = 250.0

@objc @implementation extension IFSkeinPage {
    // The skein view
    @IBOutlet private final var splitView: NSSplitView!
    /// The skein view
    @IBOutlet private final var skeinView: IFSkeinView!

    @IBOutlet private final var webViewParent: NSView!
    private final var webView: WKWebView!
    private final let helper: IFWebViewHelper

    private final var cachedHash = 0

    private final var testingTemplate = ""
    private final var settingDividerProgrammatically = false

    // The page bar buttons
    /// The 'Play All Blessed' button
    private final let playAllCell: IFPageBarCell
    /// The 'Save Transcript' button
    private final let saveTranscriptCell: IFPageBarCell
    /// The 'Show Help/Hide Help' button
    private final let toggleHelpCell: IFPageBarCell

    // MARK: - Initialisation

    @objc(initWithProjectController:withPane:)
    init(projectController controller: IFProjectController,
         with pane: IFProjectPane) {
        // Web view
        helper = IFWebViewHelper(projectController: controller,
                                 with: controller.oppositePane(pane))

        // Create the cells for the page bar
        playAllCell = IFPageBarCell(textCell: IFUtility.localizedString("Play All Blessed"))
        saveTranscriptCell = IFPageBarCell(textCell: IFUtility.localizedString("Save Transcript"))
        toggleHelpCell = IFPageBarCell(textCell: "")

        super.init(nibName: "Skein",
                   projectController: controller)

        let doc = parent?.document as? IFProject

        settingDividerProgrammatically = false

        // Split view
        splitView.delegate = self

        // Skein view
        skeinView.skein = doc?.currentSkein
        skeinView.delegate = parent

        // Web view
        webView = helper.createWebView(withFrame: webViewParent.bounds)

        // Set delegates
        webView.navigationDelegate = self

        // Load template and html fragments
        loadHTMLTemplate()

        // Add to view hieracrchy
        webViewParent.addSubview(webView)

        cachedHash = 0
        updateHelpHTML()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didResizeSplitView(_:)),
                                               name: NSSplitView.didResizeSubviewsNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(fontSizePreferenceChanged(_:)),
                                               name: .IFPreferencesAppFontSizeDidChange,
                                               object: IFPreferences.shared)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(skeinSelectionDidChange(_:)),
                                               name: .IFSkeinSelectionChanged,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(skeinDidChange(_:)),
                                               name: .IFSkeinChanged,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(skeinWasReplaced(_:)),
                                               name: .IFSkeinReplaced,
                                               object: nil)

        // Set up the cells for the page bar
        playAllCell.target = self
        playAllCell.action = #selector(replayEntireSkein(_:))

        saveTranscriptCell.target = self
        saveTranscriptCell.action = #selector(saveTranscript(_:))
        saveTranscriptCell.isEnabled = false

        toggleHelpCell.target = self
        toggleHelpCell.action = #selector(toggleHelp(_:))
        toggleHelpCell.isEnabled = true

        if doc?.settings.testingTabHelpShown ?? false {
            setTestingTabHelpShownTitleControl(true)
            setTestingTabSplitControlShowingHelp(true)
        }
        else {
            setTestingTabHelpShownTitleControl(false)
            setTestingTabSplitControlShowingHelp(false)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private final func updateHelpHTML() {
        let html = testingTemplate
        let hash = (html as NSString).hash
        if cachedHash != hash {
            loadHTMLString(html)
            cachedHash = hash
        }
        var jsCommands: [String] = []

        let doc = parent?.document as? IFProject
        let count = doc?.settings.testingTabShownCount ?? 0
        let showWelcome = (count < 10)
        let isGreyOrBlueVisible  = skeinView.isAnyItemGrey || skeinView.isAnyItemBlue
        let isTickOrCrossVisible = skeinView.isTickVisible || skeinView.isCrossVisible

        jsCommands.append(showWelcome                               ? "showBlock('welcome')"   : "hideBlock('welcome')")
        jsCommands.append((skeinView.layoutTree.rootItem != nil)    ? "showBlock('title')"     : "hideBlock('title')")
        jsCommands.append(skeinView.isAnyItemPurple                 ? "showBlock('purple')"    : "hideBlock('purple')")
        jsCommands.append(isGreyOrBlueVisible                       ? "showBlock('grey')"      : "hideBlock('grey')")
        jsCommands.append(isGreyOrBlueVisible                       ? "showBlock('blue')"      : "hideBlock('blue')")
        jsCommands.append(skeinView.isReportVisible                 ? "showBlock('report')"    : "hideBlock('report')")
        jsCommands.append(isTickOrCrossVisible                      ? "showBlock('tick')"      : "hideBlock('tick')")
        jsCommands.append(skeinView.isCrossVisible                  ? "showBlock('cross')"     : "hideBlock('cross')")
        jsCommands.append(skeinView.isBadgedItemVisible             ? "showBlock('badge')"     : "hideBlock('badge')")
        jsCommands.append((skeinView.itemsVisible >= 2)             ? "showBlock('threads')"   : "hideBlock('threads')")
        jsCommands.append((skeinView.itemsVisible == 1)             ? "showBlock('knots')"     : "hideBlock('knots')")
        jsCommands.append(((skeinView.itemsVisible >= 2) && (skeinView.itemsVisible <= 10))
                                                                    ? "showBlock('moreknots')" : "hideBlock('moreknots')")
        jsCommands.append((skeinView.itemsVisible >= 5)             ? "showBlock('menu')"      : "hideBlock('menu')")
        jsCommands.append(!showWelcome                              ? "showBlock('welcomead')" : "hideBlock('welcomead')")

        for command in jsCommands {
            webView.evaluateJavaScript(command, completionHandler: nil)
        }
    }

    public override func didSwitchToPage() {
        // Remember how many times we have gone to this page, so we can show appropriate help
        let doc = parent?.document as? IFProject
        var count = doc?.settings.testingTabShownCount ?? 0
        count += 1
        doc?.settings.testingTabShownCount = count

        // Make sure the skein is shown properly
        if let skein = skeinView?.skein {
            skein.postChanged(withAnimate: false,
                              keepActiveVisible: false)
        }

        updateHelpHTML()
    }

    // MARK: - Preferences

    @objc private final func fontSizePreferenceChanged(_ not: Notification) {
        helper.fontSizePreferenceChanged(webView)
        skeinView.fontSizePreferenceChanged(not)
    }

    // MARK: - Details about this view

    public override var title: String {
        return IFUtility.localizedString("Skein Page Title")
    }

    // MARK: - The skein view

    @objc private final func skeinSelectionDidChange(_ not: Notification) {
        let enableSaveTranscript = skeinView.selectedItem != nil
        saveTranscriptCell.isEnabled = enableSaveTranscript
        perform(#selector(updateHelpHTML),
                with: nil,
                afterDelay: 0.0)
    }

    @objc private final func skeinDidChange(_ not: Notification) {
        perform(#selector(updateHelpHTML),
                with: nil,
                afterDelay: 0.0)
    }

    @objc private final func skeinWasReplaced(_ not: Notification) {
        let doc = parent?.document as? IFProject
        skeinView.skein = doc?.currentSkein
        perform(#selector(updateHelpHTML),
                with: nil,
                afterDelay: 0.0)
    }

    @objc private final func replayEntireSkein(_ sender: Any?) {
        let action = #selector(replayEntireSkein(_:))
        _ = (NSApp.target(forAction: action) as AnyObject?)?.perform(action, with: sender)
    }

    @objc private final func saveTranscript(_ sender: Any?) {
        skeinView.saveTranscript(sender)
    }

    // MARK: - The page bar

    public override var toolbarCells: [IFPageBarCell] {
        return [playAllCell, saveTranscriptCell, toggleHelpCell]
    }

    func selectSkeinItem(withNodeId skeinItemNodeId: UInt) -> Bool {
        if skeinView != nil {
            return skeinView.selectItem(withNodeId: skeinItemNodeId)
        }
        return false
    }

    private final func setTestingTabHelpShownTitleControl(_ helpIsShown: Bool) {
        if helpIsShown {
            toggleHelpCell.title = IFUtility.localizedString("Hide Help")
        }
        else {
            toggleHelpCell.title = IFUtility.localizedString("Show Help")
        }
        toggleHelpCell.controlView?.needsDisplay = true
    }

    private final func setTestingTabHelpShownSetting(_ helpIsShown: Bool) {
        let doc = parent?.document as? IFProject

        doc?.settings.testingTabHelpShown = helpIsShown
    }

    @objc private final func didResizeSplitView(_ not: Notification) {
        if !settingDividerProgrammatically {
            if splitView.isSubviewCollapsed(webViewParent) {
                setTestingTabHelpShownTitleControl(false)
                setTestingTabHelpShownSetting(false)
            }
            else {
                setTestingTabHelpShownTitleControl(true)
                setTestingTabHelpShownSetting(true)
            }
        }
    }

    private final func isTestingTabSplitControlShowingHelp() -> Bool {
        return !splitView.isSubviewCollapsed(webViewParent)
    }

    private final func setTestingTabSplitControlShowingHelp(_ showHelp: Bool) {
        setTestingTabHelpShownTitleControl(showHelp)

        settingDividerProgrammatically = true
        if showHelp {
            splitView.setPosition(webViewHeight, ofDividerAt: 0)
        }
        else {
            splitView.setPosition(splitView.bounds.size.height, ofDividerAt: 0)
        }
        settingDividerProgrammatically = false
    }

    @objc private final func toggleHelp(_ sender: Any?) {
        if (sender as AnyObject?) === toggleHelpCell.controlView {
            if isTestingTabSplitControlShowingHelp() {
                setTestingTabHelpShownTitleControl(false)
                setTestingTabSplitControlShowingHelp(false)
                setTestingTabHelpShownSetting(false)
            }
            else {
                setTestingTabHelpShownTitleControl(true)
                setTestingTabSplitControlShowingHelp(true)
                setTestingTabHelpShownSetting(true)
            }
        }
    }

    private final func loadHTMLString(_ htmlString: String) {
        webView.loadHTMLString(htmlString,
                               baseURL: URL(string: "inform:/"))
    }

    private final func loadHTMLTemplate() {
        let template = try? String(contentsOf: URL(string: "inform:/TestingTemplate.html")!,
                                   encoding: .utf8)
        precondition(template != nil)
        testingTemplate = template!
    }
}

// The page's header conforms to WKNavigationDelegate and NSSplitViewDelegate,
// whose methods an @implementation doesn't take
extension IFSkeinPage {
    // MARK: - WKNavigationDelegate

    @objc(webView:decidePolicyForNavigationAction:decisionHandler:)
    public func webView(_ webView: WKWebView,
                        decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        // Allow everything for now
        decisionHandler(.allow)
    }

    // MARK: - Split view delegate

    @objc(splitView:canCollapseSubview:)
    public func splitView(_ split: NSSplitView,
                          canCollapseSubview subview: NSView) -> Bool {
        if split.subviews[1].isEqual(subview) {
            return true
        }
        return false
    }

    @objc(splitView:constrainSplitPosition:ofSubviewAt:)
    public func splitView(_ split: NSSplitView,
                          constrainSplitPosition proposedPosition: CGFloat,
                          ofSubviewAt dividerIndex: Int) -> CGFloat {
        let limit = max(webViewHeight, split.bounds.size.height - webViewHeight)
        return limit
    }

    @objc(splitView:resizeSubviewsWithOldSize:)
    public func splitView(_ split: NSSplitView,
                          resizeSubviewsWithOldSize oldSize: NSSize) {
        // If either view is collapsed, do the standard behaviour
        if split.isSubviewCollapsed(split.subviews[0]) {
            split.adjustSubviews()
            return
        }
        if split.isSubviewCollapsed(split.subviews[1]) {
            split.adjustSubviews()
            return
        }

        // Both views are visible
        let newFrame = split.frame
        let dividerThickness = split.dividerThickness

        var rect0 = split.subviews[0].frame
        var rect1 = split.subviews[1].frame
        let minSize0: CGFloat = -1
        var height0: CGFloat = 0

        rect0.origin = NSPoint(x: 0, y: 0)
        rect0.size.width = newFrame.size.width
        rect1.size.width = newFrame.size.width
        rect1.size.height = webViewHeight

        // Adjust view at index 0 to keep view 1 at it's current height
        height0 = newFrame.size.height - rect1.size.height - dividerThickness
        if height0 < minSize0 {
            rect0.size.height = minSize0
            rect1.size.height = newFrame.size.height - rect0.size.height - dividerThickness
        } else {
            rect0.size.height = height0
        }

        rect1.origin = NSPoint(x: 0, y: rect0.size.height + dividerThickness)

        split.subviews[0].frame = rect0
        split.subviews[1].frame = rect1
    }
}
