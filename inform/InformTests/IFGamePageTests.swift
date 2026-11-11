//
//  IFGamePageTests.swift
//  InformTests
//

import XCTest

/// A project controller with no window, whose document is the project the test gives it, and which records what the
/// game page tells it
private final class ProjectControllerStandIn: IFProjectController {
    /// The project, which the page asks for its skein and its location
    var project: IFProject?
    /// What has told the controller that a Glk story has started
    private(set) var startedSenders: [Any?] = []
    /// What the controller has been told has finished typing commands
    private(set) var finishedSources: [Any?] = []
    /// How often the controller has been told that the story is waiting for input
    private(set) var timesWaitingForInput = 0

    override var document: AnyObject? {
        get {
            return project
        }
        set {
        }
    }

    /// No window, so that a project's isn't loaded, as its toolbar manager asks for it whenever any window resizes
    override var window: NSWindow? {
        get {
            return nil
        }
        set {
        }
    }

    override func glkTaskHasStarted(_ sender: Any?) {
        startedSenders.append(sender)
    }

    override func inputSourceHasFinished(_ source: Any?) {
        finishedSources.append(source)
    }

    override func zoomViewIsWaitingForInput() {
        timesWaitingForInput += 1
    }
}

@MainActor
final class IFGamePageTests: XCTestCase, @unchecked Sendable {
    private var controller: ProjectControllerStandIn?
    /// A folder for the project, removed after each test
    private var folder: URL?

    override func setUpWithError() throws {
        try MainActor.assumeIsolated {
            try super.setUpWithError()

            // A project controller that doesn't watch for settings changing, and so doesn't make the project window's
            // toolbar for them, which saves its configuration in the user's preferences.
            let controller = ProjectControllerStandIn()
            NotificationCenter.default.removeObserver(controller)
            self.controller = controller

            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            self.folder = folder
        }
    }

    override func tearDownWithError() throws {
        try MainActor.assumeIsolated {
            controller = nil
            if let folder {
                try FileManager.default.removeItem(at: folder)
            }
            folder = nil
            try super.tearDownWithError()
        }
    }

    // MARK: - Helpers

    /// A game page for a project called Test in the test's folder, which no story has run in
    private func makePage() throws -> IFGamePage {
        let project = IFProject()
        project.fileURL = try XCTUnwrap(folder).appendingPathComponent("Test.inform")

        let controller = try XCTUnwrap(controller)
        controller.project = project
        return IFGamePage(projectController: controller)
    }

    /// The page as the delegate of a Glk view, as it makes itself when it runs a Glk story
    private func glkDelegate(_ page: IFGamePage) throws -> GlkViewDelegate {
        return try XCTUnwrap(page as? GlkViewDelegate)
    }

    /// The page as the delegate of a Zoom view, as it makes itself when it runs a Z-machine story
    private func zoomDelegate(_ page: IFGamePage) throws -> ZoomViewDelegate {
        return try XCTUnwrap(page as? ZoomViewDelegate)
    }

    /// Everything an input source would type, in order.
    private func typed(_ source: ZoomViewInputSource) -> [String] {
        var typed: [String] = []
        while let command = source.nextCommand?() {
            typed.append(command)
        }
        return typed
    }

    /// Everything the game page's input source would type, in order.
    private func typedCommands(_ page: IFGamePage) throws -> [String] {
        return typed(try XCTUnwrap(page.takeTestCommands()))
    }

    /// How often the page asks to be shown while the block runs
    private func timesAskedToBeShown(_ page: IFGamePage, during block: () throws -> Void) rethrows -> Int {
        nonisolated(unsafe) var times = 0
        let observer = NotificationCenter.default.addObserver(forName: .IFSwitchToPage, object: page, queue: nil) { _ in
            times += 1
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }
        try block()
        return times
    }

    // MARK: - A new page

    func testANewPage() {
        let page: IFGamePage = IFGamePage(projectController: nil)
        XCTAssertEqual(page.title, "Story")
        XCTAssertFalse(page.shouldShowPage, "There's nothing to show until a story runs")
        XCTAssertFalse(page.isRunningGame)
        XCTAssertNil(page.zoomView)
        XCTAssertNil(page.glkView)
        XCTAssertNil(page.takeTestCommands())
    }

    // MARK: - Commands to type

    func testPlayingToAKnotTypesTheCommandsFromTheStart() throws {
        let skein: IFSkein = IFSkein(project: nil)
        let look: IFSkeinItem = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "look"))
        let inventory: IFSkeinItem = look.addChild(IFSkeinItem(skein: skein, command: "inventory"))
        let examine: IFSkeinItem = inventory.addChild(IFSkeinItem(skein: skein, command: "examine ball"))

        let page: IFGamePage = IFGamePage(projectController: nil)
        page.setPointToRunTo(examine)
        XCTAssertEqual(try typedCommands(page), ["look", "inventory", "examine ball"])
        XCTAssertNil(page.takeTestCommands(), "The commands are typed only once")
    }

    /// Playing to the skein's root, or to no knot, types nothing, though there's still something to type it
    func testPlayingToTheStartTypesNothing() throws {
        let skein: IFSkein = IFSkein(project: nil)
        let page: IFGamePage = IFGamePage(projectController: nil)

        page.setPointToRunTo(skein.rootItem)
        XCTAssertEqual(try typedCommands(page), [])

        page.setPointToRunTo(nil)
        XCTAssertEqual(try typedCommands(page), [])
    }

    func testTestCommandsAreTypedInOrder() throws {
        let page: IFGamePage = IFGamePage(projectController: nil)
        page.setTestCommands(["take ball", "drop ball", "test me"])
        XCTAssertEqual(try typedCommands(page), ["take ball", "drop ball", "test me"])
    }

    func testClearingTheTestCommands() {
        let page: IFGamePage = IFGamePage(projectController: nil)
        page.setTestCommands(["look"])
        page.setTestCommands(nil)
        XCTAssertNil(page.takeTestCommands())
    }

    /// A point to run to and test commands set the same commands, so the last one set is typed
    func testTheCommandsSetLastAreTyped() throws {
        let skein: IFSkein = IFSkein(project: nil)
        let look: IFSkeinItem = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "look"))
        let page: IFGamePage = IFGamePage(projectController: nil)

        page.setTestCommands(["take ball"])
        page.setPointToRunTo(look)
        XCTAssertEqual(try typedCommands(page), ["look"])

        page.setPointToRunTo(look)
        page.setTestCommands(["take ball"])
        XCTAssertEqual(try typedCommands(page), ["take ball"])
    }

    // MARK: - Glk stories

    func testAGlkViewShowsNoLogo() throws {
        let page: IFGamePage = IFGamePage(projectController: nil)
        XCTAssertEqual(try glkDelegate(page).disableLogo, true)
    }

    /// When a Glk story starts, the page tells the controller, and gives it the test commands to type
    func testWhenAGlkStoryStartsTheControllerTypesTheTestCommands() throws {
        let page = try makePage()
        let controller = try XCTUnwrap(controller)
        page.setTestCommands(["take ball", "drop ball"])

        try glkDelegate(page).taskHasStarted?()

        XCTAssertEqual(controller.startedSenders.count, 1)
        XCTAssertTrue(controller.startedSenders.first as AnyObject === page)
        XCTAssertEqual(typed(try XCTUnwrap(controller.glkInputSource)), ["take ball", "drop ball"])
        XCTAssertNil(page.takeTestCommands(), "The commands are typed only once")
    }

    func testWhenAGlkStoryStartsWithNoTestCommands() throws {
        let page = try makePage()
        let controller = try XCTUnwrap(controller)

        try glkDelegate(page).taskHasStarted?()

        XCTAssertEqual(controller.startedSenders.count, 1)
        XCTAssertNil(controller.glkInputSource)
    }

    /// When a Glk story starts, the page asks to be shown only if it has been told to
    func testWhenAGlkStoryStartsThePageAsksToBeShownIfToldTo() throws {
        let page = try makePage()
        let delegate = try glkDelegate(page)

        XCTAssertEqual(timesAskedToBeShown(page) { delegate.taskHasStarted?() }, 0)

        page.setSwitchTo(true)
        XCTAssertEqual(timesAskedToBeShown(page) { delegate.taskHasStarted?() }, 1)

        page.setSwitchTo(false)
        XCTAssertEqual(timesAskedToBeShown(page) { delegate.taskHasStarted?() }, 0)
    }

    /// A file that a Glk story names goes next to the project, without its folder, and with the extension .glkdata in
    /// place of its own
    func testANamedFileGoesNextToTheProject() throws {
        let page = try makePage()
        let delegate = try glkDelegate(page)
        let folder = try XCTUnwrap(folder)

        XCTAssertEqual(delegate.path?(forNamedFile: "scores"), folder.appendingPathComponent("scores.glkdata").path)
        XCTAssertEqual(delegate.path?(forNamedFile: "scores.txt"), folder.appendingPathComponent("scores.glkdata").path)
        XCTAssertEqual(delegate.path?(forNamedFile: "old.scores.txt"),
                       folder.appendingPathComponent("old.scores.glkdata").path)
        XCTAssertEqual(delegate.path?(forNamedFile: "Saves/scores.txt"),
                       folder.appendingPathComponent("scores.glkdata").path)
    }

    /// When the project's materials folder has a folder called Files, a named file goes in it
    func testANamedFileGoesInTheMaterialsFilesFolder() throws {
        let page = try makePage()
        let files = try XCTUnwrap(folder).appendingPathComponent("Test.materials/Files", isDirectory: true)
        try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)

        XCTAssertEqual(try glkDelegate(page).path?(forNamedFile: "scores"),
                       files.appendingPathComponent("scores.glkdata").path)
    }

    /// A file called Files in the materials folder isn't where named files go
    func testANamedFileDoesNotGoInAFileCalledFiles() throws {
        let page = try makePage()
        let folder = try XCTUnwrap(folder)
        let materials = folder.appendingPathComponent("Test.materials", isDirectory: true)
        try FileManager.default.createDirectory(at: materials, withIntermediateDirectories: true)
        try Data().write(to: materials.appendingPathComponent("Files"))

        XCTAssertEqual(try glkDelegate(page).path?(forNamedFile: "scores"),
                       folder.appendingPathComponent("scores.glkdata").path)
    }

    func testANamedFileHasNowhereToGoWithNoProject() throws {
        let page: IFGamePage = IFGamePage(projectController: nil)
        XCTAssertNil(try glkDelegate(page).path?(forNamedFile: "scores"))
    }

    /// A name that the extension can't be added to has no file, as with CocoaGlk's own default for an empty name
    func testANamedFileWithNoName() throws {
        let page = try makePage()
        let delegate = try glkDelegate(page)
        XCTAssertNil(delegate.path?(forNamedFile: ""))
        XCTAssertNil(delegate.path?(forNamedFile: "/"))
    }

    // MARK: - Z-machine stories

    /// When a Z-machine story starts, the page takes the test commands for its Zoom view to type, and asks to be
    /// shown if it has been told to. (No story is running here, so there's no view to type them.)
    func testWhenAZMachineStoryStartsThePageTakesTheTestCommands() throws {
        let page = try makePage()
        let delegate = try zoomDelegate(page)
        page.setTestCommands(["look"])

        XCTAssertEqual(timesAskedToBeShown(page) { delegate.zMachineStarted?(nil) }, 0)
        XCTAssertNil(page.takeTestCommands())

        page.setSwitchTo(true)
        XCTAssertEqual(timesAskedToBeShown(page) { delegate.zMachineStarted?(nil) }, 1)
    }

    func testWaitingForInputTellsTheController() throws {
        let page = try makePage()
        try zoomDelegate(page).zoomWaitingForInput?()
        XCTAssertEqual(try XCTUnwrap(controller).timesWaitingForInput, 1)
    }

    /// When the commands have all been typed, the page tells the controller, though not what typed them
    func testFinishingTypingTellsTheController() throws {
        let page = try makePage()
        page.setTestCommands(["look"])
        let source = try XCTUnwrap(page.takeTestCommands())

        try zoomDelegate(page).inputSourceHasFinished?(source)

        let controller = try XCTUnwrap(controller)
        XCTAssertEqual(controller.finishedSources.count, 1)
        XCTAssertTrue(controller.finishedSources.allSatisfy { $0 == nil })
    }

    // MARK: - Stopping

    /// Each pane stops its game page when it's loaded, before any story has run
    func testStoppingWithNoStory() throws {
        let page = try makePage()
        let subviews = page.view.subviews

        page.stopRunningGame()

        XCTAssertFalse(page.isRunningGame)
        XCTAssertEqual(page.view.subviews, subviews)
    }

    /// Stopping tells the project's skein that the story has stopped, so it has no active knot
    func testStoppingTellsTheSkein() throws {
        let page = try makePage()
        let skein = try XCTUnwrap(controller?.project?.currentSkein)
        skein.activeItem = skein.rootItem

        page.stopRunningGame()

        XCTAssertNil(skein.activeItem)
    }
}
