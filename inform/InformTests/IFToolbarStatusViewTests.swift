//
//  IFToolbarStatusViewTests.swift
//  InformTests
//

import XCTest

/// A project controller with a project and no window, so that a project's toolbar isn't loaded
private final class ProjectControllerStandIn: IFProjectController {
    var project: IFProject?

    override var document: AnyObject? {
        get {
            return project
        }
        set {
        }
    }

    override var window: NSWindow? {
        get {
            return nil
        }
        set {
        }
    }
}

/// A toolbar manager for the project controller given, which records when it's asked to cancel
private final class ManagerStandIn: IFToolbarManager {
    var controller: IFProjectController?
    var cancelCount = 0

    override var projectController: IFProjectController? {
        return controller
    }

    override func cancelProgress() {
        cancelCount += 1
    }
}

@MainActor
final class IFToolbarStatusViewTests: XCTestCase, @unchecked Sendable {

    private var view: IFToolbarStatusView!
    private var manager: ManagerStandIn!
    private var controller: ProjectControllerStandIn!

    /// The size the toolbar manager gives the view
    private let toolbarSize = NSSize(width: 300, height: 30)

    override func setUp() {
        MainActor.assumeIsolated {
            super.setUp()
            view = IFToolbarStatusView(frame: NSRect(origin: .zero, size: toolbarSize))
            controller = ProjectControllerStandIn()
            manager = ManagerStandIn()
            manager.controller = controller
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            view = nil
            manager = nil
            controller = nil
            super.tearDown()
        }
    }

    // MARK: - Helpers

    // The view's parts, in the order it adds them
    private var welcomeTitle: NSTextField { return view.subviews[0] as! NSTextField }
    private var welcomeBuild: NSTextField { return view.subviews[1] as! NSTextField }
    private var welcomeImage: NSImageView { return view.subviews[2] as! NSImageView }
    private var titleText: NSTextField { return view.subviews[3] as! NSTextField }
    private var storyText: NSTextField { return view.subviews[4] as! NSTextField }
    private var progressBar: NSProgressIndicator { return view.subviews[5] as! NSProgressIndicator }
    private var cancelButton: NSButton { return view.subviews[6] as! NSButton }

    private var welcomeIsShown: Bool {
        let shown = [welcomeTitle, welcomeBuild, welcomeImage].map { !$0.isHidden }
        XCTAssertEqual(Set(shown).count, 1, "Only part of the welcome is shown")
        return shown[0]
    }

    /// Gives the manager a project whose compiler is the version given
    private func useCompiler(_ version: String) {
        let project = IFProject()
        let settings = IFCompilerSettings()
        settings.compilerVersion = version
        project.compiler.settings = settings
        controller.project = project
        view.delegate = manager
    }

    /// The times a story could have started at, from before something is done to after it
    private func times(during action: () -> Void) -> Set<String> {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let before = formatter.string(from: Date())
        action()
        return [before, formatter.string(from: Date())]
    }

    /// The width of a string in the view's text
    private func width(of string: String) -> CGFloat {
        return string.size(withAttributes: [.font: storyText.font!]).width
    }

    private var lineHeight: CGFloat {
        return "Fg".size(withAttributes: [.font: NSTextField().font!]).height
    }

    /// The view drawn into a bitmap
    private func picture(appearance: NSAppearance.Name = .aqua) -> NSBitmapImageRep {
        let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
            view.cacheDisplay(in: view.bounds, to: rep)
        }
        return rep
    }

    // MARK: - The welcome

    func testTheWelcomeIsShownAtFirst() {
        XCTAssertEqual(view.subviews.count, 7)
        XCTAssertTrue(welcomeIsShown)
        XCTAssertEqual(welcomeTitle.stringValue, "Inform")
        XCTAssertEqual(welcomeBuild.stringValue, "Build \(IFUtility.coreBuildVersion ?? "")")
        XCTAssertTrue(welcomeImage.image === NSImage(named: "Blob-Logo"))

        XCTAssertEqual(titleText.stringValue, "")
        XCTAssertEqual(storyText.stringValue, "")
        XCTAssertTrue(progressBar.isHidden)
        XCTAssertTrue(cancelButton.isHidden)
    }

    func testTheWelcomeIsInTheMiddle() throws {
        let logoSize = try XCTUnwrap(NSImage(named: "Blob-Logo")).size
        let logo = NSRect(x: floor(150 - logoSize.width / 2), y: floor(15 - logoSize.height / 2),
                          width: logoSize.width, height: logoSize.height)

        XCTAssertEqual(welcomeImage.frame, logo)
        // "Inform" on the left, ten points from the logo, and the build ten points to the right
        XCTAssertEqual(welcomeTitle.frame.minX, 0)
        XCTAssertEqual(welcomeTitle.frame.maxX, logo.minX - 10)
        XCTAssertEqual(welcomeTitle.alignment, .right)
        XCTAssertEqual(welcomeBuild.frame.minX, logo.maxX + 10)
        XCTAssertEqual(welcomeBuild.frame.maxX, 300)
        XCTAssertEqual(welcomeBuild.alignment, .left)
        XCTAssertEqual(welcomeTitle.frame.midY, 15, accuracy: 1)
        XCTAssertEqual(welcomeBuild.frame.midY, 15, accuracy: 1)
    }

    func testTheWelcomeStaysInTheMiddleWhenTheViewIsResized() {
        view.setFrameSize(NSSize(width: 400, height: 30))

        XCTAssertEqual(welcomeImage.frame.midX, 200, accuracy: 1)
        XCTAssertEqual(welcomeBuild.frame.maxX, 400)
    }

    func testUpdatingTheToolbarLaysTheViewOutAgain() {
        view.postsFrameChangedNotifications = false
        view.setFrameSize(NSSize(width: 400, height: 30))
        XCTAssertEqual(welcomeImage.frame.midX, 150, accuracy: 1)

        view.updateToolbar()
        XCTAssertEqual(welcomeImage.frame.midX, 200, accuracy: 1)
    }

    // MARK: - Messages

    func testAMessageGoesInTheTitle() {
        view.showMessage("Compiling")

        XCTAssertEqual(titleText.stringValue, "Compiling")
        XCTAssertEqual(titleText.alignment, .center)
    }

    func testTheTitleIsHiddenWhenTheViewIsTooShortForIt() {
        // As in the toolbar
        XCTAssertTrue(titleText.isHidden)

        view.setFrameSize(NSSize(width: 300, height: 50))
        XCTAssertFalse(titleText.isHidden)

        view.setFrameSize(toolbarSize)
        XCTAssertTrue(titleText.isHidden)
    }

    /// The story line is hidden while the progress bar is shown, so a message has room above the bar, the two
    /// together in the middle of the view
    func testAMessageIsShownAboveTheProgressBar() {
        view.startProgress()
        view.showMessage("Compiling")

        XCTAssertFalse(titleText.isHidden)
        XCTAssertEqual(progressBar.frame.size, NSSize(width: 260, height: 10))
        XCTAssertEqual(titleText.frame.minY, progressBar.frame.maxY)
        XCTAssertEqual(progressBar.frame.minY, toolbarSize.height - titleText.frame.maxY, accuracy: 1)
        XCTAssertGreaterThanOrEqual(progressBar.frame.minY, 2)
        XCTAssertFalse(welcomeIsShown)
    }

    func testTheCancelButtonIsBesideAMessageAndTheProgressBar() {
        view.canCancel(true)
        view.startProgress()
        view.showMessage("Compiling")

        XCTAssertEqual(cancelButton.frame, NSRect(x: 274, y: 7, width: 16, height: 16))
        XCTAssertEqual(progressBar.frame.width, 244)
    }

    func testAMessageGoesWithTheProgressBar() {
        view.startProgress()
        view.showMessage("Compiling")
        view.stopProgress()

        XCTAssertTrue(titleText.isHidden)
    }

    /// A message from before the bar was shown, such as the last compilation's, isn't the new progress's
    func testAMessageFromBeforeTheProgressBarIsntShownAboveIt() {
        view.showMessage("Compiled")
        view.startProgress()

        XCTAssertTrue(titleText.isHidden || titleText.stringValue.isEmpty)
        XCTAssertEqual(progressBar.frame, NSRect(x: 20, y: 10, width: 260, height: 10))
    }

    func testInATallerViewTheTitleIsAtTheTop() {
        view.setFrameSize(NSSize(width: 300, height: 50))

        XCTAssertEqual(titleText.frame, NSRect(x: 0, y: floor(50 - lineHeight - 6), width: 300, height: lineHeight))
    }

    // MARK: - The story

    func testStartingTheStorySaysWhenItStarted() {
        useCompiler(IFUtility.coreBuildVersion ?? "")
        let times = times { view.startStory() }

        XCTAssertTrue(times.map { "Story started at \($0)." }.contains(storyText.stringValue), storyText.stringValue)
        XCTAssertFalse(storyText.isHidden)
        XCTAssertFalse(welcomeIsShown)
        XCTAssertTrue(progressBar.isHidden)
    }

    func testStartingTheStoryWithAnOldCompilerSaysWhichOne() {
        useCompiler("6L38")
        let times = times { view.startStory() }

        XCTAssertTrue(times.map { "Using historic version 6L38. Started at \($0)." }.contains(storyText.stringValue),
                      storyText.stringValue)
    }

    func testStartingTheStoryWithNoManagerUsesTheCurrentCompiler() {
        let times = times { view.startStory() }

        XCTAssertTrue(times.map { "Story started at \($0)." }.contains(storyText.stringValue), storyText.stringValue)
    }

    func testAStoryCanBeCancelled() {
        useCompiler("6L38")
        view.startStory()

        XCTAssertFalse(cancelButton.isHidden)
    }

    func testTheCancelButtonIsAfterTheStory() {
        useCompiler(IFUtility.coreBuildVersion ?? "")
        view.startStory()

        let storyWidth = width(of: storyText.stringValue)
        XCTAssertEqual(cancelButton.frame.size, NSSize(width: 16, height: 16))
        XCTAssertEqual(cancelButton.frame.minX, floor(150 + storyWidth / 2 - 21 / 2 + 5))
        // In the middle of the view, as the title is hidden
        XCTAssertEqual(cancelButton.frame.minY, 7)
    }

    func testStoppingTheStory() {
        useCompiler(IFUtility.coreBuildVersion ?? "")
        view.startStory()
        view.stopStory()

        XCTAssertEqual(storyText.stringValue, "Story stopped.")
        XCTAssertFalse(storyText.isHidden)
        XCTAssertTrue(cancelButton.isHidden)
        XCTAssertFalse(welcomeIsShown)
    }

    func testStoppingTheStoryWithAnOldCompilerSaysWhichOne() {
        useCompiler("6L38")
        view.startStory()
        view.stopStory()

        XCTAssertEqual(storyText.stringValue, "Using historic version 6L38. Story stopped.")
    }

    func testClickingCancelHidesItAndAsksTheManagerToCancel() {
        useCompiler("6L38")
        view.startStory()

        cancelButton.performClick(nil)

        XCTAssertTrue(cancelButton.isHidden)
        XCTAssertEqual(manager.cancelCount, 1)
    }

    func testAStoryThatCantBeCancelledHasNoCancelButton() {
        useCompiler("6L38")
        view.startStory()
        view.canCancel(false)
        // As the manager does whenever the progress changes
        view.stopProgress()

        XCTAssertTrue(cancelButton.isHidden)
        XCTAssertFalse(storyText.isHidden)
    }

    // MARK: - Progress

    func testStartingProgressShowsTheBar() {
        view.startProgress()

        XCTAssertFalse(progressBar.isHidden)
        XCTAssertTrue(storyText.isHidden)
        XCTAssertTrue(cancelButton.isHidden)
        XCTAssertFalse(welcomeIsShown)
        XCTAssertTrue(progressBar.usesThreadedAnimation)
    }

    func testTheProgressBarFillsTheViewWithoutACancelButton() {
        view.startProgress()

        // Twenty points either side, ten high, in the middle of the view as the title is hidden
        XCTAssertEqual(progressBar.frame, NSRect(x: 20, y: 10, width: 260, height: 10))
    }

    func testProgressThatCanBeCancelledHasTheCancelButtonOnTheRight() {
        view.canCancel(true)
        view.startProgress()

        XCTAssertFalse(cancelButton.isHidden)
        XCTAssertEqual(cancelButton.frame, NSRect(x: 274, y: 7, width: 16, height: 16))
        XCTAssertEqual(progressBar.frame, NSRect(x: 20, y: 10, width: 244, height: 10))
    }

    func testTheProgressBarsValue() {
        view.startProgress()
        view.setProgressMaxValue(100)
        view.updateProgress(40)
        view.setProgressIndeterminate(false)

        XCTAssertEqual(progressBar.maxValue, 100)
        XCTAssertEqual(progressBar.doubleValue, 40)
        XCTAssertFalse(progressBar.isIndeterminate)

        view.setProgressIndeterminate(true)
        XCTAssertTrue(progressBar.isIndeterminate)
    }

    func testStoppingProgressHidesTheBarAndEmptiesIt() {
        view.startProgress()
        view.setProgressMaxValue(100)
        view.updateProgress(40)
        view.setProgressIndeterminate(false)

        view.stopProgress()

        XCTAssertTrue(progressBar.isHidden)
        XCTAssertEqual(progressBar.doubleValue, 0)
        XCTAssertTrue(progressBar.isIndeterminate)
        XCTAssertFalse(progressBar.usesThreadedAnimation)
        XCTAssertTrue(welcomeIsShown)
    }

    func testStoppingProgressDuringAStoryShowsTheStoryAgain() {
        useCompiler("6L38")
        view.startStory()
        view.startProgress()
        XCTAssertTrue(storyText.isHidden)

        view.stopProgress()

        XCTAssertFalse(storyText.isHidden)
        XCTAssertFalse(cancelButton.isHidden)
        XCTAssertTrue(progressBar.isHidden)
        XCTAssertFalse(welcomeIsShown)
    }

    // MARK: - Drawing

    func testTheBackgroundHasRoundedCorners() {
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            let rep = picture(appearance: appearance)
            // The corners are outside, the middle and the edges' middles inside
            XCTAssertEqual(rep.colorAt(x: 0, y: 1)?.alphaComponent, 0)
            XCTAssertEqual(rep.colorAt(x: rep.pixelsWide - 1, y: rep.pixelsHigh - 1)?.alphaComponent, 0)
            XCTAssertEqual(rep.colorAt(x: rep.pixelsWide / 2, y: rep.pixelsHigh / 2)?.alphaComponent, 1)
            XCTAssertEqual(rep.colorAt(x: rep.pixelsWide / 2, y: rep.pixelsHigh / 4)?.alphaComponent, 1)
        }
    }
}
