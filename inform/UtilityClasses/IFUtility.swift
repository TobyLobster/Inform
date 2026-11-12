//
//  IFUtility.swift
//  Inform
//
//  Created by Toby Nelson, 2014
//  Translated from Objective-C in November 2026. The interface is IFUtility in IFUtility.h.
//

import Cocoa

func lerp(_ progress: CGFloat, _ from: CGFloat, _ to: CGFloat) -> CGFloat {
    return from + progress * (to - from)
}

func easeOutCubic(_ t: CGFloat) -> CGFloat {
    let t = t - 1
    return t*t*t + 1
}

// *******************************************************************************************
@objc @implementation extension IFUtility {

    // MARK: - Hosting the unit tests
    @objc(hostingUnitTests)
    class var isHostingUnitTests: Bool {
        @objc(isHostingUnitTests) get {
            return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        }
    }

    class func stopTestHostWithLeftoverHome() {
        let environment = ProcessInfo.processInfo.environment
        if isTestHostWithLeftoverHome(inEnvironment: environment) {
            NSLog("The tests' home folder %@ was there as the test host started, so the host has the user's "
                  + "preferences. It's stopped, and the tests that were left aren't run.",
                  environment["CFFIXED_USER_HOME"] ?? "")
            exit(EXIT_FAILURE)
        }
    }

    class func isTestHostWithLeftoverHome(inEnvironment environment: [String: String]) -> Bool {
        guard environment["XCTestConfigurationFilePath"] != nil, let home = environment["CFFIXED_USER_HOME"] else {
            return false
        }
        return FileManager.default.fileExists(atPath: home)
    }

    // MARK: - Alert dialogs
    @objc(runAlertWarningWindow:title:informativeText:)
    @MainActor class func runAlertWarning(_ window: NSWindow?,
                                          title: String,
                                          informativeText text: String) {
        runAlertWindow(window,
                       warning: true,
                       localizedTitle: localizedString(title),
                       informativeText: text)
    }

    @objc(runAlertWarningWindow:localizedTitle:informativeText:)
    @MainActor class func runAlertWarning(_ window: NSWindow?,
                                          localizedTitle title: String,
                                          informativeText text: String) {
        runAlertWindow(window,
                       warning: true,
                       localizedTitle: title,
                       informativeText: text)
    }

    @MainActor class func runAlertInformationWindow(_ window: NSWindow?,
                                                    title: String,
                                                    informativeText text: String) {
        runAlertWindow(window,
                       warning: false,
                       localizedTitle: localizedString(title),
                       informativeText: text)
    }

    /// An alert with an OK button
    @MainActor private class func runAlertWindow(_ window: NSWindow?,
                                                 warning warningStyle: Bool,
                                                 localizedTitle title: String,
                                                 informativeText text: String) {
        let alert = NSAlert()
        alert.addButton(withTitle: localizedString("OK"))
        alert.messageText = title
        alert.informativeText = text
        alert.alertStyle = warningStyle ? .warning : .informational

        show(alert, for: window) { _ in

        }
    }

    @objc(showAlert:forWindow:completionHandler:)
    @MainActor class func show(_ alert: NSAlert,
                               for window: NSWindow?,
                               completionHandler handler:
                                    @escaping @MainActor @Sendable (NSApplication.ModalResponse) -> Void) {
        if let window {
            alert.beginSheetModal(for: window, completionHandler: handler)
            return
        }

        // A sheet on no window doesn't appear, so the alert is run modally, unless nobody is there to close it
        if isHostingUnitTests {
            NSLog("Alert not shown while hosting the unit tests: %@ %@", alert.messageText, alert.informativeText)
            handler(.abort)
            return
        }
        handler(alert.runModal())
    }

    @objc(beginSavePanel:forWindow:completionHandler:)
    @MainActor class func begin(_ panel: NSSavePanel,
                                for window: NSWindow?,
                                completionHandler handler:
                                    @escaping @MainActor @Sendable (NSApplication.ModalResponse) -> Void) {
        // Swift's beginSheetModal(for:) needs a window, so the method is called through its implementation
        typealias BeginSheet = @convention(c) (NSSavePanel, Selector, NSWindow?,
                                               @convention(block) @MainActor (NSApplication.ModalResponse) -> Void)
                                               -> Void
        let selector = #selector(NSSavePanel.beginSheetModal(for:completionHandler:))
        let beginSheet = unsafeBitCast(panel.method(for: selector), to: BeginSheet.self)
        beginSheet(panel, selector, window, handler)
    }

    @objc(runAlertYesNoWindow:title:yes:no:modalDelegate:didEndSelector:contextInfo:informativeText:)
    @MainActor class func runAlertYesNoWindow(_ window: NSWindow?,
                                              title: String,
                                              yes: String,
                                              no: String,
                                              modalDelegate: Any?,
                                              didEnd alertDidEndSelector: Selector?,
                                              contextInfo: UnsafeMutableRawPointer?,
                                              informativeText text: String) {
        runAlertYesNoWindow(window,
                            title: title,
                            yes: yes,
                            no: no,
                            modalDelegate: modalDelegate,
                            didEnd: alertDidEndSelector,
                            contextInfo: contextInfo,
                            destructiveIndex: NSNotFound,
                            informativeText: text)
    }

    @objc(runAlertYesNoWindow:title:yes:no:modalDelegate:didEndSelector:contextInfo:destructiveIndex:informativeText:)
    @MainActor class func runAlertYesNoWindow(_ window: NSWindow?,
                                              title: String,
                                              yes: String,
                                              no: String,
                                              modalDelegate: Any?,
                                              didEnd alertDidEndSelector: Selector?,
                                              contextInfo: UnsafeMutableRawPointer?,
                                              destructiveIndex desIdx: Int,
                                              informativeText text: String) {
        let alert = NSAlert()
        alert.addButton(withTitle: yes)
        alert.addButton(withTitle: no)
        alert.messageText = title
        alert.informativeText = text
        alert.alertStyle = .informational
        if desIdx == 0 || desIdx == 1 {
            alert.buttons[desIdx].hasDestructiveAction = true
        }

        // The delegate and context are only passed back to the delegate, on the main actor
        nonisolated(unsafe) let modalDelegate = modalDelegate
        nonisolated(unsafe) let contextInfo = contextInfo
        show(alert, for: window) { response in
            self.modalYesNoResponse(response,
                                    window: window,
                                    modalDelegate: modalDelegate,
                                    didEnd: alertDidEndSelector,
                                    contextInfo: contextInfo)
        }
    }

    private class func modalYesNoResponse(_ returnCode: NSApplication.ModalResponse,
                                          window: NSWindow?,
                                          modalDelegate: Any?,
                                          didEnd alertDidEndSelector: Selector?,
                                          contextInfo: UnsafeMutableRawPointer?) {
        guard let modalDelegate = modalDelegate as? NSObject, let alertDidEndSelector else {
            return
        }
        // Hack!
        typealias DidEnd = @convention(c) (AnyObject, Selector, NSWindow?, Int, UnsafeMutableRawPointer?) -> Void
        let imp = modalDelegate.method(for: alertDidEndSelector)
        let function = unsafeBitCast(imp, to: DidEnd.self)
        function(modalDelegate, alertDidEndSelector, window, returnCode.rawValue, contextInfo)
    }

    @objc(showExtensionError:withWindow:)
    @MainActor class func showExtensionError(_ result: IFExtensionResult,
                                             with window: NSWindow?) {
        // TODO: Do we want to customise the error message depending on the IFExtensionResult?
        switch result {
        case .notFound:
            break
        case .notValid:
            break
        case .alreadyExists:
            break
        case .cantWriteDestination:
            break
        case .success:
            return
        @unknown default:
            return
        }
        runAlertWarning(window,
                        title: "Failed to Install Extension",
                        informativeText: localizedString("Failed to Install Extension Explanation"))
    }
}
