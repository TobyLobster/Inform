//
//  IFProjectController.swift
//  Inform
//
//  Created by Andrew Hunter on Wed Aug 27 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFProjectController.h.
//

import Cocoa
import GlkView
import ZoomView

// Preferences
private let IFSplitViewSizes = "IFSplitViewSizes"

/// The kind of search the toolbar's search fields make: for the phrase anywhere, in any case. (A C enum takes any
/// raw value, as the flag added to a find type makes.)
private let containsCaseInsensitive = IFFindType(rawValue: IFFindType.contains.rawValue |
                                                           IFFindType.caseInsensitive.rawValue)!

/// The controller's property that keeps one of its open panels
private typealias IFOpenPanelProperty = ReferenceWritableKeyPath<IFProjectController, NSOpenPanel?>

@objc @implementation extension IFProjectController {
    // Panes
    @IBOutlet private final var panesView: NSView?
    /// Collection of panes
    private final var projectPanes: [IFProjectPane]?
    /// Collection of pane split views
    private final var splitViews: [NSSplitView]?

    // Toolbar
    private final var toolbarManager: IFToolbarManager?

    // The Contents (headings) controller
    let headerController: IFHeaderController

    // The current tab view (used for the various tab selection menu items)
    /// The active tab view
    private final var currentTabView: NSTabView?
    /// The active project pane
    private final var currentPane: IFProjectPane?

    // Source highlighting
    private final let highlights: IFSourceHighlights

    // Compiling
    /// Action after a compile has finished
    private final var compileFinishedAction: Selector?
    /// Whether a compile started here hasn't yet finished
    private final var compiling: Bool
    /// Decides whether the project needs compiling before its story is used
    private final let compileCheck: IFCompileCheck

    /// Used when running the entire skein
    private final var playAll: IFSkeinPlayAll?

    // Glk automation
    var glkInputSource: (any ZoomViewInputSource)?

    private final var betweenWindowLoadedAndBecomingMain: Bool
    /// Test's run through the test cases
    private final let testCaseRun: IFTestCaseRun

    /// Actions that can be shared between project and single controllers
    private final let sharedActions: IFSourceSharedActions

    private final var testAllProgress: IFProgress?

    private final var extensionURL: NSURL?
    private final var inbuildAction: String

    var openExtensionPanel: NSOpenPanel?
    var openLegacyExtensionPanel: NSOpenPanel?

    /// The project, the controller's document
    private final var project: IFProject? {
        return document as? IFProject
    }

    // == Initialistion ==

    // The app makes the controller with init, which NSWindowController passes on to init(window:), with no window. The
    // Objective-C's init called initWithWindowNibName:, but Swift can't override init, which NSWindowController doesn't
    // designate, so the nib is named by windowNibName.
    override init(window: NSWindow?) {
        // Register our preferences (which the Objective-C did once, in +initialize, which Swift doesn't have)
        UserDefaults.standard.register(defaults: [IFSplitViewSizes: [0.5, 0.5]])

        projectPanes     = []
        splitViews       = []
        highlights       = IFSourceHighlights()

        headerController = IFHeaderController()
        betweenWindowLoadedAndBecomingMain = false
        compileCheck = IFCompileCheck()

        sharedActions = IFSourceSharedActions()

        testCaseRun = IFTestCaseRun()

        testAllProgress = nil
        extensionURL = nil
        inbuildAction = ""
        compiling = false

        super.init(window: window)

        shouldCloseDocument = false

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(intelFileChanged(_:)),
                                               name: .IFIntelFileHasChanged,
                                               object: nil)

        // Update ourselves when the compiler settings change
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateSettings(_:)),
                                               name: .IFSetting,
                                               object: nil)

        toolbarManager = IFToolbarManager(projectController: self)
    }

    // Swift needs this, as NSWindowController's is required. The Objective-C inherited it, setting nothing up: this
    // sets only what Swift can't leave unset.
    public required init?(coder: NSCoder) {
        highlights = IFSourceHighlights()
        headerController = IFHeaderController()
        betweenWindowLoadedAndBecomingMain = false
        compileCheck = IFCompileCheck()
        sharedActions = IFSourceSharedActions()
        testCaseRun = IFTestCaseRun()
        inbuildAction = ""
        compiling = false

        super.init(coder: coder)
    }

    public override var windowNibName: NSNib.Name? {
        return "Project"
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private final func updateSettings(_ not: Notification) {
        // Only this project's settings (every project's post the notification)
        if (not.object as AnyObject?) !== project?.settings { return }

        // Mark document as edited. This ensures a recompile happens on the next 'Go!', for example.
        project?.updateChangeCount(.changeDone)
    }

    var safeToSwitchTabs: Bool {
        return !betweenWindowLoadedAndBecomingMain
    }

    public override func windowDidLoad() {
        windowFrameAutosaveName = "ProjectWindow"
        window?.setFrameAutosaveName("ProjectWindow")

        // Once a project has loaded, remove the launcher window
        IFWelcomeWindow.hide()

        // We have loaded the window, but we are not yet main
        betweenWindowLoadedAndBecomingMain = true
    }

    @objc private final func windowDidBecomeMain(_ notification: Notification) {
        betweenWindowLoadedAndBecomingMain = false

        toolbarManager?.redrawToolbar()

        // The window accepts mouse move events
        window?.acceptsMouseMovedEvents = true
    }

    @objc private final func windowWillClose(_ not: Notification) {
        // Perform shutdown
        runningGamePage?.stopRunningGame()

        for pane in projectPanes ?? [] {
            pane.willClose()
        }

        projectPanes = nil
        splitViews = nil

        panesView?.removeFromSuperview()
        panesView = nil
    }

    private final func refreshTestCases() {
        // Run the InTest process to gather the latest array of test cases
        project?.refreshTestCases()

        // Update the toolbar to reflect the changes
        toolbarManager?.setTestCases(project?.testCases)
    }

    @objc(extensionProject)
    var isExtensionProject: Bool {
        @objc(isExtensionProject)
        get {
            return project?.isExtensionProject ?? false
        }
    }

    @objc(currentlyTesting)
    var isCurrentlyTesting: Bool {
        @objc(isCurrentlyTesting)
        get {
            return isExtensionProject && (testAllProgress?.isInProgress ?? false)
        }
    }

    nonisolated public override func awakeFromNib() {
        // Nibs are loaded on the main thread
        MainActor.assumeIsolated {
            // Setup the default panes
            projectPanes?.removeAll()
            projectPanes?.append(IFProjectPane.standard())
            projectPanes?.append(IFProjectPane.standard())

            layoutPanes()

            // Initial panes are source and documentation
            projectPanes?[0].selectView(of: .sourcePane)
            projectPanes?[1].selectView(of: .documentationPane)

            projectPanes?[0].sourcePage.setSpellChecking(
                (NSApp.delegate as? IFAppDelegate)?.sourceSpellChecking ?? false)
            projectPanes?[1].sourcePage.setSpellChecking(
                (NSApp.delegate as? IFAppDelegate)?.sourceSpellChecking ?? false)

            // Monitor for compiler finished notifications
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(compilerFinished(_:)),
                                                   name: .IFCompilerFinished,
                                                   object: project?.compiler)

            // Fullscreen mode
            window?.collectionBehavior.insert(.fullScreenPrimary)

            // Create the toolbar view
            toolbarManager?.setToolbar()

            // Update the toolbar to reflect the test cases
            toolbarManager?.setTestCases(project?.testCases)
        }
    }

    // == Project pane layout ==

    func layoutPanes() {
        guard let projectPanes, projectPanes.count != 0 else {
            return
        }

        // Remove any previous panes
        for pane in projectPanes {
            pane.removeFromSuperview()
        }
        for splitView in splitViews ?? [] {
            splitView.removeFromSuperview()
        }
        splitViews?.removeAll()

        // Remove panesView itself from window
        for subview in panesView?.subviews ?? [] {
            subview.removeFromSuperview()
        }

        if projectPanes.count == 1 {
            // Just one pane
            let firstPane = projectPanes[0]

            firstPane.setController(self, viewIndex: 1)

            firstPane.paneView.frame = panesView?.bounds ?? .zero
            panesView?.addSubview(firstPane.paneView)
        } else {
            // Create the splitViews
            var dividerWidth: CGFloat = 5

            let nviews = projectPanes.count
            for _ in 0..<nviews - 1 {
                let newView = ThinSplitView()

                newView.isVertical = true
                newView.delegate = self
                newView.autoresizingMask = [.width, .height]

                dividerWidth = newView.dividerThickness

                splitViews?.append(newView)
            }

            // Work out the widths of the panes using the preferences
            let dividerProportions = UserDefaults.standard.array(forKey: IFSplitViewSizes)
            let paneWidths = IFPaneWidths.widths(ofPanes: nviews,
                                                 inWidth: panesView?.bounds.size.width ?? 0,
                                                 dividerWidth: dividerWidth,
                                                 proportions: dividerProportions)

            // Size and add the views appropriately
            var totalRemaining   = panesView?.bounds.size.width ?? 0
            var viewWidth: CGFloat = 0

            // Insert the views
            var lastView: NSSplitView? = nil
            for view in 0..<nviews - 1 {
                // Garner some information about the views we're dealing with
                // (There are split views whenever there are panes, until the window closes)
                guard let thisView = splitViews?[view] else { continue }
                let pane     = projectPanes[view]
                let thisPane = projectPanes[view].paneView

                pane.setController(self, viewIndex: view)

                viewWidth = CGFloat(paneWidths[view].doubleValue)

                // Resize the splitview
                var splitFrame: NSRect
                if let lastView {
                    splitFrame = lastView.bounds
                    splitFrame.origin.x += viewWidth + dividerWidth
                    splitFrame.size.width = totalRemaining
                } else {
                    splitFrame = panesView?.bounds ?? .zero
                }
                thisView.frame = splitFrame

                // Add it as a subview
                if let lastView {
                    lastView.addSubview(thisView)
                } else {
                    panesView?.addSubview(thisView)
                }

                // Add the leftmost view
                var paneFrame = thisView.bounds
                paneFrame.size.width = viewWidth

                thisPane.frame = paneFrame
                thisView.addSubview(thisPane)
                thisView.delegate = self

                lastView = thisView

                // Update the amount of space remaining
                totalRemaining -= viewWidth + dividerWidth
            }

            // Final view
            let finalPane = projectPanes[nviews - 1].paneView
            var finalFrame = lastView?.bounds ?? .zero

            projectPanes[nviews - 1].setController(self, viewIndex: nviews - 1)

            finalFrame.origin.x += viewWidth + dividerWidth
            finalFrame.size.width = totalRemaining
            finalPane.frame = finalFrame

            lastView?.addSubview(finalPane)
            lastView?.adjustSubviews()
        }
    }

    func splitViewDidResizeSubviews(_ aNotification: Notification) {
        // Update the preferences with the view widths
        var paneWidths: [NSNumber] = []

        let totalWidth = window?.frame.size.width ?? 0

        for pane in projectPanes ?? [] {
            let paneFrame = pane.paneView.frame

            paneWidths.append(NSNumber(value: Double(paneFrame.size.width)))
        }

        let viewSizes = IFPaneWidths.proportions(ofWidths: paneWidths,
                                                 inWindowWidth: totalWidth)
        UserDefaults.standard.set(viewSizes, forKey: IFSplitViewSizes)
    }

    // == Toolbar item validation ==

    public override func changeFirstResponder(_ first: NSResponder?) {
        if let first = first as? NSView {
            var firstView: NSView? = first
            var pane: IFProjectPane? = nil

            while let view = firstView {
                if view is NSTabView {
                    // See if this is the tab view for a specific pane
                    var found = false
                    for possiblePane in projectPanes ?? [] {
                        if possiblePane.tabView === view {
                            pane = possiblePane
                            found = true
                            break
                        }
                    }

                    // Keep this view, if it's a suitable candidate
                    if found { break }
                    pane = nil
                }

                // Continue up the tree
                firstView = view.superview
            }

            currentPane?.setIsActive(false)
            pane?.setIsActive(true)

            currentPane = pane
            currentTabView = firstView as? NSTabView
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        return IFProjectMenuValidation.isEnabledAction(menuItem.action,
                                                       tag: menuItem.tag,
                                                       in: self)
    }

    // MARK: - What the menu's commands depend on

    var numberOfToolbarTestCases: UInt {
        return UInt(toolbarManager?.testCases?.count ?? 0)
    }

    var toolbarTestCase: String? {
        return toolbarManager?.currentTestCase
    }

    @objc(compilerRunning)
    var isCompilerRunning: Bool {
        @objc(isCompilerRunning)
        get {
            return project?.compiler.isRunning ?? false
        }
    }

    @objc(usingNaturalInform)
    var isUsingNaturalInform: Bool {
        @objc(isUsingNaturalInform)
        get {
            return project?.settings.usingNaturalInform ?? false
        }
    }

    @objc(textViewFirstResponder)
    var isTextViewFirstResponder: Bool {
        @objc(isTextViewFirstResponder)
        get {
            return window?.firstResponder is NSTextView
        }
    }

    var firstResponderSelectionLength: UInt {
        return UInt((window?.firstResponder as? NSTextView)?.selectedRange().length ?? 0)
    }

    var firstResponderHasIntelligence: Bool {
        guard let textView = window?.firstResponder as? NSTextView,
              let storage = IFSyntaxManager.registeredStorage(for: textView) else {
            return false
        }

        return IFSyntaxManager.intelligenceData(for: storage) != nil
    }

    var hasCurrentTabView: Bool {
        return currentTabView != nil
    }

    @objc(sourcePaneCurrent)
    var isSourcePaneCurrent: Bool {
        @objc(isSourcePaneCurrent)
        get {
            return currentPane?.currentView == .sourcePane
        }
    }

    var hasCurrentSkein: Bool {
        return project?.currentSkein != nil
    }

    func canSelectIndexTab(_ tab: Int32) -> Bool {
        return projectPanes?[0].indexPage.canSelectIndexTab(tab) ?? false
    }

    private final func getNumberOfTestCases() -> Int32 {
        if isExtensionProject {
            return toolbarManager?.numberOfTestCases ?? 0
        }
        return 0
    }

    private final func currentTestCase() -> String? {
        if isExtensionProject {
            // If we are doing "Test All", get the current test case based on index
            if testCaseRun.currentIndex >= 0 {
                return toolbarManager?.getTestCase(testCaseRun.currentIndex)
            }

            // Get the currently selected test case from the toolbar
            return toolbarManager?.currentTestCase
        }
        return nil
    }

    private final func performCompile(withRelease release: Bool,
                                      forTesting releaseForTesting: Bool,
                                      refreshOnly onlyRefresh: Bool,
                                      testCase: String?) {
        let doc = project

        // Remove temporary highlighting
        removeHighlights(of: .error)

        // Save the project, without user interaction. Also refreshes available test cases
        saveDocument(self)

        // Extract current test case as a story
        doc?.extractSourceTask(forExtensionTestCase: currentTestCase())

        // Stop the current game
        for pane in projectPanes ?? [] {
            pane.stopRunningGame()
        }

        // Update toolbar
        toolbarManager?.validateVisibleItems()

        // Set up the compiler
        let theCompiler = doc?.prepareCompiler(forRelease: release,
                                               forTesting: releaseForTesting,
                                               refreshOnly: onlyRefresh,
                                               testCase: testCase)
        if let theCompiler {
            // Start progress indicator
            addProgressIndicator(theCompiler.progress)
            theCompiler.progress.start()

            // Clear the console only on the first compilation of this run
            if !testCaseRun.isOnALaterTestCase {
                theCompiler.clearConsole()
            }

            compileCheck.compileDidStart(forRelease: release)
            theCompiler.launch()
            compiling = true
        } else {
            let version = doc?.settings.compilerVersion ?? ""
            let message = String(format: IFUtility.localizedString("One possibility is that the project's language version '%@' is not available. Try setting the language version in Settings."),
                                 version)
            IFUtility.runAlertWarning(window,
                                      localizedTitle: IFUtility.localizedString("Could not launch compiler."),
                                      informativeText: message)
        }

        // Show the Console pane if required
        if !isTestAllCasesSelected {
            if IFPreferences.shared.showConsoleDuringBuilds {
                projectPanes?[1].selectView(of: .errorPane)
            }
        }
    }

    func showPublicLibrary() {
        currentTabView?.selectTabViewItem(withIdentifier: IFExtensionsPage.description())
        if projectPanes?[1].currentView == .extensionsPane {
            projectPanes?[1].extensionsPage.showPublicLibrary(nil)
        }
    }

    // == View selection functions ==

    @IBAction private final func saveDocument(_ sender: Any?) {
        // Need to call prepareToSave here to give the project panes a chance to shut down any editing operations that
        // might be ongoing
        for pane in projectPanes ?? [] {
            pane.prepareToSave()
        }

        // Save the project, without user interaction.
        project?.saveDocumentWithoutUserInteraction()

        // Refresh the available test cases
        refreshTestCases()
    }

    /// The folders of the extensions the project's story may include: those installed in the project's materials and
    /// in the user's Library, and Inform's own for the project's version of Inform
    private final var extensionFolderURLs: [URL] {
        var folders = [URL(fileURLWithPath: IFUtility.pathForInformExternalExtensions())]
        if let materials = project?.materialsDirectoryURL {
            folders.append(materials.appendingPathComponent("Extensions"))
        }
        if let settings = project?.settings {
            folders.append(URL(fileURLWithPath: IFUtility.path(forInformInternalExtensions: settings.compilerVersion)))
        }
        return folders
    }

    private final func make(withRelease release: Bool,
                            forTesting releaseForTesting: Bool,
                            refreshOnly onlyRefresh: Bool,
                            forceCompile: Bool,
                            onSuccess: Selector) {
        let needsToCompile = compileCheck.needsCompileForcing(forceCompile,
                                                              alwaysCompile: IFPreferences.shared.alwaysCompile,
                                                              unsavedChanges: project?.hasUnautosavedChanges ?? false,
                                                              sourceURL: project?.mainSourceFileURL,
                                                              settingsURL: project?.settingsFileURL,
                                                              extensionFolderURLs: extensionFolderURLs,
                                                              outputURL: project?.buildOutputFileURL)

        if needsToCompile {
            compileFinishedAction = onSuccess

            performCompile(withRelease: release,
                           forTesting: releaseForTesting,
                           refreshOnly: onlyRefresh,
                           testCase: currentTestCase())
        } else {
            showMessage(IFUtility.localizedString("No compilation required."))

            IFUtility.perform(onSuccess, object: self)
        }
    }

    @IBAction func release(_ sender: Any?) {
        make(withRelease: true,
             forTesting: false,
             refreshOnly: false,
             forceCompile: true,
             onSuccess: #selector(saveCompilerOutput))
    }

    @IBAction func releaseForTesting(_ sender: Any?) {
        make(withRelease: true,
             forTesting: true,
             refreshOnly: false,
             forceCompile: true,
             onSuccess: #selector(saveCompilerOutput))
    }

    @IBAction func compile(_ sender: Any?) {
        make(withRelease: false,
             forTesting: false,
             refreshOnly: false,
             forceCompile: true,
             onSuccess: #selector(saveCompilerOutput))
    }

    @IBAction func compileAndRefresh(_ sender: Any?) {
        make(withRelease: false,
             forTesting: false,
             refreshOnly: true,
             forceCompile: true,
             onSuccess: #selector(refreshIndexTabs))
    }

    @IBAction func compileAndRun(_ sender: Any?) {
        if !compiling {
            // In place of any threads Play All has left
            playAll = nil
            gamePage?.setSwitchTo(true)
            gamePage?.setTestCommands(nil)

            make(withRelease: false,
                 forTesting: false,
                 refreshOnly: false,
                 forceCompile: false,
                 onSuccess: #selector(runCompilerOutput))
        }
    }

    @objc(testAllCasesSelected)
    var isTestAllCasesSelected: Bool {
        @objc(isTestAllCasesSelected)
        get {
            if isExtensionProject {
                return toolbarManager?.currentTestCase == nil
            }
            return false
        }
    }

    @IBAction func testMe(_ sender: Any?) {
        // In place of any threads Play All has left
        playAll = nil

        if isExtensionProject {
            if isTestAllCasesSelected {
                // Run all test cases
                testCaseRun.chooseTestCases(from: 0,
                                            to: getNumberOfTestCases() - 1)
            } else {
                // Run a specific test only
                let testCaseIndex = toolbarManager?.testCaseIndex ?? 0
                testCaseRun.chooseTestCases(from: testCaseIndex,
                                            to: testCaseIndex)
            }

            // Compile and run each test case in turn
            if testCaseRun.currentIndex == -1 {
                // Create new progress
                let progress = IFProgress(priority: IFProgressPriorityTestAll,
                                          showsProgressBar: true,
                                          canCancel: true)
                testAllProgress = progress
                addProgressIndicator(progress)
                progress.start()

                // If the left side is the skein, show the source instead.
                if projectPanes?[0].currentView == .skeinPane {
                    projectPanes?[0].selectView(of: .sourcePane)
                }

                // Show the skein page on the right
                projectPanes?[1].selectView(of: .skeinPane)

                startNextTestCase()

                // Update toolbar
                toolbarManager?.validateVisibleItems()
                return
            }
            return
        } else {
            // Show the game page on the right
            gamePage?.setSwitchTo(true)
        }

        // Test current case
        testMeInternal()
    }

    private final func testMeInternal() {
        if isExtensionProject {
            if testCaseRun.currentIndex >= 0 {
                project?.selectSkein(testCaseRun.currentIndex)
            }
        }

        make(withRelease: false,
             forTesting: false,
             refreshOnly: false,
             forceCompile: true,
             onSuccess: #selector(runCompilerOutputAndTest))
    }

    @IBAction func replayUsingSkein(_ sender: Any?) {
        make(withRelease: false,
             forTesting: false,
             refreshOnly: false,
             forceCompile: false,
             onSuccess: #selector(runCompilerOutputAndReplay))
    }

    @IBAction func replayEntireSkein(_ sender: Any?) {
        if !isTestAllCasesSelected {
            // Always recompile
            make(withRelease: false,
                 forTesting: false,
                 refreshOnly: false,
                 forceCompile: false,
                 onSuccess: #selector(runCompilerOutputAndEntireSkein))
        }
    }

    @IBAction func compileAndDebug(_ sender: Any?) {
        // In place of any threads Play All has left
        playAll = nil

        gamePage?.setSwitchTo(true)
        gamePage?.setTestCommands(nil)

        make(withRelease: false,
             forTesting: false,
             refreshOnly: false,
             forceCompile: false,
             onSuccess: #selector(debugCompilerOutput))
    }

    @IBAction func stopProcess(_ sender: Any?) {
        // Play All's threads left are dropped, or they'd be played when what's played next runs out of commands
        playAll = nil

        for pane in projectPanes ?? [] {
            pane.stopRunningGame()
        }
    }

    @IBAction func openMaterials(_ sender: Any?) {
        project?.openMaterials()
    }

    @IBAction func exportIFiction(_ sender: Any?) {
        // Compile and export the iFiction metadata
        make(withRelease: false,
             forTesting: false,
             refreshOnly: false,
             forceCompile: false,
             onSuccess: #selector(saveIFiction))
    }

    @objc private final func saveIFiction() {
        // IFiction compilation has finished
        if let window, let project {
            IFProjectPanels(project: project).saveIFiction(with: window)
        }
    }

    // MARK: - Displaying a specific index tab

    @IBAction func showIndexTab(_ sender: Any?) {
        let tag = Int32(truncatingIfNeeded: (sender as? NSMenuItem)?.tag ?? 0)

        for pane in projectPanes ?? [] {
            pane.indexPage.switch(toTab: tag)
        }

        indexPane?.selectView(of: .indexPane)
    }

    // MARK: - Things to do after the compiler has finished

    @objc private final func refreshIndexTabs() {
        // Display the index pane
        indexPane?.selectView(of: .indexPane)
    }

    @objc private final func saveCompilerOutput() {
        // Check to see if one of the compile controllers has already got a save location for the game
        let paneController = projectPanes?[0].compilerController
        let copyLocation = paneController?.blorbLocation

        // Show the 'success' pane
        projectPanes?[1].selectView(of: .errorPane)

        if let copyLocation {
            // Copy the result to the specified location (overwriting any existing file)
            try? FileManager.default.removeItem(atPath: copyLocation)
            if let outputFile = project?.compiler.outputFile {
                try? FileManager.default.copyItem(atPath: outputFile,
                                                  toPath: copyLocation)
            }
        } else {
            if let window, let project {
                IFProjectPanels(project: project).saveCompilerOutput(with: window)
            }
        }
    }

    @objc private final func runCompilerOutputAndTest() {
        // Set test commands
        if isExtensionProject {
            let testCommands = project?.testCommands(forExtensionTestCase: currentTestCase() ?? "")
            gamePage?.setTestCommands(testCommands)
        } else {
            gamePage?.setTestCommands(["test me"])
        }

        runCompilerOutput()
    }

    @objc private final func runCompilerOutput() {
        gamePage?.startRunningGame(project?.buildOutputFileURL?.path ?? "")

        toolbarManager?.validateVisibleItems()
    }

    @objc private final func runCompilerOutputAndReplay() {
        playAll = nil

        gamePage?.setSwitchTo(true)
        // The skein's previous commands are most recent first
        let commands = project?.currentSkein?.previousCommands.reverseObjectEnumerator().allObjects as? [String]
        gamePage?.setTestCommands(commands)
        runCompilerOutput()
    }

    @objc private final func debugCompilerOutput() {
        gamePage?.activateDebug()
        gamePage?.startRunningGame(project?.compiler.outputFile ?? "")

        toolbarManager?.validateVisibleItems()
    }

    private final func createAndShowReport(_ numTests: Int32, reportURL: URL?) {
        if numTests > 1 {
            if let baseReportURL = project?.baseReportURL,
               let combinedReportURL = project?.combinedReportURL {
                project?.generateCombinedReport(forBaseInputURL: baseReportURL,
                                                numTests: numTests,
                                                outputURL: combinedReportURL)
            }
        } else {
            if let reportURL,
               let combinedReportURL = project?.combinedReportURL {
                IFTestReport.copy(reportURL,
                                  toCombinedURL: combinedReportURL)
            }
        }

        updateBuildResults()
        projectPanes?[1].selectView(of: .errorPane)
    }

    private final func updateBuildResults() {
        let buildURL = project?.buildDirectoryURL
        let buildDir = buildURL.flatMap { try? FileWrapper(url: $0, options: .immediate) }

        for pane in projectPanes ?? [] {
            pane.compilerController.clearTabViewsExcept(.tabConsole)
            if let buildDir, let buildPath = buildURL?.path {
                pane.compilerController.showContentsOfFiles(in: buildDir,
                                                            fromPath: buildPath)
            }
        }
    }

    @objc private final func compilerFinished(_ not: Notification) {
        let exitCode = (not.userInfo?["exitCode"] as? NSNumber)?.int32Value ?? 0
        // (A C enum takes any raw value)
        let problemType = ECompilerProblemType(rawValue: (not.userInfo?["problemType"] as? NSNumber)?.int32Value ?? 0)!
        let intestCode = IFTestReport.intestCode(for: problemType)

        if let progress = project?.compiler.progress {
            removeProgressIndicator(progress)
        }

        if exitCode != 0 || (not.object as? IFCompiler)?.problemsURL != nil {
            if !isTestAllCasesSelected {
                // Show the errors pane if there was an error while compiling
                projectPanes?[1].selectView(of: .errorPane)
            }
        }

        // Re-read the contents of the directory, now that the compiler has written a bunch of files there
        project?.reloadDirectory()

        // Show the 'build results' files
        updateBuildResults()

        // Update the index tab(s)
        for pane in projectPanes ?? [] {
            pane.indexPage.updateIndexView()
        }

        // Make a report if there was an error while compiling a test case
        var reportURL: URL? = nil
        if isCurrentlyTesting {
            if let intestCode {
                reportURL = project?.currentReportURL

                if let reportURL {
                    project?.generateReport(forTestCase: currentTestCase() ?? "",
                                            errorCode: intestCode,
                                            skeinNodeId: 0,
                                            skeinNodes: 0,
                                            outputURL: reportURL)
                }
                project?.reloadSourceDirectory()
            }
        }

        if exitCode == 0 {
            compileCheck.compileDidSucceed()
            // Success!
            if let compileFinishedAction {
                IFUtility.perform(compileFinishedAction, object: self)
            }
        }

        compiling = false
        compileFinishedAction = nil
        toolbarManager?.validateVisibleItems()

        // If not successful, start the next test case
        if exitCode != 0 && isCurrentlyTesting {
            if startNextTestCaseSoon() {
                return
            }

            // All test cases finished.

            // Create a consolidated report and display it.
            if !(testAllProgress?.isCancelled ?? false) && reportURL != nil {
                createAndShowReport(testCaseRun.numberTested, reportURL: reportURL)
            }
        }
    }

    // MARK: - Communication from the containing panes

    /// What each of the panes is showing, as IFProjectPaneType numbers
    private final func paneViews() -> [NSNumber] {
        var views: [NSNumber] = []
        for pane in projectPanes ?? [] {
            views.append(NSNumber(value: pane.currentView.rawValue))
        }
        return views
    }

    var sourcePane: IFProjectPane? {
        return projectPanes?[IFPaneChoice.sourcePane(forViews: paneViews())]
    }

    var auxPane: IFProjectPane? {
        return projectPanes?[IFPaneChoice.auxPane(forViews: paneViews())]
    }

    var indexPane: IFProjectPane? {
        return projectPanes?[IFPaneChoice.indexPane(forViews: paneViews())]
    }

    func oppositePane(_ pane: IFProjectPane) -> IFProjectPane? {
        // Find this pane
        guard let projectPanes,
              let index = projectPanes.firstIndex(where: { $0 === pane }) else { return nil }

        return projectPanes[IFPaneChoice.paneOppositePane(index, count: projectPanes.count)]
    }

    private final func loadInform7Extension(withFullFilePath extnFile: String) {
        // Find existing document
        if let newDoc = NSDocumentController.shared.document(for: URL(fileURLWithPath: extnFile)) {
            // Force it to the front
            for controller in newDoc.windowControllers {
                controller.window?.makeKeyAndOrderFront(self)
            }
        } else {
            // If it doesn't exist, then construct it
            guard let newDoc = try? IFSingleFile(contentsOf: URL(fileURLWithPath: extnFile),
                                                 ofType: "Inform 7 extension") else {
                return
            }

            NSDocumentController.shared.addDocument(newDoc)
            newDoc.makeWindowControllers()
            newDoc.showWindows()
        }
    }

    private final func loadInform7Extension(_ filename: String) -> Bool {
        guard let extnFile = IFExtensionFileFinder.file(forExtension: filename,
                                                        extensionsManager: IFExtensionsManager.sharedNaturalInform)
        else {
            return false
        }

        // This is the extension file we need to open
        loadInform7Extension(withFullFilePath: extnFile)
        return true
    }

    func showTestCase(_ testCase: String, skeinNode skeinNodeId: UInt) -> Bool {
        // Select this test case
        if !(toolbarManager?.selectTestCase(testCase) ?? false) {
            return false
        }

        // Switch panes to the testing pane
        projectPanes?[0].selectView(of: .skeinPane)

        // Select the problem node in the skein
        for pane in projectPanes ?? [] {
            let skeinPage = pane.skeinPage
            skeinPage.selectSkeinItem(withNodeId: skeinNodeId)
        }
        return true
    }

    func selectSourceFile(_ fileName: String) -> Bool {
        if project?.storage(forFile: fileName) != nil {
            // Load this file
            sourcePage?.showSourceFile(fileName)
        } else if !loadInform7Extension(fileName) {
            // Display an error if we couldn't find the file
            let description = IFUtility.localizedString("Unable to open source file description")
            IFUtility.runAlertWarning(window,
                                      title: "Unable to open source file",
                                      informativeText: description)
        }

        return true
    }

    private final var sourcePage: IFSourcePage? {
        return sourcePane?.sourcePage
    }

    func move(toSourceFileLine line: Int) {
        let thePane = sourcePane

        thePane?.selectView(of: .sourcePane)
        thePane?.sourcePage.move(toLine: line)
        window?.makeFirstResponder(thePane?.activeView)
    }

    private final func selectSourceFileRange(_ range: NSRange) {
        let thePane = sourcePane

        thePane?.selectView(of: .sourcePane)
        thePane?.sourcePage.indicateRange(range)

        window?.makeFirstResponder(thePane?.activeView)
    }

    @objc(removeHighlightsInFile:ofStyle:)
    func removeHighlights(inFile file: String, of style: IFLineStyle) {
        let file = project?.path(forSourceFile: file)

        let updated = highlights.removeHighlights(of: style,
                                                  inFile: file)

        if updated {
            for pane in projectPanes ?? [] {
                if let panePath = project?.path(forSourceFile: pane.sourcePage.currentFile), panePath == file {
                    pane.sourcePage.updateHighlightedLines()
                }
            }
        }
    }

    @objc(removeHighlightsOfStyle:)
    func removeHighlights(of style: IFLineStyle) {
        // Remove highlights in all files
        for file in highlights.files {
            removeHighlights(inFile: file,
                             of: style)
        }
    }

    func removeAllTemporaryHighlights() {
        if !highlights.hasTemporaryHighlights { return }

        for style in IFLineStyle._Temporary.rawValue..<IFLineStyle._LastTemporary.rawValue {
            // (A C enum takes any raw value)
            removeHighlights(of: IFLineStyle(rawValue: style)!)
        }

        highlights.temporaryHighlightsWereRemoved()
    }

    func highlightSourceFileLine(_ line: Int,
                                 inFile file: String,
                                 style: IFLineStyle) {
        // Get the 'true' path to this file (none without a project, where the Objective-C raised an exception)
        guard let file = project?.path(forSourceFile: file) else { return }

        // See if there's a document that manages this file
        let fileDocument = NSDocumentController.shared.document(for: URL(fileURLWithPath: file))
        if let fileDocument, fileDocument !== document, !fileDocument.isEqual(document) {
            // Pass this message on to this document's controllers
            for docController in fileDocument.windowControllers {
                // If this controller is capable of highlighting lines, tell it to do so
                (docController as AnyObject).highlightSourceFileLine?(line,
                                                                      inFile: file,
                                                                      style: style)
            }
            return
        }

        highlights.highlightLine(line,
                                 inFile: file,
                                 style: style)

        // Display the highlight
        for pane in projectPanes ?? [] {
            if let panePath = project?.path(forSourceFile: pane.sourcePage.currentFile), panePath == file {
                pane.sourcePage.updateHighlightedLines()

                if highlights.hasTemporaryHighlights {
                    pane.sourcePage.indicateLine(Int32(truncatingIfNeeded: line))
                }
            }
        }
    }

    func highlights(forFile file: String?) -> [[NSNumber]]? {
        let file = project?.path(forSourceFile: file)

        return highlights.highlights(inFile: file)
    }

    // MARK: - Debugging controls

    var runningGamePane: IFProjectPane? {
        // Return the pane that we're displaying/going to display the game in
        for pane in projectPanes ?? [] {
            if pane.gamePage?.isRunningGame ?? false { return pane }
        }

        return nil
    }

    private final var runningGamePage: IFGamePage? {
        return runningGamePane?.gamePage
    }

    private final var gamePage: IFGamePage? {
        return projectPanes?[1].gamePage
    }

    var currentIntelligence: IFIntelFile? {
        return sourcePage?.currentIntelligence
    }

    // MARK: - Documentation controls

    func docIndex(_ sender: Any?) {
        auxPane?.documentationPage.open(URL(string: "inform:/index.html")!)
    }

    @IBAction func docRecipes(_ sender: Any?) {
        // The contents of the Recipe Book (the old Recipe Book, until 2024, started at Rdoc1.html)
        auxPane?.documentationPage.open(URL(string: "inform:/RB_index.html")!)
    }

    @IBAction func docExtensions(_ sender: Any?) {
        let extensions: String

        if project?.useNewExtensions ?? false {
            extensions = "inform://Extensions/Reserved/Documentation/Extensions.html"
        } else {
            extensions = "inform://Extensions/Extensions.html"
        }
        auxPane?.extensionsPage.open(URL(string: extensions)!)
    }

    // MARK: - New Extensions

    @IBAction func addExtensionFromFile(_ sender: Any?) {
        addExtensionFromFile(usingPanel: \.openExtensionPanel,
                             withInitialDirectory: nil)
    }

    @IBAction func addExtensionFromLegacyInstalledFolder(_ sender: Any?) {
        addExtensionFromFile(usingPanel: \.openLegacyExtensionPanel,
                             withInitialDirectory: URL(fileURLWithPath: IFUtility.pathForInformExternalExtensions()))
    }

    @IBAction private final func gotoPublicLibrary(_ sender: Any?) {
        window?.makeKeyAndOrderFront(self)
        gotoRightPane(sender)
        showPublicLibrary()
    }

    func confirmInbuildAction() {
        if let extensionURL {
            let project = self.project
            project?.executeInBuild(forExtension: extensionURL as URL,
                                    action: inbuildAction,
                                    withConfirmation: true)

            // Show results
            for pane in projectPanes ?? [] {
                pane.compilerController.clearTabViewsExcept(.tabConsole)
                let id = pane.compilerController.makeTab(forFile: project?.extensionReportURL?.path ?? "")
                pane.compilerController.switchToView(with: id)
            }
            projectPanes?[1].selectView(of: .errorPane)
        }
    }

    func installExtension(_ extensionPath: String) {
        installExtensionURL(URL(fileURLWithPath: extensionPath))
    }

    func installExtensionURL(_ extensionURL: URL) {
        self.extensionURL = extensionURL as NSURL
        inbuildAction = "-install"

        let project = self.project
        project?.executeInBuild(forExtension: extensionURL,
                                action: inbuildAction,
                                withConfirmation: false)

        // Show results
        for pane in projectPanes ?? [] {
            pane.compilerController.clearTabViewsExcept(.tabConsole)
            let id = pane.compilerController.makeTab(forFile: project?.extensionReportURL?.path ?? "")
            pane.compilerController.switchToView(with: id)
        }
        projectPanes?[1].selectView(of: .errorPane)
    }

    func uninstallExtension(_ extensionPath: String) {
        let project = self.project
        let extensionURL = URL(fileURLWithPath: extensionPath)
        self.extensionURL = extensionURL as NSURL
        inbuildAction = "-uninstall"

        project?.executeInBuild(forExtension: extensionURL,
                                action: inbuildAction,
                                withConfirmation: false)

        // Show results
        for pane in projectPanes ?? [] {
            pane.compilerController.clearTabViewsExcept(.tabConsole)
            let id = pane.compilerController.makeTab(forFile: project?.extensionReportURL?.path ?? "")
            pane.compilerController.switchToView(with: id)
        }
        projectPanes?[1].selectView(of: .errorPane)
    }

    func moderniseExtension(_ extensionPath: String) {
        moderniseExtensionURL(URL(fileURLWithPath: extensionPath))
    }

    private final func moderniseExtensionURL(_ extensionURL: URL) {
        self.extensionURL = extensionURL as NSURL
        inbuildAction = "-run-moderniser"

        let project = self.project
        project?.executeInBuild(forExtension: extensionURL,
                                action: inbuildAction,
                                withConfirmation: false)

        // Show results
        for pane in projectPanes ?? [] {
            pane.compilerController.clearTabViewsExcept(.tabConsole)
            let id = pane.compilerController.makeTab(forFile: project?.extensionReportURL?.path ?? "")
            pane.compilerController.switchToView(with: id)
        }
        projectPanes?[1].selectView(of: .errorPane)
    }

    func testExtension(_ extensionPath: String,
                       command: String,
                       testcase: String) {
        let project = self.project

        for pane in projectPanes ?? [] {
            pane.compilerController.clearConsole(nil)
        }
        projectPanes?[1].selectView(of: .errorPane)

        project?.testExtension(extensionPath,
                               command: command,
                               testcase: testcase)

        for pane in projectPanes ?? [] {
            pane.compilerController.switchToSplitView()
        }
    }

    /// Shows the panel kept in the property given (making it if there's none) for choosing extensions to install
    private final func addExtensionFromFile(usingPanel pPanel: IFOpenPanelProperty,
                                            withInitialDirectory initialURL: URL?) {
        // Present a panel for installing new extensions
        if self[keyPath: pPanel] == nil {
            self[keyPath: pPanel] = NSOpenPanel()
        }
        guard let panel = self[keyPath: pPanel] else { return }

        if let initialURL {
            panel.directoryURL = initialURL
        }
        panel.accessoryView           = nil
        panel.canChooseFiles          = true
        panel.canChooseDirectories    = true
        panel.resolvesAliases         = true
        panel.allowsMultipleSelection = true
        panel.title = IFUtility.localizedString("Install Inform 7 Extension")
        panel.delegate = self    // Determines which file types are valid to choose (panel:shouldEnableURL)

        panel.begin { result in
            self[keyPath: pPanel]?.delegate = nil

            if result != .OK { return }

            guard let url = self[keyPath: pPanel]?.url,
                  let project = self.project else { return }
            let name = url.lastPathComponent
            self.extensionURL = IFNewExtensionsManager.shared.copy(withUnzip: url,
                                                                   toProjectTemporary: project,
                                                                   extensionName: name) as NSURL?
            if let extensionURL = self.extensionURL {
                // Call inbuild to check it's a valid extension and install
                self.installExtensionURL(extensionURL as URL)
            }
        }
    }

    @objc(panel:shouldEnableURL:)
    func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path,
                                                    isDirectory: &isDir)
        if !exists { return false }
        if isDir.boolValue {
            if NSWorkspace.shared.isFilePackage(atPath: url.path) {
                return false
            }
            return true
        }

        let extn = url.pathExtension.lowercased()

        if extn == "i7x" ||
           extn == "i7xd" ||
           extn == "zip" {
            return true
        }
        return false
    }

    // MARK: - Skein delegate

    func stopGame() {
        // Play All's threads left are dropped, as for Stop
        playAll = nil

        let gamePage = self.gamePage

        if gamePage?.isRunningGame ?? false {
            gamePage?.stopRunningGame()
        }
    }

    func play(toPoint point: IFSkeinItem,
              fromPoint currentPoint: IFSkeinItem) {
        // In place of any threads Play All has left
        playAll = nil

        if gamePage?.isRunningGame ?? false {
            let inputSource = IFSkein.inputSource(from: currentPoint,
                                                  to: point)

            let zView = runningGamePage?.zoomView
            let gView = runningGamePage?.glkView

            if let zView {
                zView.inputSource = inputSource
            } else {
                glkInputSource = inputSource
                gView?.addInputReceiver(self)
                gView?.alwaysPageOnMore = true

                viewIsWaiting(forInput: gView)
            }
        } else {
            compileAndRun(self)
            gamePage?.setSwitchTo(false)
            gamePage?.setPointToRunTo(point)
        }
    }

    // MARK: - Displaying progress

    private final func showMessage(_ message: String) {
        toolbarManager?.showMessage(message)
    }

    func addProgressIndicator(_ indicator: IFProgress) {
        toolbarManager?.addProgressIndicator(indicator)
    }

    func removeProgressIndicator(_ indicator: IFProgress) {
        toolbarManager?.removeProgressIndicator(indicator)
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        return toolbarManager?.validateToolbarItem(item) ?? false
    }

    // MARK: - Dealing with search panels

    func searchShowSelectedItem(atLocation location: Int,
                                phrase: String,
                                inFile filename: String,
                                type: IFFindLocation,
                                anchorTag: String?) {
        // If the match is a document, order the documentation pane to display it
        // (Not sure how to deal with the location: I don't think it makes much sense
        // relative to a web view)

        if type.contains(.documentationBasic) ||
           type.contains(.documentationSource) ||
           type.contains(.documentationDefinitions) {
            // Doc pane
            let urlString: String

            if let anchorTag, !anchorTag.isEmpty {
                urlString = "inform:/\((filename as NSString).lastPathComponent)#\(anchorTag)"
            } else {
                urlString = "inform:/\((filename as NSString).lastPathComponent)"
            }

            // (The Objective-C passed on no URL, where the string doesn't make one)
            if let url = URL(string: urlString) {
                auxPane?.documentationPage.open(url)
            }
        } else if type == .extensions {
            // Show the appropriate extension source file
            selectSourceFile(filename)

            // Highlight the appropriate phrase
            let newDoc = NSDocumentController.shared.document(for: URL(fileURLWithPath: filename))
            if let newDoc {
                // Pass this message on to this document's controllers
                for docController in newDoc.windowControllers {
                    // If this controller is capable of indicating lines, tell it to do so
                    (docController as AnyObject).indicateRange?(NSRange(location: location,
                                                                        length: phrase.utf16.count))
                }
            }
        } else {
            // Show the appropriate source file
            selectSourceFile(filename)
            selectSourceFileRange(NSRange(location: location, length: phrase.utf16.count))
        }
    }

    // MARK: - Menu options

    @IBAction func shiftLeft(_ sender: Any?) {
        let responder = window?.firstResponder

        if let textView = responder as? NSTextView, let document = document as? NSDocument {
            sharedActions.shiftLeftTextView(in: document,
                                            textView: textView)
        }
    }

    @IBAction func shiftRight(_ sender: Any?) {
        let responder = window?.firstResponder

        if let textView = responder as? NSTextView, let document = document as? NSDocument {
            sharedActions.shiftRightTextView(in: document,
                                             textView: textView)
        }
    }

    @IBAction func renumberSections(_ sender: Any?) {
        let responder = window?.firstResponder

        if let textView = responder as? NSTextView, let document = document as? NSDocument {
            sharedActions.renumberSections(in: document,
                                           textView: textView)
        }
    }

    @IBAction func commentOutSelection(_ sender: Any?) {
        let responder = window?.firstResponder

        if let textView = responder as? NSTextView, let document = document as? NSDocument {
            sharedActions.commentOutSelection(in: document,
                                              textView: textView)
        }
    }

    @IBAction func uncommentSelection(_ sender: Any?) {
        let responder = window?.firstResponder

        if let textView = responder as? NSTextView, let document = document as? NSDocument {
            sharedActions.uncommentSelection(in: document,
                                             textView: textView)
        }
    }

    // MARK: - Searching

    @IBAction func searchDocs(_ sender: Any?) {
        guard let phrase = (sender as? NSControl)?.stringValue, phrase != "" else { return }

        IFFindInFilesController.shared().showFind(inFilesWindow: self)
        IFFindInFilesController.shared().startFindInFilesSearch(withPhrase: phrase,
                                                                withLocationType: [.documentationBasic,
                                                                                   .documentationSource,
                                                                                   .documentationDefinitions],
                                                                with: containsCaseInsensitive)
    }

    @IBAction func searchProject(_ sender: Any?) {
        guard let phrase = (sender as? NSControl)?.stringValue, phrase != "" else { return }

        IFFindInFilesController.shared().showFind(inFilesWindow: self)
        IFFindInFilesController.shared().startFindInFilesSearch(withPhrase: phrase,
                                                                withLocationType: .source,
                                                                with: containsCaseInsensitive)
    }

    @IBAction func testSelector(_ sender: Any?) {
        // Change test selection
        if let button = sender as? NSPopUpButton {
            let selectedIndex = Int32(truncatingIfNeeded: button.indexOfSelectedItem)
            compileCheck.testCaseDidChange()

            project?.selectSkein(selectedIndex - 1)
        }
    }

    /* For an extension project, we install that extension, otherwise we call the app delegate's
     version to show an open dialog to install any extension */
    @IBAction func installLegacyExtension(_ sender: Any?) {
        if project?.isExtensionProject ?? false {
            // This only applies in an Extension Project.
            // Save extension.i7x (without user interaction) and install it
            saveDocument(sender)

            let doc = project
            var finalPath: NSString? = nil
            let result = IFExtensionsManager.sharedNaturalInform.installLegacyExtension(doc?.mainSourcePathName ?? "",
                                                                                       finalPath: &finalPath,
                                                                                       title: nil,
                                                                                       author: nil,
                                                                                       version: nil,
                                                                                       showWarningPrompts: true,
                                                                                       notify: true)
            if result != .success {
                IFUtility.showExtensionError(result, with: window)
            }
        } else {
            (NSApp.delegate as? IFAppDelegate)?.installLegacyExtension(sender)
        }
    }

    // MARK: - IFRuntimeErrorParser delegate methods

    func runtimeError(_ error: String,
                      inDirectory directory: String?) {
        let project = self.project

        let page = IFRuntimeProblemPage(problem: error,
                                        inDirectory: directory,
                                        materialsDirectory: project?.materialsDirectoryURL?.path,
                                        internalDirectory: IFUtility.path(forInformInternalAppSupport: ""))
        var errorURL = page.appPageURL
        let markdownPath = page.markdownPath

        if let markdownPath {
            // Run inbuild to convert the markdown file to HTML. When that fails, inbuild writes a page about the
            // error there instead, which is shown in its place.
            let htmlURL = IFUtility.temporaryDirectoryURL().appendingPathComponent("temp.html")
            errorURL = htmlURL
            let internalURL = URL(fileURLWithPath: IFUtility.path(forInformInternalAppSupport: ""))
            if let project {
                project.inBuild.execute(forConvertingMarkdown: markdownPath,
                                        toHTML: htmlURL.path,
                                        withInternal: internalURL,
                                        settings: project.settings)
            }
        }

        if let errorURL {
            // For each pane, add the runtime error message
            for pane in projectPanes ?? [] {
                pane.compilerController.showRuntimeError(errorURL)
            }

            // Change the source view to the errors view (so we can see the text leading to the error as well as the
            // error itself
            projectPanes?[0].selectView(of: .errorPane)
        }
    }

    // MARK: - Tabbing around

    private final func activateNearestTextView() {
        // Start from the current tab view
        var first: NSResponder? = currentTabView

        // Get the first responder
        if first == nil { first = window?.firstResponder }

        // Go inside the tab view
        if let tabView = first as? NSTabView {
            // Is a tab view: try the view for the active tab item
            first = tabView.selectedTabViewItem?.view
        }

        // Iterate past things that won't accept the first responder
        while let view = first as? NSView, !view.acceptsFirstResponder {
            if view.subviews.count > 0 {
                first = view.subviews[0]
            } else {
                first = nil
            }
        }

        if let zoomView = first as? ZoomView {
            // Zoom view: use the contained text view
            first = zoomView.textView
        }

        if let scroll = first as? NSScrollView {
            // If a scroll view, then activate the document view
            first = scroll.documentView
        } else if let clip = first as? NSClipView {
            // Same for a clip view
            first = clip.documentView
        }

        if let first, first is NSText {
            // If the contents of the active scroll or clip view is a text view, then make that the first responder
            window?.makeFirstResponder(first)
        }
    }

    @IBAction func tabSource(_ sender: Any?) {
        currentTabView?.selectTabViewItem(withIdentifier: IFSourcePage.description())
        activateNearestTextView()
    }

    @IBAction func tabErrors(_ sender: Any?) {
        currentTabView?.selectTabViewItem(withIdentifier: IFErrorsPage.description())
        activateNearestTextView()
    }

    @IBAction func tabIndex(_ sender: Any?) {
        currentTabView?.selectTabViewItem(withIdentifier: IFIndexPage.description())
        activateNearestTextView()
    }

    @IBAction func tabSkein(_ sender: Any?) {
        currentTabView?.selectTabViewItem(withIdentifier: IFSkeinPage.description())
        activateNearestTextView()
    }

    @IBAction func tabGame(_ sender: Any?) {
        runningGamePane?.tabView.selectTabViewItem(withIdentifier: IFGamePage.description())
        window?.makeFirstResponder(runningGamePane?.tabView)
        activateNearestTextView()
    }

    @IBAction func tabDocumentation(_ sender: Any?) {
        currentTabView?.selectTabViewItem(withIdentifier: IFDocumentationPage.description())
        activateNearestTextView()
    }

    @IBAction func tabExtensions(_ sender: Any?) {
        currentTabView?.selectTabViewItem(withIdentifier: IFExtensionsPage.description())
        activateNearestTextView()
    }

    @IBAction func tabSettings(_ sender: Any?) {
        currentTabView?.selectTabViewItem(withIdentifier: IFSettingsPage.description())
        activateNearestTextView()
    }

    @IBAction func gotoLeftPane(_ sender: Any?) {
        window?.makeFirstResponder(projectPanes?[0].tabView.selectedTabViewItem?.view)
        activateNearestTextView()
    }

    @IBAction func gotoRightPane(_ sender: Any?) {
        window?.makeFirstResponder(projectPanes?[1].tabView.selectedTabViewItem?.view)
        activateNearestTextView()
    }

    @IBAction func switchPanes(_ sender: Any?) {
        var newView: NSTabView? = nil

        if currentTabView === projectPanes?[0].tabView {
            newView = projectPanes?[1].tabView
        } else {
            newView = projectPanes?[0].tabView
        }

        if let newView {
            window?.makeFirstResponder(newView.selectedTabViewItem?.view)
            activateNearestTextView()
        }
    }

    // MARK: - Spell checking

    func setSourceSpellChecking(_ spellChecking: Bool) {
        // Update the panes
        for pane in projectPanes ?? [] {
            pane.sourcePage.setSpellChecking((NSApp.delegate as? IFAppDelegate)?.sourceSpellChecking ?? false)
        }
    }

    // MARK: - CocoaGlk -> skein gateway (GlkAutomation)

    @IBAction func glkTaskHasStarted(_ sender: Any?) {
        let currentSkein = project?.currentSkein

        currentSkein?.interpreterRestart()
    }

    @objc(receivedCharacters:window:fromView:)
    func receivedCharacters(_ characters: String!,
                            window windowNumber: Int32,
                            from view: GlkView!) {
        let currentSkein = project?.currentSkein

        currentSkein?.outputText(characters ?? "")
    }

    @objc(userTyped:window:lineInput:fromView:)
    func userTyped(_ userInput: String!,
                   window windowNumber: Int32,
                   lineInput isLineInput: Bool,
                   from view: GlkView!) {
        let currentSkein = project?.currentSkein

        if isLineInput {
            currentSkein?.inputCommand(userInput ?? "")
        } else {
            currentSkein?.inputCharacter(userInput ?? "")
        }
    }

    @objc(userClickedAtXPos:ypos:window:fromView:)
    func userClicked(atXPos xpos: Int32,
                     ypos: Int32,
                     window windowNumber: Int32,
                     from view: GlkView!) {
    }

    @objc(viewWaiting:)
    func viewWaiting(_ view: GlkView!) {
        let currentSkein = project?.currentSkein
        currentSkein?.waitingForInput()
    }

    @objc(viewIsWaitingForInput:)
    func viewIsWaiting(forInput view: GlkView!) {
        // Only do anything if there's at least one view waiting for input
        if !(view?.canSendInput ?? false) { return }

        let currentSkein = project?.currentSkein
        currentSkein?.waitingForInput()

        // Get the next command from the input source (which is a zoom-style input source)
        guard let nextCommand = glkInputSource?.nextCommand?() else {
            view.removeAutomationObject(self)
            view.addOutputReceiver(self)
            view.alwaysPageOnMore = false

            inputSourceHasFinished(nil)
            return
        }

        view.sendCharacters(nextCommand,
                            toWindow: 0)
    }

    func zoomViewIsWaitingForInput() {
        let currentSkein = project?.currentSkein
        currentSkein?.waitingForInput()
    }

    @IBAction private final func showFindInFiles(_ sender: Any?) {
        IFFindInFilesController.shared().showFind(inFilesWindow: self)
    }

    // MARK: - The find action

    @objc private final func performFindPanelAction(_ sender: Any?) {
        // TODO: [[self currentTabView] performFindPanelAction: sender];
    }

    // MARK: - Running the entire skein

    @objc private final func runCompilerOutputAndEntireSkein() {
        playAll = (project?.currentSkein?.rootItem).map { IFSkeinPlayAll(rootItem: $0) }
        inputSourceHasFinished(nil)
    }

    private final func finishRunningTestCases() {
        // Stop the current game
        for pane in projectPanes ?? [] {
            pane.stopRunningGame()
        }

        // Show completion message
        if testAllProgress?.isCancelled ?? false {
            testAllProgress?.message = IFUtility.localizedString("Tests cancelled")
        } else {
            testAllProgress?.message = IFUtility.localizedString("Tests completed")
        }
        testAllProgress?.stop()
        if let testAllProgress {
            removeProgressIndicator(testAllProgress)
        }

        // Reset variables
        testCaseRun.finish()

        // Update toolbar
        toolbarManager?.validateVisibleItems()

        // Restore the skein
        project?.selectSkein(toolbarManager?.testCaseIndex ?? 0)
    }

    @discardableResult
    @objc private final func startNextTestCase() -> Bool {
        testCaseRun.moveToNextTestCase()

        // Did we reach the end of the test cases?
        if (testCaseRun.isPastTheLastTestCase || currentTestCase() == nil) || (testAllProgress?.isCancelled ?? false) {
            finishRunningTestCases()
            return false
        }

        let done  = testCaseRun.numberStarted
        let total = testCaseRun.numberInRun
        let message = String(format: IFUtility.localizedString("Testing %d of %d"), done, total)
        testAllProgress?.percentage = CGFloat(testCaseRun.percentageStarted)
        testAllProgress?.message = message

        testMeInternal()
        return true
    }

    private final func startNextTestCaseSoon() -> Bool {
        if currentTestCase() == nil || (testAllProgress?.isCancelled ?? false) {
            finishRunningTestCases()
            return false
        }

        // After the last test case, finish now, so that the caller knows to make the report
        if testCaseRun.isOnTheLastTestCase {
            return startNextTestCase()
        }

        // Enforce a delay to let current task finish gracefully before starting another
        Timer.scheduledTimer(timeInterval: 0.0,
                             target: self,
                             selector: #selector(startNextTestCase),
                             userInfo: nil,
                             repeats: false)
        return true
    }

    @objc private final func inputSourceHasFinishedAfterDelay() {
        // Gather report data
        let currentSkein = project?.currentSkein
        let intestCode = currentSkein?.reportStateForSkein ?? ""
        let reportItem = project?.nodeToReport
        let skeinNodeId = reportItem?.uniqueId ?? 0
        let skeinNodes = IFTestReport.skeinNodes(to: project?.currentSkein?.activeItem)

        if let nextItem = playAll?.nextItem {
            // We are testing the entire skein.
            // Run the next set of commands on the skein stack.
            gamePage?.setSwitchTo(false)
            gamePage?.setPointToRunTo(nextItem)
            runCompilerOutput()
            playAll?.removeNextItem()
        } else if isCurrentlyTesting {
            // Make a report
            let reportURL = project?.currentReportURL
            if let reportURL {
                project?.generateReport(forTestCase: currentTestCase() ?? "",
                                        errorCode: intestCode,
                                        skeinNodeId: skeinNodeId,
                                        skeinNodes: skeinNodes,
                                        outputURL: reportURL)
            }
            // Start next case
            if startNextTestCase() {
                return
            }

            // All test cases finished. Create a consolidated report and display it.
            if !(testAllProgress?.isCancelled ?? false) {
                createAndShowReport(testCaseRun.numberTested, reportURL: reportURL)
            }
        }
    }

    func inputSourceHasFinished(_ source: Any?) {
        // Enforce a delay to let current task finish gracefully before starting another
        Timer.scheduledTimer(timeInterval: 0.0,
                             target: self,
                             selector: #selector(inputSourceHasFinishedAfterDelay),
                             userInfo: nil,
                             repeats: false)
    }

    // MARK: - Importing skein information

    @IBAction func importIntoSkein(_ sender: Any?) {
        if let window, let project {
            IFProjectPanels(project: project).importIntoSkein(with: window)
        }
    }

    @IBAction func exportExtension(_ sender: Any?) {
        if let window, let project {
            IFProjectPanels(project: project).exportExtension(with: window)
        }
    }

    // MARK: - Headers

    @objc private final func intelFileChanged(_ not: Notification) {
        // Must be the current intelligence object
        if (not.object as AnyObject?) !== currentIntelligence { return }

        // Update the header controller
        headerController.update(fromIntelligence: not.object as? IFIntelFile)
    }

    // MARK: - Moving around source headings

    @IBAction func showHeadings(_ sender: Any?) {
        // Select the source page in the current tab
        currentTabView?.selectTabViewItem(withIdentifier: IFSourcePage.description())
        activateNearestTextView()

        // Retrieve the page for the current tab
        let sourcePage = currentPane?.sourcePage

        // Toggle the header page
        sourcePage?.toggleHeaderPage(self)
    }

    @IBAction func showCurrentSectionOnly(_ sender: Any?) {
        // Select the source page in the current tab
        currentTabView?.selectTabViewItem(withIdentifier: IFSourcePage.description())
        activateNearestTextView()

        // Retrieve the page for the current tab
        let sourcePage = currentPane?.sourcePage

        sourcePage?.showCurrentSectionOnly(self)
    }

    @IBAction func showFewerHeadings(_ sender: Any?) {
        // Select the source page in the current tab
        currentTabView?.selectTabViewItem(withIdentifier: IFSourcePage.description())
        activateNearestTextView()

        // Retrieve the page for the current tab
        let sourcePage = currentPane?.sourcePage

        sourcePage?.showFewerHeadings(self)
    }

    @IBAction func showMoreHeadings(_ sender: Any?) {
        // Select the source page in the current tab
        currentTabView?.selectTabViewItem(withIdentifier: IFSourcePage.description())
        activateNearestTextView()

        // Retrieve the page for the current tab
        let sourcePage = currentPane?.sourcePage

        sourcePage?.showMoreHeadings(self)
    }

    @IBAction func showEntireSource(_ sender: Any?) {
        // Select the source page in the current tab
        currentTabView?.selectTabViewItem(withIdentifier: IFSourcePage.description())
        activateNearestTextView()

        // Retrieve the page for the current tab
        let sourcePage = currentPane?.sourcePage

        sourcePage?.showEntireSource(self)
    }

    @IBAction func showPreviousSection(_ sender: Any?) {
        // Select the source page in the current tab
        currentTabView?.selectTabViewItem(withIdentifier: IFSourcePage.description())
        activateNearestTextView()

        // Retrieve the page for the current tab
        let sourcePage = currentPane?.sourcePage

        // Show the previous section
        sourcePage?.sourceFileShowPreviousSection(self)
    }

    @IBAction func showNextSection(_ sender: Any?) {
        // Select the source page in the current tab
        currentTabView?.selectTabViewItem(withIdentifier: IFSourcePage.description())
        activateNearestTextView()

        // Retrieve the page for the current tab
        let sourcePage = currentPane?.sourcePage

        // Show the next section
        sourcePage?.sourceFileShowNextSection(self)
    }

    func extensionUpdated(_ javascriptId: String?) {
        for pane in projectPanes ?? [] {
            pane.extensionUpdated(javascriptId)
        }
    }

    @objc(runningGame)
    var isRunningGame: Bool {
        @objc(isRunningGame)
        get {
            return runningGamePage?.isRunningGame ?? false
        }
    }

    @objc(compiling)
    var isCompiling: Bool {
        @objc(isCompiling)
        get {
            return compiling
        }
    }

    @objc(playingAll)
    var isPlayingAll: Bool {
        @objc(isPlayingAll)
        get {
            return playAll?.nextItem != nil
        }
    }

    // -- Split view delegate --
    func splitView(_ splitView: NSSplitView,
                   constrainMinCoordinate proposedMinimumPosition: CGFloat,
                   ofSubviewAt dividerIndex: Int) -> CGFloat {
        return IFPaneWidths.leastDividerPosition(proposedMinimumPosition)
    }

    func splitView(_ splitView: NSSplitView,
                   constrainMaxCoordinate proposedMaximumPosition: CGFloat,
                   ofSubviewAt dividerIndex: Int) -> CGFloat {
        return IFPaneWidths.greatestDividerPosition(proposedMaximumPosition,
                                                    inWidth: splitView.bounds.size.width)
    }

    func splitView(_ splitView: NSSplitView,
                   canCollapseSubview subview: NSView) -> Bool {
        return false
    }

    public override func windowTitle(forDocumentDisplayName displayName: String) -> String {
        if isExtensionProject {
            return "\(IFUtility.localizedString("Extension Project")) - \(displayName)"
        }
        return displayName
    }
}
