//
//  IFCompilerControllerTests.swift
//  InformTests
//

import WebKit
import XCTest

/// A project controller with no document or window
private final class ProjectControllerStandIn: IFProjectController {
    override var document: AnyObject? {
        get {
            return nil
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
}

/// Keeps what the compiler controller tells its delegate
private final class Delegate: NSObject, IFCompilerControllerDelegate {
    private(set) var told: [String] = []

    func forget() {
        told = []
    }

    func errorMessageHighlighted(_ sender: IFCompilerController, atLine line: Int32, inFile file: String) {
        told.append("highlighted \(line) in \(file)")
    }

    func viewSetHasUpdated(_ sender: IFCompilerController) {
        told.append("views updated")
    }

    func compiler(_ sender: IFCompilerController, switchedToView viewIndex: Int32) {
        told.append("switched to \(viewIndex)")
    }
}

/// The compiler controller, which shows what the compiler and intest write in the Results page's console, the
/// errors Inform 6 gives, and tabs for the files of results
final class IFCompilerControllerTests: XCTestCase {

    /// The project controller and the page whose nib makes the compiler controller, kept until the test ends
    private var projectController: ProjectControllerStandIn?
    private var page: IFErrorsPage?
    private var controller: IFCompilerController!
    private let delegate = Delegate()
    /// A folder for files of results
    private var folder: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // A project controller that doesn't watch for settings changing, and so doesn't make the project window's
        // toolbar for them, which saves its configuration in the user's preferences.
        let projectController = ProjectControllerStandIn()
        NotificationCenter.default.removeObserver(projectController)
        self.projectController = projectController

        let page = IFErrorsPage(projectController: projectController, with: IFProjectPane())
        self.page = page
        controller = page.compilerController
        controller.delegate = delegate

        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        controller = nil
        page = nil
        projectController = nil
        try FileManager.default.removeItem(at: folder)
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func views<T: NSView>(_ type: T.Type, in view: NSView) -> [T] {
        var found: [T] = []
        if let view = view as? T {
            found.append(view)
        }
        for subview in view.subviews {
            found += views(type, in: subview)
        }
        return found
    }

    /// The console's text view
    private var console: NSTextView {
        get throws {
            return try XCTUnwrap(views(NSTextView.self, in: controller.splitView).first)
        }
    }

    private var consoleText: String {
        get throws {
            return try console.string
        }
    }

    /// The list of errors
    private var errorList: NSOutlineView {
        get throws {
            return try XCTUnwrap(views(NSOutlineView.self, in: controller.splitView).first)
        }
    }

    private func post(_ name: Notification.Name, _ userInfo: [String: Any]? = nil) {
        NotificationCenter.default.post(name: name, object: controller.compiler, userInfo: userInfo)
    }

    private func stdout(_ string: String, style: String = IFStyleBase) {
        post(.IFCompilerStdout, ["string": string, "style": style])
    }

    private func stderr(_ string: String) {
        post(.IFCompilerStderr, ["string": string])
    }

    /// Starts a build, as the project controller does
    private func startBuild() {
        post(.IFCompilerClearConsole)
        post(.IFCompilerStarting)
    }

    private func style(_ name: String) throws -> [NSAttributedString.Key: Any] {
        let styles = IFCompilerController.defaultStyles()
        return try XCTUnwrap(styles[NSAttributedString.Key(name)] as? [NSAttributedString.Key: Any])
    }

    /// Checks that the console's text has the font and colour of a style, where the style gives them, from the
    /// start of the first match of some text to its end
    private func assertStyle(_ name: String, of text: String,
                             file: StaticString = #filePath, line: UInt = #line) throws {
        let storage = try XCTUnwrap(console.textStorage)
        let range = (storage.string as NSString).range(of: text)
        XCTAssertNotEqual(range.location, NSNotFound, "\(text) isn't in the console", file: file, line: line)
        let expected = try style(name)
        for index in [range.location, NSMaxRange(range) - 1] {
            let attributes = storage.attributes(at: index, effectiveRange: nil)
            if let font = expected[.font] as? NSFont {
                XCTAssertEqual(attributes[.font] as? NSFont, font, "font of \(text)", file: file, line: line)
            }
            if let colour = expected[.foregroundColor] as? NSColor {
                XCTAssertEqual(attributes[.foregroundColor] as? NSColor, colour, "colour of \(text)",
                               file: file, line: line)
            }
        }
    }

    /// An error as Inform 6 gives it
    private func inform6(_ message: String, file: String = "/Story.inform/Build/auto.inf", line: Int = 10) -> String {
        return "File \"\(file)\"; Line \(line)\t# \(message)\n"
    }

    /// What the list of errors shows: each file's name and its errors
    private func errorListContents() throws -> [String] {
        let list = try errorList
        let source = try XCTUnwrap(list.dataSource)
        var contents: [String] = []
        let files = source.outlineView?(list, numberOfChildrenOfItem: nil) ?? 0
        for fileIndex in 0..<files {
            let file = try XCTUnwrap(source.outlineView?(list, child: fileIndex, ofItem: nil))
            XCTAssertEqual(source.outlineView?(list, isItemExpandable: file), true)
            let name = source.outlineView?(list, objectValueFor: nil, byItem: file) as? NSAttributedString
            contents.append(name?.string ?? "?")
            let errors = source.outlineView?(list, numberOfChildrenOfItem: file) ?? 0
            for errorIndex in 0..<errors {
                let error = try XCTUnwrap(source.outlineView?(list, child: errorIndex, ofItem: file))
                XCTAssertEqual(source.outlineView?(list, isItemExpandable: error), false)
                let text = source.outlineView?(list, objectValueFor: nil, byItem: error) as? NSAttributedString
                contents.append("  " + (text?.string ?? "?"))
            }
        }
        return contents
    }

    /// Writes a file of results in the folder
    @discardableResult
    private func write(_ name: String, _ contents: String = "Output", encoding: String.Encoding = .utf8) throws -> URL {
        let file = folder.appendingPathComponent(name)
        try XCTUnwrap(contents.data(using: encoding)).write(to: file)
        return file
    }

    private var tabIds: [IFCompilerTabId] {
        return controller.viewTabs.map { $0.tabId }
    }

    // MARK: - The console

    func testTheStyles() throws {
        let styles = IFCompilerController.defaultStyles()
        XCTAssertEqual(Set(styles.keys.map { $0.rawValue }),
                       [IFStyleBase, IFStyleLaunch, IFStyleCompilerVersion, IFStyleCompilerMessage,
                        IFStyleCompilerWarning, IFStyleCompilerError, IFStyleCompilerFatalError, IFStyleFilename,
                        IFStyleProgress])
        let monaco = NSFont(name: "Monaco", size: 11)
        XCTAssertEqual(try style(IFStyleBase)[.font] as? NSFont, monaco)
        XCTAssertEqual(try style(IFStyleBase)[.foregroundColor] as? NSColor, .textColor)
        XCTAssertEqual(try style(IFStyleCompilerMessage)[.foregroundColor] as? NSColor, .systemGreen)
        XCTAssertNil(try style(IFStyleCompilerMessage)[.font])
        XCTAssertEqual(try style(IFStyleCompilerWarning)[.foregroundColor] as? NSColor, .systemBlue)
        XCTAssertEqual(try style(IFStyleCompilerFatalError)[.foregroundColor] as? NSColor, .systemRed)
        XCTAssertEqual(try style(IFStyleProgress)[.foregroundColor] as? NSColor, .systemIndigo)
        // Errors are in bold, and fatal errors in bold italic, as far as Monaco has them (it has neither)
        let bold = NSFontManager.shared.convert(try XCTUnwrap(monaco), toHaveTrait: .boldFontMask)
        XCTAssertEqual(try style(IFStyleCompilerError)[.font] as? NSFont, bold)
        XCTAssertEqual(try style(IFStyleCompilerFatalError)[.font] as? NSFont,
                       NSFontManager.shared.convert(bold, toHaveTrait: .italicFontMask))
    }

    func testTheConsoleShowsWhatTheCompilerWrites() throws {
        startBuild()
        stdout("Launching ni\n", style: IFStyleLaunch)
        stderr("Something on stderr\n")
        stdout("Partial ")
        stdout("line\n")

        XCTAssertEqual(try consoleText, "Launching ni\nSomething on stderr\nPartial line\n")
        try assertStyle(IFStyleLaunch, of: "Launching ni")
        try assertStyle(IFStyleBase, of: "Something on stderr")
    }

    func testEachLineIsStyledForWhatItSays() throws {
        startBuild()
        stderr("Inform 7 v10.2.0 has started.\n")
        stderr("++ 45% (Binding rulebooks)\n")
        stdout(inform6("Warning:  Local variable unused"))
        stdout(inform6("Error:  No such constant"))
        stdout("> Message\n")

        try assertStyle(IFStyleCompilerVersion, of: "Inform 7 v10.2.0")
        try assertStyle(IFStyleProgress, of: "++ 45% (Binding rulebooks)")
        try assertStyle(IFStyleCompilerWarning, of: "Local variable unused")
        try assertStyle(IFStyleCompilerError, of: "No such constant")
        try assertStyle(IFStyleCompilerMessage, of: "> Message")
    }

    func testALineIsStyledOnceItsEndArrives() throws {
        startBuild()
        stdout("File \"auto.inf\"; Line 3\t# Err")
        XCTAssertEqual(try errorListContents(), [])

        stdout("or:  No such constant\n")
        try assertStyle(IFStyleCompilerError, of: "File \"auto.inf\"")
        XCTAssertEqual(try errorListContents(), ["auto.inf", "  L3: No such constant"])
    }

    func testWhatTheOutputTellsTheCompiler() throws {
        startBuild()
        stderr("++ 45% (Binding rulebooks)\n")
        XCTAssertEqual(controller.compiler.progress.percentage, 45)
        XCTAssertEqual(controller.compiler.progress.message, "Binding rulebooks")

        // A progress line without a stage leaves the stage as it was
        stderr("++ 50%\n")
        XCTAssertEqual(controller.compiler.progress.percentage, 50)
        XCTAssertEqual(controller.compiler.progress.message, "Binding rulebooks")

        stderr("++ Ended: Translation succeeded: 1 room\n")
        XCTAssertEqual(controller.compiler.endTextString, "Translation succeeded: 1 room")
    }

    func testWhereCblorbAsksForTheBlorbFileToGo() {
        XCTAssertNil(controller.blorbLocation)
        startBuild()
        stdout("Copy blorb to: [[/Release/Story.gblorb]]\n")
        XCTAssertEqual(controller.blorbLocation, "/Release/Story.gblorb")

        // The next build forgets it
        post(.IFCompilerStarting)
        XCTAssertNil(controller.blorbLocation)
    }

    func testFinishing() throws {
        startBuild()
        stdout("Output\n")
        post(.IFCompilerFinished, ["exitCode": NSNumber(value: 0)])
        XCTAssertEqual(try consoleText, "Output\n\nCompiler finished with code 0\n")

        startBuild()
        post(.IFCompilerFinished, ["exitCode": NSNumber(value: 1)])
        XCTAssertEqual(try consoleText, "\nCompiler finished with code 1\n")
    }

    func testClearingTheConsole() throws {
        startBuild()
        stdout(inform6("Error:  No such constant"))
        try controller.makeTab(forFile: write("Debug log.txt").path)
        XCTAssertEqual(tabIds, [.tabConsole, .tabDebugging])
        delegate.forget()

        post(.IFCompilerClearConsole)
        XCTAssertEqual(try consoleText, "")
        XCTAssertEqual(try errorListContents(), [])
        XCTAssertEqual(tabIds, [.tabConsole])
        XCTAssertEqual(delegate.told, ["views updated"])

        // Lines are styled from the start again
        stdout(inform6("Error:  Another"))
        try assertStyle(IFStyleCompilerError, of: "Another")
    }

    func testAnotherCompilersOutputIsntShown() throws {
        startBuild()
        let other = IFCompiler()
        NotificationCenter.default.post(name: .IFCompilerStdout, object: other,
                                        userInfo: ["string": "Elsewhere\n", "style": IFStyleBase])
        XCTAssertEqual(try consoleText, "")
    }

    func testGivingTheControllerACompiler() throws {
        let old = controller.compiler
        let new = IFCompiler()
        controller.compiler = new
        XCTAssertTrue(controller.compiler === new)

        startBuild()
        NotificationCenter.default.post(name: .IFCompilerStdout, object: old,
                                        userInfo: ["string": "Old\n", "style": IFStyleBase])
        stdout("New\n")
        XCTAssertEqual(try consoleText, "New\n")
    }

    // MARK: - intest

    func testTheConsoleShowsWhatIntestWrites() throws {
        startBuild()
        NotificationCenter.default.post(name: .IFInTestStarting, object: nil,
                                        userInfo: ["command": "/usr/bin/intest", "args": ["-from", "Project"]])
        NotificationCenter.default.post(name: .IFInTestStdout, object: nil, userInfo: ["string": "Passed\n"])
        NotificationCenter.default.post(name: .IFInTestStderr, object: nil, userInfo: ["string": "Failed\n"])
        NotificationCenter.default.post(name: .IFInTestFinished, object: nil,
                                        userInfo: ["exitCode": NSNumber(value: 1)])

        XCTAssertEqual(try consoleText,
                       "Launching: /usr/bin/intest -from Project \nPassed\nFailed\nIntest finished with code 1\n")
        try assertStyle(IFStyleBase, of: "Launching: /usr/bin/intest")
        try assertStyle(IFStyleBase, of: "Passed")
        try assertStyle(IFStyleCompilerError, of: "Failed")
    }

    // MARK: - The list of errors

    func testTheListOfErrors() throws {
        startBuild()
        stdout(inform6("Error:  No such constant", line: 10))
        stdout(inform6("Warning:  Unused", file: "/Story.inform/Source/Other.inf", line: 3))
        stdout(inform6("Fatal error: Too many errors", line: 20))

        XCTAssertEqual(try errorListContents(),
                       ["auto.inf", "  L10: No such constant", "  L20: Too many errors", "Other.inf", "  L3: Unused"])

        // Each file is in the filename style, and each error in the style for its kind
        let list = try errorList
        let source = try XCTUnwrap(list.dataSource)
        let auto = try XCTUnwrap(source.outlineView?(list, child: 0, ofItem: nil))
        let name = try XCTUnwrap(source.outlineView?(list, objectValueFor: nil, byItem: auto) as? NSAttributedString)
        XCTAssertEqual(name.attribute(.font, at: 0, effectiveRange: nil) as? NSFont,
                       try style(IFStyleFilename)[.font] as? NSFont)
        let fatal = try XCTUnwrap(source.outlineView?(list, child: 1, ofItem: auto))
        let text = try XCTUnwrap(source.outlineView?(list, objectValueFor: nil, byItem: fatal) as? NSAttributedString)
        XCTAssertEqual(text.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor, .systemRed)
        let other = try XCTUnwrap(source.outlineView?(list, child: 1, ofItem: nil))
        let warning = try XCTUnwrap(source.outlineView?(list, child: 0, ofItem: other))
        let warningText = try XCTUnwrap(source.outlineView?(list, objectValueFor: nil, byItem: warning)
                                        as? NSAttributedString)
        XCTAssertEqual(warningText.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor, .systemBlue)
    }

    func testOtherItemsHaveNoErrors() throws {
        startBuild()
        stdout(inform6("Error:  No such constant"))
        let list = try errorList
        let source = try XCTUnwrap(list.dataSource)
        XCTAssertEqual(source.outlineView?(list, numberOfChildrenOfItem: "Not a file"), 0)
        XCTAssertEqual(source.outlineView?(list, isItemExpandable: "Not a file"), false)
    }

    func testTheListOfErrorsIsKeptOutOfSight() throws {
        startBuild()
        stdout(inform6("Error:  No such constant"))
        let scroller = try XCTUnwrap(try errorList.enclosingScrollView)
        XCTAssertEqual(scroller.frame.height, 0)
    }

    func testChoosingAnErrorTellsTheDelegate() throws {
        startBuild()
        stdout(inform6("Error:  No such constant", line: 10))
        stdout(inform6("Warning:  Unused", file: "/Story.inform/Source/Other.inf", line: 3))
        let list = try errorList
        delegate.forget()

        // Choosing a file tells it nothing
        list.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        XCTAssertEqual(delegate.told, [])

        list.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
        XCTAssertEqual(delegate.told, ["highlighted 10 in /Story.inform/Build/auto.inf"])

        list.selectRowIndexes(IndexSet(integer: 3), byExtendingSelection: false)
        XCTAssertEqual(delegate.told.last, "highlighted 3 in /Story.inform/Source/Other.inf")
    }

    // MARK: - The problems page

    func testTheProblemsPageThatTheCompilerGives() throws {
        controller.setProject(try XCTUnwrap(projectController), with: IFProjectPane())
        try write("Problems.html", "<html><body>Problems</body></html>")
        try write("Notes.txt")

        // Without one, the build folder's problems page is shown, as the report
        startBuild()
        post(.IFCompilerFinished, ["exitCode": NSNumber(value: 0)])
        controller.showContentsOfFiles(in: try FileWrapper(url: folder), fromPath: folder.path)
        XCTAssertEqual(Set(controller.viewTabs.map { $0.name }), ["Console", "Report", "Notes"])
        XCTAssertEqual(controller.selectedTabId, .tabReport)

        // A known error has a page of its own, shown instead, and which leaves out any file of its name
        try write("ErrorI6TooBig.txt")
        startBuild()
        stdout(inform6("Fatal error: The story file exceeds version-8 limit (512K) by 10 bytes"))
        post(.IFCompilerFinished, ["exitCode": NSNumber(value: 1)])
        controller.showContentsOfFiles(in: try FileWrapper(url: folder), fromPath: folder.path)
        XCTAssertEqual(controller.viewTabs.map { $0.name }, ["Console", "Report", "Notes"])
        let report = try XCTUnwrap(controller.viewTabs.first { $0.tabId == .tabReport })
        XCTAssertTrue(report.view is WKWebView)

        // The next build forgets it
        startBuild()
        post(.IFCompilerFinished, ["exitCode": NSNumber(value: 0)])
        controller.showContentsOfFiles(in: try FileWrapper(url: folder), fromPath: folder.path)
        XCTAssertEqual(Set(controller.viewTabs.map { $0.name }), ["Console", "Report", "Notes", "ErrorI6TooBig"])
    }

    func testFilesThatArentAFolderShowNothing() throws {
        let file = try write("Notes.txt")
        controller.showContentsOfFiles(in: try FileWrapper(url: file), fromPath: file.path)
        XCTAssertEqual(tabIds, [.tabConsole])
    }

    // MARK: - Tabs

    func testATabForATextFile() throws {
        delegate.forget()
        let tabId = controller.makeTab(forFile: try write("auto.inf", "Constant Story \"Café\";\n").path)
        XCTAssertEqual(tabId, .tabInform6)
        XCTAssertEqual(tabIds, [.tabConsole, .tabInform6])
        XCTAssertEqual(delegate.told, ["views updated"])

        let tab = controller.viewTabs[1]
        XCTAssertEqual(tab.name, "Inform 6")
        let scrollView = try XCTUnwrap(tab.view as? NSScrollView)
        let textView = try XCTUnwrap(scrollView.documentView as? NSTextView)
        XCTAssertEqual(textView.string, "Constant Story \"Café\";\n")
        XCTAssertFalse(textView.isEditable)
    }

    func testATextFileThatIsntUTF8IsReadAsLatin1() throws {
        controller.makeTab(forFile: try write("Notes.txt", "Café\n", encoding: .isoLatin1).path)
        let scrollView = try XCTUnwrap(controller.viewTabs[1].view as? NSScrollView)
        XCTAssertEqual((scrollView.documentView as? NSTextView)?.string, "Café\n")
        XCTAssertEqual(controller.viewTabs[1].name, "Notes")
        XCTAssertEqual(controller.viewTabs[1].tabId, .tabInvalid)
    }

    func testSwitchingTabs() throws {
        try controller.makeTab(forFile: write("auto.inf").path)
        try controller.makeTab(forFile: write("Debug log.txt").path)
        delegate.forget()

        controller.switchToView(with: .tabDebugging)
        XCTAssertEqual(controller.selectedTabId, .tabDebugging)
        XCTAssertNil(controller.currentWebView)
        XCTAssertEqual(delegate.told, ["switched to 2"])
        XCTAssertTrue(controller.viewTabs[2].view.superview != nil)
        XCTAssertNil(controller.splitView.superview)

        // A tab that isn't there changes nothing
        controller.switchToView(with: .tabRuntime)
        XCTAssertEqual(controller.selectedTabId, .tabDebugging)
        XCTAssertEqual(delegate.told, ["switched to 2"])

        controller.switchToSplitView()
        XCTAssertEqual(controller.selectedTabId, .tabConsole)
        XCTAssertNotNil(controller.splitView.superview)
        XCTAssertEqual(controller.tabId(withTabIndex: 1), Int32(IFCompilerTabId.tabInform6.rawValue))
    }

    func testClearingTheTabs() throws {
        try controller.makeTab(forFile: write("auto.inf").path)
        try controller.makeTab(forFile: write("Debug log.txt").path)
        controller.switchToView(with: .tabDebugging)
        delegate.forget()

        controller.clearTabViewsExcept(.tabInform6)
        XCTAssertEqual(tabIds, [.tabInform6])
        // It switches to the console, which isn't there now
        XCTAssertEqual(delegate.told, ["views updated"])
        XCTAssertEqual(controller.selectedTabId, .tabDebugging)

        // Nothing to clear
        delegate.forget()
        controller.clearTabViewsExcept(.tabInform6)
        XCTAssertEqual(delegate.told, [])
    }

    func testARunTimeProblem() throws {
        controller.setProject(try XCTUnwrap(projectController), with: IFProjectPane())
        delegate.forget()
        let first = try write("RTP_1.html", "<html><body>One</body></html>")
        controller.showRuntimeError(first)
        XCTAssertEqual(tabIds, [.tabConsole, .tabRuntime])
        XCTAssertEqual(controller.viewTabs[1].name, "Run-Time Problem")
        XCTAssertEqual(controller.selectedTabId, .tabRuntime)
        let firstView = try XCTUnwrap(controller.viewTabs[1].view as? WKWebView)
        XCTAssertTrue(controller.currentWebView === firstView)
        XCTAssertEqual(delegate.told, ["views updated", "switched to 1"])

        // Another replaces it in the same tab
        delegate.forget()
        controller.showRuntimeError(try write("RTP_2.html", "<html><body>Two</body></html>"))
        XCTAssertEqual(tabIds, [.tabConsole, .tabRuntime])
        XCTAssertFalse(controller.viewTabs[1].view === firstView)
        XCTAssertEqual(delegate.told, ["switched to 1"])
    }
}
