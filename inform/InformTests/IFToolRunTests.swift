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
