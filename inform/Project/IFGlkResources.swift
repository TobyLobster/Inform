//
//  IFGlkResources.swift
//  Inform
//
//  Created by Andrew Hunter on 29/08/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFGlkResources.h.
//

import Cocoa

@objc @implementation
extension IFGlkResources {
    private final let project: IFProject
    private final var manifest: NSDictionary?

    init(project newProject: IFProject) {
        project = newProject
        super.init()
    }

    /// The file that a section of the project's manifest gives for a resource, relative to the materials directory
    private final func file(inManifestSection section: String, forResource resource: glui32) -> String? {
        // Load the manifest, if it exists
        if manifest == nil {
            // Try the project directory first
            var manifestFileURL = project.fileURL?.appendingPathComponent("manifest.plist")

            // If there's no manifest in the project, look in the materials directory
            let projectHasManifest = manifestFileURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
            if !projectHasManifest {
                manifestFileURL = project.materialsDirectoryURL?.appendingPathComponent("manifest.plist")
            }

            // Load the manifest file if it appears to exist; if there's no manifest file, then use a blank one
            manifest = manifestFileURL.flatMap { NSDictionary(contentsOf: $0) } ?? NSDictionary()
        }

        // Get the filename from the section, which is ignored unless it's a dictionary of strings
        guard let files = manifest?[section] as? NSDictionary else {
            return nil
        }
        return files[String(resource)] as? String
    }

    func data(forImageResource image: glui32) -> Data? {
        // Get the location of the image directory
        let materialsURL = project.materialsDirectoryURL

        // Get the image filename from the graphics manifest, with a fallback
        let imageFile = file(inManifestSection: "Graphics", forResource: image) ?? "Figure \(image).png"

        // Try to load the image
        if let imageURL = materialsURL?.appendingPathComponent(imageFile),
           FileManager.default.fileExists(atPath: imageURL.path) {
            return try? Data(contentsOf: imageURL)
        }

        // Load the default image, and return its data
        return NSImage(named: "App/Interpreter/Error")?.tiffRepresentation
    }

    func data(forSoundResource sound: glui32) -> Data? {
        // Get the sound filename from the sounds manifest
        guard let soundFile = file(inManifestSection: "Sounds", forResource: sound) else {
            return nil
        }

        // Try to load the sound
        guard let soundURL = project.materialsDirectoryURL?.appendingPathComponent(soundFile) else {
            return nil
        }
        return try? Data(contentsOf: soundURL)
    }
}
