//
//  IFFindInFilesTests.swift
//  InformTests
//

import XCTest

@MainActor
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
                        in project: IFProject? = nil,
                        with finder: IFFindInFiles = IFFindInFiles()) -> (results: [IFFindResult], progress: [[Int32]]) {
        let project = project ?? IFProject()
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

    /// Starting a search while another runs doesn't wait for that one to end, and that one's progress isn't reported
    /// after, as its last report would stop the new search's progress indicator
    func testANewSearchDoesntWaitForOneRunning() throws {
        let project = try openProject(source: ["story.ni": "A beaker is in the Lab."])
        let finder = IFFindInFiles()
        let firstReported = expectation(description: "The first search reports progress")
        var firstFinished = false
        var firstReports = 0
        let documentation: IFFindLocation = [.documentationBasic, .documentationSource, .documentationDefinitions]
        finder.start(withPhrase: "the", withSearch: .contains, from: project,
                     withLocations: documentation) { num, total, _ in
            firstReports += 1
            if num == 1 { firstReported.fulfill() }
            if num == total { firstFinished = true }
        }
        wait(for: [firstReported], timeout: 60)
        XCTAssertFalse(firstFinished)

        let secondFinished = expectation(description: "The second search finishes")
        let firstReportsBeforeTheSecond = firstReports
        let started = Date()
        finder.start(withPhrase: "beaker", withSearch: .contains, from: project,
                     withLocations: .source) { num, total, _ in
            if num == total { secondFinished.fulfill() }
        }
        let startTook = Date().timeIntervalSince(started)
        wait(for: [secondFinished], timeout: 60)

        XCTAssertLessThan(startTook, 1)
        XCTAssertEqual(firstReports, firstReportsBeforeTheSecond)
        XCTAssertEqual(finder.results.map(\.context), ["A beaker is in the Lab."])
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

    /// The file names of results
    private func files(_ results: [IFFindResult]) -> [String] {
        return results.map { ($0.filepath as NSString?)?.lastPathComponent ?? "-" }
    }

    /// The documentation the app shows, with Writing with Inform first, then the Recipe Book, then the examples, each
    /// a page of its own. One result for a page's text, however many matches it has.
    func testFindsOneResultForEachPagesText() {
        let results = search("Sybil", .documentationBasic).results

        XCTAssertEqual(results.map(\.documentDisplayName),
                       ["7.7: Reading and talking", "18.13: Topic columns", "7.7: Saying Simple Things",
                        "Example 97: Sybil 1", "Example 98: Sybil 2"])
        XCTAssertEqual(files(results), ["WI_7_7.html", "WI_18_13.html", "RB_7_7.html", "eg_97.html", "eg_98.html"])
        XCTAssertEqual(results.map(\.recipeBookResult), [false, false, true, false, false])
        for result in results {
            XCTAssertEqual(result.phrase, "Sybil")
            XCTAssertEqual(result.locationType, .documentationBasic)
            XCTAssertNil(result.exampleName)
            XCTAssertNil(result.codeAnchorTag)
        }
    }

    /// The contents pages have no search title and section, and aren't searched
    func testLeavesOutPagesWithoutASearchTitle() {
        let results = search("Declaring files", .documentationBasic).results

        XCTAssertEqual(files(results), ["WI_27_10.html", "WI_27_11.html", "WI_27_12.html"])
    }

    /// Every match in the documentation's code is a result, with the code's anchor
    func testFindsEveryMatchInTheDocumentationsCode() {
        let results = search("Bodleian Library;", .documentationSource).results

        XCTAssertEqual(results.map(\.context), ["move the player to the Bodleian Library;",
                                                "now the player is in the Bodleian Library;"])
        for result in results {
            XCTAssertEqual(result.documentDisplayName, "8.9: Moving the player")
            XCTAssertEqual(result.codeAnchorTag, "code466")
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
        XCTAssertEqual(textAndCode.map { $0.codeAnchorTag ?? "" }.sorted(), ["", "code466", "code466"])
    }

    /// ...and in its definitions of phrases, which the text leaves to them
    func testFindsEveryMatchInTheDocumentationsDefinitions() {
        let results = search("arccosine", .documentationDefinitions).results

        XCTAssertEqual(results.map(\.definitionAnchorTag), ["defn260", "defn266"])
        XCTAssertEqual(results.map(\.documentDisplayName), ["16.8: Trigonometry", "16.8: Trigonometry"])
        XCTAssertEqual(search("arccosine", .documentationBasic).results, [])
    }

    /// The source is listed before the documentation
    func testListsTheSourceBeforeTheDocumentation() throws {
        let project = try openProject(source: ["story.ni": "Sybil is a woman."])
        XCTAssertEqual(search("Sybil", [.source, .documentationBasic], in: project).results.map(\.locationType),
                       [.source] + Array(repeating: .documentationBasic, count: 5))
    }
}
