//
//  IFRuntimeErrorParserTests.swift
//  InformTests
//

import XCTest

@MainActor
final class IFRuntimeErrorParserTests: XCTestCase {

    /// The folder holding the explanations of the Standard Rules' run-time problems.
    private let folder = "Internal/Extensions/Graham Nelson/Standard Rules.i7xd/Materials/Inter/WorldModelKit/RTPs"

    /// Records the run-time problems reported by a parser.
    private final class Recorder: NSObject, IFRuntimeErrorParserDelegate {
        var problems: [String] = []

        func runtimeError(_ error: String, inDirectory directory: String?) {
            if let directory {
                problems.append("\(error) in \(directory)")
            } else {
                problems.append(error)
            }
        }
    }

    /// Gives a parser the story's output in the pieces listed, as Zoom does (Z-code) and as Glk
    /// does (Glulx), and checks the problems it reports in each case.
    private func assertProblems(_ pieces: [String], _ expected: [String],
                                file: StaticString = #filePath, line: UInt = #line) {
        let zoom = Recorder()
        let zoomParser = IFRuntimeErrorParser()
        zoomParser.delegate = zoom
        for piece in pieces {
            zoomParser.outputText(piece)
        }
        XCTAssertEqual(zoom.problems, expected, "Zoom", file: file, line: line)

        let glk = Recorder()
        let glkParser = IFRuntimeErrorParser()
        glkParser.delegate = glk
        for piece in pieces {
            glkParser.receivedCharacters(piece, window: 0, from: nil)
        }
        XCTAssertEqual(glk.problems, expected, "Glk", file: file, line: line)
    }

    func testFindsAProblemOnALineOfItsOwn() {
        assertProblems(["*** Run-time problem SceneHasNotEnded: \(folder)\n"],
                       ["SceneHasNotEnded in \(folder)"])
    }

    /// The story starts a new line for the problem, and follows it with an explanation.
    func testFindsAProblemAmongOtherOutput() {
        assertProblems(["You wait.\n\n*** Run-time problem SceneHasNotEnded: \(folder)\n*** The scene has not ended.\n\n>"],
                       ["SceneHasNotEnded in \(folder)"])
    }

    /// The story prints the problem in several parts, which can reach the parser separately.
    func testFindsAProblemSplitIntoPieces() {
        assertProblems(["You wait.\n", "\n*** Run-time problem ", "SceneHasNotEnded", ": ", folder, "\n",
                        "*** The scene has not ended.\n", "\n>"],
                       ["SceneHasNotEnded in \(folder)"])
    }

    /// A story compiled without debugging doesn't print the folder.
    func testFindsAProblemWithoutAFolder() {
        assertProblems(["\n*** Run-time problem SceneHasNotEnded\n"], ["SceneHasNotEnded"])
    }

    /// Older versions of Inform numbered their problems, which are explained by pages in the app.
    func testFindsANumberedProblem() {
        assertProblems(["\n*** Run-time problem P10: Since the scene has not ended...\n"], ["P10"])
    }

    func testFindsEachProblem() {
        assertProblems(["*** Run-time problem P10: One.\nThen\n", "*** Run-time problem P11: Two.\n"], ["P10", "P11"])
    }

    func testIgnoresOtherText() {
        assertProblems(["You say \"*** Run-time problem P10: oops\".\n",
                        "*** Run-time problems are rare.\n",
                        "Run-time problem P10: no stars\n"], [])
    }

    /// A line is only checked once it has ended.
    func testWaitsForTheEndOfTheLine() {
        let recorder = Recorder()
        let parser = IFRuntimeErrorParser()
        parser.delegate = recorder

        parser.outputText("*** Run-time problem P10")
        XCTAssertEqual(recorder.problems, [])

        parser.outputText(": oops\n")
        XCTAssertEqual(recorder.problems, ["P10"])
    }

    /// Text from any of Glk's windows counts.
    func testReadsTheTextOfEveryGlkWindow() {
        let recorder = Recorder()
        let parser = IFRuntimeErrorParser()
        parser.delegate = recorder

        parser.receivedCharacters("*** Run-time problem ", window: 3, from: nil)
        parser.receivedCharacters("P10\n", window: 1, from: nil)

        XCTAssertEqual(recorder.problems, ["P10"])
    }

    /// What the player types, and Glk's other automation calls, aren't the story's output.
    func testIgnoresGlksOtherAutomationCalls() {
        let recorder = Recorder()
        let parser = IFRuntimeErrorParser()
        parser.delegate = recorder

        parser.receivedCharacters("You wait.\n", window: 0, from: nil)
        parser.userTyped("*** Run-time problem P10", window: 0, lineInput: true, from: nil)
        parser.userClicked(atXPos: 10, ypos: 20, window: 0, from: nil)
        parser.viewWaiting(nil)
        parser.viewIsWaiting(forInput: nil)
        parser.receivedCharacters("\n", window: 0, from: nil)

        XCTAssertEqual(recorder.problems, [])
    }

    func testWorksWithADelegateThatImplementsNothing() {
        final class SilentDelegate: NSObject, IFRuntimeErrorParserDelegate {
        }
        let delegate = SilentDelegate()
        let parser = IFRuntimeErrorParser()
        parser.delegate = delegate

        parser.outputText("*** Run-time problem P10\n")

        XCTAssertTrue(parser.delegate === delegate)
    }

    func testHoldsItsDelegateWeakly() {
        let parser = IFRuntimeErrorParser()
        weak var weakRecorder: Recorder?

        autoreleasepool {
            let recorder = Recorder()
            weakRecorder = recorder
            parser.delegate = recorder
        }

        XCTAssertNil(weakRecorder)
        XCTAssertNil(parser.delegate)
        // With no delegate, a problem is told to nobody
        parser.outputText("*** Run-time problem P10\n")
    }
}
