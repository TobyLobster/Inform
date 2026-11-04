//
//  IFHighlighterTests.swift
//  InformTests
//

import XCTest

final class IFHighlighterTests: XCTestCase {

    /// Highlights the text as the editor does, and returns the style of each character (UTF-16 unit).
    private func styles(_ text: String, _ type: IFHighlightType) throws -> [IFSyntaxStyle] {
        let storage = NSTextStorage(string: text)
        IFSyntaxManager.register(storage, name: "IFHighlighterTests", type: type,
                                 intelligence: nil, undoManager: nil)
        defer { IFSyntaxManager.unregisterTextStorage(storage) }
        let data: IFSyntaxData = try XCTUnwrap(IFSyntaxManager.data(for: storage))
        return (0..<storage.length).map { data.style(at: UInt($0)) }
    }

    private let names: [UInt8: String] = [
        0x00: "none", 0x01: "string", 0x02: "comment", 0x03: "monospace", 0x04: "directive",
        0x05: "property", 0x06: "function", 0x07: "code", 0x08: "code alpha", 0x09: "assembly",
        0x0a: "escape character", 0x80: "heading", 0x81: "plain", 0x82: "game text",
        0x83: "substitution", 0x84: "natural Inform", 0x85: "title",
    ]

    private func name(_ style: IFSyntaxStyle) -> String {
        return names[style.rawValue] ?? String(format: "0x%02x", style.rawValue)
    }

    /// Checks that each piece of text, found in order, is all in the given style.
    private func assertStyles(_ text: String, _ type: IFHighlightType, _ expected: [(String, IFSyntaxStyle)],
                              file: StaticString = #filePath, line: UInt = #line) throws {
        let styles = try self.styles(text, type)
        let string = text as NSString
        var searchFrom = 0
        for (piece, style) in expected {
            let range = string.range(of: piece, range: NSRange(location: searchFrom, length: string.length - searchFrom))
            guard range.location != NSNotFound else {
                XCTFail("\"\(piece)\" not found", file: file, line: line)
                continue
            }
            let found = Set(styles[range.location..<NSMaxRange(range)].map { name($0) })
            XCTAssertEqual(found, [name(style)], "\"\(piece)\"", file: file, line: line)
            searchFrom = NSMaxRange(range)
        }
    }

    // MARK: - Inform 7

    func testInform7TextAndComments() throws {
        try assertStyles("The Kitchen is a room. \"A [bold type]warm[roman type] kitchen.\" [A comment [nested] here.] Then more.\n",
                         .inform7, [
                            ("The Kitchen is a room. ", .naturalInform),
                            ("\"A ", .gameText),
                            ("[bold type]", .substitution),
                            ("warm", .gameText),
                            ("[roman type]", .substitution),
                            (" kitchen.\"", .gameText),
                            ("[A comment [nested] here.]", .comment),
                            (" Then more.", .naturalInform),
                         ])
    }

    func testInform7Headings() throws {
        try assertStyles("""
            "Highlighting" by Toby Nelson

            Volume 1 - The House

            Book 2 - Downstairs

            Part Three - The Kitchen

            Chapter 4: Cooking

            Section 5 - Knives

            Partly Cloudy is a room.

            """, .inform7, [
                ("Volume 1 - The House", .heading),
                ("Book 2 - Downstairs", .heading),
                ("Part Three - The Kitchen", .heading),
                ("Chapter 4: Cooking", .heading),
                ("Section 5 - Knives", .heading),
                ("Partly Cloudy is a room.", .naturalInform),
            ])
    }

    /// Inform 6 code included in Inform 7 source is highlighted as Inform 6.
    func testInform6Inclusions() throws {
        try assertStyles("""
            Include (- Global counter = 1; ! An Inform 6 comment
            -).

            To decide what number is the answer: (- 42 -).

            """, .inform7, [
                ("Include (", .naturalInform),
                ("Global", .directive),
                ("! An Inform 6 comment", .comment),
                (").", .naturalInform),
                ("To decide what number is the answer: (", .naturalInform),
                ("42", .codeAlpha),
                (").", .naturalInform),
            ])
    }

    /// The "-" that starts an inclusion of Inform 6 isn't a string.
    func testStartOfInform6Inclusions() throws {
        let text = "Include (- Global counter = 1; -).\n"
        let styles = try self.styles(text, .inform7)
        let dash = (text as NSString).range(of: "-").location
        XCTAssertNotEqual(name(styles[dash]), "string")
    }

    // MARK: - Inform 6

    func testInform6() throws {
        try assertStyles("""
            ! A comment
            Constant Story "Heading";
            [ Main x;
                x = 'a' + 1;
                print "b~c^", (name) x; ! Another comment
                @print_char x;
                if (x == 1) return true;
            ];
            Object -> lamp "brass lamp"
              with name 'lamp',
              has light;

            """, .inform6, [
                ("! A comment", .comment),
                ("Constant", .directive),
                ("\"Heading\"", .string),
                ("[ Main", .function),
                ("'a'", .string),
                ("print", .code),
                ("\"b", .string),
                ("~", .escapeCharacter),
                ("c", .string),
                ("^", .escapeCharacter),
                ("! Another comment", .comment),
                ("@print_char", .assembly),
                ("if", .code),
                ("return", .code),
                ("true", .code),
                ("]", .function),
                ("Object", .directive),
                ("\"brass lamp\"", .string),
                ("with", .directive),
                ("name", .property),
                ("'lamp'", .string),
                ("has", .directive),
                ("light", .property),
            ])
    }
}
