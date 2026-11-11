//
//  IFGamePage.swift
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

import Cocoa
import GlkSound
import GlkView
import ZoomView

private final class IFSemiTransparentView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        // When the game is not running, show this view (semi transparent white) over the top.
        NSColor(deviceRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.5).setFill()
        NSIntersectionRect(dirtyRect, bounds).fill(using: .copy)
        super.draw(dirtyRect)
    }
}

@objc @implementation extension IFGamePage {
    /// The Glk (glulxe) view
    private final var gView: GlkView?
    /// The Z-Machine view
    private final var zView: ZoomView?
    /// The filename of the game to start
    private final var gameToRun: String?
    /// `true` to switch view to show the game page
    private final var willSwitchToPage = false

    /// The progress indicator (how much we've compiled, how the game is running, etc)
    private final var gameRunningProgress: IFProgress?
    private final var semiTransparentView: NSView?

    /// `true` if we are allowed to set breakpoints
    private final var setBreakpoint = false
    /// List of commands to automatically run once game has started
    private final var testCommands: [String]?

    private final var _isRunningGame = false

    var zoomView: ZoomView? {
        return zView
    }

    var glkView: GlkView? {
        return gView
    }

    var isRunningGame: Bool {
        return _isRunningGame
    }

    // MARK: - Initialisation

    @objc(initWithProjectController:)
    init(projectController controller: IFProjectController?) {
        super.init(nibName: "Game",
                   projectController: controller)

        // Register for changes to the app's font size
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(preferencesChanged(_:)),
                                               name: .IFPreferencesAppFontSizeDidChange,
                                               object: IFPreferences.shared)
    }

    deinit {
        // The pane lets go of its pages on the main thread
        MainActor.assumeIsolated {
            NotificationCenter.default.removeObserver(self)

            if let gameRunningProgress {
                gameRunningProgress.stop()
                parent?.removeProgressIndicator(gameRunningProgress)
            }

            if let zView {
                zView.removeFromSuperview()
                zView.delegate = nil
                zView.killTask()
            }
            if let gView {
                gView.removeFromSuperview()
                gView.delegate = nil
                gView.terminateClient()
            }
        }
    }

    // MARK: - Details about this view

    public override var title: String {
        return IFUtility.localizedString("Game Page Title",
                                         default: "Game")
    }

    // MARK: - Page validation

    public override var shouldShowPage: Bool {
        return zView != nil || gView != nil
    }

    // MARK: - The game view

    @objc private final func preferencesChanged(_ not: Notification) {
        zView?.scaleFactor = 1.0 / IFPreferences.shared.appFontSizeMultiplier
        gView?.scaleFactor = IFPreferences.shared.appFontSizeMultiplier
    }

    func activateDebug() {
        setBreakpoint = true
    }

    @objc(startRunningGame:)
    func startRunningGame(_ fileName: String) {
        (parent?.document as? IFProject)?.currentSkein?.interpreterRestart()

        if let zView {
            zView.killTask()
            zView.removeFromSuperview()
            self.zView = nil
        }

        if let gView {
            gView.terminateClient()
            gView.removeFromSuperview()
            self.gView = nil
        }
        if semiTransparentView == nil {
            let semiTransparentView = IFSemiTransparentView(frame: view.frame)
            self.semiTransparentView = semiTransparentView
            semiTransparentView.autoresizingMask = [.width, .height]

            // "Wants layer" is set so that the subviews (semiTransparentView and zView/gView) are ordered in Z correctly when sibling views overlap
            view.wantsLayer = true
            view.addSubview(semiTransparentView)
        }

        gameToRun = fileName

        if gameRunningProgress == nil {
            let gameRunningProgress = IFProgress(priority: IFProgressPriorityRunGame,
                                                 showsProgressBar: false,
                                                 canCancel: true)
            self.gameRunningProgress = gameRunningProgress
            if let parent {
                gameRunningProgress.setCancelAction(#selector(IFProjectController.stopProcess(_:)),
                                                    for: parent)
            }
            parent?.addProgressIndicator(gameRunningProgress)
            gameRunningProgress.start()
        }

        if (fileName as NSString).pathExtension == "ulx" {
            let runtimeErrors = IFRuntimeErrorParser()
            runtimeErrors.delegate = parent

            // Screws up the first responder, will cause the GlkView object to force a new first responder after it starts
            parent?.window?.makeFirstResponder(parent?.window)

            // Work out the default client to use
            var clientName = IFPreferences.shared.glulxInterpreter
            clientName = clientName + "-client"

            // Start running as a glulxe task
            let gView = GlkView()
            self.gView = gView
            gView.soundHandler = GlkSoundHandler()
            gView.delegate = self
            if let parent {
                gView.addOutputReceiver(parent)
            }
            gView.addOutputReceiver(runtimeErrors)

            if let project = parent?.document as? IFProject {
                gView.imageSource = IFGlkResources(project: project)
            }

            gView.autoresizingMask = [.width, .height]
            gView.frame = view.bounds
            view.addSubview(gView)

            gView.scaleFactor = IFPreferences.shared.appFontSizeMultiplier

            gView.setInputFileURL(URL(fileURLWithPath: fileName))

            let interpreterPath = Bundle.main.path(forAuxiliaryExecutable: clientName)

            if let interpreterPath {
                gView.launchClientApplication(interpreterPath,
                                              withArguments: nil)
            }
        } else {
            // Start running as a Zoom task
            let runtimeErrors = IFRuntimeErrorParser()

            runtimeErrors.delegate = parent

            let zView = ZoomView()
            self.zView = zView
            zView.delegate = self
            (parent?.document as? IFProject)?.currentSkein?.interpreterRestart()
            if let skein = (parent?.document as? IFProject)?.currentSkein {
                zView.add(skein)
            }
            zView.add(runtimeErrors)
            zView.runNewServer(nil)

            zView.setColours([NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 1),
                              NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1),
                              NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1),
                              NSColor(deviceRed: 1, green: 1, blue: 0, alpha: 1),
                              NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1),
                              NSColor(deviceRed: 1, green: 0, blue: 1, alpha: 1),
                              NSColor(deviceRed: 0, green: 1, blue: 1, alpha: 1),
                              NSColor(deviceRed: 1, green: 1, blue: 1, alpha: 1),

                              NSColor(deviceRed: 0.73, green: 0.73, blue: 0.73, alpha: 1),
                              NSColor(deviceRed: 0.53, green: 0.53, blue: 0.53, alpha: 1),
                              NSColor(deviceRed: 0.26, green: 0.26, blue: 0.26, alpha: 1)])

            zView.scaleFactor = 1.0 / IFPreferences.shared.appFontSizeMultiplier

            zView.frame = view.bounds
            zView.autoresizingMask = [.width, .height]
            view.addSubview(zView)
        }
        semiTransparentView?.isHidden = true
        _isRunningGame = true
    }

    func setPointToRunTo(_ item: IFSkeinItem?) {
        var commands: [String] = []

        var item = item
        while let current = item, current.parent != nil {
            commands.insert(current.command, at: 0)
            item = current.parent
        }
        setTestCommands(commands)
    }

    func setTestCommands(_ myTestCommands: [String]?) {
        testCommands = myTestCommands
    }

    func takeTestCommands() -> ZoomViewInputSource? {
        guard let testCommands else {
            return nil
        }

        // TestCommands types its last command first
        let reversedArray = Array(testCommands.reversed())
        self.testCommands = nil

        return TestCommands(commands: reversedArray)
    }

    @objc(setSwitchToPage:)
    func setSwitchTo(_ switchToPage: Bool) {
        willSwitchToPage = switchToPage
    }

    func stopRunningGame() {
        zView?.killTask()

        gView?.terminateClient()

        _isRunningGame = false

        (parent?.document as? IFProject)?.currentSkein?.interpreterStop()

        // Make sure the semi transparent white window is shown on top of other views
        if let semiTransparentView {
            semiTransparentView.removeFromSuperview()
            view.addSubview(semiTransparentView,
                            positioned: .above,
                            relativeTo: nil)
            semiTransparentView.isHidden = false
            semiTransparentView.needsDisplay = true
        }
        gameRunningProgress?.stopStory()
    }

    // MARK: - Page actions

    public override func didSwitchToPage() {
        gView?.showMoreWindow()
    }

    public override func didSwitchAwayFromPage() {
        gView?.hideMoreWindow()
    }
}

// The page is the delegate of the views it runs stories in, as its class extension declared. They call it on the
// main thread, but don't say so, so the conformances are @preconcurrency.
extension IFGamePage: @preconcurrency GlkViewDelegate, @preconcurrency ZoomViewDelegate {
    // MARK: - GlkView delegate methods

    public func taskHasStarted() {
        if willSwitchToPage {
            switchToPage()
        }

        parent?.glkTaskHasStarted(self)

        gameRunningProgress?.stop()
        gameRunningProgress?.startStory()

        let inputSource = takeTestCommands()
        if let inputSource {
            parent?.glkInputSource = inputSource
            if let parent {
                gView?.addInputReceiver(parent)
            }
        }
    }

    public var disableLogo: Bool {
        return true
    }

    public func path(forNamedFile name: String) -> String? {
        // Append .glkdata if the name has no extension
        var name = (name as NSString).lastPathComponent
        guard let nameWithExtension = ((name as NSString).deletingPathExtension as NSString).appendingPathExtension("glkdata") else {
            // There's no file for a name that the extension can't be added to, such as an empty one
            return nil
        }
        name = nameWithExtension

        // Work out the location of the materials directory
        let projectURL   = (parent?.document as? IFProject)?.fileURL
        let materialsURL = (parent?.document as? IFProject)?.materialsDirectoryURL

        // Default location is materials/Files
        let filesDirURL = materialsURL?.appendingPathComponent("Files")

        // Use this directory if it exists
        var isDir: ObjCBool = false
        let exists = filesDirURL.map { FileManager.default.fileExists(atPath: $0.path, isDirectory: &isDir) } ?? false

        if exists && isDir.boolValue {
            // Use the files directory
            return filesDirURL?.appendingPathComponent(name).path
        } else {
            // Use the directory the project is in
            return projectURL?.deletingLastPathComponent().appendingPathComponent(name).path
        }
    }

    // MARK: - ZoomView delegate methods

    public func inputSourceHasFinished(_ sender: ZoomViewInputSource) {
        parent?.inputSourceHasFinished(nil)
    }

    public func zMachineStarted(_ sender: Any?) {
        let storyFile = gameToRun.flatMap { NSData(contentsOfFile: $0) }
        zView?.zMachine?.loadStoryFile((storyFile ?? NSData()) as Data)

        if let projectPath = (parent?.document as? IFProject)?.fileURL?.path as NSString? {
            zView?.zMachine?.loadDebugSymbols(fromFile: (projectPath.appendingPathComponent("Build") as NSString).appendingPathComponent("gameinfo.dbg"),
                                              withSourcePath: projectPath.appendingPathComponent("Source"))
        }

        // Set the initial breakpoint if 'Debug' was selected
        if setBreakpoint {
            if zView?.zMachine?.setBreakpointAtName("Initialise") != true {
                _ = zView?.zMachine?.setBreakpointAtName("main")
            }
        }

        setBreakpoint = false

        // Run to the appropriate point in the current skein
        let inputSource = takeTestCommands()
        if let inputSource {
            zView?.inputSource = inputSource
        }
        if willSwitchToPage {
            switchToPage()
        }

        parent?.window?.makeFirstResponder(zView?.textView)

        gameRunningProgress?.stop()
        gameRunningProgress?.startStory()
    }

    // MARK: - Debugging

    public func zoomWaitingForInput() {
        parent?.zoomViewIsWaitingForInput()
    }
}
