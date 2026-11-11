//
//  IFNewProject.swift
//  Inform
//
//  Created by Andrew Hunter on Fri Sep 12 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFNewProject.h.
//

import Cocoa

@objc @implementation extension IFNewProject {
    /// The pane that contains the display for the current stage in the creation process
    @IBOutlet private final var projectPaneView: NSView?
    @IBOutlet private final var promptTextField: NSTextField?

    /// The current project type
    private final var projectType: (any IFNewProjectProtocol)?
    /// The view of (Inform 6 project) settings
    private final var projectView: (any IFNewProjectSetupView)?
    private final var projectFileTypes: [String]?
    private final var projectTitle: String?
    private final var projectPrompt: String?
    private final var projectStory: String?
    // The URLs are NSURLs, as @implementation can't store a URL
    private final var projectExtensionURL: NSURL?
    private final var projectDefaultFilename: String?
    private final var projectFlow: IFNewProjectFlow = []

    /// Location of extension file or extension project
    private final var projectLocation: NSURL?

    // MARK: - Initialisation

    // The initialisers are NSWindowController's, so init, which the app uses, starts with no window. The Objective-C's
    // init called initWithWindowNibName:, but Swift can't override init, which NSWindowController doesn't designate,
    // so the nib is named here.
    public override var windowNibName: NSNib.Name? {
        return "NewProject"
    }

    // MARK: - Interface

    private final func isExtension() -> Bool {
        return projectType is IFNewInform7ExtensionFile
    }

    /// Creates the extension, or says it couldn't, and gives whether it did
    private final func createExtension() -> Bool {
        // Only asked for a new extension
        let proj = projectType as! IFNewInform7ExtensionFile

        // There's a filename, as showError has just found nothing wrong
        let location = URL(fileURLWithPath: proj.saveFilename!)
        projectLocation = location as NSURL
        if proj.createAndOpenDocument(location) {
            // Success
            return true
        } else {
            // On the window if it's shown, which is kept for the options to be changed, as it isn't closed
            IFUtility.runAlertWarning(visibleWindow(),
                                      title: "Unable to create project",
                                      informativeText: IFUtility.localizedString("Inform was unable to save the extension file"))
            return false
        }
    }

    /// Creates the project, or says it couldn't, and gives whether it did
    private final func createProject() -> Bool {
        let theFile = IFProjectFile(emptyProject: ())

        theFile.filename = projectLocation?.path
        projectType?.setupFile(theFile,
                               from: projectView as? NSObject & IFNewProjectSetupView,
                               withStory: projectStory,
                               withExtensionURL: projectExtensionURL as URL?)

        let success = theFile.write

        if success {
            // Create IFProject (an NSDocument)
            guard let projectLocation, let projectType,
                  let newDoc = try? IFProject(contentsOf: projectLocation as URL, ofType: projectType.typeName) else {
                // The project is written, but can't be opened (the Objective-C gave the document controller nil)
                return true
            }
            newDoc.initialSelectionRange = projectType.initialSelectionRange
            newDoc.createMaterials()

            NSDocumentController.shared.addDocument(newDoc)
            newDoc.makeWindowControllers()
            newDoc.showWindows()
            return true
        } else {
            // The window is never shown for a new project, so the alert is run on its own
            IFUtility.runAlertWarning(visibleWindow(),
                                      title: "Unable to create project",
                                      informativeText: IFUtility.localizedString("Inform was unable to save the project file"))
            return false
        }
    }

    /// Creates the extension or project, or says it couldn't, and gives whether it did
    private final func createItem() -> Bool {
        // Create extension
        if isExtension() {
            return createExtension()
        }

        // Create project
        return createProject()
    }

    public override func close() {
        projectTitle            = nil
        projectPrompt           = nil
        projectFileTypes        = nil
        projectStory            = nil
        projectDefaultFilename  = nil
        projectView?.view?.removeFromSuperview()
        projectView             = nil
        projectLocation         = nil
        projectType             = nil

        window?.close()
    }

    private final func visibleWindow() -> NSWindow? {
        if let window, window.isVisible {
            return window
        }
        return nil
    }

    /// Shows what's wrong with the way things are set up, if anything, and gives whether there was something
    private final func showError() -> Bool {
        if let errorMessage = projectType?.errorMessage, let error = errorMessage {
            IFUtility.runAlertWarning(visibleWindow(),
                                      title: "Error",
                                      informativeText: error)
            return true
        }
        return false
    }

    private final func validate() {
        let win = visibleWindow()

        if showError() {
            return
        }

        if let confirmationMessage = projectType?.confirmationMessage, let confirm = confirmationMessage {
            IFUtility.runAlertYesNoWindow(win,
                                          title: IFUtility.localizedString("Are you sure?"),
                                          yes: IFUtility.localizedString("Create"),
                                          no: IFUtility.localizedString("Cancel"),
                                          modalDelegate: self,
                                          didEnd: #selector(confirmDidEnd(_:returnCode:contextInfo:)),
                                          contextInfo: nil,
                                          informativeText: confirm)
            return
        }

        if createItem() {
            close()
        }
    }

    @objc private func confirmDidEnd(_ sheet: NSWindow?,
                                     returnCode: NSApplication.ModalResponse,
                                     contextInfo: UnsafeMutableRawPointer?) {
        if returnCode == .alertFirstButtonReturn {
            // Something may have gone wrong while the user was asked, such as the project closing
            if showError() {
                return
            }
            if createItem() {
                close()
            }
        }
    }

    private final func chooseLocation() {
        // Setup a save panel
        let panel = NSSavePanel()

        panel.accessoryView = nil
        panel.allowedContentTypes = IFUtility.contentTypes(forFilenameExtensions: projectFileTypes ?? [])
        panel.prompt = projectPrompt
        panel.treatsFilePackagesAsDirectories = false
        if let projectDefaultFilename {
            panel.nameFieldStringValue = projectDefaultFilename
        }

        // Use any currently visible window
        var win: NSWindow? = nil
        if let window, window.isVisible {
            win = window
        }

        // Show it
        IFUtility.begin(panel, for: win) { result in
            if result == .OK {
                self.projectLocation = panel.url as NSURL?

                self.validate()
            }

            // Finished
            self.close()
        }
    }

    @IBAction func cancelButtonClicked(_ sender: Any?) {
        close()
    }

    @IBAction func okButtonClicked(_ sender: Any?) {
        if projectFlow.contains(.location) {
            chooseLocation()
        } else {
            validate()
        }
    }

    private final func chooseOptions() {
        showWindow(self)
        window?.title = projectTitle ?? ""
        promptTextField?.stringValue = projectPrompt ?? ""

        projectView?.view?.frame = projectPaneView?.bounds ?? .zero

        if let view = projectView?.view {
            projectPaneView?.addSubview(view,
                                        positioned: .above,
                                        relativeTo: nil)
        }

        if let window {
            projectType?.setInitialFocus(window)
        }
    }

    private final func startFlow() {
        if projectFlow.contains(.options) {
            chooseOptions()
        } else if projectFlow.contains(.location) {
            chooseLocation()
        } else {
            validate()
        }
    }

    func createInform7ExtensionProject(_ title: String,
                                       fromExtensionURL extensionURL: URL) {
        close()

        projectType             = IFNewInform7ExtensionProject()
        projectFileTypes        = ["i7xp"]
        projectTitle            = IFUtility.localizedString("Create Extension Project")
        projectPrompt           = IFUtility.localizedString("Create Extension Project")
        projectView             = projectType?.configView
        projectFlow             = .location
        projectStory            = nil
        projectExtensionURL     = extensionURL as NSURL
        projectDefaultFilename  = title

        startFlow()
    }

    func createInform7Project(_ title: String?,
                              fileType: IFFileType,
                              story: String?) {
        close()

        if fileType == .inform7Project {
            projectType         = IFNewInform7Project()
            projectFileTypes    = ["inform"]
        } else if fileType == .inform7ExtensionProject {
            projectType         = IFNewInform7ExtensionProject()
            projectFileTypes    = ["i7xp"]
        } else {
            preconditionFailure("invalid project type")
        }
        projectTitle            = IFUtility.localizedString("Create Project")
        projectPrompt           = IFUtility.localizedString("Create Project")
        projectView             = projectType?.configView
        projectFlow             = .location
        projectStory            = story
        projectExtensionURL     = nil
        projectDefaultFilename  = title

        startFlow()
    }

    @objc(createInform7ExtensionForProject:)
    func createInform7Extension(for theProject: IFProject) {
        close()

        projectType             = IFNewInform7ExtensionFile(project: theProject)
        projectFileTypes        = ["i7x"]
        projectTitle            = IFUtility.localizedString("Create Extension")
        projectPrompt           = IFUtility.localizedString("Create Extension")
        projectView             = projectType?.configView
        projectFlow             = .options
        projectStory            = nil
        projectExtensionURL     = nil
        projectDefaultFilename  = nil

        startFlow()
    }
}
