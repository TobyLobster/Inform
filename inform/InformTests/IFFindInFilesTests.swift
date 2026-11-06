//
//  IFFindInFilesTests.swift
//  InformTests
//

import XCTest

final class IFFindInFilesTests: XCTestCase {

    // MARK: - Helpers

    /// A project in a new folder, with these files in its Source folder, opened as the app does. The folder is
    /// removed, and the project closed, when the test ends.
    private func openProject(source: [String: String]) throws -> IFProject {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("Lab.inform")
        let sourceFolder = url.appendingPathComponent("Source")
        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
        for (filename, text) in source {
            try Data(text.utf8).write(to: sourceFolder.appendingPathComponent(filename))
        }
        let project = try IFProject(contentsOf: url, ofType: "org.inform-fiction.project")
        addTeardownBlock { project.close() }
        return project
    }

    /// Searches as Find in Files does, waits for it to finish, and gives the results and each call of the progress
    /// block (the items searched, the items to search, and the results so far)
    private func search(_ phrase: String,
                        _ locations: IFFindLocation,
                        in project: IFProject = IFProject(),
                        with finder: IFFindInFiles = IFFindInFiles()) -> (results: [IFFindResult], progress: [[Int32]]) {
        var progress: [[Int32]] = []
        let finished = expectation(description: "The search finishes")
        finder.start(withPhrase: phrase, withSearch: .contains, from: project, withLocations: locations) { num, total, found in
            progress.append([num, total, found])
            if num == total {
                finished.fulfill()
            }
        }
        wait(for: [finished], timeout: 60)
        return (finder.results, progress)
    }

    /// The context of the first match of `phrase` in `text`, and the match's range in it
    private func context(of phrase: String, in text: String) -> (context: String, range: NSRange) {
        let match = (text as NSString).range(of: phrase)
        var range = NSRange(location: NSNotFound, length: 0)
        let context = IFFindInFiles.getContextFromText(text,
                                                       withLocation: UInt(match.location),
                                                       andLength: UInt(match.length),
                                                       findingContextRange: &range)
        return (context, range)
    }

    // MARK: - The context of a match

    /// The context is the line the match is on
    func testTheContextIsTheLineOfTheMatch() {
        let found = context(of: "beaker", in: "The Lab is a room.\nA beaker is in the Lab.\rThe beaker is fragile.")
        XCTAssertEqual(found.context, "A beaker is in the Lab.")
        XCTAssertEqual(found.range, NSRange(location: 2, length: 6))
    }

    /// ...without the whitespace at either end
    func testTheContextLeavesOutWhitespaceAtEitherEnd() {
        let found = context(of: "beaker", in: "Lab\n\t  A beaker is in the Lab. \t\r\nThe end")
        XCTAssertEqual(found.context, "A beaker is in the Lab.")
        XCTAssertEqual(found.range, NSRange(location: 2, length: 6))
    }

    func testTheContextOfAMatchAtTheStartOrEndOfTheText() {
        XCTAssertEqual(context(of: "Lab", in: "Lab is a room").range, NSRange(location: 0, length: 3))
        let atEnd = context(of: "room", in: "\nThe Lab is a room")
        XCTAssertEqual(atEnd.context, "The Lab is a room")
        XCTAssertEqual(atEnd.range, NSRange(location: 13, length: 4))
    }

    /// A match over more than one line has the lines it's on
    func testTheContextOfAMatchOverLines() {
        let found = context(of: "Lab.\nThe", in: "Room\nA beaker is in the Lab.\nThe beaker is fragile.\nEnd")
        XCTAssertEqual(found.context, "A beaker is in the Lab.\nThe beaker is fragile.")
        XCTAssertEqual(found.range, NSRange(location: 19, length: 8))
    }

    /// A match ending in whitespace that runs to the end of its line keeps that whitespace
    func testTheContextHoldsAMatchEndingInWhitespace() {
        let found = context(of: "Lab. ", in: "A beaker is in the Lab. \nThe end")
        XCTAssertEqual(found.context, "A beaker is in the Lab. ")
        XCTAssertEqual(found.range, NSRange(location: 19, length: 5))
    }

    // MARK: - Searching a project's source

    /// Every match in the source is a result, with where it is, its line, and the file's name
    func testFindsEveryMatchInTheSource() throws {
        let source = "\"Lab\" by Jane Doe\n\nThe Lab is a room. A beaker is in the Lab.\nThe beaker is fragile.\n"
        let project = try openProject(source: ["story.ni": source])

        let results = search("beaker", .source, in: project).results

        XCTAssertEqual(results.map(\.fileRange), [(source as NSString).range(of: "beaker"),
                                                  (source as NSString).range(of: "beaker", options: .backwards)])
        XCTAssertEqual(results.map(\.context), ["The Lab is a room. A beaker is in the Lab.", "The beaker is fragile."])
        XCTAssertEqual(results.map(\.phrase), ["beaker", "beaker"])
        for result in results {
            XCTAssertEqual(result.filepath, "story.ni")
            XCTAssertEqual(result.documentDisplayName, "story")
            XCTAssertEqual(result.documentSortName, "story")
            XCTAssertEqual(result.locationType, .source)
            XCTAssertNil(result.exampleName)
            XCTAssertNil(result.codeAnchorTag)
        }
    }

    /// Files are in order of their names, with numbers in them compared as numbers
    func testListsFilesInOrderOfTheirNames() throws {
        let project = try openProject(source: ["Part 10.i7": "A beaker.", "Part 9.i7": "A beaker.", "story.ni": "A beaker."])
        XCTAssertEqual(search("beaker", .source, in: project).results.map(\.documentDisplayName),
                       ["Part 9", "Part 10", "story"])
    }

    /// The progress block is called after each file, and once more at the end
    func testReportsProgress() throws {
        let project = try openProject(source: ["Part 1.i7": "A beaker. A beaker.", "story.ni": "No."])
        let (results, progress) = search("beaker", .source, in: project)

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(progress.map { $0[0] }, [1, 2, 3])
        XCTAssertEqual(progress.map { $0[1] }, [3, 3, 3])
        XCTAssertEqual(progress.last?[2], 2)
    }

    /// A new search forgets the last one's results
    func testANewSearchStartsAfresh() throws {
        let project = try openProject(source: ["story.ni": "A beaker is in the Lab. The beaker is fragile."])
        let finder = IFFindInFiles()
        XCTAssertEqual(search("beaker", .source, in: project, with: finder).results.count, 2)
        XCTAssertEqual(search("fragile", .source, in: project, with: finder).results.map(\.phrase), ["fragile"])
    }

    /// The source is searched as it was when the search started, though that's done later, on another thread
    func testSearchesTheSourceAsItWasWhenTheSearchStarted() throws {
        let project = try openProject(source: ["story.ni": "A beaker. A beaker."])
        let storage = try XCTUnwrap(project.sourceFiles?["story.ni"])
        let finder = IFFindInFiles()
        let finished = expectation(description: "The search finishes")

        // Holding the results' lock keeps the search from recording a match until the text has changed
        _ = objc_sync_enter(finder.searchResultsLock)
        finder.start(withPhrase: "beaker", withSearch: .contains, from: project, withLocations: .source) { num, total, _ in
            if num == total {
                finished.fulfill()
            }
        }
        storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: "Nothing.")
        _ = objc_sync_exit(finder.searchResultsLock)
        wait(for: [finished], timeout: 10)

        XCTAssertEqual(finder.results.map(\.context), ["A beaker. A beaker.", "A beaker. A beaker."])
    }

    func testFindsNothingWhereItIsNotLooking() throws {
        let project = try openProject(source: ["story.ni": "SYBIL is a woman."])
        let (results, progress) = search("SYBIL", [], in: project)
        XCTAssertEqual(results, [])
        XCTAssertEqual(progress, [[1, 1, 0]])
    }

    // MARK: - Searching the documentation

    /// One result for a page's text, however many matches it has, and one for each example on it. Writing with
    /// Inform comes before the Recipe Book.
    func testFindsOneResultForAPagesTextAndOneForEachExample() {
        let results = search("SYBIL", .documentationBasic).results

        XCTAssertEqual(results.map(\.documentDisplayName),
                       ["7.6: Reading and talking", "7.7: Saying Simple Things", "7.7: Saying Simple Things"])
        XCTAssertEqual(results.map(\.recipeBookResult), [false, true, true])
        XCTAssertEqual(results.first?.exampleName, "93: Sybil 2")
        XCTAssertEqual(results.first?.exampleAnchorTag, "e350")
        XCTAssertEqual(Set(results.dropFirst().map { $0.exampleName ?? "" }), ["", "93: Sybil 2"])
        for result in results {
            XCTAssertEqual(result.phrase, "SYBIL")
            XCTAssertEqual(result.locationType, .documentationBasic)
            XCTAssertTrue(result.filepath?.hasSuffix(".html") ?? false)
            XCTAssertNil(result.codeAnchorTag)
        }
    }

    /// Every match in the documentation's code is a result, with the code's anchor
    func testFindsEveryMatchInTheDocumentationsCode() {
        let results = search("Bodleian", .documentationSource).results

        XCTAssertEqual(results.map(\.context), ["move the player to the Bodleian Library;",
                                                "now the player is in the Bodleian Library;"])
        for result in results {
            XCTAssertEqual(result.documentDisplayName, "8.9: Moving the player")
            XCTAssertEqual(result.codeAnchorTag, "c1869")
            XCTAssertEqual(result.locationType, .documentationBasic)
        }
    }

    /// A match in code doesn't use up the one result for the page's text, whether or not code is searched
    func testAMatchInCodeLeavesThePagesTextToBeFound() {
        let text = search("Bodleian", .documentationBasic).results
        XCTAssertEqual(text.map(\.context), ["This will ordinarily result in a room description of the Bodleian Library "
                                              + "being printed up, but that might not always be desirable. For instance:"])
        XCTAssertEqual(text.first?.documentDisplayName, "8.9: Moving the player")
        XCTAssertNil(text.first?.codeAnchorTag)

        let textAndCode = search("Bodleian", [.documentationBasic, .documentationSource]).results
        XCTAssertEqual(textAndCode.map { $0.codeAnchorTag ?? "" }.sorted(), ["", "c1869", "c1869"])
    }

    /// ...and in its definitions of phrases, which the text leaves to them
    func testFindsEveryMatchInTheDocumentationsDefinitions() {
        let results = search("arccosine", .documentationDefinitions).results

        XCTAssertEqual(results.map(\.definitionAnchorTag), ["defn210", "defn216"])
        XCTAssertEqual(results.map(\.documentDisplayName), ["15.7: Trigonometry", "15.7: Trigonometry"])
        XCTAssertEqual(search("arccosine", .documentationBasic).results, [])
    }

    /// The source is listed before the documentation
    func testListsTheSourceBeforeTheDocumentation() throws {
        let project = try openProject(source: ["story.ni": "SYBIL is a woman."])
        XCTAssertEqual(search("SYBIL", [.source, .documentationBasic], in: project).results.map(\.locationType),
                       [.source, .documentationBasic, .documentationBasic, .documentationBasic])
    }
}
