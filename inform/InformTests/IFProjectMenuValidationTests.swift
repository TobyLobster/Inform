//
//  IFProjectMenuValidationTests.swift
//  InformTests
//

import XCTest

/// Which of a project window's menu commands are enabled
@MainActor
final class IFProjectMenuValidationTests: XCTestCase {
    /// What the commands depend on, set by each test, as the project controller would know it
    private final class MenuState: NSObject, IFProjectMenuState {
        var isRunningGame = false
        var isExtensionProject = false
        var numberOfToolbarTestCases: UInt = 0
        var toolbarTestCase: String?
        var isTestAllCasesSelected = false
        var isCurrentlyTesting = false
        var isCompilerRunning = false
        var isUsingNaturalInform = true
        var isTextViewFirstResponder = false
        var firstResponderSelectionLength: UInt = 0
        var firstResponderHasIntelligence = false
        var hasCurrentTabView = false
        var isSourcePaneCurrent = false

        /// The index tabs that can be shown
        var indexTabs: Set<Int32> = []
        /// The index tabs asked about, in order
        var indexTabsAskedFor: [Int32] = []

        func canSelectIndexTab(_ tab: Int32) -> Bool {
            indexTabsAskedFor.append(tab)
            return indexTabs.contains(tab)
        }
    }

    private var state = MenuState()

    /// The commands that compile the project and then do something with the story
    private let compileCommands = [#selector(IFProjectController.compile(_:)),
                                   #selector(IFProjectController.release(_:)),
                                   #selector(IFProjectController.releaseForTesting(_:)),
                                   #selector(IFProjectController.compileAndRun(_:)),
                                   #selector(IFProjectController.compileAndDebug(_:)),
                                   #selector(IFProjectController.replayUsingSkein(_:)),
                                   #selector(IFProjectController.compileAndRefresh(_:))]

    /// The commands that switch the current pane to one of its tabs, or to the other pane
    private let tabCommands = [#selector(IFProjectController.tabSource(_:)),
                               #selector(IFProjectController.tabErrors(_:)),
                               #selector(IFProjectController.tabIndex(_:)),
                               #selector(IFProjectController.tabSkein(_:)),
                               #selector(IFProjectController.tabGame(_:)),
                               #selector(IFProjectController.tabDocumentation(_:)),
                               #selector(IFProjectController.tabExtensions(_:)),
                               #selector(IFProjectController.tabSettings(_:)),
                               #selector(IFProjectController.switchPanes(_:))]

    /// The commands that change which headings' sections the source page shows
    private let headingsCommands = [#selector(IFProjectController.showNextSection(_:)),
                                    #selector(IFProjectController.showPreviousSection(_:)),
                                    #selector(IFProjectController.showCurrentSectionOnly(_:)),
                                    #selector(IFProjectController.showEntireSource(_:)),
                                    #selector(IFProjectController.showFewerHeadings(_:)),
                                    #selector(IFProjectController.showMoreHeadings(_:))]

    private func isEnabled(_ action: Selector?, tag: Int = 0) -> Bool {
        return IFProjectMenuValidation.isEnabledAction(action, tag: tag, in: state)
    }

    /// An extension project with three test cases, the one given chosen in the toolbar, or Test All when it's nil
    private func makeExtensionProject(choosing testCase: String?) {
        state.isExtensionProject = true
        state.numberOfToolbarTestCases = 3
        state.toolbarTestCase = testCase
        state.isTestAllCasesSelected = testCase == nil
    }

    // MARK: - Running

    func testStopIsEnabledOnlyWhileAStoryRuns() {
        let stop = #selector(IFProjectController.stopProcess(_:))
        XCTAssertFalse(isEnabled(stop))

        state.isRunningGame = true
        XCTAssertTrue(isEnabled(stop))
    }

    func testTestMeIsEnabledInAStoryProject() {
        XCTAssertTrue(isEnabled(#selector(IFProjectController.testMe(_:))))
    }

    func testTestMeIsEnabledWhileTheCompilerRuns() {
        state.isCompilerRunning = true
        XCTAssertTrue(isEnabled(#selector(IFProjectController.testMe(_:))))
    }

    func testTestMeIsDisabledWhileTestCasesAreRun() {
        state.isCurrentlyTesting = true
        XCTAssertFalse(isEnabled(#selector(IFProjectController.testMe(_:))))
    }

    func testTestMeInAnExtensionProjectNeedsTestCases() {
        let testMe = #selector(IFProjectController.testMe(_:))

        state.isExtensionProject = true
        XCTAssertFalse(isEnabled(testMe), "with no test cases")

        makeExtensionProject(choosing: "Test 1")
        XCTAssertTrue(isEnabled(testMe))

        // Test Me runs them all, as the toolbar's Test button does
        makeExtensionProject(choosing: nil)
        XCTAssertTrue(isEnabled(testMe), "with Test All chosen")
    }

    func testReplayingInAnExtensionProjectNeedsATestCaseChosen() {
        for replay in [#selector(IFProjectController.replayEntireSkein(_:)),
                       #selector(IFProjectController.replayUsingSkein(_:))] {
            state = MenuState()
            XCTAssertTrue(isEnabled(replay), "\(replay) in a story project")

            state.isExtensionProject = true
            XCTAssertFalse(isEnabled(replay), "\(replay) with no test cases")

            makeExtensionProject(choosing: "Test 1")
            XCTAssertTrue(isEnabled(replay), "\(replay)")

            makeExtensionProject(choosing: nil)
            XCTAssertFalse(isEnabled(replay), "\(replay) with Test All chosen")

            makeExtensionProject(choosing: "Test 1")
            state.isCurrentlyTesting = true
            XCTAssertFalse(isEnabled(replay), "\(replay) while test cases are run")
        }
    }

    func testReplayEntireSkeinIsEnabledWhileTheCompilerRuns() {
        state.isCompilerRunning = true
        XCTAssertTrue(isEnabled(#selector(IFProjectController.replayEntireSkein(_:))))
    }

    // MARK: - Compiling

    func testTheCompileCommandsAreDisabledWhileTheCompilerRuns() {
        for command in compileCommands {
            state.isCompilerRunning = false
            XCTAssertTrue(isEnabled(command), "\(command)")

            state.isCompilerRunning = true
            XCTAssertFalse(isEnabled(command), "\(command)")
        }
    }

    func testTheCompileCommandsInAnExtensionProjectNeedATestCaseChosen() {
        for command in compileCommands {
            state = MenuState()
            state.isExtensionProject = true
            XCTAssertFalse(isEnabled(command), "\(command) with no test cases")

            makeExtensionProject(choosing: nil)
            XCTAssertFalse(isEnabled(command), "\(command) with Test All chosen")

            makeExtensionProject(choosing: "Test 1")
            XCTAssertTrue(isEnabled(command), "\(command)")
        }
    }

    func testTheCompileCommandsOtherThanReplayingAreEnabledWhileTestCasesAreRun() {
        makeExtensionProject(choosing: "Test 1")
        state.isCurrentlyTesting = true

        for command in compileCommands {
            XCTAssertEqual(isEnabled(command), command != #selector(IFProjectController.replayUsingSkein(_:)),
                           "\(command)")
        }
    }

    // MARK: - Formatting the source

    func testShiftingNeedsATextView() {
        for shift in [#selector(IFProjectController.shiftLeft(_:)),
                      #selector(IFProjectController.shiftRight(_:))] {
            state.isTextViewFirstResponder = false
            XCTAssertFalse(isEnabled(shift), "\(shift)")

            state.isTextViewFirstResponder = true
            XCTAssertTrue(isEnabled(shift), "\(shift)")
        }
    }

    func testRenumberingSectionsNeedsATextViewWithIntelligence() {
        let renumber = #selector(IFProjectController.renumberSections(_:))

        state.firstResponderHasIntelligence = true
        XCTAssertFalse(isEnabled(renumber), "without a text view")

        state.isTextViewFirstResponder = true
        XCTAssertTrue(isEnabled(renumber))

        state.firstResponderHasIntelligence = false
        XCTAssertFalse(isEnabled(renumber), "without intelligence")
    }

    func testCommentingNeedsInform7ATextViewAndASelection() {
        for command in [#selector(IFProjectController.commentOutSelection(_:)),
                        #selector(IFProjectController.uncommentSelection(_:))] {
            state = MenuState()
            state.firstResponderSelectionLength = 5
            XCTAssertFalse(isEnabled(command), "\(command) without a text view")

            state.isTextViewFirstResponder = true
            XCTAssertTrue(isEnabled(command), "\(command)")

            state.firstResponderSelectionLength = 0
            XCTAssertFalse(isEnabled(command), "\(command) without a selection")

            state.firstResponderSelectionLength = 5
            state.isUsingNaturalInform = false
            XCTAssertFalse(isEnabled(command), "\(command) in Inform 6")
        }
    }

    // MARK: - Tabs

    func testTheTabCommandsNeedACurrentTabView() {
        for command in tabCommands {
            state.hasCurrentTabView = false
            XCTAssertFalse(isEnabled(command), "\(command)")

            state.hasCurrentTabView = true
            XCTAssertTrue(isEnabled(command), "\(command)")
        }
    }

    func testShowingAnIndexTabAsksTheIndexPageForTheItemsTag() {
        let showIndexTab = #selector(IFProjectController.showIndexTab(_:))
        state.indexTabs = [3]

        XCTAssertTrue(isEnabled(showIndexTab, tag: 3))
        XCTAssertFalse(isEnabled(showIndexTab, tag: 4))
        XCTAssertEqual(state.indexTabsAskedFor, [3, 4])
    }

    func testOnlyShowingAnIndexTabAsksTheIndexPage() {
        for command in compileCommands + tabCommands + headingsCommands {
            _ = isEnabled(command, tag: 3)
        }
        XCTAssertEqual(state.indexTabsAskedFor, [])
    }

    // MARK: - Headings

    func testTheHeadingsCommandsNeedATextViewInTheSourcePane() {
        for command in headingsCommands {
            state = MenuState()
            state.isSourcePaneCurrent = true
            XCTAssertFalse(isEnabled(command), "\(command) without a text view")

            state.isTextViewFirstResponder = true
            XCTAssertTrue(isEnabled(command), "\(command)")

            state.isSourcePaneCurrent = false
            XCTAssertFalse(isEnabled(command), "\(command) in another pane")
        }
    }

    // MARK: - Exporting

    func testExportingAnIFictionRecordNeedsInform7() {
        let export = #selector(IFProjectController.exportIFiction(_:))
        XCTAssertTrue(isEnabled(export))

        state.isUsingNaturalInform = false
        XCTAssertFalse(isEnabled(export))
    }

    func testExportingAnExtensionNeedsAnExtensionProject() {
        let export = #selector(IFProjectController.exportExtension(_:))
        XCTAssertFalse(isEnabled(export))

        state.isExtensionProject = true
        XCTAssertTrue(isEnabled(export))
    }

    // MARK: - Everything else

    func testOtherCommandsAreEnabled() {
        for command in [#selector(IFProjectController.openMaterials(_:)),
                        #selector(IFProjectController.gotoLeftPane(_:)),
                        #selector(IFProjectController.searchDocs(_:)),
                        #selector(IFProjectController.showHeadings(_:))] {
            XCTAssertTrue(isEnabled(command), "\(command)")
        }
        XCTAssertTrue(isEnabled(nil), "an item with no action")
    }
}
