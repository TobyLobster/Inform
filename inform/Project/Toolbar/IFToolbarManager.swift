//
//  IFToolbarManager.swift
//  Inform
//
//  Created by Toby Nelson in 2014
//

import Cocoa

// Limits the width of a toolbar item's view (replaces NSToolbarItem's deprecated minSize and maxSize)
private func setToolbarViewWidth(_ view: NSView?, _ minWidth: CGFloat, _ maxWidth: CGFloat) {
    view?.widthAnchor.constraint(greaterThanOrEqualToConstant: minWidth).isActive = true
    view?.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth).isActive = true
}

// == Toolbar items ==

/// The toolbar items, of which each toolbar is given copies
private struct IFToolbarItems {
    let stopItem: NSToolbarItem
    let itemDictionary: [String: NSToolbarItem]
}

private let toolbarItems: IFToolbarItems = {
    // Create the toolbar items
    let compileItem         = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("compileItem"))
    let compileAndRunItem   = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("compileAndRunItem"))
    let releaseItem         = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("releaseItem"))
    let replayItem          = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("replayItem"))
    let refreshIndexItem    = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("refreshIndexItem"))

    let testSelectorItem    = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("testSelectorItem"))
    let installExtensionItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("installExtensionItem"))
    let testItem            = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("testItem"))

    let stopItem            = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("stopItem"))

    let searchDocsItem      = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("searchDocsItem"))
    let searchProjectItem   = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("searchProjectItem"))

    let toolbarStatusSpacingItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("toolbarStatusSpacingItem"))
    let toolbarStatusSpacingView = IFToolbarStatusSpacingView(frame: NSRect(x: 0, y: 0, width: 1, height: 30))

    let itemDictionary = [ "compileItem":                     compileItem,
                           "compileAndRunItem":               compileAndRunItem,
                           "replayItem":                      replayItem,
                           "refreshIndexItem":                refreshIndexItem,
                           "releaseItem":                     releaseItem,
                           "testSelectorItem":                testSelectorItem,
                           "installExtensionItem":            installExtensionItem,
                           "testItem":                        testItem,
                           "stopItem":                        stopItem,
                           "searchDocsItem":                  searchDocsItem,
                           "searchProjectItem":               searchProjectItem,
                           "toolbarStatusSpacingItem":        toolbarStatusSpacingItem ]

    // Images
    compileItem.image = NSImage(named: "App/Toolbar/compile")
    compileAndRunItem.image = NSImage(named: "App/Toolbar/run")
    releaseItem.image = NSImage(named: "App/Toolbar/release")
    installExtensionItem.image = NSImage(named: "App/Toolbar/install")
    testItem.image = NSImage(named: "App/Toolbar/test")
    replayItem.image = NSImage(named: "App/Toolbar/replay")
    refreshIndexItem.image = NSImage(named: "App/Toolbar/refresh_index")

    stopItem.image = NSImage(named: "App/Toolbar/stop")

    // Labels
    compileItem.label = IFUtility.localizedString("Compile")
    compileAndRunItem.label = IFUtility.localizedString("Go!")
    releaseItem.label = IFUtility.localizedString("Release")
    replayItem.label = IFUtility.localizedString("Replay")
    refreshIndexItem.label = IFUtility.localizedString("Refresh Index")

    stopItem.label = IFUtility.localizedString("Stop")

    testSelectorItem.label = IFUtility.localizedString("Test Case")
    installExtensionItem.label = IFUtility.localizedString("Install Extension")
    testItem.label = IFUtility.localizedString("Test")

    searchDocsItem.label = IFUtility.localizedString("Search Documentation")
    searchProjectItem.label = IFUtility.localizedString("Search Project")

    toolbarStatusSpacingItem.view = toolbarStatusSpacingView
    toolbarStatusSpacingItem.label = ""

    // Set palette labels
    for item in itemDictionary.values {
        item.paletteLabel = item.label
    }

    // The tooltips
    compileItem.toolTip = IFUtility.localizedString("CompileTip", default: nil)
    compileAndRunItem.toolTip = IFUtility.localizedString("GoTip", default: nil)
    releaseItem.toolTip = IFUtility.localizedString("ReleaseTip", default: nil)
    replayItem.toolTip = IFUtility.localizedString("ReplayTip", default: nil)

    stopItem.toolTip = IFUtility.localizedString("StopTip", default: nil)

    searchDocsItem.toolTip = IFUtility.localizedString("SearchDocsTip", default: nil)
    searchProjectItem.toolTip = IFUtility.localizedString("SearchProjectTip", default: nil)

    refreshIndexItem.toolTip = IFUtility.localizedString("RefreshIndexTip", default: nil)
    testSelectorItem.toolTip = IFUtility.localizedString("TestSelectorTip", default: nil)
    installExtensionItem.toolTip = IFUtility.localizedString("InstallExtensionTip", default: nil)
    testItem.toolTip = IFUtility.localizedString("TestTip", default: nil)

    // The action heroes
    compileItem.action = #selector(IFProjectController.compile(_:))
    compileAndRunItem.action = #selector(IFProjectController.compileAndRun(_:))
    releaseItem.action = #selector(IFProjectController.release(_:))
    replayItem.action = #selector(IFProjectController.replayUsingSkein(_:))
    refreshIndexItem.action = #selector(IFProjectController.compileAndRefresh(_:))

    stopItem.action = #selector(IFProjectController.stopProcess(_:))
    testSelectorItem.action = #selector(IFProjectController.testSelector(_:))
    installExtensionItem.action = #selector(IFProjectController.installLegacyExtension(_:))
    testItem.action = #selector(IFProjectController.testMe(_:))

    return IFToolbarItems(stopItem: stopItem, itemDictionary: itemDictionary)
}()

private let toolbarStatusWidth: CGFloat = 300.0

@objc @implementation extension IFToolbarManager {
    // The toolbar
    private final var toolbar: NSToolbar?
    private final var toolbarView: NSView?

    private final var toolbarStatusView: IFToolbarStatusView?

    // Progress indicators
    private final var progressObjects: [IFProgress] = []

    private final var _testCasesPopUpButton: NSPopUpButton?
    private final var _testCases: [[String: Any]]?
    private final weak var _projectController: IFProjectController?

    var testCasesPopUpButton: NSPopUpButton? {
        return _testCasesPopUpButton
    }

    var testCases: [[String: Any]]? {
        return _testCases
    }

    weak var projectController: IFProjectController? {
        return _projectController
    }

    // == Initialisation ==
    override init() {
        super.init()
    }

    @objc(initWithProjectController:)
    init(projectController pc: IFProjectController) {
        _projectController = pc
        toolbarStatusView = IFToolbarStatusView(frame: NSRect(x: 0, y: 0, width: toolbarStatusWidth, height: 32))

        super.init()

        toolbarStatusView?.delegate = self

        // Register for settings updates
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(windowDidResize(_:)),
                                               name: NSWindow.didResizeNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(toolbarChangedVisibility(_:)),
                                               name: IFToolbar.ChangedVisibility,
                                               object: nil)

        // Full screen
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(willEnterFullScreen(_:)),
                                               name: NSWindow.willEnterFullScreenNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didEnterFullScreen(_:)),
                                               name: NSWindow.didEnterFullScreenNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(willExitFullScreen(_:)),
                                               name: NSWindow.willExitFullScreenNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didExitFullScreen(_:)),
                                               name: NSWindow.didExitFullScreenNotification,
                                               object: nil)
    }

    @objc private final func willEnterFullScreen(_ notification: Notification) {
        if notification.object as AnyObject? === projectController?.window {
            toolbarStatusView?.removeFromSuperview()
        }
    }

    @objc private final func didEnterFullScreen(_ notification: Notification) {
        if notification.object as AnyObject? === projectController?.window {
            adjustToolbarStatusView()
        }
    }

    @objc private final func willExitFullScreen(_ notification: Notification) {
        if notification.object as AnyObject? === projectController?.window {
            toolbarStatusView?.removeFromSuperview()
        }
    }

    @objc private final func didExitFullScreen(_ notification: Notification) {
        if notification.object as AnyObject? === projectController?.window {
            adjustToolbarStatusView()
        }
    }

    @objc private final func toolbarChangedVisibility(_ notification: Notification) {
        if notification.object as AnyObject? === toolbar {
            adjustToolbarStatusView()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private final func toolbarStatusViewParent() -> NSView? {
        return projectController?.window?.standardWindowButton(.closeButton)?.superview
    }

    // This function keeps the toolbar status view in the right place on the toolbar.
    // Called when anything relevant changes, e.g.:
    //      (a) the window changes size,
    //      (b) the window goes fullscreen or back, or
    //      (c) when the toolbar visibility changes.
    private final func adjustToolbarStatusView() {
        // Find the toolbar view. The toolbar view isn't easily available. We have to search the
        // subviews of the content view to find it. Once we've found it, we remember it.
        if toolbarView == nil {
            for subview in projectController?.window?.contentView?.superview?.subviews ?? [] {
                // 10.9 and earlier? has an NSToolbarView
                if let toolbarViewClass = NSClassFromString("NSToolbarView"), subview.isKind(of: toolbarViewClass) {
                    toolbarView = subview
                    break
                }

                // 10.10 Yosemite has an NSTitlebarContainerView instead of NSToolbarView
                if let containerViewClass = NSClassFromString("NSTitlebarContainerView"),
                   subview.isKind(of: containerViewClass) {
                    toolbarView = subview
                    break
                }
            }
        }

        // Get appropriate parent for the view
        let parentView = toolbarStatusViewParent()

        if let toolbarView {
            // Position our view within the toolbar
            let toolbarRect = parentView?.convert(toolbarView.bounds,
                                                  from: toolbarView) ?? .zero

            // Calculate the ideal frame to centre the toolbar status view in the toolbar
            let statusWidth = toolbarStatusView?.frame.size.width ?? 0
            var newFrame = toolbarRect
            newFrame.origin.x = (toolbarRect.size.width / 2) - (statusWidth / 2)
            let deltaHeight: CGFloat = -2.0
            newFrame.origin.y += 15.0 - deltaHeight / 2
            newFrame.size.width = statusWidth

            newFrame.size.height = 30.0

            newFrame.origin.x = floor(newFrame.origin.x)
            newFrame.origin.y = floor(newFrame.origin.y)
            newFrame.size.width = floor(newFrame.size.width)
            newFrame.size.height = floor(newFrame.size.height)

            // Make sure we position ourselves within the bounds of the special IFToolbarStatusSpacingView item
            var found = false
            var startPoint = NSPoint.zero
            var endPoint = NSPoint.zero
            for item in toolbar?.items ?? [] {
                if let itemView = item.view, itemView is IFToolbarStatusSpacingView {
                    startPoint = itemView.bounds.origin
                    endPoint = NSPoint(x: itemView.bounds.origin.x + itemView.bounds.size.width,
                                       y: itemView.bounds.origin.y + itemView.bounds.size.height)

                    startPoint = itemView.convert(startPoint,
                                                  to: parentView)
                    endPoint = itemView.convert(endPoint,
                                                to: parentView)
                    found = true
                    break
                }
            }

            if found {
                if newFrame.origin.x < startPoint.x {
                    newFrame.origin.x = startPoint.x
                }
                if (newFrame.origin.x + newFrame.size.width) > endPoint.x {
                    // Hide - not enough room to show it
                    toolbarStatusView?.removeFromSuperview()
                    return
                }
            } else {
                // Hide - no IFToolbarStatusSpacingView, so not wanted
                toolbarStatusView?.removeFromSuperview()
                return
            }

            toolbarStatusView?.frame = newFrame
            toolbarStatusView?.needsDisplay = true
            toolbarView.needsDisplay = true
        }

        // Update visibility
        let isVisible = toolbar?.isVisible ?? false
        if isVisible && toolbarStatusView?.superview == nil {
            if let toolbarStatusView {
                parentView?.addSubview(toolbarStatusView,
                                       positioned: .above,
                                       relativeTo: nil)
            }
        } else if !isVisible && toolbarStatusView?.superview != nil {
            toolbarStatusView?.removeFromSuperview()
        }
    }

    var toolbarIdentifier: String {
        // Create the view switch toolbar
        if (projectController?.document as? IFProject)?.projectFileType == .inform7ExtensionProject {
            return "IFInform7ExtensionProjectToolbar"
        }
        return "IFInform7Toolbar"
    }

    func setToolbar() {
        // Create the view switch toolbar
        let toolbar = IFToolbar(identifier: toolbarIdentifier)
        self.toolbar = toolbar

        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.displayMode = .iconAndLabel

        projectController?.window?.toolbar = toolbar

        // Remove all items from the context menu
        if let contextMenu = projectController?.window?.contentView?.superview?.menu {
            contextMenu.removeAllItems()
        }

        adjustToolbarStatusView()
    }

    // == Toolbar item validation ==

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        let itemSelector = item.action
        let itemIdentifier = item.itemIdentifier

        if itemIdentifier == toolbarItems.stopItem.itemIdentifier {
            return projectController?.isRunningGame ?? false
        }

        if itemSelector == #selector(IFProjectController.testMe(_:)) {
            if (_testCases?.count ?? 0) == 0 {
                return false
            }
            if projectController?.isCurrentlyTesting ?? false {
                return false
            }
        }

        if itemSelector == #selector(IFProjectController.compile(_:)) ||
            itemSelector == #selector(IFProjectController.release(_:)) ||
            itemSelector == #selector(IFProjectController.releaseForTesting(_:)) ||
            itemSelector == #selector(IFProjectController.compileAndRun(_:)) ||
            itemSelector == #selector(IFProjectController.replayUsingSkein(_:)) ||
            itemSelector == #selector(IFProjectController.compileAndRefresh(_:)) {

            let isExtensionProject = (projectController?.document as? IFProject)?.projectFileType == .inform7ExtensionProject
            let selectedNoTestCase = isExtensionProject && (((_testCases?.count ?? 0) == 0) ||
                                                            (currentTestCase == nil))

            // If we are in an Extension Project, and there are no test cases to run, disable Go! (etc) buttons.
            if selectedNoTestCase {
                return false
            }
            return !(projectController?.isCompiling ?? false)
        }

        return true
    }

    func validateVisibleItems() {
        toolbar?.validateVisibleItems()
    }

    func windowDidResize(_ notification: Notification) {
        let window = notification.object as? NSWindow
        if window === projectController?.window {
            // Adjust toolbar status window appropriately
            adjustToolbarStatusView()
        }
    }

    func showMessage(_ message: String) {
        toolbarStatusView?.showMessage(message)
    }

    private final func findBestProgress(thatIsActive active: Bool) -> IFProgress? {
        var best: IFProgress?
        var bestPriority: Int32 = 0

        for progress in progressObjects {
            let isActive = progress.isInProgress
            if isActive == active {
                if progress.priority > bestPriority {
                    bestPriority = progress.priority
                    best = progress
                }
            }
        }
        return best
    }

    private final func currentProgress() -> IFProgress? {
        // Find the highest priority active object, or failing that, the best inactive one
        var best = findBestProgress(thatIsActive: true)

        if best == nil {
            best = findBestProgress(thatIsActive: false)
        }
        return best
    }

    func updateProgress() {
        let best = currentProgress()

        toolbarStatusView?.canCancel((best?.canCancel ?? false) && !(best?.isCancelled ?? false))
        if let best, best.showsProgressBar {
            // Enable progress bar
            toolbarStatusView?.startProgress()
        } else {
            // Disable progress bar
            toolbarStatusView?.stopProgress()
        }

        toolbarStatusView?.setProgressMaxValue(100.0)

        // Set percentage
        let percentage = best?.percentage ?? 0
        if percentage > 0.0 {
            toolbarStatusView?.updateProgress(percentage)
            toolbarStatusView?.setProgressIndeterminate(false)
        } else {
            toolbarStatusView?.setProgressIndeterminate(true)
        }

        if let message = best?.message {
            toolbarStatusView?.showMessage(message)
        }

        // Make sure parent redraws (avoids blocky edges where semi-transparent pixels are repeatedly redrawn)
        toolbarStatusViewParent()?.needsDisplay = true
    }

    func addProgressIndicator(_ indicator: IFProgress) {
        indicator.delegate = self
        progressObjects.append(indicator)

        updateProgress()
    }

    func removeProgressIndicator(_ indicator: IFProgress) {
        indicator.delegate = nil
        progressObjects.removeAll { $0 === indicator }

        updateProgress()
    }

    func progressIndicator(_ indicator: IFProgress,
                           percentage newPercentage: CGFloat) {
        updateProgress()
    }

    func progressIndicator(_ indicator: IFProgress,
                           message newMessage: String?) {
        updateProgress()
    }

    func progressIndicatorStartStory(_ indicator: IFProgress) {
        toolbarStatusView?.startStory()

        // Make sure parent redraws (avoids blocky edges where semi-transparent pixels are repeatedly redrawn)
        toolbarStatusViewParent()?.needsDisplay = true
    }

    func progressIndicatorStopStory(_ indicator: IFProgress) {
        toolbarStatusView?.stopStory()

        // Make sure parent redraws (avoids blocky edges where semi-transparent pixels are repeatedly redrawn)
        toolbarStatusViewParent()?.needsDisplay = true
    }

    @objc(progressIndicatorStartProgress:)
    func progressIndicatorStart(_ indicator: IFProgress) {
        updateProgress()
    }

    @objc(progressIndicatorStopProgress:)
    func progressIndicatorStop(_ indicator: IFProgress) {
        updateProgress()
    }

    // Information passed back from view

    func cancelProgress() {
        currentProgress()?.cancel()

        // Make sure parent redraws (avoids blocky edges where semi-transparent pixels are repeatedly redrawn)
        toolbarStatusViewParent()?.needsDisplay = true
    }

    func redrawToolbar() {
        adjustToolbarStatusView()
    }

    func setTestCases(_ testCasesArray: [[String: Any]]?) {
        if let testCasesPopUpButton = _testCasesPopUpButton {
            // Remember current selected item
            let selectedTitle = testCasesPopUpButton.selectedItem?.title

            // Remove all items, then repopulate
            testCasesPopUpButton.removeAllItems()

            if (testCasesArray?.count ?? 0) > 0 {
                testCasesPopUpButton.addItem(withTitle: IFUtility.localizedString("Test All"))
            }

            for item in testCasesArray ?? [] {
                var title = item["testTitle"] as? String ?? ""
                title = (title as NSString).trimmingCharacters(in: "\"")
                // Added to the menu, as the pop-up would remove an earlier item with the same title, and the
                // items have to match the test cases one for one
                testCasesPopUpButton.menu?.addItem(withTitle: title, action: nil, keyEquivalent: "")
            }

            if let selectedTitle {
                // Restore current selected item
                testCasesPopUpButton.selectItem(withTitle: selectedTitle)

                // If that didn't work, select the first item
                if testCasesPopUpButton.selectedItem == nil {
                    if testCasesPopUpButton.itemArray.count > 0 {
                        testCasesPopUpButton.selectItem(at: 0)
                    }
                }
            }
        }
        _testCases = testCasesArray
    }

    func selectTestCase(_ testCase: String) -> Bool {
        for i in 0..<(_testCases?.count ?? 0) {
            if let key = _testCases?[i]["testKey"] as? String,
               (key as NSString).isEqual(toStringCaseInsensitive: testCase) {
                _testCasesPopUpButton?.selectItem(at: 1 + i)

                projectController?.testSelector(_testCasesPopUpButton)

                return true
            }
        }
        return false
    }

    var numberOfTestCases: Int32 {
        @objc(getNumberOfTestCases)
        get {
            guard let testCases = _testCases else {
                return 0
            }
            return Int32(truncatingIfNeeded: testCases.count)
        }
    }

    func getTestCase(_ index: Int32) -> String? {
        guard let testCases = _testCases else {
            return nil
        }
        // (A negative index is beyond the end, as the Objective-C compared it unsigned)
        if index < 0 || index >= testCases.count {
            return nil
        }
        return testCases[Int(index)]["testKey"] as? String
    }

    var testCaseIndex: Int32 {
        @objc(getTestCaseIndex)
        get {
            var selectedIndex = Int32(truncatingIfNeeded: _testCasesPopUpButton?.indexOfSelectedItem ?? 0)
            if selectedIndex < 0 {
                return -1
            }
            if selectedIndex == 0 {
                // Test all case
                return -1
            }

            selectedIndex -= 1
            return selectedIndex
        }
    }

    var currentTestCase: String? {
        let selectedIndex = testCaseIndex
        if selectedIndex < 0 {
            return nil
        }
        if selectedIndex >= (_testCases?.count ?? 0) {
            return nil
        }
        return _testCases?[Int(selectedIndex)]["testKey"] as? String
    }
}

// The manager is the delegate of its toolbar, as its header declares, and of its progress indicators, as its
// class extension declared
extension IFToolbarManager: IFProgressDelegate {
    // MARK: - Toolbar delegate functions

    @objc public func toolbar(_ toolbar: NSToolbar,
                              itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                              willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        // NSToolbar items can't be shared between windows, so we create copies.

        // Make a copy of the item
        let item = toolbarItems.itemDictionary[itemIdentifier.rawValue]?.copy() as? NSToolbarItem

        // The search views need to be set up here
        if itemIdentifier.rawValue == "searchDocsItem" {
            let searchDocs = NSSearchField(frame: NSRect(x: 0, y: 0, width: 130, height: 22))
            (searchDocs.cell as? NSSearchFieldCell)?.placeholderString = IFUtility.localizedString("Documentation")

            setToolbarViewWidth(searchDocs, 70, 150)
            item?.view = searchDocs
            searchDocs.sizeToFit()
            searchDocs.cell?.isScrollable = true

            searchDocs.isContinuous = false
            (searchDocs.cell as? NSSearchFieldCell)?.sendsWholeSearchString = true
            searchDocs.target = projectController
            searchDocs.action = #selector(IFProjectController.searchDocs(_:))

            item?.label = ""

            return item
        } else if itemIdentifier.rawValue == "searchProjectItem" {
            let searchProject = NSSearchField(frame: NSRect(x: 0, y: 0, width: 130, height: 22))
            (searchProject.cell as? NSSearchFieldCell)?.placeholderString = IFUtility.localizedString("Project")

            setToolbarViewWidth(searchProject, 70, 150)
            item?.view = searchProject
            searchProject.sizeToFit()
            searchProject.cell?.isScrollable = true

            searchProject.isContinuous = false
            (searchProject.cell as? NSSearchFieldCell)?.sendsWholeSearchString = true
            searchProject.target = projectController
            searchProject.action = #selector(IFProjectController.searchProject(_:))

            item?.label = ""

            return item
        } else if itemIdentifier.rawValue == "testSelectorItem" {
            let testCasesPopUpButton = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 190, height: 22))
            _testCasesPopUpButton = testCasesPopUpButton
            setToolbarViewWidth(testCasesPopUpButton, 100, 190)
            item?.view = testCasesPopUpButton
            testCasesPopUpButton.target = projectController
            testCasesPopUpButton.action = #selector(IFProjectController.testSelector(_:))
        } else if itemIdentifier.rawValue == "toolbarStatusSpacingItem" {
            // The copy's view is unarchived without the constraints, so they're set here
            setToolbarViewWidth(item?.view, 10, 10000)
        }

        return item
    }

    @objc public func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [NSToolbarItem.Identifier("compileItem"),
                NSToolbarItem.Identifier("compileAndRunItem"),
                NSToolbarItem.Identifier("replayItem"),
                NSToolbarItem.Identifier("refreshIndexItem"),
                NSToolbarItem.Identifier("stopItem"),
                NSToolbarItem.Identifier("searchDocsItem"),
                NSToolbarItem.Identifier("searchProjectItem"),
                NSToolbarItem.Identifier("toolbarStatusSpacingItem"),
                .space,
                .flexibleSpace,
                NSToolbarItem.Identifier("releaseItem"),
                NSToolbarItem.Identifier("testSelectorItem")]
    }

    @objc public func toolbarDefaultItemIdentifiers(_ tb: NSToolbar) -> [NSToolbarItem.Identifier] {
        let identifier = tb.identifier
        if identifier == "IFInform7Toolbar" {
            return [NSToolbarItem.Identifier("compileAndRunItem"),
                    NSToolbarItem.Identifier("replayItem"),
                    NSToolbarItem.Identifier("releaseItem"),
                    NSToolbarItem.Identifier("searchProjectItem"),
                    NSToolbarItem.Identifier("toolbarStatusSpacingItem"),
                    NSToolbarItem.Identifier("searchDocsItem")]
        } else if identifier == "IFInform7ExtensionProjectToolbar" {
            return [NSToolbarItem.Identifier("compileAndRunItem"),
                    NSToolbarItem.Identifier("testItem"),
                    NSToolbarItem.Identifier("testSelectorItem"),
                    NSToolbarItem.Identifier("installExtensionItem"),
                    NSToolbarItem.Identifier("toolbarStatusSpacingItem"),
                    NSToolbarItem.Identifier("searchProjectItem"),
                    NSToolbarItem.Identifier("searchDocsItem")]
        } else {
            // Inform 6 toolbar items
            return [NSToolbarItem.Identifier("compileAndRunItem"),
                    NSToolbarItem.Identifier("replayItem"),
                    NSToolbarItem.Identifier("releaseItem"),
                    NSToolbarItem.Identifier("toolbarStatusSpacingItem")]
        }
    }

    @objc public func toolbarWillAddItem(_ notification: Notification) {
        adjustToolbarStatusView()
        toolbarStatusView?.updateToolbar()
    }

    @objc public func toolbarDidRemoveItem(_ notification: Notification) {
        adjustToolbarStatusView()
        toolbarStatusView?.updateToolbar()
    }
}
