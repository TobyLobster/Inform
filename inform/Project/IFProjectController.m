//
//  IFProjectController.m
//  Inform
//
//  Created by Andrew Hunter on Wed Aug 27 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "IFProject.h"
#import "IFAppDelegate.h"
#import "IFProjectController.h"
#import "IFProjectPane.h"
#import "IFProjectTypes.h"
#import "IFWelcomeWindow.h"
#import "IFInform7MutableString.h"
#import "IFFindInFilesController.h"
#import "IFSyntaxManager.h"
#import "IFSingleController.h"
#import "IFToolbarManager.h"
#import "IFSkein.h"
#import "IFSkeinItem.h"
#import "IFSkeinPlayAll.h"
#import "IFSourceHighlights.h"
#import "IFRuntimeProblemPage.h"
#import "IFExtensionFileFinder.h"
#import "IFInBuild.h"


#import "IFSourcePage.h"
#import "IFErrorsPage.h"
#import "IFIndexPage.h"
#import "IFSkeinPage.h"
#import "IFGamePage.h"
#import "IFDocumentationPage.h"
#import "IFExtensionsPage.h"
#import "IFSettingsPage.h"

#import "IFPreferences.h"
#import "IFSingleFile.h"
#import "IFNaturalIntel.h"

#import "IFHeaderController.h"

#import "IFExtensionsManager.h"
#import "IFNewExtensionsManager.h"

#import "IFCompilerController.h"
#import "IFCompilerSettings.h"
#import "IFCompileCheck.h"
#import "IFProjectMenuValidation.h"
#import "IFPaneChoice.h"
#import "IFPaneWidths.h"
#import "IFTestCaseRun.h"

#import "IFUtility.h"
#import <ZoomView/ZoomView.h>
#import "Inform-Swift.h"

// Preferences
static NSString* const    IFSplitViewSizes    = @"IFSplitViewSizes";

// *******************************************************************************************
@interface IFProjectController() <IFProjectMenuState>

- (void) refreshIndexTabs;
- (void) runCompilerOutput;
- (void) runCompilerOutputAndReplay;

@property (atomic, readonly, strong) IFGamePage *gamePage;

@end

// *******************************************************************************************
@implementation IFProjectController {
    // Panes
    IBOutlet NSView*        panesView;
    /// Collection of panes
    NSMutableArray*         projectPanes;
    /// Collection of pane split views
    NSMutableArray*         splitViews;

    // Toolbar
    IFToolbarManager*       toolbarManager;

    // The Contents (headings) controller
    IFHeaderController*     headerController;

    // The current tab view (used for the various tab selection menu items)
    /// The active tab view
    NSTabView*              currentTabView;
    /// The active project pane
    IFProjectPane*          currentPane;

    // Source highlighting
    IFSourceHighlights*     highlights;

    // Compiling
    /// Action after a compile has finished
    SEL                     compileFinishedAction;
    BOOL                    isCompiling;
    /// Decides whether the project needs compiling before its story is used
    IFCompileCheck*         compileCheck;

    // The last file selected
    NSString*               lastFilename;

    /// Used when running the entire skein
    IFSkeinPlayAll*         playAll;

    // Glk automation
    id<ZoomViewInputSource> glkInputSource;

    BOOL                    betweenWindowLoadedAndBecomingMain;
    /// Test's run through the test cases
    IFTestCaseRun*          testCaseRun;

    /// Actions that can be shared between project and single controllers
    IFSourceSharedActions*  sharedActions;

    IFProgress*             testAllProgress;

    NSURL*                  extensionURL;
    NSString*               inbuildAction;
}

+ (void) initialize {
    // Register our preferences
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults: @{IFSplitViewSizes: @[@0.5, @0.5]}];
}

// == Initialistion ==

- (instancetype) init {
    self = [super initWithWindowNibName:@"Project"];

    if (self) {
        projectPanes     = [[NSMutableArray alloc] init];
        splitViews       = [[NSMutableArray alloc] init];
        highlights       = [[IFSourceHighlights alloc] init];

        [self setShouldCloseDocument: NO];

        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(intelFileChanged:)
                                                     name: IFIntelFileHasChangedNotification
                                                   object: nil];

        // Update ourselves when the compiler settings change
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(updateSettings)
                                                     name: IFSettingNotification
                                                   object: nil];

        headerController = [[IFHeaderController alloc] init];
        betweenWindowLoadedAndBecomingMain = NO;
        compileCheck = [[IFCompileCheck alloc] init];

        sharedActions = [[IFSourceSharedActions alloc] init];
        toolbarManager = [[IFToolbarManager alloc] initWithProjectController: self];

        testCaseRun = [[IFTestCaseRun alloc] init];

        testAllProgress = nil;
        extensionURL = nil;
        inbuildAction = @"";
    }

    return self;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void) updateSettings {
    // Mark document as edited. This ensures a recompile happens on the next 'Go!', for example.
    [self.document updateChangeCount: NSChangeDone];
}

- (BOOL) safeToSwitchTabs {
    return !betweenWindowLoadedAndBecomingMain;
}

- (void) windowDidLoad {
    self.windowFrameAutosaveName = @"ProjectWindow";
    [self.window setFrameAutosaveName: @"ProjectWindow"];

    // Once a project has loaded, remove the launcher window
    [IFWelcomeWindow hideWelcomeWindow];

    // We have loaded the window, but we are not yet main
    betweenWindowLoadedAndBecomingMain = YES;
}

- (void)windowDidBecomeMain:(NSNotification *)notification {
    betweenWindowLoadedAndBecomingMain = NO;

    [toolbarManager redrawToolbar];

    // The window accepts mouse move events
    [self.window setAcceptsMouseMovedEvents:YES];
}

- (void) windowWillClose: (NSNotification*) not {
    // Perform shutdown
    [[self runningGamePage] stopRunningGame];

    for( IFProjectPane* pane in projectPanes ) {
        [pane willClose];
    }

    projectPanes = nil;
    splitViews = nil;

    [panesView removeFromSuperview];
    panesView = nil;
}

-(void) refreshTestCases {
    // Run the InTest process to gather the latest array of test cases
    [self.document refreshTestCases];

    // Update the toolbar to reflect the changes
    [toolbarManager setTestCases: [self.document testCases]];
}

-(BOOL) isExtensionProject {
    return [self.document isExtensionProject];
}

-(BOOL) isCurrentlyTesting {
    return [self isExtensionProject] && testAllProgress && testAllProgress.inProgress;
}

- (void) awakeFromNib {
    // Setup the default panes
    [projectPanes removeAllObjects];
    [projectPanes addObject: [IFProjectPane standardPane]];
    [projectPanes addObject: [IFProjectPane standardPane]];

    [self layoutPanes];

    // Initial panes are source and documentation
    [projectPanes[0] selectViewOfType: IFSourcePane];
    [projectPanes[1] selectViewOfType: IFDocumentationPane];

    [[projectPanes[0] sourcePage] setSpellChecking: ((IFAppDelegate*)NSApp.delegate).sourceSpellChecking];
    [[projectPanes[1] sourcePage] setSpellChecking: ((IFAppDelegate*)NSApp.delegate).sourceSpellChecking];

    // Monitor for compiler finished notifications
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(compilerFinished:)
                                                 name: IFCompilerFinishedNotification
                                               object: [self.document compiler]];

    // Fullscreen mode
    self.window.collectionBehavior = self.window.collectionBehavior | NSWindowCollectionBehaviorFullScreenPrimary;

    // Create the toolbar view
    [toolbarManager setToolbar];

    // Update the toolbar to reflect the test cases
    [toolbarManager setTestCases: [self.document testCases]];
}

// == Project pane layout ==

- (void) layoutPanes {
    if (projectPanes.count == 0) {
        return;
    }

    // Remove any previous panes
    [projectPanes makeObjectsPerformSelector: @selector(removeFromSuperview)];
    [splitViews makeObjectsPerformSelector: @selector(removeFromSuperview)];
    [splitViews removeAllObjects];

    // Remove panesView itself from window
    [panesView.subviews makeObjectsPerformSelector: @selector(removeFromSuperview)];

    if (projectPanes.count == 1) {
        // Just one pane
        IFProjectPane* firstPane = projectPanes[0];

        [firstPane setController: self viewIndex: 1];
        
        firstPane.paneView.frame = panesView.bounds;
        [panesView addSubview: firstPane.paneView];
    } else {
        // Create the splitViews
        NSInteger view, nviews;
        CGFloat dividerWidth = 5;

        nviews = projectPanes.count;
        for (view=0; view<nviews-1; view++) {
            NSSplitView* newView = [[ThinSplitView alloc] init];

            [newView setVertical: YES];
            newView.delegate = self;
            newView.autoresizingMask = (NSViewWidthSizable|NSViewHeightSizable);

            dividerWidth = newView.dividerThickness;

            [splitViews addObject: newView];
        }

        // Work out the widths of the panes using the preferences
        NSArray* dividerProportions = [[NSUserDefaults standardUserDefaults] arrayForKey: IFSplitViewSizes];
        NSArray<NSNumber*>* paneWidths = [IFPaneWidths widthsOfPanes: nviews
                                                             inWidth: panesView.bounds.size.width
                                                        dividerWidth: dividerWidth
                                                         proportions: dividerProportions];

        // Size and add the views appropriately
        CGFloat totalRemaining   = panesView.bounds.size.width;
        CGFloat viewWidth        = 0;

        // Insert the views
        NSSplitView* lastView = nil;
        for (view=0; view<nviews-1; view++) {
            // Garner some information about the views we're dealing with
            NSSplitView*   thisView = splitViews[view];
            IFProjectPane* pane     = projectPanes[view];
            NSView*        thisPane = [projectPanes[view] paneView];

            [pane setController: self viewIndex: view];

            viewWidth = (paneWidths[view]).doubleValue;

            // Resize the splitview
            NSRect splitFrame;
            if (lastView != nil) {
                splitFrame = lastView.bounds;
                splitFrame.origin.x += viewWidth + dividerWidth;
                splitFrame.size.width = totalRemaining;
            } else {
                splitFrame = panesView.bounds;
            }
            thisView.frame = splitFrame;

            // Add it as a subview
            if (lastView != nil) {
                [lastView addSubview: thisView];
            } else {
                [panesView addSubview: thisView];
            }

            // Add the leftmost view
            NSRect paneFrame = thisView.bounds;
            paneFrame.size.width = viewWidth;

            thisPane.frame = paneFrame;
            [thisView addSubview: thisPane];
            thisView.delegate = self;

            lastView = thisView;

            // Update the amount of space remaining
            totalRemaining -= viewWidth + dividerWidth;
        }

        // Final view
        NSView* finalPane = [projectPanes.lastObject paneView];
        NSRect finalFrame = lastView.bounds;

        [projectPanes.lastObject setController: self viewIndex: nviews-1];

        finalFrame.origin.x += viewWidth + dividerWidth;
        finalFrame.size.width = totalRemaining;
        finalPane.frame = finalFrame;
        
        [lastView addSubview: finalPane];
        [lastView adjustSubviews];
    }
}

- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification {
    // Update the preferences with the view widths
    int nviews = (int) projectPanes.count;
    int view;

    NSMutableArray<NSNumber*>* paneWidths = [NSMutableArray array];

    CGFloat totalWidth = self.window.frame.size.width;

    for (view=0; view<nviews; view++) {
        IFProjectPane* pane = projectPanes[view];
        NSRect paneFrame = pane.paneView.frame;

        [paneWidths addObject: @(paneFrame.size.width)];
    }

    NSArray<NSNumber*>* viewSizes = [IFPaneWidths proportionsOfWidths: paneWidths
                                                        inWindowWidth: totalWidth];
    [[NSUserDefaults standardUserDefaults] setObject: viewSizes
                                              forKey: IFSplitViewSizes];
}


// == Toolbar item validation ==

- (void) changeFirstResponder: (NSResponder*) first {
    if ([first isKindOfClass: [NSView class]]) {
        NSView* firstView = (NSView*)first;
        IFProjectPane* pane = nil;

        while (firstView != nil) {
            if ([firstView isKindOfClass: [NSTabView class]]) {
                // See if this is the tab view for a specific pane
                BOOL found = NO;
                for( IFProjectPane* possiblePane in projectPanes ) {
                    if (possiblePane.tabView == firstView) {
                        pane = possiblePane;
                        found = YES;
                        break;
                    }
                }

                // Keep this view, if it's a suitable candidate
                if (found) break;
                pane = nil;
            }

            // Continue up the tree
            firstView = firstView.superview;
        }

        [currentPane setIsActive: NO];
        [pane setIsActive: YES];

        currentPane = pane;
        currentTabView = (NSTabView*)firstView;
    }
}

- (NSTabView*) currentTabView {
    return currentTabView;
}

- (BOOL)validateMenuItem:(NSMenuItem*) menuItem {
    return [IFProjectMenuValidation isEnabledAction: menuItem.action
                                                tag: menuItem.tag
                                            inState: self];
}

#pragma mark - What the menu's commands depend on

- (NSUInteger) numberOfToolbarTestCases {
    return toolbarManager.testCases.count;
}

- (NSString*) toolbarTestCase {
    return toolbarManager.currentTestCase;
}

- (BOOL) isCompilerRunning {
    return [self.document compiler].running;
}

- (BOOL) isUsingNaturalInform {
    return [self.document settings].usingNaturalInform;
}

- (BOOL) isTextViewFirstResponder {
    return [self.window.firstResponder isKindOfClass: [NSTextView class]];
}

- (NSUInteger) firstResponderSelectionLength {
    return [(NSTextView*)self.window.firstResponder selectedRange].length;
}

- (BOOL) firstResponderHasIntelligence {
    NSTextStorage* storage = [IFSyntaxManager registeredStorageForTextView: (NSTextView*)self.window.firstResponder];

    return !(storage == nil || [IFSyntaxManager intelligenceDataForStorage: storage] == nil);
}

- (BOOL) hasCurrentTabView {
    return [self currentTabView] != nil;
}

- (BOOL) isSourcePaneCurrent {
    return currentPane.currentView == IFSourcePane;
}

- (BOOL) canSelectIndexTab: (int) tab {
    return [[projectPanes[0] indexPage] canSelectIndexTab: tab];
}

-(int) getNumberOfTestCases {
    if ([self isExtensionProject]) {
        return toolbarManager.numberOfTestCases;
    }
    return 0;
}

-(NSString*) currentTestCase {
    if ([self isExtensionProject]) {
        // If we are doing "Test All", get the current test case based on index
        if (testCaseRun.currentIndex >= 0) {
            return [toolbarManager getTestCase: testCaseRun.currentIndex];
        }

        // Get the currently selected test case from the toolbar
        return toolbarManager.currentTestCase;
    }
    return nil;
}

- (void) performCompileWithRelease: (BOOL) release
                        forTesting: (BOOL) releaseForTesting
                       refreshOnly: (BOOL) onlyRefresh
                          testCase: (NSString*) testCase {
    IFProject* doc = self.document;

    // Remove temporary highlighting
    [self removeHighlightsOfStyle: IFLineStyleError];

    // Save the project, without user interaction. Also refreshes available test cases
    [self saveDocument: self];

    // Extract current test case as a story
    [doc extractSourceTaskForExtensionTestCase: [self currentTestCase]];

    // Stop the current game
    [projectPanes makeObjectsPerformSelector: @selector(stopRunningGame)];

    // Update toolbar
    [toolbarManager validateVisibleItems];

    // Set up the compiler
    IFCompiler* theCompiler = [doc prepareCompilerForRelease: release
                                                  forTesting: releaseForTesting
                                                 refreshOnly: onlyRefresh
                                                    testCase: testCase];
    if (theCompiler != nil)
    {
        // Start progress indicator
        [self addProgressIndicator: theCompiler.progress];
        [theCompiler.progress startProgress];

        // Clear the console only on the first compilation of this run
        if (!testCaseRun.isOnALaterTestCase) {
            [theCompiler clearConsole];
        }

        [compileCheck compileDidStartForRelease: release];
        [theCompiler launch];
        isCompiling = YES;
    }
    else
    {
        NSString* version = doc.settings.compilerVersion;
        NSString* message = [NSString stringWithFormat: [IFUtility localizedString: @"One possibility is that the project's language version '%@' is not available. Try setting the language version in Settings."], version];
        [IFUtility runAlertWindow: self.window
                        localized: YES
                          warning: YES
                            title: [IFUtility localizedString: @"Could not launch compiler."]
                          message: @"%@", message];
    }

    // Show the Console pane if required
    if( ![self isTestAllCasesSelected] ) {
        if ( [IFPreferences sharedPreferences].showConsoleDuringBuilds ) {
            [projectPanes[1] selectViewOfType: IFErrorPane];
        }
    }
}

- (void) showPublicLibrary {
    [[self currentTabView] selectTabViewItemWithIdentifier: [[IFExtensionsPage class] description]];
    if( [projectPanes[1] currentView] == IFExtensionsPane ) {
        [(IFExtensionsPage *)[projectPanes[1] extensionsPage] showPublicLibrary:nil ];
    }
}

// == View selection functions ==

- (IBAction)saveDocument:(id)sender {
    // Need to call prepareToSave here to give the project panes a chance to shut down any editing operations that might be ongoing
    for( IFProjectPane* pane in projectPanes ) {
        [pane prepareToSave];
    }

    // Save the project, without user interaction.
    [self.document saveDocumentWithoutUserInteraction];

    // Refresh the available test cases
    [self refreshTestCases];
}

/*
 - (IBAction)saveDocumentAs:(id)sender {
 // Need to call prepareToSave here to give the project panes a chance to shut down any editing operations that might be ongoing
 for( IFProjectPane* pane in projectPanes ) {
 [pane prepareToSave];
 }

 // Save the project, without user interaction.
 [[self document] saveDocumentWithoutUserInteraction];

 // Refresh the available test cases
 [self refreshTestCases];
 }
 */

- (void) makeWithRelease: (BOOL) release
              forTesting: (BOOL) releaseForTesting
             refreshOnly: (BOOL) onlyRefresh
            forceCompile: (BOOL) forceCompile
               onSuccess: (SEL) onSuccess {
    BOOL needsToCompile = [compileCheck needsCompileForcing: forceCompile
                                              alwaysCompile: [IFPreferences sharedPreferences].alwaysCompile
                                             unsavedChanges: [self.document hasUnautosavedChanges]
                                                  sourceURL: [self.document mainSourceFileURL]
                                                settingsURL: [self.document settingsFileURL]
                                                  outputURL: [self.document buildOutputFileURL]];

    if( needsToCompile ) {
        compileFinishedAction = onSuccess;

        [self performCompileWithRelease: release
                             forTesting: releaseForTesting
                            refreshOnly: onlyRefresh
                               testCase: [self currentTestCase]];
    } else {
        [self showMessage: [IFUtility localizedString: @"No compilation required."]];

        [IFUtility performSelector: onSuccess object: self];
    }
}

- (IBAction) release: (id) sender {
    [self makeWithRelease: YES
               forTesting: NO
              refreshOnly: NO
             forceCompile: YES
                onSuccess: @selector(saveCompilerOutput)];
}

- (IBAction) releaseForTesting: (id) sender {
    [self makeWithRelease: YES
               forTesting: YES
              refreshOnly: NO
             forceCompile: YES
                onSuccess: @selector(saveCompilerOutput)];
}

- (IBAction) compile: (id) sender {
    [self makeWithRelease: NO
               forTesting: NO
              refreshOnly: NO
             forceCompile: YES
                onSuccess: @selector(saveCompilerOutput)];
}

- (IBAction) compileAndRefresh: (id) sender {
    [self makeWithRelease: NO
               forTesting: NO
              refreshOnly: YES
             forceCompile: YES
                onSuccess: @selector(refreshIndexTabs)];
}

- (IBAction) compileAndRun: (id) sender {
    if( !isCompiling ) {
        [self.gamePage setSwitchToPage: YES];
        [self.gamePage setTestCommands: nil];

        [self makeWithRelease: NO
                   forTesting: NO
                  refreshOnly: NO
                 forceCompile: NO
                    onSuccess: @selector(runCompilerOutput)];
    }
}

-(BOOL) isTestAllCasesSelected {
    if( [self isExtensionProject] ) {
        return (toolbarManager.currentTestCase == nil);
    }
    return NO;
}

- (IBAction) testMe: (id) sender {
    if( [self isExtensionProject] ) {
        if( [self isTestAllCasesSelected] ) {
            // Run all test cases
            [testCaseRun chooseTestCasesFrom: 0
                                          to: [self getNumberOfTestCases] - 1];
        }
        else {
            // Run a specific test only
            int testCaseIndex = toolbarManager.testCaseIndex;
            [testCaseRun chooseTestCasesFrom: testCaseIndex
                                          to: testCaseIndex];
        }

        // Compile and run each test case in turn
        if( testCaseRun.currentIndex == -1 ) {
            // Create new progress
            testAllProgress = [[IFProgress alloc] initWithPriority: IFProgressPriorityTestAll
                                                  showsProgressBar: YES
                                                         canCancel: YES];
            [self addProgressIndicator: testAllProgress];
            [testAllProgress startProgress];

            // If the left side is the skein, show the source instead.
            if( [projectPanes[0] currentView] == IFSkeinPane ) {
                [projectPanes[0] selectViewOfType: IFSourcePane];
            }

            // Show the skein page on the right
            [projectPanes[1] selectViewOfType: IFSkeinPane];

            [self startNextTestCase];

            // Update toolbar
            [toolbarManager validateVisibleItems];
            return;
        }
        return;
    } else {
        // Show the game page on the right
        [self.gamePage setSwitchToPage: YES];
    }

    // Test current case
    [self testMeInternal];
}

- (void) testMeInternal {
    if( [self isExtensionProject] ) {
        if (testCaseRun.currentIndex >= 0) {
            [self.document selectSkein: testCaseRun.currentIndex];
        }
    }

    [self makeWithRelease: NO
               forTesting: NO
              refreshOnly: NO
             forceCompile: YES
                onSuccess: @selector(runCompilerOutputAndTest)];
}

- (IBAction) replayUsingSkein: (id) sender {
    [self makeWithRelease: NO
               forTesting: NO
              refreshOnly: NO
             forceCompile: NO
                onSuccess: @selector(runCompilerOutputAndReplay)];
}

- (IBAction) replayEntireSkein: (id) sender {
    if( ![self isTestAllCasesSelected] ) {
        // Always recompile
        [self makeWithRelease: NO
                   forTesting: NO
                  refreshOnly: NO
                 forceCompile: NO
                    onSuccess: @selector(runCompilerOutputAndEntireSkein)];
    }
}

- (IBAction) compileAndDebug: (id) sender {
    [self.gamePage setSwitchToPage: YES];
    [self.gamePage setTestCommands: nil];

    [self makeWithRelease: NO
               forTesting: NO
              refreshOnly: NO
             forceCompile: NO
                onSuccess: @selector(debugCompilerOutput)];
}

- (IBAction) stopProcess: (id) sender {
    [projectPanes makeObjectsPerformSelector: @selector(stopRunningGame)];
}

- (IBAction) openMaterials: (id) sender {
    [self.document openMaterials];
}

- (IBAction) exportIFiction: (id) sender {
    // Compile and export the iFiction metadata
    [self makeWithRelease: NO
               forTesting: NO
              refreshOnly: NO
             forceCompile: NO
                onSuccess: @selector(saveIFiction)];
}

- (void) saveIFiction {
    // IFiction compilation has finished
    [self.document saveIFictionWithWindow: self.window];
}

#pragma mark - Displaying a specific index tab

- (IBAction) showIndexTab: (id) sender {
    int tag = (int) [sender tag];

    for( IFProjectPane* pane in projectPanes ) {
        [pane.indexPage switchToTab: tag];
    }

    [self.indexPane selectViewOfType: IFIndexPane];
}

#pragma mark - Things to do after the compiler has finished

- (void) refreshIndexTabs {
    // Display the index pane
    [self.indexPane selectViewOfType: IFIndexPane];
}

- (void) saveCompilerOutput {
    // Check to see if one of the compile controllers has already got a save location for the game
    IFCompilerController* paneController = [projectPanes[0] compilerController];
    NSString*               copyLocation = paneController.blorbLocation;

    // Show the 'success' pane
    [projectPanes[1] selectViewOfType: IFErrorPane];

    if (copyLocation != nil) {
        NSError* error;

        // Copy the result to the specified location (overwriting any existing file)
        [[NSFileManager defaultManager] removeItemAtPath: copyLocation
                                                   error: &error];
        [[NSFileManager defaultManager] copyItemAtPath: [self.document compiler].outputFile
                                                toPath: copyLocation
                                                 error: &error];
    } else {
        [self.document saveCompilerOutputWithWindow: self.window];
    }
}

- (void) runCompilerOutputAndTest {
    // Set test commands
    if( [self isExtensionProject] ) {
        NSArray* testCommands = [self.document testCommandsForExtensionTestCase: [self currentTestCase]];
        [self.gamePage setTestCommands: testCommands];
    }
    else {
        [self.gamePage setTestCommands: @[@"test me"]];
    }

    [self runCompilerOutput];
}


- (void) runCompilerOutput {
    [self.gamePage startRunningGame: [self.document buildOutputFileURL].path];

    [toolbarManager validateVisibleItems];
}

- (void) runCompilerOutputAndReplay {
    playAll = nil;

    [self.gamePage setSwitchToPage: YES];
    // The skein's previous commands are most recent first
    [self.gamePage setTestCommands: [[self.document currentSkein].previousCommands reverseObjectEnumerator].allObjects];
    [self runCompilerOutput];
}

- (void) debugCompilerOutput {
    [self.gamePage activateDebug];
    [self.gamePage startRunningGame: [self.document compiler].outputFile];

    [toolbarManager validateVisibleItems];
}

- (void) createAndShowReport:(int) numTests reportURL:(NSURL*) reportURL {
    if( numTests > 1 ) {
        [self.document generateCombinedReportForBaseInputURL: [self.document baseReportURL]
                                                      numTests: numTests
                                                     outputURL: [self.document combinedReportURL]];
    }
    else {
        // Copy from reportURL to [[self document] combinedReportURL];
        NSFileManager *fm = [NSFileManager defaultManager];
        NSError* err;
        if( [fm removeItemAtURL:[self.document combinedReportURL] error: &err] ) {
            if (![fm copyItemAtURL:reportURL
                             toURL:[self.document combinedReportURL]
                             error: &err] )
            {
                NSLog(@"Error copying file %@",err.localizedDescription);
            }
        }
        else {
            NSLog(@"Error removing file %@",err.localizedDescription);
        }
    }

    [self updateBuildResults];
    [projectPanes[1] selectViewOfType: IFErrorPane];
}

-(void) updateBuildResults {
    NSURL* buildURL = [self.document buildDirectoryURL];
    NSError* error;
    NSFileWrapper* buildDir = [[NSFileWrapper alloc] initWithURL: buildURL
                                                         options: NSFileWrapperReadingImmediate
                                                           error: &error];

    for (int x=0; x<projectPanes.count; x++) {
        IFProjectPane* pane = projectPanes[x];

        [pane.compilerController clearTabViewsExcept: IFTabConsole];
        [pane.compilerController showContentsOfFilesIn: buildDir
                                                fromPath: buildURL.path];
    }
}

- (void) compilerFinished: (NSNotification*) not {
    int exitCode = [not.userInfo[@"exitCode"] intValue];
    ECompilerProblemType problemType = [not.userInfo[@"problemType"] intValue];
    NSString* intestCode = nil;

    // Convert our problem type into an intest error code
    switch( problemType ) {
        case EProblemTypeNone:
        {
            break;
        }
        case EProblemTypeInform6:
        {
            intestCode = @"i6";
            break;
        }
        case EProblemTypeInform7:
        {
            intestCode = @"i7";
            break;
        }
        case EProblemTypeCBlorb:
        {
            intestCode = @"i7";
            break;
        }
        case EProblemTypeUnknown:
        {
            intestCode = @"i7";
            break;
        }
    }

    [self removeProgressIndicator: [self.document compiler].progress];

    if (exitCode != 0 || [not.object problemsURL] != nil) {
        if( ![self isTestAllCasesSelected] ) {
            // Show the errors pane if there was an error while compiling
            [projectPanes[1] selectViewOfType: IFErrorPane];
        }
    }

    // Re-read the contents of the directory, now that the compiler has written a bunch of files there
    [self.document reloadDirectory];

    // Show the 'build results' files
    [self updateBuildResults];

    // Update the index tab(s)
    for (int x=0; x<projectPanes.count; x++) {
        IFProjectPane* pane = projectPanes[x];
        [pane.indexPage updateIndexView];
    }

    // Make a report if there was an error while compiling a test case
    NSURL* reportURL = nil;
    if( self.currentlyTesting ) {

        if( intestCode != nil ) {
            reportURL = [self.document currentReportURL];

            [self.document generateReportForTestCase: [self currentTestCase]
                                             errorCode: intestCode
                                           skeinNodeId: 0
                                            skeinNodes: 0
                                             outputURL: reportURL];
            [self.document reloadSourceDirectory];
        }
    }

    if (exitCode == 0) {
        [compileCheck compileDidSucceed];
        // Success!
        [IFUtility performSelector: compileFinishedAction object: self];
    }

    isCompiling = NO;
    compileFinishedAction = nil;
    [toolbarManager validateVisibleItems];

    // If not successful, start the next test case
    if ((exitCode != 0) && self.currentlyTesting) {
        if( [self startNextTestCaseSoon] ) {
            return;
        }

        // All test cases finished.

        // Create a consolidated report and display it.
        if( !testAllProgress.isCancelled && (reportURL != nil) ) {
            [self createAndShowReport: testCaseRun.numberTested reportURL: reportURL];
        }
    }
}

#pragma mark - Communication from the containing panes

/// What each of the panes is showing, as IFProjectPaneType numbers
- (NSArray<NSNumber*>*) paneViews {
    NSMutableArray<NSNumber*>* views = [NSMutableArray array];
    for (IFProjectPane* pane in projectPanes) {
        [views addObject: @(pane.currentView)];
    }
    return views;
}

- (IFProjectPane*) sourcePane {
    return projectPanes[[IFPaneChoice sourcePaneForViews: [self paneViews]]];
}

- (IFProjectPane*) auxPane {
    return projectPanes[[IFPaneChoice auxPaneForViews: [self paneViews]]];
}

- (IFProjectPane*) indexPane {
    return projectPanes[[IFPaneChoice indexPaneForViews: [self paneViews]]];
}

- (IFProjectPane*) oppositePane: (IFProjectPane*) pane {
    // Find this pane
    NSInteger index = [projectPanes indexOfObjectIdenticalTo: pane];
    if (index == NSNotFound) return nil;

    return projectPanes[[IFPaneChoice paneOppositePane: index count: projectPanes.count]];
}

-(void) loadInform7ExtensionWithFullFilePath:(NSString*) extnFile {
    // Find existing document
    NSDocument* newDoc = [[NSDocumentController sharedDocumentController] documentForURL: [NSURL fileURLWithPath: extnFile]];
    if (newDoc == nil) {
        // If it doesn't exist, then construct it
        NSError* error;
        newDoc = [[IFSingleFile alloc] initWithContentsOfURL: [NSURL fileURLWithPath: extnFile]
                                                      ofType: @"Inform 7 extension"
                                                       error: &error];

        [[NSDocumentController sharedDocumentController] addDocument: newDoc];
        [newDoc makeWindowControllers];
        [newDoc showWindows];
    } else {
        // Force it to the front
        for( NSWindowController* controller in newDoc.windowControllers ) {
            [controller.window makeKeyAndOrderFront: self];
        }
    }
}

- (BOOL) loadInform7Extension: (NSString*) filename {
    NSString* extnFile = [IFExtensionFileFinder fileForExtension: filename
                                               extensionsManager: [IFExtensionsManager sharedNaturalInformExtensionsManager]];
    if (extnFile == nil) return NO;

    // This is the extension file we need to open
    [self loadInform7ExtensionWithFullFilePath: extnFile];
    return YES;
}

- (BOOL) showTestCase: (NSString*) testCase skeinNode:(unsigned long) skeinNodeId {
    // Select this test case
    if( ![toolbarManager selectTestCase: testCase] ) {
        return NO;
    }

    // Switch panes to the testing pane
    [projectPanes[0] selectViewOfType: IFSkeinPane];

    // Select the problem node in the skein
    for(IFProjectPane* pane in projectPanes) {
        IFSkeinPage* skeinPage = pane.skeinPage;
        [skeinPage selectSkeinItemWithNodeId: skeinNodeId];
    }
    return YES;
}

- (BOOL) selectSourceFile: (NSString*) fileName {
    if ([self.document storageForFile: fileName] != nil) {
        // Load this file
        [self.sourcePage showSourceFile: fileName];
        //[projectPanes makeObjectsPerformSelector: @selector(showSourceFile:)
        //							  withObject: fileName];
    } else if (![self loadInform7Extension: fileName]) {
        // Display an error if we couldn't find the file
        [IFUtility runAlertWarningWindow: self.window
                                   title: @"Unable to open source file"
                                 message: @"Unable to open source file description"];
    }

    lastFilename = [fileName copy];

    return YES;
}

- (IFSourcePage*) sourcePage {
    return self.sourcePane.sourcePage;
}

- (NSString*) selectedSourceFile {
    return [self sourcePage].currentFile;
}

- (void) moveToSourceFileLine: (NSInteger) line {
    IFProjectPane* thePane = self.sourcePane;

    [thePane selectViewOfType: IFSourcePane];
    [thePane.sourcePage moveToLine: line];
    [self.window makeFirstResponder: thePane.activeView];
}

- (void) moveToSourceFilePosition: (NSInteger) location {
    IFProjectPane* thePane = self.sourcePane;

    [thePane selectViewOfType: IFSourcePane];
    [thePane.sourcePage moveToLocation: location];
    [self.window makeFirstResponder: thePane.activeView];
}

- (void) selectSourceFileRange: (NSRange) range {
    IFProjectPane* thePane = self.sourcePane;

    [thePane selectViewOfType: IFSourcePane];
    [thePane.sourcePage indicateRange: range];

    [self.window makeFirstResponder: thePane.activeView];
}

- (void) removeHighlightsInFile: (NSString*) file
                        ofStyle: (IFLineStyle) style {
    file = [self.document pathForSourceFile: file];

    BOOL updated = [highlights removeHighlightsOfStyle: style
                                                inFile: file];

    if (updated) {
        for( IFProjectPane* pane in projectPanes ) {
            if ([[self.document pathForSourceFile: pane.sourcePage.currentFile] isEqualToString: file]) {
                [pane.sourcePage updateHighlightedLines];
            }
        }
    }
}

- (void) removeHighlightsOfStyle: (IFLineStyle) style {
    // Remove highlights in all files
    for( NSString* file in highlights.files ) {
        [self removeHighlightsInFile: file
                             ofStyle: style];
    }
}

- (void) removeAllTemporaryHighlights {
    if (!highlights.hasTemporaryHighlights) return;

    int style;

    for (style = IFLineStyle_Temporary; style<IFLineStyle_LastTemporary; style++) {
        [self removeHighlightsOfStyle: style];
    }

    [highlights temporaryHighlightsWereRemoved];
}

- (void) highlightSourceFileLine: (NSInteger) line
                          inFile: (NSString*) file {
    [self highlightSourceFileLine: line
                           inFile: file
                            style: IFLineStyleNeutral];
}

- (void) highlightSourceFileLine: (NSInteger) line
                          inFile: (NSString*) file
                           style: (IFLineStyle) style {
    // Get the 'true' path to this file
    file = [self.document pathForSourceFile: file];

    // See if there's a document that manages this file
    NSDocument* fileDocument = [[NSDocumentController sharedDocumentController] documentForURL: [NSURL fileURLWithPath: file]];
    if (fileDocument && fileDocument != self.document && ![fileDocument isEqual: self.document]) {

        // Pass this message on to this document's controllers
        for( id	docController in fileDocument.windowControllers ) {
            // If this controller is capable of highlighting lines, tell it to do so
            if ([docController respondsToSelector: @selector(highlightSourceFileLine:inFile:style:)]) {
                [docController highlightSourceFileLine: line
                                                inFile: file
                                                 style: style];
            }
        }
        return;
    }

    [highlights highlightLine: line
                       inFile: file
                        style: style];

    // Display the highlight
    for( IFProjectPane* pane in projectPanes ) {
        if ([[self.document pathForSourceFile: pane.sourcePage.currentFile] isEqualToString: file]) {
            [pane.sourcePage updateHighlightedLines];

            if (highlights.hasTemporaryHighlights) {
                [pane.sourcePage indicateLine: (int) line];
            }
        }
    }
}

- (NSArray*) highlightsForFile: (NSString*) file {
    file = [self.document pathForSourceFile: file];

    return [highlights highlightsInFile: file];
}

#pragma mark - Debugging controls

- (IFProjectPane*) runningGamePane {
    // Return the pane that we're displaying/going to display the game in
    for( IFProjectPane* pane in projectPanes ) {
        if (pane.gamePage.isRunningGame) return pane;
    }

    return nil;
}

- (IFGamePage*) runningGamePage {
    return self.runningGamePane.gamePage;
}

- (IFGamePage*) gamePage {
    return [projectPanes[1] gamePage];
}

- (void) restartRunning {
    // Perform actions to switch back to the game when we click on continue, etc
    [self.window makeFirstResponder: [self runningGamePage].zoomView];

    [toolbarManager validateVisibleItems];
}

- (void) pauseProcess: (id) sender {
    [[self runningGamePage] pauseRunningGame];
}

- (IFIntelFile*) currentIntelligence {
    return [self sourcePage].currentIntelligence;
}

#pragma mark - Documentation controls

- (void) docIndex: (id) sender {
    [self.auxPane.documentationPage openURL: [NSURL URLWithString: @"inform:/index.html"]];
}

- (void) docRecipes: (id) sender {
    [self.auxPane.documentationPage openURL: [NSURL URLWithString: @"inform:/Rdoc1.html"]];
}

- (void) docExtensions: (id) sender {
    NSString* extensions;

    IFProject *project = self.document;
    if (project.useNewExtensions) {
        extensions = @"inform://Extensions/Reserved/Documentation/Extensions.html";
    } else {
        extensions = @"inform://Extensions/Extensions.html";
    }
    [self.auxPane.extensionsPage openURL: [NSURL URLWithString: extensions]];
}

#pragma mark - New Extensions

- (IBAction) addExtensionFromFile: (id) sender {
    [self addExtensionFromFileUsingPanel: &_openExtensionPanel
                    withInitialDirectory: nil];
}

- (IBAction) addExtensionFromLegacyInstalledFolder: (id) sender {
    [self addExtensionFromFileUsingPanel: &_openLegacyExtensionPanel
                    withInitialDirectory: [NSURL fileURLWithPath:[IFUtility pathForInformExternalExtensions]]];
}

- (IBAction) gotoPublicLibrary: (id) sender {
    [self.window makeKeyAndOrderFront: self];
    [self gotoRightPane: sender];
    [self showPublicLibrary];
}

-(void) confirmInbuildAction {
    if (self->extensionURL != nil) {
        IFProject *project = self.document;
        [project executeInBuildForExtension: self->extensionURL
                                     action: self->inbuildAction
                           withConfirmation: true];

        // Show results
        for (int x=0; x<self->projectPanes.count; x++) {
            IFProjectPane* pane = self->projectPanes[x];

            [pane.compilerController clearTabViewsExcept: IFTabConsole];
            IFCompilerTabId id = [pane.compilerController makeTabForFile: project.extensionReportURL.path];
            [pane.compilerController switchToViewWithTabId: id];
        }
        [self->projectPanes[1] selectViewOfType: IFErrorPane];
    }
}

-(void) installExtension: (NSString*) extension {
    [self installExtensionURL: [NSURL fileURLWithPath: extension]];
}

-(void) installExtensionURL: (NSURL*) extension {
    self->extensionURL = extension;
    self->inbuildAction = @"-install";

    IFProject *project = self.document;
    [project executeInBuildForExtension: extension
                                 action: self->inbuildAction
                       withConfirmation: false];

    // Show results
    for (int x=0; x<self->projectPanes.count; x++) {
        IFProjectPane* pane = self->projectPanes[x];

        [pane.compilerController clearTabViewsExcept: IFTabConsole];
        IFCompilerTabId id = [pane.compilerController makeTabForFile: project.extensionReportURL.path];
        [pane.compilerController switchToViewWithTabId: id];
    }
    [self->projectPanes[1] selectViewOfType: IFErrorPane];
}

-(void) uninstallExtension: (NSString*) extension {
    IFProject *project = self.document;
    self->extensionURL = [NSURL fileURLWithPath: extension];
    self->inbuildAction = @"-uninstall";

    [project executeInBuildForExtension: self->extensionURL
                                 action: self->inbuildAction
                       withConfirmation: false];

    // Show results
    for (int x=0; x<self->projectPanes.count; x++) {
        IFProjectPane* pane = self->projectPanes[x];

        [pane.compilerController clearTabViewsExcept: IFTabConsole];
        IFCompilerTabId id = [pane.compilerController makeTabForFile: project.extensionReportURL.path];
        [pane.compilerController switchToViewWithTabId: id];
    }
    [self->projectPanes[1] selectViewOfType: IFErrorPane];
}

-(void) moderniseExtension: (NSString*) extension {
    [self moderniseExtensionURL: [NSURL fileURLWithPath: extension]];
}

-(void) moderniseExtensionURL: (NSURL*) extension {
    self->extensionURL = extension;
    self->inbuildAction = @"-run-moderniser";

    IFProject *project = self.document;
    [project executeInBuildForExtension: extension
                                 action: self->inbuildAction
                       withConfirmation: false];

    // Show results
    for (int x=0; x<self->projectPanes.count; x++) {
        IFProjectPane* pane = self->projectPanes[x];

        [pane.compilerController clearTabViewsExcept: IFTabConsole];
        IFCompilerTabId id = [pane.compilerController makeTabForFile: project.extensionReportURL.path];
        [pane.compilerController switchToViewWithTabId: id];
    }
    [self->projectPanes[1] selectViewOfType: IFErrorPane];
}


-(void) testExtension: (NSString*) extension
              command: (NSString*) command
             testcase: (NSString*) testcase {
    IFProject *project = self.document;

    for( IFProjectPane* pane in projectPanes ) {
        [pane.compilerController clearConsole: nil];
    }
    [projectPanes[1] selectViewOfType: IFErrorPane];

    [project testExtension: extension
                   command: command
                  testcase: testcase];

    for( IFProjectPane* pane in projectPanes ) {
        [pane.compilerController switchToSplitView];
    }
}

-(void) addExtensionFromFileUsingPanel: (NSOpenPanel*__strong*) pPanel
                  withInitialDirectory: (NSURL*) initialURL {
    // Present a panel for installing new extensions
    if (!*pPanel) {
        *pPanel = [NSOpenPanel openPanel];
    }
    if (initialURL != nil) {
        (*pPanel).directoryURL = initialURL;
    }
    [*pPanel setAccessoryView:           nil];
    [*pPanel setCanChooseFiles:          YES];
    [*pPanel setCanChooseDirectories:    YES];
    [*pPanel setResolvesAliases:         YES];
    [*pPanel setAllowsMultipleSelection: YES];
    (*pPanel).title = [IFUtility localizedString:@"Install Inform 7 Extension"];
    (*pPanel).delegate = self;    // Determines which file types are valid to choose (panel:shouldEnableURL)

    [*pPanel beginWithCompletionHandler: ^(NSInteger result) {
        [*pPanel setDelegate: nil];

        if (result != NSModalResponseOK) return;

        NSURL *url = (*pPanel).URL;
        IFProject *project = self.document;
        NSString* name = url.lastPathComponent;
        self->extensionURL = [[IFNewExtensionsManager sharedNewExtensionsManager] copyWithUnzip: url
                                                                             toProjectTemporary: project
                                                                                  extensionName: name];
        if (self->extensionURL) {
            // Call inbuild to check it's a valid extension and install
            [self installExtensionURL: self->extensionURL];
        }
    }];
}

- (BOOL)    panel: (id) sender
  shouldEnableURL: (NSURL *) url {
    BOOL isDir;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath: url.path
                                                       isDirectory: &isDir];
    if (!exists) return NO;
    if (isDir) {
        if ([[NSWorkspace sharedWorkspace] isFilePackageAtPath: url.path]) {
            return NO;
        }
        return YES;
    }

    NSString* extn = url.pathExtension.lowercaseString;

    if( [extn isEqualToString: @"i7x"] ||
        [extn isEqualToString: @"i7xd"] ||
        [extn isEqualToString: @"zip"]) {
        return YES;
    }
    return NO;
}

#pragma mark - Skein delegate

- (void) stopGame {
    IFGamePage* gamePage = self.gamePage;

	if (gamePage.isRunningGame) {
        [gamePage stopRunningGame];
	}
}

- (void) playToPoint: (IFSkeinItem*) point
		   fromPoint: (IFSkeinItem*) currentPoint {
    if ((self.gamePage).isRunningGame) {
		id<ZoomViewInputSource> inputSource = [IFSkein inputSourceFromSkeinItem: currentPoint
                                                                         toItem: point];
	
		ZoomView* zView = [self runningGamePage].zoomView;
		GlkView* gView = [self runningGamePage].glkView;
		
		if (zView != nil) {
			zView.inputSource = inputSource;
		} else {
			self.glkInputSource = inputSource;
			[gView addInputReceiver: self];
			[gView setAlwaysPageOnMore: YES];
			
			[self viewIsWaitingForInput: gView];
		}
	} else {
		[self compileAndRun: self];
        [self.gamePage setSwitchToPage: NO];
		[self.gamePage setPointToRunTo: point];
	}
}

#pragma mark - Displaying progress

- (void) showMessage: (NSString*) message {
    [toolbarManager showMessage: message];
}

- (void) addProgressIndicator: (IFProgress*) indicator {
    [toolbarManager addProgressIndicator: indicator];
}

- (void) removeProgressIndicator: (IFProgress*) indicator {
    [toolbarManager removeProgressIndicator: indicator];
}

- (void) progressIndicator: (IFProgress*) indicator
				percentage: (CGFloat) newPercentage {
	[toolbarManager progressIndicator: indicator
                           percentage: newPercentage];
}

- (void) progressIndicator: (IFProgress*) indicator
				   message: (NSString*) newMessage {
    [toolbarManager progressIndicator: indicator
                              message: newMessage];
}

- (void) updateProgress {
    [toolbarManager updateProgress];
}

- (BOOL) validateToolbarItem: (NSToolbarItem*) item {
    return [toolbarManager validateToolbarItem: item];
}

#pragma mark - Dealing with search panels

- (void) searchShowSelectedItemAtLocation: (NSInteger) location
                                   phrase: (NSString*) phrase
                                   inFile: (NSString*) filename
                                     type: (IFFindLocation) type
                                anchorTag: (NSString*) anchorTag {
	// If the match is a document, order the documentation pane to display it
	// (Not sure how to deal with the location: I don't think it makes much sense
	// relative to a web view)
	
	if ( (type & IFFindDocumentationBasic) ||
         (type & IFFindDocumentationSource) ||
         (type & IFFindDocumentationDefinitions) ) {
		// Doc pane
        NSString* urlString;
        
        if((anchorTag != nil) && (anchorTag.length > 0)) {
            urlString = [NSString stringWithFormat:@"inform:/%@#%@", filename.lastPathComponent, anchorTag];
        }
        else {
            urlString = [NSString stringWithFormat:@"inform:/%@", filename.lastPathComponent];
        }
        
		[self.auxPane.documentationPage openURL: [NSURL URLWithString: urlString]];
	} else if (type == IFFindExtensions ) {
		// Show the appropriate extension source file
		[self selectSourceFile: filename];
        
        // Highlight the appropriate phrase
        NSDocument* newDoc = [[NSDocumentController sharedDocumentController] documentForURL: [NSURL fileURLWithPath: filename]];
        if( newDoc != nil ) {
            // Pass this message on to this document's controllers
            for( id	docController in newDoc.windowControllers ) {
                // If this controller is capable of indicating lines, tell it to do so
                if ([docController respondsToSelector: @selector(indicateRange:)]) {
                    [docController indicateRange: NSMakeRange(location, phrase.length)];
                }
            }
        }
    } else {
		// Show the appropriate source file
		[self selectSourceFile: filename];
		[self selectSourceFileRange: NSMakeRange(location, phrase.length)];
	}
}

#pragma mark - Menu options

- (IBAction) shiftLeft: (id) sender {
    NSResponder* responder = self.window.firstResponder;
    
	if ([responder isKindOfClass: [NSTextView class]]) {
        [sharedActions shiftLeftTextViewInDocument: self.document
                                          textView: (NSTextView*) responder];
    }
}

- (IBAction) shiftRight: (id) sender {
    NSResponder* responder = self.window.firstResponder;

	if ([responder isKindOfClass: [NSTextView class]]) {
        [sharedActions shiftRightTextViewInDocument: self.document
                                           textView: (NSTextView*) responder];
    }
}

- (IBAction) renumberSections: (id) sender {
    NSResponder* responder = self.window.firstResponder;
    
	if ([responder isKindOfClass: [NSTextView class]]) {
        [sharedActions renumberSectionsInDocument: self.document
                                         textView: (NSTextView*) responder];
    }
}

- (void) commentOutSelection: (id) sender {
    NSResponder* responder = self.window.firstResponder;
    
	if ([responder isKindOfClass: [NSTextView class]]) {
        [sharedActions commentOutSelectionInDocument: self.document
                                            textView: (NSTextView*) responder];
    }
}

- (void) uncommentSelection: (id) sender {
    NSResponder* responder = self.window.firstResponder;
    
	if ([responder isKindOfClass: [NSTextView class]]) {
        [sharedActions uncommentSelectionInDocument: self.document
                                           textView: (NSTextView*) responder];
    }
}

#pragma mark - Searching

- (IBAction) searchDocs: (id) sender {
	if ( ([sender stringValue] == nil) ||
        ([[sender stringValue] isEqualToString: @""]) ) return;
    
    [[IFFindInFilesController sharedFindInFilesController] showFindInFilesWindow: self];
    [[IFFindInFilesController sharedFindInFilesController] startFindInFilesSearchWithPhrase: [sender stringValue]
                                                                           withLocationType: (IFFindDocumentationBasic | IFFindDocumentationSource | IFFindDocumentationDefinitions)
                                                                                   withType: (IFFindType) (IFFindContains | IFFindCaseInsensitive)];
}

- (IBAction) searchProject: (id) sender {
	if ( ([sender stringValue] == nil) ||
         ([[sender stringValue] isEqualToString: @""]) ) return;

    [[IFFindInFilesController sharedFindInFilesController] showFindInFilesWindow: self];
    [[IFFindInFilesController sharedFindInFilesController] startFindInFilesSearchWithPhrase: [sender stringValue]
                                                                           withLocationType: IFFindSource
                                                                                   withType: (IFFindType) (IFFindContains | IFFindCaseInsensitive)];
}

- (IBAction) testSelector: (id) sender {
    // Change test selection
    if( [sender isKindOfClass: [NSPopUpButton class]] )
    {
        NSPopUpButton* button = sender;
        int selectedIndex = (int) button.indexOfSelectedItem;
        [compileCheck testCaseDidChange];

        [self.document selectSkein: selectedIndex-1];
    }
}

/* For an extension project, we install that extension, otherwise we call the app delegate's
 version to show an open dialog to install any extension */
- (IBAction) installLegacyExtension: (id) sender {
    if ([self.document isExtensionProject]) {
        // This only applies in an Extension Project.
        // Save extension.i7x (without user interaction) and install it
        [self saveDocument: sender];

        IFProject* doc = self.document;
        NSString* finalPath = nil;
        IFExtensionResult result = [[IFExtensionsManager sharedNaturalInformExtensionsManager] installLegacyExtension: doc.mainSourcePathName
                                                                                                      finalPath: &finalPath
                                                                                                          title: nil
                                                                                                         author: nil
                                                                                                        version: nil
                                                                                             showWarningPrompts: YES
                                                                                                         notify: YES];
        if (result != IFExtensionSuccess) {
            [IFUtility showExtensionError: result withWindow: self.window];
        }
    } else {
        [((IFAppDelegate *) NSApp.delegate) installLegacyExtension: sender];
    }
}

#pragma mark - IFRuntimeErrorParser delegate methods

- (void) runtimeError: (NSString*) error
          inDirectory: (NSString*) directory {
    IFProject *project = self.document;

    IFRuntimeProblemPage* page = [[IFRuntimeProblemPage alloc] initWithProblem: error
                                                                   inDirectory: directory
                                                            materialsDirectory: project.materialsDirectoryURL.path
                                                             internalDirectory: [IFUtility pathForInformInternalAppSupport: @""]];
    NSURL* errorURL = page.appPageURL;
    NSString* markdownPath = page.markdownPath;

    if (markdownPath != nil) {
        // Run inbuild to convert the markdown file to HTML
        errorURL = [[IFUtility temporaryDirectoryURL] URLByAppendingPathComponent: @"temp.html"];
        int result = [project.inBuild executeInBuildForConvertingMarkdown: markdownPath
                                                                   toHTML: errorURL.path
                                                             withInternal: [NSURL fileURLWithPath:[IFUtility pathForInformInternalAppSupport: @""]]
                                                                 settings: project.settings];
        if (result != 0) {
            return;
        }
    }

    if (errorURL != nil) {
        // For each pane, add the runtime error message
        for( IFProjectPane* pane in projectPanes ) {
            [pane.compilerController showRuntimeError: errorURL];
        }

        // Change the source view to the errors view (so we can see the text leading to the error as well as the error itself
        [projectPanes[0] selectViewOfType: IFErrorPane];
    }
}

#pragma mark - Tabbing around

- (void) activateNearestTextView {
	// Start from the current tab view
	NSResponder* first = [self currentTabView];
	
	// Get the first responder
	if (first == nil) first = self.window.firstResponder;
		
	// Go inside the tab view
	if ([first isKindOfClass: [NSTabView class]]) {
		// Is a tab view: try the view for the active tab item
		first = ((NSTabView*)first).selectedTabViewItem.view;
	}
	
	// Iterate past things that won't accept the first responder
	while (first != nil && [first isKindOfClass: [NSView class]] && !((NSView*)first).acceptsFirstResponder) {
		if (((NSView*)first).subviews.count > 0) {
			first = ((NSView*)first).subviews[0];
		} else {
			first = nil;
		}
	}
	
	if ([first isKindOfClass: [ZoomView class]]) {
		// Zoom view: use the contained text view
		first = ((ZoomView*)first).textView;
	}
	
	if ([first isKindOfClass: [NSScrollView class]]) {
		// If a scroll view, then activate the document view
		NSScrollView* scroll = (NSScrollView*)first;
		
		first = scroll.documentView;
	} else if ([first isKindOfClass: [NSClipView class]]) {
		// Same for a clip view
		NSClipView* clip = (NSClipView*)first;
		
		first = clip.documentView;
	}
	
	if (first != nil && [first isKindOfClass: [NSText class]]) {
		// If the contents of the active scroll or clip view is a text view, then make that the first responder
		[self.window makeFirstResponder: first];
	}
}

- (IBAction) tabSource: (id) sender {
	[[self currentTabView] selectTabViewItemWithIdentifier: [[IFSourcePage class] description]];
	[self activateNearestTextView];
}

- (IBAction) tabErrors: (id) sender {
	[[self currentTabView] selectTabViewItemWithIdentifier: [[IFErrorsPage class] description]];
	[self activateNearestTextView];
}

- (IBAction) tabIndex: (id) sender {
	[[self currentTabView] selectTabViewItemWithIdentifier: [[IFIndexPage class] description]];
	[self activateNearestTextView];
}

- (IBAction) tabSkein: (id) sender {
	[[self currentTabView] selectTabViewItemWithIdentifier: [[IFSkeinPage class] description]];
	[self activateNearestTextView];
}

- (IBAction) tabGame: (id) sender {
	[self.runningGamePane.tabView selectTabViewItemWithIdentifier: [[IFGamePage class] description]];
	[self.window makeFirstResponder: self.runningGamePane.tabView];
	[self activateNearestTextView];
}

- (IBAction) tabDocumentation: (id) sender {
	[[self currentTabView] selectTabViewItemWithIdentifier: [[IFDocumentationPage class] description]];
	[self activateNearestTextView];
}

- (IBAction) tabExtensions: (id) sender {
	[[self currentTabView] selectTabViewItemWithIdentifier: [[IFExtensionsPage class] description]];
	[self activateNearestTextView];
}

- (IBAction) tabSettings: (id) sender {
	[[self currentTabView] selectTabViewItemWithIdentifier: [[IFSettingsPage class] description]];
	[self activateNearestTextView];
}

- (IBAction) gotoLeftPane: (id) sender {
	[self.window makeFirstResponder: [projectPanes[0] tabView].selectedTabViewItem.view];
	[self activateNearestTextView];
}

- (IBAction) gotoRightPane: (id) sender {
	[self.window makeFirstResponder: [projectPanes[1] tabView].selectedTabViewItem.view];
	[self activateNearestTextView];
}

- (IBAction) switchPanes: (id) sender {
	NSTabView* newView = nil;
	
	if ([self currentTabView] == ((IFProjectPane*)projectPanes[0]).tabView) {
		newView = [projectPanes[1] tabView];
	} else {
		newView = [projectPanes[0] tabView];
	}

	if (newView != nil) {
		[self.window makeFirstResponder: newView.selectedTabViewItem.view];
		[self activateNearestTextView];
	}
}

#pragma mark - Spell checking

- (void) setSourceSpellChecking: (BOOL) spellChecking {
	// Update the panes
	for( IFProjectPane* pane in projectPanes ) {
		[pane.sourcePage setSpellChecking: ((IFAppDelegate *) NSApp.delegate).sourceSpellChecking];
	}
}

#pragma mark - CocoaGlk -> skein gateway (GlkAutomation)

- (IBAction) glkTaskHasStarted: (id) sender {
	IFSkein* currentSkein = [self.document currentSkein];
	
	[currentSkein interpreterRestart];
}

@synthesize glkInputSource;

- (void) receivedCharacters: (NSString*) characters
					 window: (int) windowNumber
				   fromView: (GlkView*) view {
	IFSkein* currentSkein = [self.document currentSkein];
	
	[currentSkein outputText: characters];
}

- (void) userTyped: (NSString*) userInput
			window: (int) windowNumber
		 lineInput: (BOOL) isLineInput
		  fromView: (GlkView*) view {
	IFSkein* currentSkein = [self.document currentSkein];

	if (isLineInput) {
		[currentSkein inputCommand: userInput];
	} else {
		[currentSkein inputCharacter: userInput];
	}
}

- (void) userClickedAtXPos: (int) xpos
					  ypos: (int) ypos
					window: (int) windowNumber
				  fromView: (GlkView*) view {
}

- (void) viewWaiting: (GlkView*) view {
    IFSkein* currentSkein = [self.document currentSkein];
    [currentSkein waitingForInput];
}

- (void) viewIsWaitingForInput: (GlkView*) view {
	// Only do anything if there's at least one view waiting for input
	if (!view.canSendInput) return;

    IFSkein* currentSkein = [self.document currentSkein];
    [currentSkein waitingForInput];

    // Get the next command from the input source (which is a zoom-style input source)
	NSString* nextCommand = [glkInputSource nextCommand];

	if (nextCommand == nil) {
		[view removeAutomationObject: self];
		[view addOutputReceiver: self];
		[view setAlwaysPageOnMore: NO];
		
		[self inputSourceHasFinished: nil];
		return;
	}

	[view sendCharacters: nextCommand
				toWindow: 0];
}

- (void) zoomViewIsWaitingForInput {
    IFSkein* currentSkein = [self.document currentSkein];
    [currentSkein waitingForInput];
}

- (IBAction) showFindInFiles: (id) sender {
    [[IFFindInFilesController sharedFindInFilesController] showFindInFilesWindow: self];
}

#pragma mark - The find action

- (void) performFindPanelAction: (id) sender {
	// TODO: [[self currentTabView] performFindPanelAction: sender];
}

#pragma mark - Running the entire skein

- (void) runCompilerOutputAndEntireSkein {
	playAll = [[IFSkeinPlayAll alloc] initWithRootItem: [self.document currentSkein].rootItem];
	[self inputSourceHasFinished: nil];
}

- (void) finishRunningTestCases {
    // Stop the current game
    [projectPanes makeObjectsPerformSelector: @selector(stopRunningGame)];

    // Show completion message
    if(testAllProgress.isCancelled) {
        testAllProgress.message = [IFUtility localizedString:@"Tests cancelled"];
    }
    else {
        testAllProgress.message = [IFUtility localizedString:@"Tests completed"];
    }
    [testAllProgress stopProgress];
    [self removeProgressIndicator: testAllProgress];

    // Reset variables
    [testCaseRun finish];

    // Update toolbar
    [toolbarManager validateVisibleItems];

    // Restore the skein
    [self.document selectSkein: toolbarManager.testCaseIndex];
}

- (BOOL) startNextTestCase {
    [testCaseRun moveToNextTestCase];

    // Did we reach the end of the test cases?
    if(( testCaseRun.isPastTheLastTestCase || [self currentTestCase] == nil ) || (testAllProgress.isCancelled)) {
        [self finishRunningTestCases];
        return NO;
    }

    int done  = testCaseRun.numberStarted;
    int total = testCaseRun.numberInRun;
    NSString* message;
    message = [NSString stringWithFormat: [IFUtility localizedString:@"Testing %d of %d"], done, total];
    testAllProgress.percentage = testCaseRun.percentageStarted;
    testAllProgress.message = message;

    [self testMeInternal];
    return YES;
}

-(BOOL) startNextTestCaseSoon {
    if(( [self currentTestCase] == nil ) || (testAllProgress.isCancelled)) {
        [self finishRunningTestCases];
        return NO;
    }

    // After the last test case, finish now, so that the caller knows to make the report
    if( testCaseRun.isOnTheLastTestCase ) {
        return [self startNextTestCase];
    }

    // Enforce a delay to let current task finish gracefully before starting another
    [NSTimer scheduledTimerWithTimeInterval: 0.0
                                     target: self
                                   selector: @selector(startNextTestCase)
                                   userInfo: nil
                                    repeats: NO];
    return YES;
}

- (void) inputSourceHasFinishedAfterDelay {
    // Gather report data
    NSString* intestCode = [self.document reportStateForSkein];
    IFSkeinItem* reportItem = [self.document nodeToReport];
    unsigned long skeinNodeId = reportItem.uniqueId;
    IFSkeinItem* activeItem = [self.document currentSkein].activeItem;
    int skeinNodes = 0;
    while( (activeItem != nil) && (activeItem.parent != nil) ) {
        activeItem = activeItem.parent;
        skeinNodes++;
    }

    if (playAll.nextItem != nil) {
        // We are testing the entire skein.
        // Run the next set of commands on the skein stack.
        [self.gamePage setSwitchToPage: NO];
        [self.gamePage setPointToRunTo: playAll.nextItem];
        [self runCompilerOutput];
        [playAll removeNextItem];
    }
    else if ( self.currentlyTesting ) {
        // Make a report
        NSURL* reportURL = [self.document currentReportURL];
        [self.document generateReportForTestCase: [self currentTestCase]
                                         errorCode: intestCode
                                       skeinNodeId: skeinNodeId
                                        skeinNodes: skeinNodes
                                         outputURL: reportURL];
        // Start next case
        if ([self startNextTestCase]) {
            return;
        }

        // All test cases finished. Create a consolidated report and display it.
        if(!testAllProgress.isCancelled) {
            [self createAndShowReport: testCaseRun.numberTested reportURL: reportURL];
        }
    }
}

- (void) inputSourceHasFinished: (id) source {
    // Enforce a delay to let current task finish gracefully before starting another
    [NSTimer scheduledTimerWithTimeInterval: 0.0
                                     target: self
                                   selector: @selector(inputSourceHasFinishedAfterDelay)
                                   userInfo: nil
                                    repeats: NO];
}

#pragma mark - Importing skein information

- (IBAction) importIntoSkein: (id) sender {
    [self.document importIntoSkeinWithWindow: self.window];
}

- (IBAction) exportExtension: (id) sender {
    [self.document exportExtension: self.window];
}

#pragma mark - Documentation

- (void) openDocUrl: (NSURL*) url {
	IFProjectPane* auxPane = self.auxPane;
	
	[auxPane selectViewOfType: IFDocumentationPane];
	[auxPane.documentationPage openURL: url];
}

#pragma mark - Headers

- (void) intelFileChanged: (NSNotification*) not {
	// Must be the current intelligence object
	if (not.object != self.currentIntelligence) return;
	
	// Update the header controller
	[headerController updateFromIntelligence: (IFIntelFile*)not.object];
}

@synthesize headerController;

#pragma mark - Moving around source headings
- (void) showHeadings: (id) sender {
	// Select the source page in the current tab
	[[self currentTabView] selectTabViewItemWithIdentifier: [[IFSourcePage class] description]];
	[self activateNearestTextView];	
	
	// Retrieve the page for the current tab
	IFSourcePage* sourcePage = currentPane.sourcePage;
	
	// Toggle the header page
	[sourcePage toggleHeaderPage: self];
}

- (void) showCurrentSectionOnly: (id) sender {
	// Select the source page in the current tab
	[[self currentTabView] selectTabViewItemWithIdentifier: [[IFSourcePage class] description]];
	[self activateNearestTextView];	
	
	// Retrieve the page for the current tab
	IFSourcePage* sourcePage = currentPane.sourcePage;
	
	[sourcePage showCurrentSectionOnly: self];
}

- (void) showFewerHeadings: (id) sender {
	// Select the source page in the current tab
	[[self currentTabView] selectTabViewItemWithIdentifier: [[IFSourcePage class] description]];
	[self activateNearestTextView];	
	
	// Retrieve the page for the current tab
	IFSourcePage* sourcePage = currentPane.sourcePage;
	
	[sourcePage showFewerHeadings: self];
}

- (void) showMoreHeadings: (id) sender {
	// Select the source page in the current tab
	[[self currentTabView] selectTabViewItemWithIdentifier: [[IFSourcePage class] description]];
	[self activateNearestTextView];	
	
	// Retrieve the page for the current tab
	IFSourcePage* sourcePage = currentPane.sourcePage;
	
	[sourcePage showMoreHeadings: self];
}

- (void) showEntireSource: (id) sender {
	// Select the source page in the current tab
	[[self currentTabView] selectTabViewItemWithIdentifier: [[IFSourcePage class] description]];
	[self activateNearestTextView];	
	
	// Retrieve the page for the current tab
	IFSourcePage* sourcePage = currentPane.sourcePage;
	
	[sourcePage showEntireSource: self];
}

- (void) showPreviousSection: (id) sender {
	// Select the source page in the current tab
	[[self currentTabView] selectTabViewItemWithIdentifier: [[IFSourcePage class] description]];
	[self activateNearestTextView];	
	
	// Retrieve the page for the current tab
	IFSourcePage* sourcePage = currentPane.sourcePage;
	
	// Show the previous section
	[sourcePage sourceFileShowPreviousSection: self];
}

- (void) showNextSection: (id) sender {
	// Select the source page in the current tab
	[[self currentTabView] selectTabViewItemWithIdentifier: [[IFSourcePage class] description]];
	[self activateNearestTextView];	
	
	// Retrieve the page for the current tab
	IFSourcePage* sourcePage = currentPane.sourcePage;
	
	// Show the next section
	[sourcePage sourceFileShowNextSection: self];
}

-(void) extensionUpdated: (NSString*) javascriptId {
    for(IFProjectPane* pane in projectPanes) {
        [pane extensionUpdated: javascriptId];
    }
}

-(BOOL) isRunningGame {
    return [self runningGamePage].isRunningGame;
}

-(BOOL) isCompiling {
    return isCompiling;
}

// -- Split view delegate --
- (CGFloat)     splitView: (NSSplitView *) splitView
   constrainMinCoordinate: (CGFloat) proposedMinimumPosition
              ofSubviewAt: (NSInteger) dividerIndex
{
    return [IFPaneWidths leastDividerPosition: proposedMinimumPosition];
}

- (CGFloat)     splitView: (NSSplitView *) splitView
   constrainMaxCoordinate: (CGFloat) proposedMaximumPosition
              ofSubviewAt: (NSInteger) dividerIndex
{
    return [IFPaneWidths greatestDividerPosition: proposedMaximumPosition
                                         inWidth: [splitView bounds].size.width];
}

- (BOOL)    splitView: (NSSplitView *) splitView
   canCollapseSubview: (NSView *) subview {
    return NO;
}

-(NSString*) windowTitleForDocumentDisplayName:(NSString *)displayName {
    if( [self isExtensionProject] ) {
        return [NSString stringWithFormat: @"%@ - %@", [IFUtility localizedString: @"Extension Project"], displayName];
    }
    return displayName;
}

@end
