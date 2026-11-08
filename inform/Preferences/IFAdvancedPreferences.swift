//
//  IFAdvancedPreferences.swift
//  Inform
//
//  Created by Andrew Hunter on 12/10/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFAdvancedPreferences.h.
//

import Cocoa

@objc @implementation extension IFAdvancedPreferences {
    /// The preferences the pane shows and sets
    private final var preferences: IFPreferences

    /// If checked, show the Inform 6 source and Inform 7 debugging logs
    @IBOutlet private final var showDebugLogs: NSButton?
    /// Causes the Inform 7 build process to be run
    @IBOutlet private final var runBuildSh: NSButton?
    /// If checked, always compile the story (no make-style dependency checking)
    @IBOutlet private final var alwaysCompile: NSButton?
    /// If checked, show the Console during building
    @IBOutlet private final var showConsole: NSButton?
    /// If checked, the public library is accessed from a different location (for debugging)
    @IBOutlet private final var publicLibraryDebug: NSButton?

    /// If checked, use the external Inform Core directory
    @IBOutlet private final var useExternalInformCore: NSButton?
    /// Text field to show the external Inform Core driectory
    @IBOutlet private final var externalInformCoreDirectory: NSTextField?
    private final var openInformCorePanel: NSOpenPanel?

    /// If checked, build files are cleaned out
    @IBOutlet private final var cleanBuildFiles: NSButton?
    /// If checked, index files are cleaned out in addition to build files
    @IBOutlet private final var alsoCleanIndexFiles: NSButton?
    /// The glulx interpreter to use
    @IBOutlet private final var glulxInterpreter: NSPopUpButton?

    /// Array of interpreter names, indexed by tags in the glulxInterpreter menu
    private final var interpreters: [String] = []

    // MARK: - Initialisation

    override convenience init() {
        self.init(preferences: IFPreferences.shared)
    }

    init(preferences thePreferences: IFPreferences) {
        preferences = thePreferences
        super.init(nibName: "AdvancedPreferences")

        reflectCurrentPreferences()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reflectCurrentPreferences),
                                               name: .IFPreferencesAdvancedDidChange,
                                               object: preferences)
    }

    // MARK: - Preference overrides

    public override var preferenceName: String {
        return "Advanced"
    }

    public override var toolbarImage: NSImage? {
        return Bundle(for: type(of: self)).image(forResource: "App/gearshape.2")
    }

    public override var tooltip: String? {
        return IFUtility.localizedString("Advanced preferences tooltip")
    }

    // MARK: - Actions

    @IBAction func setPreference(_ sender: Any?) {
        // Read the current state of the buttons
        let willBuildSh            = runBuildSh?.state == .on
        let willAlwaysCompile      = alwaysCompile?.state == .on
        let willDebug              = showDebugLogs?.state == .on
        let willShowConsole        = showConsole?.state == .on
        let willPublicLibraryDebug = publicLibraryDebug?.state == .on
        let willCleanBuild         = cleanBuildFiles?.state == .on
        let willAlsoCleanIndex     = alsoCleanIndexFiles?.state == .on
        let interpreter            = interpreters[glulxInterpreter?.selectedItem?.tag ?? 0]
        let useInformCore          = useExternalInformCore?.state == .on
        let informCoreDirectory    = externalInformCoreDirectory?.stringValue ?? ""

        // Set the preferences to suitable values
        preferences.runBuildSh = willBuildSh
        preferences.alwaysCompile = willAlwaysCompile
        preferences.showDebuggingLogs = willDebug
        preferences.showConsoleDuringBuilds = willShowConsole
        preferences.publicLibraryDebug = willPublicLibraryDebug
        preferences.cleanProjectOnClose = willCleanBuild
        preferences.alsoCleanIndexFiles = willAlsoCleanIndex
        preferences.glulxInterpreter = interpreter
        preferences.useExternalInformCoreDirectory = useInformCore
        preferences.externalInformCoreDirectory = informCoreDirectory
    }

    @IBAction private func toggleUseExternalDirectory(_ sender: Any?) {
        setPreference(sender)

        reflectCurrentPreferences()
    }

    @IBAction private func chooseExternalInformCoreDirectory(_ sender: Any?) {
        // Present a panel for choosing an external Inform Core directory
        let panel: NSOpenPanel

        if let openInformCorePanel {
            panel = openInformCorePanel
        } else {
            panel = NSOpenPanel()
            openInformCorePanel = panel
        }

        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.resolvesAliases = true
        panel.allowsMultipleSelection = false
        panel.title = IFUtility.localizedString("Choose Inform Core directory")

        panel.begin { result in
            if result != .OK { return }

            self.externalInformCoreDirectory?.stringValue = panel.url?.path ?? ""
            self.useExternalInformCore?.state = .on
            self.setPreference(sender)
        }
    }

    func reflectCurrentPreferences() {
        // Update the list of interpreters
        let terpMenu = glulxInterpreter?.menu
        if let terpMenu {
            while terpMenu.numberOfItems > 0 { terpMenu.removeItem(at: 0) }
        }

        let configuration = Bundle.main.infoDictionary?["InformConfiguration"] as? [String: Any]
        interpreters = configuration?["AvailableInterpreters"] as? [String] ?? []
        var selIndex = 0
        for terp in interpreters {
            // Get the description of this interpreter from the localised strings
            let terpDesc = IFUtility.localizedString("terp-\(terp)",
                                                     default: terp)

            // Create the menu item for this interpreter
            let newItem = NSMenuItem(title: terpDesc,
                                     action: nil,
                                     keyEquivalent: "")
            newItem.tag = terpMenu?.numberOfItems ?? 0
            if terp == preferences.glulxInterpreter {
                selIndex = terpMenu?.numberOfItems ?? 0
            }

            // Add it to the menu
            terpMenu?.addItem(newItem)
        }

        // Select the appropriate item in the menu
        glulxInterpreter?.selectItem(at: selIndex)

        // Hide buttons that won't work when sandboxed
        runBuildSh?.isHidden = IFUtility.isSandboxed
        publicLibraryDebug?.isHidden = IFUtility.isSandboxed

        // Set the buttons according to the current state of the preferences
        runBuildSh?.state = preferences.runBuildSh              ? .on : .off
        alwaysCompile?.state = preferences.alwaysCompile           ? .on : .off
        showDebugLogs?.state = preferences.showDebuggingLogs       ? .on : .off
        showConsole?.state = preferences.showConsoleDuringBuilds ? .on : .off
        publicLibraryDebug?.state = preferences.publicLibraryDebug      ? .on : .off

        cleanBuildFiles?.state = preferences.cleanProjectOnClose         ? .on : .off

        if preferences.cleanProjectOnClose {
            alsoCleanIndexFiles?.state = preferences.alsoCleanIndexFiles ? .on : .off
            alsoCleanIndexFiles?.isEnabled = true
        } else {
            alsoCleanIndexFiles?.state = .off
            alsoCleanIndexFiles?.isEnabled = false
        }

        // External inform core
        useExternalInformCore?.state = preferences.useExternalInformCoreDirectory ? .on : .off
        externalInformCoreDirectory?.stringValue = preferences.externalInformCoreDirectory

        // Set text colour of label, based on if the 'Use Inform Core directory' is checked.
        let use = preferences.useExternalInformCoreDirectory
        if !use {
            externalInformCoreDirectory?.textColor = .disabledControlTextColor
        } else {
            externalInformCoreDirectory?.textColor = .controlTextColor
        }
    }
}
