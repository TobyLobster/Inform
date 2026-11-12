//
//  IFProjectMenuValidation.swift
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//  Translated from Objective-C in November 2026. The interface is still IFProjectMenuValidation.h.
//

import Foundation

@objc @implementation extension IFProjectMenuValidation {
    @objc(isEnabledAction:tag:inState:)
    class func isEnabledAction(_ itemSelector: Selector?,
                               tag: Int,
                               in state: IFProjectMenuState) -> Bool {
        let isRunning = state.isRunningGame

        if itemSelector == #selector(IFProjectController.stopProcess(_:)) {
            return isRunning
        }

        let selectedNoTestCase = state.isExtensionProject && ((state.numberOfToolbarTestCases == 0) ||
                                                              (state.toolbarTestCase == nil))
        let selectedTestAllCase = state.isExtensionProject && state.isTestAllCasesSelected
        let currentlyTesting = state.isCurrentlyTesting

        if itemSelector == #selector(IFProjectController.testMe(_:)) {
            // If we are in an Extension Project, and there are no test cases to run, disable Test Me. With Test All
            // chosen, it runs them all.
            let noTestCases = state.isExtensionProject && (state.numberOfToolbarTestCases == 0)
            if noTestCases || currentlyTesting {
                return false
            }
        }

        if itemSelector == #selector(IFProjectController.replayEntireSkein(_:)) ||
            itemSelector == #selector(IFProjectController.replayUsingSkein(_:)) {

            // If we are in an Extension Project, and there are no test cases to run, disable Go! (etc) menu items.
            if selectedNoTestCase || selectedTestAllCase || currentlyTesting {
                return false
            }
        }

        if itemSelector == #selector(IFProjectController.compile(_:)) ||
            itemSelector == #selector(IFProjectController.release(_:)) ||
            itemSelector == #selector(IFProjectController.releaseForTesting(_:)) ||
            itemSelector == #selector(IFProjectController.compileAndRun(_:)) ||
            itemSelector == #selector(IFProjectController.compileAndDebug(_:)) ||
            itemSelector == #selector(IFProjectController.replayUsingSkein(_:)) ||
            itemSelector == #selector(IFProjectController.compileAndRefresh(_:)) {

            // If we are in an Extension Project, and there are no test cases to run, disable Go! (etc) menu items.
            if selectedNoTestCase {
                return false
            }
            return !state.isCompilerRunning
        }

        // Format options
        if itemSelector == #selector(IFProjectController.shiftLeft(_:)) ||
            itemSelector == #selector(IFProjectController.shiftRight(_:)) ||
            itemSelector == #selector(IFProjectController.renumberSections(_:)) {
            // First responder must be an NSTextView object
            if !state.isTextViewFirstResponder {
                return false
            }
        }

        if itemSelector == #selector(IFProjectController.commentOutSelection(_:))
            || itemSelector == #selector(IFProjectController.uncommentSelection(_:)) {
            // Must be an Inform 7 project (not supporting this for I6 unless someone asks or implements themselves :-)
            if !state.isUsingNaturalInform {
                return false
            }

            // First responder must be a NSTextView object
            if !state.isTextViewFirstResponder {
                return false
            }

            // There must be a non-zero length selection
            if state.firstResponderSelectionLength == 0 {
                return false
            }
        }

        if itemSelector == #selector(IFProjectController.renumberSections(_:)) {
            // First responder must be an NSTextView object containing a NSTextStorage with some intel data
            if !state.isTextViewFirstResponder {
                return false
            }

            if !state.firstResponderHasIntelligence {
                return false
            }
        }

        // Tabbing options
        if itemSelector == #selector(IFProjectController.tabSource(_:))
            || itemSelector == #selector(IFProjectController.tabErrors(_:))
            || itemSelector == #selector(IFProjectController.tabIndex(_:))
            || itemSelector == #selector(IFProjectController.tabSkein(_:))
            || itemSelector == #selector(IFProjectController.tabGame(_:))
            || itemSelector == #selector(IFProjectController.tabDocumentation(_:))
            || itemSelector == #selector(IFProjectController.tabExtensions(_:))
            || itemSelector == #selector(IFProjectController.tabSettings(_:))
            || itemSelector == #selector(IFProjectController.switchPanes(_:)) {
            return state.hasCurrentTabView
        }

        if itemSelector == #selector(IFProjectController.showIndexTab(_:)) {
            return state.canSelectIndexTab(Int32(truncatingIfNeeded: tag))
        }

        // Heading options
        if itemSelector == #selector(IFProjectController.showNextSection(_:))
            || itemSelector == #selector(IFProjectController.showPreviousSection(_:))
            || itemSelector == #selector(IFProjectController.showCurrentSectionOnly(_:))
            || itemSelector == #selector(IFProjectController.showEntireSource(_:))
            || itemSelector == #selector(IFProjectController.showFewerHeadings(_:))
            || itemSelector == #selector(IFProjectController.showMoreHeadings(_:)) {
            // For any of these to work, the source page must be visible
            if !state.isTextViewFirstResponder {
                return false
            }

            if !state.isSourcePaneCurrent {
                return false
            }
        }

        if itemSelector == #selector(IFProjectController.exportIFiction(_:)) {
            return state.isUsingNaturalInform
        }

        if itemSelector == #selector(IFProjectController.exportExtension(_:)) {
            return state.isExtensionProject
        }

        // What's imported is added to the skein shown
        if itemSelector == #selector(IFProjectController.importIntoSkein(_:)) {
            return state.hasCurrentSkein
        }

        return true
    }
}
