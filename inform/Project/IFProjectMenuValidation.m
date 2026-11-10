//
//  IFProjectMenuValidation.m
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//

#import "IFProjectMenuValidation.h"
#import "IFProjectController.h"

@implementation IFProjectMenuValidation

+ (BOOL) isEnabledAction: (SEL) itemSelector
                     tag: (NSInteger) tag
                 inState: (id<IFProjectMenuState>) state {
    BOOL isRunning = state.isRunningGame;

    if (itemSelector == @selector(stopProcess:)) {
        return isRunning;
    }

    BOOL selectedNoTestCase = state.isExtensionProject && ((state.numberOfToolbarTestCases == 0) ||
                                                           (state.toolbarTestCase == nil));
    BOOL selectedTestAllCase = state.isExtensionProject && state.isTestAllCasesSelected;
    BOOL currentlyTesting = state.currentlyTesting;

    if (itemSelector == @selector(testMe:)) {
        // If we are in an Extension Project, and there are no test cases to run, disable Test Me. With Test All
        // chosen, it runs them all.
        BOOL noTestCases = state.isExtensionProject && (state.numberOfToolbarTestCases == 0);
        if( noTestCases || currentlyTesting) {
            return NO;
        }
    }

    if (itemSelector == @selector(replayEntireSkein:) ||
        itemSelector == @selector(replayUsingSkein:)) {

        // If we are in an Extension Project, and there are no test cases to run, disable Go! (etc) menu items.
        if( selectedNoTestCase || selectedTestAllCase || currentlyTesting) {
            return NO;
        }
    }

    if (itemSelector == @selector(compile:) ||
        itemSelector == @selector(release:) ||
        itemSelector == @selector(releaseForTesting:) ||
        itemSelector == @selector(compileAndRun:) ||
        itemSelector == @selector(compileAndDebug:) ||
        itemSelector == @selector(replayUsingSkein:) ||
        itemSelector == @selector(compileAndRefresh:)) {

        // If we are in an Extension Project, and there are no test cases to run, disable Go! (etc) menu items.
        if( selectedNoTestCase ) {
            return NO;
        }
        return !state.isCompilerRunning;
    }

    // Format options
    if (itemSelector == @selector(shiftLeft:) ||
        itemSelector == @selector(shiftRight:) ||
        itemSelector == @selector(renumberSections:)) {
        // First responder must be an NSTextView object
        if (!state.isTextViewFirstResponder)
            return NO;
    }

    if (itemSelector == @selector(commentOutSelection:)
        || itemSelector == @selector(uncommentSelection:)) {
        // Must be an Inform 7 project (not supporting this for I6 unless someone asks or implements themselves :-)
        if (!state.isUsingNaturalInform)
            return NO;

        // First responder must be a NSTextView object
        if (!state.isTextViewFirstResponder)
            return NO;

        // There must be a non-zero length selection
        if (state.firstResponderSelectionLength == 0)
            return 0;
    }

    if (itemSelector == @selector(renumberSections:)) {
        // First responder must be an NSTextView object containing a NSTextStorage with some intel data
        if (!state.isTextViewFirstResponder)
            return NO;

        if (!state.firstResponderHasIntelligence) return NO;
    }

    // Tabbing options
    if (itemSelector == @selector(tabSource:)
        || itemSelector == @selector(tabErrors:)
        || itemSelector == @selector(tabIndex:)
        || itemSelector == @selector(tabSkein:)
        || itemSelector == @selector(tabGame:)
        || itemSelector == @selector(tabDocumentation:)
        || itemSelector == @selector(tabExtensions:)
        || itemSelector == @selector(tabSettings:)
        || itemSelector == @selector(switchPanes:)) {
        return state.hasCurrentTabView;
    }

    if (itemSelector == @selector(showIndexTab:)) {
        return [state canSelectIndexTab: (int) tag];
    }

    // Heading options
    if (itemSelector == @selector(showNextSection:)
        || itemSelector == @selector(showPreviousSection:)
        || itemSelector == @selector(showCurrentSectionOnly:)
        || itemSelector == @selector(showEntireSource:)
        || itemSelector == @selector(showFewerHeadings:)
        || itemSelector == @selector(showMoreHeadings:)) {
        // For any of these to work, the source page must be visible
        if (!state.isTextViewFirstResponder)
            return NO;

        if (!state.isSourcePaneCurrent)
            return NO;
    }

    if (itemSelector == @selector(exportIFiction:)) {
        return state.isUsingNaturalInform;
    }

    if (itemSelector == @selector(exportExtension:)) {
        return state.isExtensionProject;
    }

    return YES;
}

@end
