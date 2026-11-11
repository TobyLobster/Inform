//
//  IFSyntaxStylesTests.swift
//  InformTests
//

import XCTest

@MainActor
final class IFSyntaxStylesTests: XCTestCase {

    private let none = IFSyntaxStyle(rawValue: 0)

    func testNewStylesHaveNone() {
        let styles = IFSyntaxStyles()
        XCTAssertNil(styles.styles)
        XCTAssertEqual(styles.numCharStyles, 0)

        // The index just past the end counts as a terminator
        XCTAssertEqual(styles.read(0), none)
    }

    func testReadingAndWritingTheStyles() {
        let buffer = UnsafeMutablePointer<IFSyntaxStyle>.allocate(capacity: 4)
        defer { buffer.deallocate() }
        buffer.initialize(repeating: .comment, count: 4)

        // Highlighters are given the styles from a line onwards
        let styles = IFSyntaxStyles()
        styles.styles = buffer + 1
        styles.numCharStyles = 3
        XCTAssertEqual(styles.read(0), .comment)
        XCTAssertEqual(styles.read(2), .comment)
        XCTAssertEqual(styles.read(3), none)

        styles.write(0, value: .gameText)
        styles.write(2, value: .substitution)
        XCTAssertEqual(styles.read(0), .gameText)
        XCTAssertEqual(styles.read(2), .substitution)
        XCTAssertEqual(Array(UnsafeBufferPointer(start: buffer, count: 4)),
                       [.comment, .gameText, .comment, .substitution])
    }
}
