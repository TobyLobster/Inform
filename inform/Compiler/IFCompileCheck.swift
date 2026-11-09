//
//  IFCompileCheck.swift
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//  Translated from Objective-C in November 2026. The interface is still IFCompileCheck.h.
//

import Foundation

@objc @implementation extension IFCompileCheck {
    private final var testCaseChangedSinceLastSuccessfulCompile = true
    /// Whether the story was made by a compile for release
    private final var storyIsForRelease = false

    func testCaseDidChange() {
        testCaseChangedSinceLastSuccessfulCompile = true
    }

    func compileDidStart(forRelease release: Bool) {
        storyIsForRelease = release
    }

    func compileDidSucceed() {
        testCaseChangedSinceLastSuccessfulCompile = false
    }

    private final func timestampsInChronologicalOrder(_ first: URL?,
                                                      second: URL?) -> Bool {
        // If the datestamps both exist, and the first timestamp is earlier or equal to the second.
        let firstAttributes  = first.flatMap  { try? FileManager.default.attributesOfItem(atPath: $0.path) }
        let secondAttributes = second.flatMap { try? FileManager.default.attributesOfItem(atPath: $0.path) }

        if let firstAttributes, let secondAttributes {
            let firstDate  = firstAttributes[.modificationDate] as? Date
            let secondDate = secondAttributes[.modificationDate] as? Date

            // Note that datestamps are only recorded to the second.
            if let firstDate, let secondDate, firstDate.compare(secondDate) != .orderedDescending {
                return true
            }
        }
        return false
    }

    func needsCompileForcing(_ force: Bool,
                             alwaysCompile: Bool,
                             unsavedChanges: Bool,
                             sourceURL: URL?,
                             settingsURL: URL?,
                             outputURL: URL?) -> Bool {
        var needsToCompile = force

        // If the debug setting to always compile is switched on, then always compile
        if !needsToCompile && alwaysCompile {
            needsToCompile = true
        }

        // If the document has unsaved changes, always save and compile
        if !needsToCompile && unsavedChanges {
            needsToCompile = true
        }

        // If we have changed test case in an extension project, always save and compile
        if !needsToCompile && testCaseChangedSinceLastSuccessfulCompile {
            needsToCompile = true
        }

        // A story made for release has no debugging commands and its random numbers aren't fixed, so don't use it
        if !needsToCompile && storyIsForRelease {
            needsToCompile = true
        }

        if !needsToCompile {
            // If the source timestamp is later than the output timestamp, then we need to compile
            needsToCompile = !timestampsInChronologicalOrder(sourceURL,
                                                             second: outputURL)

            if !needsToCompile {
                // If the settings timestamp is later than the output timestamp, then we need to compile
                needsToCompile = !timestampsInChronologicalOrder(settingsURL,
                                                                 second: outputURL)
            }
        }

        return needsToCompile
    }
}
