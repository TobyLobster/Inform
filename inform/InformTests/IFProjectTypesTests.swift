//
//  IFProjectTypesTests.swift
//  InformTests
//

import XCTest

final class IFProjectTypesTests: XCTestCase {

    private let latin1 = String.Encoding.isoLatin1.rawValue
    private let utf8 = String.Encoding.utf8.rawValue

    func testGivesInform6FilesLatin1() {
        for filename in ["story.inf", "story.i6", "game.icl", "notes.txt", "Parser.h", "/Users/jane/Lib/VERBLIB.H", "Story.INF"] {
            XCTAssertEqual(IFProjectTypes.encoding(forFilename: filename), latin1, filename)
        }
    }

    func testGivesInform7FilesUTF8() {
        for filename in ["story.ni", "story.i7", "Locksmith.i7x", "Contents.w", "index.html", "index.htm", "story", "Source/STORY.NI"] {
            XCTAssertEqual(IFProjectTypes.encoding(forFilename: filename), utf8, filename)
        }
    }

    func testGivesOtherFilesUTF8() {
        for filename in ["picture.png", "data.json", "story.ulx"] {
            XCTAssertEqual(IFProjectTypes.encoding(forFilename: filename), utf8, filename)
        }
    }

    func testTellsTheInformVersionOfAFile() {
        for filename in ["story.inf", "story.i6", "Parser.h", "STORY.INF"] {
            XCTAssertEqual(IFProjectTypes.informVersion(forFilename: filename), .version6, filename)
        }
        for filename in ["story.ni", "story.i7", "Locksmith.i7x", "story", "Source/Story.NI"] {
            XCTAssertEqual(IFProjectTypes.informVersion(forFilename: filename), .version7, filename)
        }
        // Neither, though some are read as Latin-1 or UTF-8
        for filename in ["game.icl", "notes.txt", "Contents.w", "index.html", "picture.png"] {
            XCTAssertEqual(IFProjectTypes.informVersion(forFilename: filename), .versionUnknown, filename)
        }
    }

    func testHighlightsAFileForItsInformVersion() {
        XCTAssertEqual(IFProjectTypes.highlighterType(forFilename: "story.inf"), .inform6)
        XCTAssertEqual(IFProjectTypes.highlighterType(forFilename: "Parser.h"), .inform6)
        XCTAssertEqual(IFProjectTypes.highlighterType(forFilename: "story.ni"), .inform7)
        XCTAssertEqual(IFProjectTypes.highlighterType(forFilename: "Locksmith.i7x"), .inform7)
        XCTAssertEqual(IFProjectTypes.highlighterType(forFilename: "story"), .inform7)
        XCTAssertEqual(IFProjectTypes.highlighterType(forFilename: "game.icl"), .none)
        XCTAssertEqual(IFProjectTypes.highlighterType(forFilename: "notes.txt"), .none)
    }

    func testGivesOnlyInform7FilesIntelligence() {
        let intelligence = IFProjectTypes.intelligence(forFilename: "story.ni")
        XCTAssertTrue(intelligence is IFNaturalIntel)
        XCTAssertTrue(IFProjectTypes.intelligence(forFilename: "Locksmith.i7x") is IFNaturalIntel)
        // A new one each time
        XCTAssertFalse(IFProjectTypes.intelligence(forFilename: "story.ni") === intelligence)

        XCTAssertNil(IFProjectTypes.intelligence(forFilename: "story.inf"))
        XCTAssertNil(IFProjectTypes.intelligence(forFilename: "game.icl"))
        XCTAssertNil(IFProjectTypes.intelligence(forFilename: "notes.txt"))
    }

    func testTellsTheTypeOfADocument() {
        let types: [(String, IFFileType)] = [
            ("org.inform-fiction.project", .inform7Project),
            ("Inform Project", .inform7Project),
            ("Inform project file", .inform7Project),
            ("org.inform-fiction.xproject", .inform7ExtensionProject),
            ("org.inform-fiction.source.inform6", .inform6SourceFile),
            ("Inform 6 source file", .inform6SourceFile),
            ("org.inform-fiction.source.inform7", .inform7SourceFile),
            ("Inform 7 source file", .inform7SourceFile),
            ("Natural Inform source file", .inform7SourceFile),
            ("Inform Control Language file", .inform6ICLFile),
            // An Inform 6 header is opened as an ICL file
            ("public.c-header", .inform6ICLFile),
            ("org.inform-fiction.inform7.extension", .inform7ExtensionFile),
            ("Inform 7 extension", .inform7ExtensionFile),
            // In any case
            ("ORG.INFORM-FICTION.PROJECT", .inform7Project),
            ("inform 7 SOURCE file", .inform7SourceFile),
        ]
        for (typeName, fileType) in types {
            XCTAssertEqual(IFProjectTypes.fileType(from: typeName), fileType, typeName)
        }
    }

    func testDoesntKnowOtherDocumentTypes() {
        for typeName in ["public.plain-text", "Inform Materials", "org.inform-fiction.blurb", "Inform Extension Directory", ""] {
            XCTAssertEqual(IFProjectTypes.fileType(from: typeName), .unknown, typeName)
        }
    }
}
