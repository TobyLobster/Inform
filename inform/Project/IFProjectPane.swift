//
//  IFProjectPane.swift
//  Inform
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

import Cocoa
import ZoomView

/// Zoom shows the warnings a story's interpreter gives, once there's a pane to run it in: set as the first pane is made
private let zoomShowsWarnings: Void = {
    ZoomPreferences.global.displayWarnings = true
}()

@objc @implementation extension IFProjectPane {
    // Outlets
    /// The main pane view, which the nib sets
    private final var _paneView: NSView?
    /// The tab view, which the nib sets
    private final var _tabView: NSTabView?

    // The page bar
    /// The page toolbar
    @IBOutlet private final var pageBar: IFPageBarView?

    /// The 'forward' button
    private final var forwardCell: IFPageBarCell?
    /// The 'backwards' button
    private final var backCell: IFPageBarCell?

    // History
    /// The history, for the backwards and forwards buttons, made once the pane is
    private final var paneHistory: IFPaneHistory!

    // The pages
    /// Pages being managed by this control
    private final var pages: [IFPage] = []

    // The pages, made as the pane is set up for its controller
    /// The source page
    private final var _sourcePage: IFSourcePage?
    /// The errors page
    private final var _errorsPage: IFErrorsPage?
    /// The index page
    private final var _indexPage: IFIndexPage?
    /// The skein page
    private final var _skeinPage: IFSkeinPage?
    /// The game page
    private final var _gamePage: IFGamePage?
    /// The documentation page
    private final var _documentationPage: IFDocumentationPage?
    /// The extensions page
    private final var _extensionsPage: IFExtensionsPage?
    /// The settings page
    private final var _settingsPage: IFSettingsPage?

    // Other variables
    /// \c YES if we've loaded from the nib and initialised properly
    private final var awake = false
    /// The 'parent' project controller (not retained)
    private final weak var parent: IFProjectController?

    @objc(standardPane)
    class func standard() -> IFProjectPane {
        return IFProjectPane()
    }

    override init() {
        super.init()

        _ = zoomShowsWarnings

        paneHistory = IFPaneHistory(changeHandler: { [weak self] in
            self?.updateHistoryControls()
        })
    }

    deinit {
        // The project window lets go of its panes on the main thread
        MainActor.assumeIsolated {
            _sourcePage?.finished()
            _errorsPage?.finished()
            _indexPage?.finished()
            _skeinPage?.finished()
            _gamePage?.finished()
            _documentationPage?.finished()
            _extensionsPage?.finished()
            _settingsPage?.finished()

            for page in pages {
                page.recorder = nil
            }
            for page in pages {
                page.otherPane = nil
            }

            NotificationCenter.default.removeObserver(self)
        }
    }

    @objc(attributeForStyle:)
    class func attribute(for style: IFSyntaxStyle) -> [NSAttributedString.Key: Any] {
        return IFPreferences.shared.styles[Int(style.rawValue)] as! [NSAttributedString.Key: Any]
    }

    var paneView: NSView {
        get {
            if !awake {
                _ = Bundle.customLoadNib("ProjectPane",
                                         owner: self)
            }

            return _paneView!
        }
        set {
            _paneView = newValue
        }
    }

    var activeView: NSView? {
        switch currentView {
        case .sourcePane:   return _sourcePage?.activeView
        default:            return _tabView?.selectedTabViewItem?.view
        }
    }

    func removeFromSuperview() {
        _paneView?.removeFromSuperview()
    }

    private final func setupFromController(withViewIndex viewIndex: Int) {
        guard let ourParent = parent, let tabView = _tabView else {
            return
        }

        let doc = ourParent.document as? IFProject

        // Remove the first tab view item - which we can't do in interface builder :-/
        tabView.removeTabViewItem(tabView.tabViewItems[0])

        // Source page
        let sourcePage = IFSourcePage(projectController: ourParent)
        _sourcePage = sourcePage
        add(sourcePage)

        if let mainSourceFile = doc?.mainSourceFile {
            sourcePage.showSourceFile(mainSourceFile)
            sourcePage.updateHighlightedLines()
        }

        // Errors page
        let errorsPage = IFErrorsPage(projectController: ourParent,
                                      with: self)
        _errorsPage = errorsPage
        add(errorsPage)

        // Compiler and intest (live on the errors page)
        if let doc {
            errorsPage.compilerController.compiler = doc.compiler
            errorsPage.compilerController.inTest = doc.inTest
        }
        errorsPage.compilerController.setProject(ourParent, with: self)

        // Game page
        if viewIndex == 1 {
            let gamePage = IFGamePage(projectController: ourParent)
            _gamePage = gamePage
            add(gamePage)
        }

        // Skein page
        let skeinPage = IFSkeinPage(projectController: ourParent,
                                    with: self)
        _skeinPage = skeinPage
        add(skeinPage)

        // Index page
        let indexPage = IFIndexPage(projectController: ourParent,
                                    with: self)
        _indexPage = indexPage
        add(indexPage)

        indexPage.updateIndexView()
        // Start on the welcome page
        indexPage.switch(toTab: IFIndexTabType.welcome.rawValue)

        // Documentation page
        let documentationPage = IFDocumentationPage(projectController: ourParent,
                                                    with: self)
        _documentationPage = documentationPage
        add(documentationPage)
        NSLog("HISTORY: ProjectPane (%@): (setupFromController) documentationPage:showToc", self)
        documentationPage.recordInHistory { documentationPage.showToc(self) }

        // Extensions page
        let extensionsPage = IFExtensionsPage(projectController: ourParent,
                                              with: self)
        _extensionsPage = extensionsPage
        add(extensionsPage)
        NSLog("HISTORY: ProjectPane (%@): (setupFromController) extensionsPage:showHome", self)
        extensionsPage.recordInHistory { extensionsPage.showHome(self) }

        // Settings
        let settingsPage = IFSettingsPage(projectController: ourParent)
        _settingsPage = settingsPage
        add(settingsPage)

        settingsPage.updateSettings()

        // Misc stuff

        // Resize the tab view so that the only margin is on the left
        if let tabViewParent = tabView.superview,
           let tabViewClient = tabView.selectedTabViewItem?.view {
            let clientRect   = tabViewParent.convert(tabViewClient.bounds,
                                                     from: tabViewClient)
            let parentRect   = tabViewParent.bounds
            var tabRect      = tabView.frame

            //float leftMissing = NSMinX(clientRect) - NSMinX(parentRect);
            let topMissing    = clientRect.minY - parentRect.minY
            let bottomMissing = parentRect.maxY - clientRect.maxY

            //tabRect.origin.x -= leftMissing;
            //tabRect.size.width += leftMissing;
            tabRect.origin.y -= topMissing
            tabRect.size.height += topMissing + bottomMissing

            tabView.frame = tabRect
        }

        historyEvent?.addAction { self.selectView(of: .sourcePane) }
    }

    nonisolated public override func awakeFromNib() {
        // Nibs are loaded on the main thread
        MainActor.assumeIsolated {
            awake = true

            _tabView?.delegate = self

            // Set up the backwards/forwards buttons
            let backCell    = IFPageBarCell(imageCell: NSImage(named: NSImage.goBackTemplateName))
            let forwardCell = IFPageBarCell(imageCell: NSImage(named: NSImage.goForwardTemplateName))
            self.backCell    = backCell
            self.forwardCell = forwardCell

            backCell.setKeyEquivalent("-")
            forwardCell.setKeyEquivalent("=")

            backCell.target = self
            forwardCell.target = self
            backCell.action = #selector(goBackwards(_:))
            forwardCell.action = #selector(goForwards(_:))

            pageBar?.setLeftCells([backCell, forwardCell])
        }
    }

    func setController(_ p: IFProjectController,
                       viewIndex: Int) {
        if !awake {
            _ = Bundle.customLoadNib("ProjectPane",
                                     owner: self)
        }

        parent = p

        if awake {
            setupFromController(withViewIndex: viewIndex)
        }
    }

    func willClose() {
        // The history might reference this object (or cause a circular reference some other way), so we destroy it now
        paneHistory.clear()

        for page in pages {
            if page.responds(to: #selector(IFPage.willClose)) {
                page.willClose()
            }
        }
    }

    /// The tab of the page given; none for no page
    private final func tabViewItem(for page: IFPage?) -> NSTabViewItem? {
        guard let page, let tabView = _tabView else {
            return nil
        }
        return tabView.tabViewItem(at: tabView.indexOfTabViewItem(withIdentifier: page.identifier))
    }

    private final func page(for item: NSTabViewItem?) -> IFPage? {
        let identifier = item?.identifier as? String
        for page in pages {
            if page.identifier == identifier {
                return page
            }
        }

        return nil
    }

    @objc(selectViewOfType:)
    func selectView(of pane: IFProjectPaneType) {
        if !awake {
            _ = Bundle.customLoadNib("ProjectPane",
                                     owner: self)
        }

        var toSelect: NSTabViewItem? = nil
        switch pane {
        case .sourcePane:           toSelect = tabViewItem(for: _sourcePage)
        case .errorPane:            toSelect = tabViewItem(for: _errorsPage)
        case .gamePane:             toSelect = tabViewItem(for: _gamePage)
        case .documentationPane:    toSelect = tabViewItem(for: _documentationPage)
        case .indexPane:            toSelect = tabViewItem(for: _indexPage)
        case .skeinPane:            toSelect = tabViewItem(for: _skeinPage)
        case .extensionsPane:       toSelect = tabViewItem(for: _extensionsPage)
        case .unknownPane:
            // No idea
            break
        @unknown default:
            break
        }

        if let toSelect {
            _tabView?.selectTabViewItem(toSelect)
        } else {
            NSLog("Unable to select pane")
        }
    }

    var currentView: IFProjectPaneType {
        let selectedId = _tabView?.selectedTabViewItem?.identifier as? String

        /// Whether the tab shown is the page given's
        func isShown(_ page: IFPage?) -> Bool {
            guard let selectedId, let page else {
                return false
            }
            return selectedId == page.identifier
        }

        if isShown(_sourcePage)         { return .sourcePane }
        if isShown(_errorsPage)         { return .errorPane }
        if isShown(_gamePage)           { return .gamePane }
        if isShown(_documentationPage)  { return .documentationPane }
        if isShown(_indexPage)          { return .indexPane }
        if isShown(_skeinPage)          { return .skeinPane }
        if isShown(_extensionsPage)     { return .extensionsPane }
        if isShown(_settingsPage)       { return .unknownPane }

        return .sourcePane
    }

    func setIsActive(_ isActive: Bool) {
        pageBar?.setIsActive(isActive)
    }

    var compilerController: IFCompilerController {
        return errorsPage.compilerController
    }

    // MARK: - The source view

    func prepareToSave() {
        _sourcePage?.prepareToSave()
    }

    // MARK: - The pages

    var sourcePage: IFSourcePage {
        return _sourcePage!
    }

    var errorsPage: IFErrorsPage {
        return _errorsPage!
    }

    var indexPage: IFIndexPage {
        return _indexPage!
    }

    var skeinPage: IFSkeinPage {
        return _skeinPage!
    }

    var gamePage: IFGamePage? {
        return _gamePage
    }

    var documentationPage: IFDocumentationPage {
        return _documentationPage!
    }

    var extensionsPage: IFExtensionsPage {
        return _extensionsPage!
    }

    var settingsPage: IFSettingsPage {
        return _settingsPage!
    }

    // MARK: - The game page

    func stopRunningGame() {
        _gamePage?.stopRunningGame()
    }

    // MARK: - Tab view delegate

    @objc(tabView:shouldSelectTabViewItem:)
    func tabView(_ view: NSTabView,
                 shouldSelect item: NSTabViewItem?) -> Bool {
        // Get the identifier for this tab page
        guard let identifier = item?.identifier else {
            return true
        }

        // Find the associated IFPage object
        var page: IFPage? = nil
        for possiblePage in pages {
            if (possiblePage.identifier as NSString).isEqual(identifier) {
                page = possiblePage
                break
            }
        }

        if let page {
            // HACK: When Lion auto-restores documents, it wants to switch pages to something random.
            // We stop the madness here.
            if !(parent?.safeToSwitchTabs ?? false) {
                return false
            }
            return page.shouldShowPage
        }

        return true
    }

    @objc(selectTabViewItem:)
    func select(_ item: NSTabViewItem) {
        _tabView?.selectTabViewItem(item)
    }

    @objc(activatePage:)
    func activate(_ page: IFPage?) {
        // Select the active view for the specified page
        parent?.window?.makeFirstResponder(page?.activeView)
    }

    @objc(tabView:willSelectTabViewItem:)
    func tabView(_ thisTabView: NSTabView,
                 willSelect tabViewItem: NSTabViewItem?) {
        let page     = self.page(for: tabViewItem)
        let lastPage = self.page(for: thisTabView.selectedTabViewItem)

        // Record in the history
        NSLog("HISTORY: Project Pane (%@): (willSelectTabViewItem) page %@ tabViewItem %@",
              self, page.map { "\($0)" } ?? "(null)", tabViewItem.map { "\($0)" } ?? "(null)")
        if let tabViewItem {
            historyEvent?.addAction { self.select(tabViewItem) }
        }
        historyEvent?.addAction { self.activate(page) }

        // Notify the page that it has been selected
        page?.pageIsVisible = true
        lastPage?.pageIsVisible = false
        lastPage?.didSwitchAwayFromPage()
        page?.didSwitchToPage()

        // Update the right-hand page bar cells
        pageBar?.setRightCells(self.page(for: tabViewItem)?.toolbarCells)
    }

    // MARK: - The tab view

    var tabView: NSTabView {
        get {
            return _tabView!
        }
        set {
            _tabView = newValue
        }
    }

    // MARK: - Dealing with pages

    @objc private final func refreshToolbarCells(_ not: Notification) {
        // Work out which page we're updating
        let page = not.object as? IFPage

        // Refresh the page bar cells
        if let page, page === self.page(for: _tabView?.selectedTabViewItem) {
            pageBar?.setRightCells(page.toolbarCells)
        }
    }

    @objc private final func switchToPage(_ not: Notification) {
        // Work out which page we're switching to, and the optional page that must be showing for the switch to occur
        var identifier = not.userInfo?["Identifier"] as? String
        let fromPage = not.userInfo?["OldPageIdentifier"] as? String

        // If no 'to' page is specified, then switch to the sending object
        if identifier == nil {
            identifier = (not.object as? IFPage)?.identifier
        }

        // If a 'from' page is specified, then the current page must be that page, or the switch won't take place
        if let fromPage {
            let currentPage = _tabView?.selectedTabViewItem?.identifier as? String
            if fromPage != currentPage {
                return
            }
        }

        // Select the page
        guard let identifier, let tabView = _tabView else {
            return
        }
        tabView.selectTabViewItem(tabView.tabViewItem(at: tabView.indexOfTabViewItem(withIdentifier: identifier)))
    }

    @objc(addPage:)
    func add(_ newPage: IFPage) {
        // Add this page to the list of pages being managed by this control
        pages.append(newPage)
        newPage.thisPane = self
        newPage.otherPane = parent?.oppositePane(self)
        newPage.recorder = self

        // Register for notifications from this page
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(switchToPage(_:)),
                                               name: .IFSwitchToPage,
                                               object: newPage)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(refreshToolbarCells(_:)),
                                               name: .IFUpdatePageBarCells,
                                               object: newPage)

        // Add the page to the tab view
        let newItem = NSTabViewItem(identifier: newPage.identifier)
        newItem.label = newPage.title

        _tabView?.addTabViewItem(newItem)

        if (newItem.view?.frame.size.width ?? 0) <= 0 {
            newItem.view?.setFrameSize(NSSize(width: 1280, height: 1024))
        }
        newPage.view.frame = newItem.view?.bounds ?? .zero
        newItem.view?.addSubview(newPage.view)
    }

    // MARK: - The history

    private final func updateHistoryControls() {
        backCell?.isEnabled = paneHistory.canGoBackwards
        forwardCell?.isEnabled = paneHistory.canGoForwards
    }

    var historyEvent: IFHistoryEvent? {
        return paneHistory.eventForThisPass()
    }

    func goBackwards(_ sender: Any?) {
        paneHistory.goBackwards()
    }

    func goForwards(_ sender: Any?) {
        paneHistory.goForwards()
    }

    // Extension updated
    func extensionUpdated(_ javascriptId: String?) {
        _extensionsPage?.extensionUpdated(javascriptId)
    }
}
