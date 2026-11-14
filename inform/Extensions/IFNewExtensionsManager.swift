//
//  IFNewExtensionsManager.swift
//  Inform
//
//  Created by Toby Nelson on 21/04/2023.
//  Translated from Objective-C in November 2026. The interface is still IFNewExtensionsManager.h.
//

import Cocoa

/// The shared manager, made when it's first needed
@MainActor private let sharedManager = IFNewExtensionsManager()

// *******************************************************************************************
@objc @implementation
extension IFNewExtensionsManager {

    // MARK: - Shared extension manager

    @objc(sharedNewExtensionsManager)
    class var shared: IFNewExtensionsManager {
        return sharedManager
    }

    // MARK: - Initialisation

    override init() {
        super.init()
    }

    // MARK: - Methods

    @objc(copyWithUnzip:toProjectTemporary:extensionName:)
    func copy(withUnzip sourceURL: URL, toProjectTemporary project: IFProject, extensionName name: String) -> URL? {
        guard let destinationURL = temporaryFolder(of: project) else {
            return nil
        }
        return copy(withUnzip: sourceURL,
                    to: destinationURL,
                    extensionName: name)
    }

    /// The project's temporary extensions folder, where an extension is copied to be installed from
    private final func temporaryFolder(of project: IFProject) -> URL? {
        return project.materialsDirectoryURL?.appendingPathComponent("Extensions")
                                             .appendingPathComponent("Reserved")
                                             .appendingPathComponent("Temporary", isDirectory: true)
    }

    @objc(removeTemporaryFolderOfProject:)
    func removeTemporaryFolder(of project: IFProject) {
        if let folder = temporaryFolder(of: project) {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    // Returns a URL of the downloaded file (or the .i7xd directory inside an unzipped zip file)
    @objc(copyWithUnzip:to:extensionName:)
    func copy(withUnzip sourceURL: URL, to destinationURL: URL, extensionName name: String) -> URL? {
        if sourceURL.pathExtension.lowercased() == "zip" {
            if IFUtility.unzip(sourceURL, toDirectory: destinationURL) {
                let name = ((name as NSString).deletingPathExtension as NSString).appendingPathExtension("i7xd")!
                return destinationURL.appendingPathComponent(name)
            }
            return nil
        }
        let fm = FileManager.default

        // Remove any existing file or directory
        try? fm.removeItem(at: destinationURL)
        // Create destination directory
        try? fm.createDirectory(at: destinationURL,
                                withIntermediateDirectories: true,
                                attributes: nil)
        let destinationURL = destinationURL.appendingPathComponent(name)
        do {
            try fm.copyItem(at: sourceURL,
                            to: destinationURL)
        } catch {
            IFUtility.runAlertWarning(nil,
                                      title: IFUtility.localizedString("Error"),
                                      informativeText: error.localizedDescription)
            return nil
        }
        return destinationURL
    }
}
