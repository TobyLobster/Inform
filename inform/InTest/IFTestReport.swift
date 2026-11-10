//
//  IFTestReport.swift
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//  Translated from Objective-C in November 2026. The interface is still IFTestReport.h.
//

import Foundation

@objc @implementation extension IFTestReport {
    @objc(intestCodeForProblemType:)
    class func intestCode(for problemType: ECompilerProblemType) -> String? {
        var intestCode: String?

        // Convert our problem type into an intest error code
        switch problemType {
        case .none:
            break
        case .inform6:
            intestCode = "i6"
        case .inform7:
            intestCode = "i7"
        case .cBlorb:
            intestCode = "i7"
        case .unknown:
            intestCode = "i7"
        @unknown default:
            break
        }

        return intestCode
    }

    @objc(skeinNodesToItem:)
    class func skeinNodes(to item: IFSkeinItem?) -> Int32 {
        var activeItem = item
        var skeinNodes: Int32 = 0
        while let parent = activeItem?.parent {
            activeItem = parent
            skeinNodes += 1
        }
        return skeinNodes
    }

    @objc(copyReport:toCombinedURL:)
    class func copy(_ reportURL: URL,
                    toCombinedURL combinedReportURL: URL) {
        // Copy from reportURL to combinedReportURL
        let fm = FileManager.default
        do {
            try fm.removeItem(at: combinedReportURL)
        } catch let err as NSError where err.domain == NSCocoaErrorDomain && err.code == NSFileNoSuchFileError {
            // (There may be no combined report yet)
        } catch {
            NSLog("Error removing file %@", error.localizedDescription)
            return
        }

        do {
            try fm.copyItem(at: reportURL, to: combinedReportURL)
        } catch {
            NSLog("Error copying file %@", error.localizedDescription)
        }
    }
}
