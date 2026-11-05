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

    /// A keyword is coloured by going back over it once it's recognised, which mustn't stop at the start of the text.
    func testInform6KeywordAtTheStartOfTheText() throws {
        try assertStyles("Constant Story \"Heading\";\n", .inform6, [
            ("Constant", .directive),
            ("\"Heading\"", .string),
        ])
    }

    // MARK: - More Inform 7

    func testInform7CurlyQuotes() throws {
        try assertStyles("The sign says \u{201C}Keep out\u{201D} in red.\n", .inform7, [
            ("The sign says ", .naturalInform),
            ("\u{201C}Keep out\u{201D}", .gameText),
            (" in red.", .naturalInform),
        ])
    }

    func testInform7HeadingsWithColons() throws {
        try assertStyles("""
            "Colons" by Toby Nelson

            Volume: One

            Book: Two

            Part: Three

            Chapter: Four

            Section: Five

            Example: * Six - A sample

            Parted lips are a thing.

            Chapterhouse is a room.

            ---- DOCUMENTATION ----

            Some documentation.

            """, .inform7, [
                ("Volume: One", .heading),
                ("Book: Two", .heading),
                ("Part: Three", .heading),
                ("Chapter: Four", .heading),
                ("Section: Five", .heading),
                ("Example: * Six - A sample", .heading),
                ("Parted lips are a thing.", .naturalInform),
                ("Chapterhouse is a room.", .naturalInform),
                ("---- DOCUMENTATION ----", .heading),
                ("Some documentation.", .naturalInform),
            ])
    }

    /// A line in the middle of quoted text or a comment isn't a heading, whatever it starts with.
    func testInform7HeadingWordsInQuotesAndComments() throws {
        try assertStyles("""
            The note is "A long note
            Chapter 1 of the note" here.
            [A long comment
            Section 2 of the comment]

            """, .inform7, [
                ("The note is ", .naturalInform),
                ("\"A long note\nChapter 1 of the note\"", .gameText),
                (" here.", .naturalInform),
                ("[A long comment\nSection 2 of the comment]", .comment),
            ])
    }

    /// Brackets that don't start Inform 6 are ordinary text.
    func testInform7Parentheses() throws {
        try assertStyles("The box (which is open) is here.\n", .inform7, [
            ("The box (which is open) is here.", .naturalInform),
        ])
    }

    /// Only "-)" ends Inform 6 code, not a minus sign in it.
    func testInform6InclusionsWithMinusSigns() throws {
        try assertStyles("To decide what number is the answer: (- 43 - 1 -). The end.\n", .inform7, [
            ("To decide what number is the answer: (", .naturalInform),
            ("43 - 1 ", .codeAlpha),
            (". The end.", .naturalInform),
        ])
    }

    func testInform6InclusionsWithAccentedLetters() throws {
        try assertStyles("Include (- Constant Greeting \"Caf\u{E9}~\"; -).\n", .inform7, [
            ("Constant", .directive),
            ("\"Caf\u{E9}", .string),
            ("~", .escapeCharacter),
            ("\"", .string),
        ])
    }

    // MARK: - More Inform 6

    /// Escape characters and keywords are found by their place in the line, which a letter outside ASCII mustn't move.
    func testInform6AfterAccentedLetters() throws {
        try assertStyles("""
            [ Greet;
                print "Caf\u{E9}~ok^"; rtrue;
            ];

            """, .inform6, [
                ("print", .code),
                ("\"Caf\u{E9}", .string),
                ("~", .escapeCharacter),
                ("ok", .string),
                ("^", .escapeCharacter),
                ("\"", .string),
                ("rtrue", .code),
            ])
    }

    func testInform6Escapes() throws {
        try assertStyles("""
            [ Main;
                print "a\\b @@92 c";
            ];

            """, .inform6, [
                ("\"a", .string),
                ("\\", .escapeCharacter),
                ("b ", .string),
                ("@@92", .escapeCharacter),
                (" c\"", .string),
            ])
    }

    /// The character after an "@" and its digits is looked at too, so it can be another escape.
    func testInform6EscapeAfterAnAtSignAndDigits() throws {
        try assertStyles("""
            [ Main;
                print "@@92~ok";
            ];

            """, .inform6, [
                ("@@92", .escapeCharacter),
                ("~", .escapeCharacter),
                ("ok\"", .string),
            ])
    }

    /// An exclamation mark in a string doesn't start a comment.
    func testInform6ExclamationMarksInStrings() throws {
        try assertStyles("""
            [ Main;
                print "Hello!"; ! A comment
            ];

            """, .inform6, [
                ("\"Hello!\"", .string),
                ("! A comment", .comment),
            ])
    }

    func testInform6KeywordsInCapitals() throws {
        try assertStyles("""
            [ Main x;
                IF (x) RTRUE;
            ];

            """, .inform6, [
                ("IF", .code),
                ("x", .codeAlpha),
                ("RTRUE", .code),
            ])
    }

    func testInform6Grammar() throws {
        try assertStyles("Verb meta 'score' * -> Score;\n", .inform6, [
            ("Verb", .directive),
            ("meta", .directive),
            ("'score'", .string),
            ("*", .directive),
            ("->", .directive),
            ("Score", []),
        ])
    }

    func testInform6ObjectProperties() throws {
        try assertStyles("""
            Object box "box"
              class Container
              with name 'box', description "A box.",
              has open light;

            """, .inform6, [
                ("Object", .directive),
                ("\"box\"", .string),
                ("class", .directive),
                ("Container", .property),
                ("with", .directive),
                ("name", .property),
                ("'box'", .string),
                ("description", .property),
                ("\"A box.\"", .string),
                ("has", .directive),
                ("open", .property),
                ("light", .property),
            ])
    }

    // MARK: - Styles

    func testTabStopsAndAttributes() {
        let natural = IFNaturalHighlighter()
        let inform6 = IFInform6Highlighter()
        XCTAssertEqual(natural.tabStopWidth, IFPreferences.shared.tabWidth)
        XCTAssertEqual(inform6.tabStopWidth, 28)

        for style: IFSyntaxStyle in [[], .comment, .string, .directive, .heading, .gameText, .naturalInform] {
            let expected = IFPreferences.shared.styles[Int(style.rawValue)] as NSDictionary
            XCTAssertEqual(natural.attributes(for: style) as NSDictionary, expected, name(style))
            XCTAssertEqual(inform6.attributes(for: style) as NSDictionary, expected, name(style))
        }
    }
}
