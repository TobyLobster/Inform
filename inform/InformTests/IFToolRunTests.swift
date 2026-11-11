//
//  IFToolRunTests.swift
//  InformTests
//

import XCTest

/// A run of one of Inform's tools, here the shell
final class IFToolRunTests: XCTestCase {
    /// Runs a shell script, with the arguments given as $1 onwards
    private func shell(_ script: String, _ arguments: String...) -> IFToolRun {
        return IFToolRun(command: "/bin/sh", arguments: ["-c", script, "sh"] + arguments)
    }

    private func text(_ data: Data) -> String {
        return String(decoding: data, as: UTF8.self)
    }

    func testKeepsWhatTheToolWritesToStdout() {
        let run = shell("printf 'Passed\\n'")

        XCTAssertEqual(text(run.standardOutput), "Passed\n")
        XCTAssertEqual(run.standardError, Data())
        XCTAssertEqual(run.exitCode, 0)
    }

    func testKeepsWhatTheToolWritesToStderr() {
        let run = shell("printf 'Failed\\n' >&2")

        XCTAssertEqual(run.standardOutput, Data())
        XCTAssertEqual(text(run.standardError), "Failed\n")
    }

    /// More than a pipe holds (64 KB)
    func testKeepsAllTheToolWritesToStdout() {
        let run = shell("head -c 100000 /dev/zero | tr '\\0' o")

        XCTAssertEqual(run.standardOutput, Data(repeating: UInt8(ascii: "o"), count: 100000))
    }

    /// More than a pipe holds, before the tool ends its stdout. If stderr weren't read until then, the tool would wait
    /// for room to write it, and the run for stdout to end; so the tool stops itself after ten seconds, for the test
    /// to fail rather than hang.
    func testKeepsAllTheToolWritesToStderrBeforeItsStdoutEnds() {
        let run = shell("""
            ( sleep 10; kill $$ ) >/dev/null 2>&1 & watchdog=$!
            head -c 100000 /dev/zero | tr '\\0' e >&2
            printf done
            kill $watchdog
            """)

        XCTAssertEqual(run.exitCode, 0)
        XCTAssertEqual(text(run.standardOutput), "done")
        XCTAssertEqual(run.standardError, Data(repeating: UInt8(ascii: "e"), count: 100000))
    }

    /// As when an external Inform Core folder (Advanced preferences) hasn't got it
    func testAToolThatIsntThereIsntRunAndStderrSaysWhy() {
        let run = IFToolRun(command: "/nonexistent/intest", arguments: [])

        XCTAssertEqual(run.exitCode, -1)
        XCTAssertEqual(run.standardOutput, Data())
        let error = text(run.standardError)
        XCTAssertTrue(error.hasPrefix("Couldn't run /nonexistent/intest: "), error)
        XCTAssertTrue(error.hasSuffix("\n"), error)
    }

    /// As when the app hasn't got the tool
    func testNoToolIsntRunAndStderrSaysWhy() {
        let run = IFToolRun(command: nil, arguments: [])

        XCTAssertEqual(run.exitCode, -1)
        XCTAssertEqual(run.standardOutput, Data())
        let error = text(run.standardError)
        XCTAssertTrue(error.hasPrefix("Couldn't run the tool: "), error)
    }

    func testKeepsTheToolsExitCode() {
        XCTAssertEqual(shell("exit 3").exitCode, 3)
    }

    func testGivesTheToolItsArguments() {
        let run = shell("printf '%s|' \"$@\"", "-from", "Two words")

        XCTAssertEqual(text(run.standardOutput), "-from|Two words|")
    }

    func testRunsTheToolInTheTemporaryFolder() {
        let run = shell("[ \"$(pwd -P)\" = \"$(cd \"$1\" && pwd -P)\" ] && printf same", NSTemporaryDirectory())

        XCTAssertEqual(text(run.standardOutput), "same")
    }
}
