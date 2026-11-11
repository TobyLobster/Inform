//
//  IFAppDelegate.swift
//  Inform
//
//  Created by Andrew Hunter on Mon Aug 18 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFAppDelegate.h.
//

import Cocoa
import GlkView.GlkHub

private let IFSourceSpellChecking = "IFSourceSpellChecking"
private let pixelWidthBetweenExtensionNameAndVersion: CGFloat = 10.0
private var newProj: IFNewProject?

@objc @implementation extension IFAppDelegate {
    /// The 'New Extension Project' menu
    @IBOutlet private final var newExtensionProjectMenu: NSMenuItem?
    /// The 'Open Extension' menu
    @IBOutlet private final var openExtensionMenu: NSMenuItem?

    /// Maps extension menu tags to source file names
    private final var extensionSources: [String] = []

    /// The 'open extension' panel
    private final var openExtensionPanel: NSOpenPanel?

    // Used for copying sample projects
    private final var copySource: NSURL?
    private final var copyDestination: NSURL?

    // Used for copying resource files (e.g. epubs)
    private final var fileCopyDestination: String?
    private final var fileCopySource: String?
    private final var exportToEPubIndex = 0

    /// Where whether the source is spell checked is kept
    private final var defaults: UserDefaults

    private final var _newsManager: IFNewsManager?

    var newsManager: IFNewsManager? {
        return _newsManager
    }

    public override convenience init() {
        self.init(defaults: UserDefaults.standard)
    }

    init(defaults theDefaults: UserDefaults) {
        defaults = theDefaults

        super.init()
    }

    nonisolated public override func observeValue(forKeyPath keyPath: String?,
                                                  of object: Any?,
                                                  change: [NSKeyValueChangeKey: Any]?,
                                                  context: UnsafeMutableRawPointer?) {
        performSelector(onMainThread: #selector(darkModeChanged), with: nil, waitUntilDone: false)
    }

    private final func isDark() -> Bool {
        let basicAppearance = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        return basicAppearance == .darkAqua
    }

    func doCopyProject(_ source: URL, to destination: URL) {
        let materialsDestination = destination.deletingPathExtension().appendingPathExtension("materials")

        let exists = FileManager.default.fileExists(atPath: destination.path) ||
                     FileManager.default.fileExists(atPath: materialsDestination.path)

        if exists {
            copySource = source as NSURL
            copyDestination = destination as NSURL

            // Ask for confirmation
            IFUtility.runAlertYesNoWindow(nil,
                                          title: IFUtility.localizedString("Are you sure?"),
                                          yes: IFUtility.localizedString("Overwrite"),
                                          no: IFUtility.localizedString("Cancel"),
                                          modalDelegate: self,
                                          didEnd: #selector(confirmDidEnd(_:returnCode:contextInfo:)),
                                          contextInfo: nil,
                                          destructiveIndex: 0,
                                          informativeText: String(format: IFUtility.localizedString("Do you want to overwrite %@?"),
                                                                  destination.path))
            return
        }

        type(of: self).copyProjectWithoutConfirmation(source, to: destination)
    }

    @discardableResult
    private static func copyProjectWithoutConfirmation(_ source: URL, to destination: URL) -> Bool {
        var isDirectory: ObjCBool = false

        // Delete the destination, then copy the .inform directory
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.copyItem(at: source, to: destination)
        } catch {
            IFUtility.runAlertWarning(nil,
                                      title: IFUtility.localizedString("Error"),
                                      informativeText: error.localizedDescription)
            return false
        }

        // Copy the associate .materials directory
        let materialsSource      = source.deletingPathExtension().appendingPathExtension("materials")
        let materialsDestination = destination.deletingPathExtension().appendingPathExtension("materials")

        if FileManager.default.fileExists(atPath: materialsSource.path,
                                          isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                try? FileManager.default.removeItem(at: materialsDestination)
                do {
                    try FileManager.default.copyItem(at: materialsSource, to: materialsDestination)
                } catch {
                    IFUtility.runAlertWarning(nil,
                                              title: IFUtility.localizedString("Error"),
                                              informativeText: error.localizedDescription)
                    return false
                }
            }
        }

        // Open the project
        let docControl = NSDocumentController.shared

        docControl.openDocument(withContentsOf: destination,
                                display: true) { document, documentWasAlreadyOpen, ourerror in
            // do nothing
        }

        return true
    }

    func createNewProject(_ title: String, story: String) {
        if newProj == nil {
            newProj = IFNewProject()
        }
        newProj?.createInform7Project(title,
                                      fileType: .inform7Project,
                                      story: story)
    }

    @IBAction func newProject(_ sender: Any?) {
        if newProj == nil {
            newProj = IFNewProject()
        }
        newProj?.createInform7Project(nil,
                                      fileType: .inform7Project,
                                      story: nil)
    }

    @IBAction func newExtension(_ sender: Any?) {
        if newProj == nil {
            newProj = IFNewProject()
        }
        let projectController = frontmostProjectController
        if let projectController, let project = projectController.document as? IFProject {
            newProj?.createInform7Extension(for: project)
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let itemSelector = menuItem.action

        // Spell checking
        if itemSelector == #selector(toggleSourceSpellChecking(_:)) {
            menuItem.state = sourceSpellChecking ? .on : .off
            return true
        }

        return true
    }

    // MARK: - Menu actions

    @IBAction func visitWebsite(_ sender: Any?) {
        // Get the URL
        let websiteUrl = URL(string: "http://www.inform7.com")!

        // Visit it
        NSWorkspace.shared.open(websiteUrl)
    }

    @IBAction func showWelcome(_ sender: Any?) {
        // Toggle welcome window
        if IFWelcomeWindow.shared().window?.isVisible ?? false {
            IFWelcomeWindow.hide()
        } else {
            IFWelcomeWindow.show()
        }
    }

    // Construct an attributed string containing the extension name and version in the menu
    private final func attributedString(for info: IFExtensionInfo,
                                        withTabWidth tabWidth: CGFloat,
                                        widthOut: UnsafeMutablePointer<CGFloat>?) -> NSAttributedString {
        let systemFont       = NSFont.menuFont(ofSize: 14)
        let smallFont        = NSFont.menuFont(ofSize: systemFont.pointSize - 4)

        // NSParagraphStyleAttributeName
        let paragraph = NSMutableParagraphStyle()
        let tab = NSTextTab(type: .leftTabStopType,
                            location: tabWidth)
        paragraph.tabStops = [tab]
        paragraph.lineBreakMode = .byClipping

        let greyDictionary: [NSAttributedString.Key: Any]       = [.foregroundColor: NSColor.systemGray,
                                                                   .font: systemFont,
                                                                   .paragraphStyle: paragraph]
        let smallBlackDictionary: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.textColor,
                                                                   .font: smallFont,
                                                                   .paragraphStyle: paragraph]
        let smallGreyDictionary: [NSAttributedString.Key: Any]  = [.foregroundColor: NSColor.systemGray,
                                                                   .font: smallFont,
                                                                   .paragraphStyle: paragraph]
        let blackDictionary: [NSAttributedString.Key: Any]      = [.foregroundColor: NSColor.textColor,
                                                                   .font: systemFont,
                                                                   .paragraphStyle: paragraph]
        var dict: [NSAttributedString.Key: Any]

        if info.isBuiltIn {
            dict = greyDictionary
        } else {
            dict = blackDictionary
        }

        let attributedTitle = NSMutableAttributedString(string: info.displayName,
                                                        attributes: dict)
        if let widthOut {
            widthOut.pointee = attributedTitle.size().width
        }

        // Append version string if we have one
        if let infoVersion = info.version {
            if info.isBuiltIn {
                dict = smallGreyDictionary
            } else {
                dict = smallBlackDictionary
            }
            let version = "\t\(infoVersion)"
            let attributedVersion = NSAttributedString(string: version,
                                                       attributes: dict)
            attributedTitle.append(attributedVersion)
        }

        return attributedTitle
    }

    // MARK: - The extensions menu

    func updateExtensionsMenu(forCompilerVersion compilerVersion: String) {
        let mgr = IFExtensionsManager.sharedNaturalInform

        // Clear out the menus
        openExtensionMenu?.submenu?.removeAllItems()
        newExtensionProjectMenu?.submenu?.removeAllItems()

        // Add new Extension items
        let newExtensionItem = NSMenuItem()
        newExtensionItem.title = IFUtility.localizedString("New Extension...")
        newExtensionItem.target = self
        newExtensionItem.tag = -1
        newExtensionItem.action = #selector(newExtensionProject(_:))
        newExtensionProjectMenu?.submenu?.addItem(newExtensionItem)

        let newMenu = NSMenu()
        newMenu.title = IFUtility.localizedString("Create From Installed Extension")
        let newMenuItem = NSMenuItem()
        newMenuItem.title = newMenu.title
        newMenuItem.submenu = newMenu
        newExtensionProjectMenu?.submenu?.addItem(newMenuItem)

        // Clear out the list of extension tags
        extensionSources = []

        // Generate the extensions menu
        for author in mgr.availableAuthors(withCompilerVersion: compilerVersion) {
            // Find the maximum width of all extensions by this author
            var maxWidth: CGFloat = 0.0
            for info in mgr.availableExtensions(byAuthor: author, withCompilerVersion: compilerVersion) {
                var width: CGFloat = 0
                _ = attributedString(for: info,
                                     withTabWidth: 0.0,
                                     widthOut: &width)
                maxWidth = max(maxWidth, width)
            }
            let tabWidth = pixelWidthBetweenExtensionNameAndVersion + maxWidth

            // Create menu and menu item for the 'Open Installed Extension' menu
            let openAuthorMenu = NSMenu()
            openAuthorMenu.title = author

            let openAuthorItem = NSMenuItem()
            openAuthorItem.title = author
            openAuthorItem.submenu = openAuthorMenu

            // Create menu and menu item for the 'New Extension Project' menu
            let newExAuthorMenu = NSMenu()
            newExAuthorMenu.title = author

            let newExAuthorItem = NSMenuItem()
            newExAuthorItem.title = author
            newExAuthorItem.submenu = newExAuthorMenu

            for info in mgr.availableExtensions(byAuthor: author, withCompilerVersion: compilerVersion) {
                let attributedTitle = attributedString(for: info,
                                                       withTabWidth: tabWidth,
                                                       widthOut: nil)

                // Create menu for each extension, for the 'Open Installed Extension' menu
                do {
                    let openItem = NSMenuItem()
                    openItem.attributedTitle = attributedTitle
                    openItem.target = self
                    openItem.tag = extensionSources.count
                    openItem.action = #selector(openExtension(_:))

                    openAuthorMenu.addItem(openItem)
                }

                // Create menu for each extension, for the 'New Extension Project' menu. A project keeps
                // its extension in one file, so there's none for a literate extension, which has sections.
                if !info.isLiterate {
                    let newExItem = NSMenuItem()
                    newExItem.attributedTitle = attributedTitle
                    newExItem.target = self
                    newExItem.tag = extensionSources.count
                    newExItem.action = #selector(newExtensionProject(_:))

                    newExAuthorMenu.addItem(newExItem)
                }


                // Add an entry in the extensionSources array so we know which file this refers to
                extensionSources.append(info.filepath ?? "")
            }
            openExtensionMenu?.submenu?.addItem(openAuthorItem)
            if newExAuthorMenu.numberOfItems > 0 {
                newMenu.addItem(newExAuthorItem)
            }
        }
    }

    // MARK: - Some misc actions

    @IBAction func showAbout(_ sender: Any?) {
        let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let informVersion = IFUtility.coreBuildVersion
        let options: [NSApplication.AboutPanelOptionKey: Any] = [
            .version: String(format: "%@, Inform %@", bundleVersion ?? "", informVersion ?? ""),
        ]
        NSApp.orderFrontStandardAboutPanel(options: options)
    }

    @IBAction func showPreferences(_ sender: Any?) {
        PreferenceController.shared.showWindow(self)
    }

    // MARK: - The help menu

    @IBAction func docIndex(_ sender: Any?) {
        // If we can switch to an open project document, do so
        for doc in NSDocumentController.shared.documents {
            if doc is IFProject {
                // Bring to front
                for controller in doc.windowControllers {
                    controller.window?.makeKeyAndOrderFront(self)
                    if let pc = controller as? IFProjectController {
                        pc.docIndex(sender)
                    }
                }

                return
            }
        }

        // This is called if there is no project currently open: in this case, the help isn't really available as
        // it's dependent on the project window.
        IFUtility.runAlertWarning(nil,
                                  title: "Help not yet available",
                                  informativeText: IFUtility.localizedString("Help not available description"))
    }

    // MARK: - Installing extensions
    // get a list of windows in app, frontmost to backmost
    private final func allWindows() -> [NSWindow] {
        let windNumsArray = NSWindow.windowNumbers(options: []) ?? []
        let windObjsArray = NSApplication.shared.windows
        var windowList: [NSWindow] = []

        for i in 0..<windNumsArray.count {
            let windowNumber = windNumsArray[i].intValue
            for wind in windObjsArray {
                if wind.windowNumber == windowNumber {
                    windowList.append(wind)
                    break
                }
            }
        }
        return windowList
    }

    var frontmostProjectController: IFProjectController? {
        let allWindows = self.allWindows()
        for window in allWindows {
            // If we can switch to an open project document, do so
            for doc in NSDocumentController.shared.documents {
                if doc is IFProject {
                    for controller in doc.windowControllers {
                        if controller.window === window {
                            if let pc = controller as? IFProjectController {
                                return pc
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    @IBAction func installLegacyExtension(_ sender: Any?) {
        // Present a panel for installing new extensions
        if openExtensionPanel == nil {
            openExtensionPanel = NSOpenPanel()
        }
        let panel = openExtensionPanel!

        panel.accessoryView = nil
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.resolvesAliases = true
        panel.allowsMultipleSelection = true
        panel.title = IFUtility.localizedString("Install Inform 7 Extension")
        panel.delegate = IFExtensionsManager.sharedNaturalInform    // Extensions manager determines which file types are valid to choose (panel:shouldShowFilename:)

        panel.begin { result in
            panel.delegate = nil

            if result != .OK { return }

            // Just add the extension
            // Add the files
            var installResult = IFExtensionResult.success
            for file in panel.urls {
                installResult = IFExtensionsManager.sharedNaturalInform.installLegacyExtension(file.path,
                                                                                               finalPath: nil,
                                                                                               title: nil,
                                                                                               author: nil,
                                                                                               version: nil,
                                                                                               showWarningPrompts: true,
                                                                                               notify: false)
                if installResult != .success { break }
            }

            // Re-run the census. In particular, this will update the Public Library of extensions web page if visible
            IFExtensionsManager.sharedNaturalInform.startLegacyCensus(true)

            // Report an error if we couldn't install the extension for some reason
            if installResult != .success {
                IFUtility.showExtensionError(installResult,
                                             with: nil)
            }
        }
    }

    // MARK: - Searching

    @IBAction func showFind2(_ sender: Any?) {
        IFFindController.shared().showWindow(self)
    }

    @IBAction func findNext(_ sender: Any?) {
        IFFindController.shared().findNext(self)
    }

    @IBAction func findPrevious(_ sender: Any?) {
        IFFindController.shared().findPrevious(self)
    }

    @IBAction func useSelectionForFind(_ sender: Any?) {
        IFFindController.shared().useSelectionForFind(self)
    }

    var sourceSpellChecking: Bool {
        return defaults.bool(forKey: IFSourceSpellChecking)
    }

    @IBAction func toggleSourceSpellChecking(_ sender: Any?) {
        // Toggle the setting
        let sourceSpellChecking = !defaults.bool(forKey: IFSourceSpellChecking)

        // Tell each document's controller about the change
        for doc in NSDocumentController.shared.documents {
            for controller in doc.windowControllers {
                if let pc = controller as? IFProjectController {
                    pc.setSourceSpellChecking(sourceSpellChecking)
                }
                else if let sc = controller as? IFSingleController {
                    sc.setSourceSpellChecking(sourceSpellChecking)
                }
            }
        }

        // Store the result
        defaults.set(sourceSpellChecking,
                     forKey: IFSourceSpellChecking)
    }

    private final func copyResource(_ resource: String,
                                    toDirectory destDir: String) -> Bool {
        let `extension` = (resource as NSString).pathExtension
        let name = ((resource as NSString).lastPathComponent as NSString).deletingPathExtension

        fileCopyDestination = ((destDir as NSString).appendingPathComponent(name) as NSString)
                                .appendingPathExtension(`extension`)
        fileCopySource = Bundle.main.path(forResource: name, ofType: `extension`)

        if fileCopySource == nil {
            IFUtility.runAlertWarning(nil,
                                      title: "Export failed",
                                      informativeText: String(format: IFUtility.localizedString("Export of %@ failed - could not find source."),
                                                              resource))
            return false
        }

        if FileManager.default.fileExists(atPath: fileCopyDestination ?? "") {
            let confirm = String(format: IFUtility.localizedString("Are you sure you want to overwrite file '%@'?"),
                                 ((fileCopyDestination ?? "") as NSString).lastPathComponent)

            IFUtility.runAlertYesNoWindow(nil,
                                          title: IFUtility.localizedString("Are you sure?"),
                                          yes: IFUtility.localizedString("Overwrite"),
                                          no: IFUtility.localizedString("Cancel"),
                                          modalDelegate: self,
                                          didEnd: #selector(confirmFileCopyDidEnd(_:returnCode:contextInfo:)),
                                          contextInfo: nil,
                                          destructiveIndex: 0,
                                          informativeText: confirm)
            return false
        }

        let result = copyResourceWithoutConfirmation(fileCopySource ?? "",
                                                     toDestination: fileCopyDestination ?? "")
        fileCopySource = nil
        fileCopyDestination = nil

        if !result {
            return false
        }

        return true
    }

    private final func copyResourceWithoutConfirmation(_ source: String,
                                                       toDestination destination: String) -> Bool {
        // Remove any existing file at destination
        try? FileManager.default.removeItem(atPath: destination)

        do {
            try FileManager.default.copyItem(atPath: source,
                                             toPath: destination)
        } catch {
            IFUtility.runAlertWarning(nil,
                                      title: "Export failed",
                                      informativeText: String(format: IFUtility.localizedString("Export to %@ failed - error %@"),
                                                              destination, error.localizedDescription))
            return false
        }
        return true
    }

    private final func exportNext(_ destDir: String) {
        let exportFiles = ["Inform - A Design System for Interactive Fiction.epub",
                           "Changes to Inform.epub"]

        while exportToEPubIndex < exportFiles.count {
            if !copyResource(exportFiles[exportToEPubIndex],
                             toDirectory: destDir) {
                // Something stopped the flow - an error or a confirmation dialog.
                return
            }
            exportToEPubIndex += 1
        }

        // All went well, open directory in Finder...
        NSWorkspace.shared.open(URL(fileURLWithPath: destDir))
    }

    @IBAction func exportToEPub(_ sender: Any?) {
        let exportPanel = NSOpenPanel()
        exportPanel.canChooseFiles = false
        exportPanel.canChooseDirectories = true
        exportPanel.canCreateDirectories = true
        exportPanel.allowsMultipleSelection = false
        exportPanel.title = IFUtility.localizedString("Choose a directory to export into")
        exportPanel.prompt = IFUtility.localizedString("Choose Directory")

        var window: NSWindow? = nil
        if IFWelcomeWindow.shared().window?.isVisible ?? false {
            window = IFWelcomeWindow.shared().window
        }

        // A Swift sheet must have a window: with none, IFUtility begins it on none, as the Objective-C did
        IFUtility.begin(exportPanel, for: window) { result in
            if result == .OK {
                self.exportToEPubIndex = 0
                self.exportNext(exportPanel.url?.path ?? "")
            }
        }
    }
}

/// The application delegate's methods, the menu item validation, the actions the main menu and the extensions
/// menus send, the alerts' endings, and what's run by selector, which the header doesn't declare
extension IFAppDelegate {
    @objc(applicationWillFinishLaunching:)
    public func applicationWillFinishLaunching(_ not: Notification) {
        _newsManager = IFNewsManager()

        // Register some custom URL handlers
        URLProtocol.registerClass(IFInformProtocol.self)

        // Standard settings
        IFSettingsController.addStandardSettingsClass(IFOutputSettings.self)
        IFSettingsController.addStandardSettingsClass(IFI7OutputSettings.self)
        IFSettingsController.addStandardSettingsClass(IFRandomSettings.self)
        IFSettingsController.addStandardSettingsClass(IFCompilerOptions.self)
        IFSettingsController.addStandardSettingsClass(IFMiscSettings.self)
        IFSettingsController.addStandardSettingsClass(IFCompilerVersionSettings.self)
        IFSettingsController.addStandardSettingsClass(IFBasicInformSettings.self)
        IFSettingsController.addStandardSettingsClass(IFAdvancedSettings.self)

        // Glk hub
        if !IFUtility.isHostingUnitTests {
            GlkHub.shared.setRandomHubCookie()
            GlkHub.shared.hubName = "GlkInform"
        }

        // Remove the 'tab' related menu entries on the Window menu
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    @objc(applicationDidFinishLaunching:)
    public func applicationDidFinishLaunching(_ not: Notification) {
        // The standard preferences
        PreferenceController.shared.add(AuthorPreferences())
        PreferenceController.shared.add(IFEditingPreferences())
        PreferenceController.shared.add(IFColourPreferences())
        PreferenceController.shared.add(IFAdvancedPreferences())

        // Finish setting up
        if !IFUtility.isHostingUnitTests {
            updateExtensionsMenu(forCompilerVersion: "")
        }

        NSApp.addObserver(self,
                          forKeyPath: "effectiveAppearance",
                          options: .new,
                          context: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateExtensionsMenu as () -> Void),
                                               name: .IFCensusFinished,
                                               object: nil)

        // Set dark mode if necessary
        darkModeChanged()

        if IFUtility.isHostingUnitTests {
            return
        }

        // Schedule "Checking whether document exists." into next UI Loop, because document is not restored yet.
        // NSInvocationOperation isn't available in Swift, so the operation is a block.
        OperationQueue.main.addOperation {
            MainActor.assumeIsolated {
                self.openWelcomeDialogIfNeeded()
            }
        }
    }

    @objc(darkModeChanged)
    public func darkModeChanged() {
        let prefs = IFPreferences.shared
        prefs.setDarkMode(isDark())
    }

    @objc(openWelcomeDialogIfNeeded)
    public func openWelcomeDialogIfNeeded() {
        //
        // HACK: Remove any open color and font panel. Lion's auto-restore of windows that were open when
        // the app last closed down can cause the panels to display. We close the window.
        //
        if NSColorPanel.sharedColorPanelExists {
            NSColorPanel.shared.close()
        }
        if NSFontPanel.sharedFontPanelExists {
            NSFontPanel.shared.close()
        }

        let documentCount = NSDocumentController.shared.documents.count

        // If no documents have opened, open the welcome dialog instead...
        if documentCount == 0 {
            IFWelcomeWindow.show()
        }
    }

    @objc(applicationShouldOpenUntitledFile:)
    public func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        if !IFUtility.isHostingUnitTests {
            IFWelcomeWindow.show()
        }

        return false
    }

    @objc(confirmDidEnd:returnCode:contextInfo:)
    public func confirmDidEnd(_ sheet: NSWindow?,
                              returnCode: NSApplication.ModalResponse,
                              contextInfo: UnsafeMutableRawPointer?) {
        if returnCode == .alertFirstButtonReturn {
            if let copySource, let copyDestination {
                type(of: self).copyProjectWithoutConfirmation(copySource as URL,
                                                              to: copyDestination as URL)
            }
            copySource = nil

            copyDestination = nil
        }
    }

    // MARK: - The extensions menu

    @objc(updateExtensionsMenu)
    public func updateExtensionsMenu() {
        let projectController = frontmostProjectController
        if let projectController {
            let project = projectController.document as? IFProject
            let compilerSettings = project?.settings
            updateExtensionsMenu(forCompilerVersion: compilerSettings?.compilerVersion ?? "")
        }
    }

    @objc(openExtension:)
    public func openExtension(_ sender: Any?) {
        // Get the tag, and from that, get the source file we want to open
        let tag = (sender as? NSMenuItem)?.tag ?? 0
        let sourceFilename = extensionSources[tag]

        // Open the file
        guard let newDoc = try? IFSingleFile(contentsOf: URL(fileURLWithPath: sourceFilename),
                                             ofType: "Inform 7 extension") else {
            return
        }

        NSDocumentController.shared.addDocument(newDoc)
        newDoc.makeWindowControllers()
        newDoc.showWindows()
    }

    @objc(newExtensionProject:)
    public func newExtensionProject(_ sender: Any?) {
        // Get the tag, and from that, get the source file we want
        let tag = (sender as? NSMenuItem)?.tag ?? 0

        if newProj == nil {
            newProj = IFNewProject()
        }

        if tag >= 0 {
            let sourceFilename  = extensionSources[tag]
            let projectTitle    = ((sourceFilename as NSString).lastPathComponent as NSString).deletingPathExtension
            let projectURL      = URL(fileURLWithPath: sourceFilename)

            newProj?.createInform7ExtensionProject(projectTitle,
                                                   fromExtensionURL: projectURL)
        }
        else {
            newProj?.createInform7Project(nil,
                                          fileType: .inform7ExtensionProject,
                                          story: nil)
        }
    }

    // MARK: - The help menu

    @objc(showExtensionsFolder:)
    public func showExtensionsFolder(_ sender: Any?) {
        let externalExtensions = IFUtility.pathForInformExternalExtensions()
        NSWorkspace.shared.open(URL(fileURLWithPath: externalExtensions))
    }

    // MARK: - Termination

    @objc(applicationWillTerminate:)
    public func applicationWillTerminate(_ not: Notification) {
        newProj = nil

        //
        // Clean up preference panes
        //
        PreferenceController.shared.removeAllPreferencePanes()
    }

    @objc(confirmFileCopyDidEnd:returnCode:contextInfo:)
    public func confirmFileCopyDidEnd(_ sheet: NSWindow?,
                                      returnCode: NSApplication.ModalResponse,
                                      contextInfo: UnsafeMutableRawPointer?) {
        let sourceCopy = fileCopySource
        let destCopy   = fileCopyDestination

        fileCopySource = nil
        fileCopyDestination = nil

        if returnCode == .alertFirstButtonReturn {
            if copyResourceWithoutConfirmation(sourceCopy ?? "",
                                               toDestination: destCopy ?? "") {
                exportToEPubIndex += 1
                exportNext(((destCopy ?? "") as NSString).deletingLastPathComponent)
            }
        }
    }
}
