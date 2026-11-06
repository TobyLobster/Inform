//
//  IFProjectMaterialsPresenterTests.swift
//  InformTests
//

import XCTest

final class IFProjectMaterialsPresenterTests: XCTestCase {

    private let fileManager = FileManager.default

    private func makeFolder() throws -> URL {
        let folder = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    private func isFolder(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func write(_ text: String, to url: URL) throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    func testPresentsTheMaterialsFolderForTheProject() throws {
        let folder = try makeFolder()
        let project = folder.appendingPathComponent("Lighthouse.inform")

        let presenter = IFProjectMaterialsPresenter(url: project)

        XCTAssertEqual(presenter.presentedItemURL?.path, folder.appendingPathComponent("Lighthouse.materials").path)
        XCTAssertEqual(presenter.primaryPresentedItemURL, project)
    }

    func testHasItsOwnOperationQueue() throws {
        let folder = try makeFolder()
        let project = folder.appendingPathComponent("Lighthouse.inform")

        let presenter = IFProjectMaterialsPresenter(url: project)
        let other = IFProjectMaterialsPresenter(url: project)

        XCTAssertTrue(presenter.presentedItemOperationQueue === presenter.presentedItemOperationQueue)
        XCTAssertFalse(presenter.presentedItemOperationQueue === other.presentedItemOperationQueue)
        XCTAssertFalse(presenter.presentedItemOperationQueue === OperationQueue.main)
    }

    func testCreatesTheMaterialsFolderWithItsIcon() throws {
        let folder = try makeFolder()
        let materials = folder.appendingPathComponent("Lighthouse.materials")

        _ = IFProjectMaterialsPresenter(url: folder.appendingPathComponent("Lighthouse.inform"))

        XCTAssertTrue(isFolder(materials))
        XCTAssertTrue(fileManager.fileExists(atPath: materials.appendingPathComponent("Icon\r").path))
    }

    func testKeepsAnExistingMaterialsFolder() throws {
        let folder = try makeFolder()
        let figure = folder.appendingPathComponent("Lighthouse.materials/Figures/Lamp.png")
        try write("lamp", to: figure)

        _ = IFProjectMaterialsPresenter(url: folder.appendingPathComponent("Lighthouse.inform"))

        XCTAssertEqual(try String(contentsOf: figure, encoding: .utf8), "lamp")
    }

    func testRenamesAnOldMaterialsFolder() throws {
        let folder = try makeFolder()
        try write("lamp", to: folder.appendingPathComponent("Lighthouse Materials/Figures/Lamp.png"))

        // The alert saying so has no window, so it's only logged while hosting the tests
        _ = IFProjectMaterialsPresenter(url: folder.appendingPathComponent("Lighthouse.inform"))

        let figure = folder.appendingPathComponent("Lighthouse.materials/Figures/Lamp.png")
        XCTAssertEqual(try String(contentsOf: figure, encoding: .utf8), "lamp")
        XCTAssertFalse(fileManager.fileExists(atPath: folder.appendingPathComponent("Lighthouse Materials").path))
    }

    func testLeavesAnOldMaterialsFolderWhenThereIsANewOne() throws {
        let folder = try makeFolder()
        let old = folder.appendingPathComponent("Lighthouse Materials/Figures/Lamp.png")
        let new = folder.appendingPathComponent("Lighthouse.materials/Figures/Lens.png")
        try write("lamp", to: old)
        try write("lens", to: new)

        _ = IFProjectMaterialsPresenter(url: folder.appendingPathComponent("Lighthouse.inform"))

        XCTAssertEqual(try String(contentsOf: old, encoding: .utf8), "lamp")
        XCTAssertEqual(try String(contentsOf: new, encoding: .utf8), "lens")
        XCTAssertFalse(fileManager.fileExists(atPath: folder.appendingPathComponent("Lighthouse.materials/Figures/Lamp.png").path))
    }

    func testDoesntRenameAFileNamedLikeAnOldMaterialsFolder() throws {
        let folder = try makeFolder()
        let file = folder.appendingPathComponent("Lighthouse Materials")
        try write("notes", to: file)

        _ = IFProjectMaterialsPresenter(url: folder.appendingPathComponent("Lighthouse.inform"))

        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "notes")
        XCTAssertTrue(isFolder(folder.appendingPathComponent("Lighthouse.materials")))
    }

    func testCopesWhenTheFolderCantBeCreated() throws {
        let folder = try makeFolder()
        let project = folder.appendingPathComponent("Missing/Lighthouse.inform")

        let presenter = IFProjectMaterialsPresenter(url: project)

        XCTAssertEqual(presenter.presentedItemURL?.path, folder.appendingPathComponent("Missing/Lighthouse.materials").path)
        XCTAssertFalse(fileManager.fileExists(atPath: folder.appendingPathComponent("Missing").path))
    }

    func testHasNoURLsWithoutAFileURL() {
        for url in [nil, URL(string: "https://example.com/Lighthouse.inform")] {
            let presenter = IFProjectMaterialsPresenter(url: url)

            XCTAssertNil(presenter.presentedItemURL)
            XCTAssertNil(presenter.primaryPresentedItemURL)
            XCTAssertNotNil(presenter.presentedItemOperationQueue)
        }
    }

    func testCloseLetsGoOfTheRegisteredPresenter() throws {
        let folder = try makeFolder()
        weak var weakPresenter: IFProjectMaterialsPresenter?
        autoreleasepool {
            let presenter = IFProjectMaterialsPresenter(url: folder.appendingPathComponent("Lighthouse.inform"))
            NSFileCoordinator.addFilePresenter(presenter)       // As it is in the sandbox
            weakPresenter = presenter
        }
        autoreleasepool {
            XCTAssertNotNil(weakPresenter, "NSFileCoordinator keeps its presenters")
            weakPresenter?.close()
        }

        XCTAssertNil(weakPresenter)
    }

    func testCloseIsHarmlessWhenNotRegistered() throws {
        let folder = try makeFolder()
        let presenter = IFProjectMaterialsPresenter(url: folder.appendingPathComponent("Lighthouse.inform"))

        presenter.close()
        presenter.close()

        XCTAssertTrue(isFolder(folder.appendingPathComponent("Lighthouse.materials")))
    }

    func testRegistersOnlyInTheSandbox() throws {
        try XCTSkipIf(IFUtility.isSandboxed, "The tests expect an app that isn't sandboxed")
        let folder = try makeFolder()

        let presenter = IFProjectMaterialsPresenter(url: folder.appendingPathComponent("Lighthouse.inform"))

        XCTAssertFalse(NSFileCoordinator.filePresenters.contains { $0 === presenter })
    }
}
