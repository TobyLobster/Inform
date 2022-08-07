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
#import "IFInspectorWindow.h"
#import "IFNewProjectFile.h"
#import "IFIsIndex.h"
#import "IFWelcomeWindow.h"
#import "IFInform7MutableString.h"
#import "IFFindInFilesController.h"
#import "IFSyntaxManager.h"
#import "IFSingleController.h"
#import "IFToolbarManager.h"
#import "IFPolicyManager.h"
#import "IFSkein.h"
#import "IFSkeinItem.h"


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

#import "IFIsFiles.h"

#import "IFHeaderController.h"

#import "IFExtensionsManager.h"

#import "IFI7OutputSettings.h"
#import "IFCompilerController.h"
#import "IFCompilerSettings.h"

#import "IFUtility.h"
#import <ZoomView/ZoomView.h>
#import "Inform-Swift.h"

// Preferences
static NSString* const    IFSplitViewSizes    = @"IFSplitViewSizes";
static CGFloat const      minDividerWidth     = 75.0f;

// *******************************************************************************************
@interface IFProjectController()

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

    // Source highlighting (indexed by file)
    NSMutableDictionary*    lineHighlighting;
    BOOL                    temporaryHighlights;

    // Compiling
    /// Action after a compile has finished
    SEL                     compileFinishedAction;
    BOOL                    isCompiling;

    // The last file selected
    NSString*               lastFilename;

    // Stack of skein items
    /// Used when running the entire skein (array of IFSkeinItem objects)
    NSMutableArray<IFSkeinItem*>*         skeinNodeStack;

    // Glk automation
    id<ZoomViewInputSource> glkInputSource;

    BOOL                    betweenWindowLoadedAndBecomingMain;
    BOOL                    testCaseChangedSinceLastSuccessfulCompile;
    /// Current index of test cases to test
    int                     currentTestCaseIndex;
    /// Range of test cases to test
    int                     startTestCaseIndex;
    /// Range of test cases to test
    int                     endTestCaseIndex;
    /// Number of test cases tested
    int                     numberOfTestCases;

    /// Policy delegates (for handling custom URLs like 'library://')
    IFPolicyManager*        policyManager;
    /// Actions that can be shared between project and single controllers
    IFSourceSharedActions*  sharedActions;

    IFProgress*             testAllProgress;
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
		lineHighlighting = [[NSMutableDictionary alloc] init];

        [self setShouldCloseDocument: NO];

        policyManager = [[IFPolicyManager alloc] initWithProjectController: self];

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
        testCaseChangedSinceLastSuccessfulCompile = YES;

        sharedActions = [[IFSourceSharedActions alloc] init];
        toolbarManager = [[IFToolbarManager alloc] initWithProjectController: self];

        currentTestCaseIndex = -1;
        numberOfTestCases = 0;

        testAllProgress = nil;
    }

    return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void) updateSettings {
    // Mark document as edited. This ensures a recompile happens on the next 'Go!', for example.
    [[self document] updateChangeCount: NSChangeDone];

    // Update toolbar
    [toolbarManager updateSettings];
}

- (BOOL) safeToSwitchTabs {
    return !betweenWindowLoadedAndBecomingMain;
}

- (void) windowDidLoad {
	[self setWindowFrameAutosaveName: @"ProjectWindow"];
	[[self window] setFrameAutosaveName: @"ProjectWindow"];

    // Once a project has loaded, remove the launcher window
	[IFWelcomeWindow hideWelcomeWindow];

    // We have loaded the window, but we are not yet main
    betweenWindowLoadedAndBecomingMain = YES;
}

- (void)windowDidBecomeMain:(NSNotification *)notification {
    betweenWindowLoadedAndBecomingMain = NO;

    [toolbarManager redrawToolbar];

    // The window accepts mouse move events
    [[self window] setAcceptsMouseMovedEvents:YES];
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
    [[self document] refreshTestCases];

    // Update the toolbar to reflect the changes
    [toolbarManager setTestCases: [[self document] testCases]];
}

-(BOOL) isExtensionProject {
    return [[self document] isExtensionProject];
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

	[[projectPanes[0] sourcePage] setSpellChecking: [(IFAppDelegate*)[NSApp delegate] sourceSpellChecking]];
    [[projectPanes[1] sourcePage] setSpellChecking: [(IFAppDelegate*)[NSApp delegate] sourceSpellChecking]];

    // Monitor for compiler finished notifications
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(compilerFinished:)
                                                 name: IFCompilerFinishedNotification
                                               object: [[self document] compiler]];

    // Fullscreen mode
    if( [IFUtility hasFullscreenSupportFeature] ) {
        // Add fullscreen capability. Only available on Lion (10.7) or above
        [[self window] setCollectionBehavior:[[self window] collectionBehavior] | NSWindowCollectionBehaviorFullScreenPrimary];
    }

    // Create the toolbar view
    [toolbarManager setToolbar];
    [toolbarManager setIsExtensionProject: [self isExtensionProject]];

    // Update the toolbar to reflect the test cases
    [toolbarManager setTestCases: [[self document] testCases]];
}

// == Project pane layout ==

- (void) layoutPanes {
    if ([projectPanes count] == 0) {
        return;
    }

    // Remove any previous panes
    [projectPanes makeObjectsPerformSelector: @selector(removeFromSuperview)];
    [splitViews makeObjectsPerformSelector: @selector(removeFromSuperview)];
    [splitViews removeAllObjects];

    // Remove panesView itself from window
    [[panesView subviews] makeObjectsPerformSelector: @selector(removeFromSuperview)];

    if ([projectPanes count] == 1) {
        // Just one pane
        IFProjectPane* firstPane = projectPanes[0];

        [firstPane setController: self viewIndex: 1];
        
        [[firstPane paneView] setFrame: [panesView bounds]];
        [panesView addSubview: [firstPane paneView]];
    } else {
        // Create the splitViews
        NSInteger view, nviews;
        CGFloat dividerWidth = 5;

        nviews = [projectPanes count];
        for (view=0; view<nviews-1; view++) {
            NSSplitView* newView = [[ThinSplitView alloc] init];

            [newView setVertical: YES];
            [newView setDelegate: self];
            [newView setAutoresizingMask: (NSViewWidthSizable|NSViewHeightSizable)];

            dividerWidth = [newView dividerThickness];

            [splitViews addObject: newView];
        }

        // Remaining space for other dividers
        CGFloat remaining        = [panesView bounds].size.width - dividerWidth*(CGFloat)(nviews-1);
        CGFloat totalRemaining   = [panesView bounds].size.width;
        CGFloat viewWidth        = floor(remaining / (CGFloat)nviews);

		// Work out the widths of the dividers using the preferences
		NSMutableArray<NSNumber*>* realDividerWidths = [NSMutableArray array];
		NSArray* dividerProportions = [[NSUserDefaults standardUserDefaults] arrayForKey: IFSplitViewSizes];

        if (![dividerProportions isKindOfClass: [NSArray class]] || [dividerProportions count] <= 0) {
			dividerProportions = @[@1.0f];
        }

        CGFloat totalWidth = 0;
		for (view=0; view<nviews; view++) {
            CGFloat width;
			
			if (view >= [dividerProportions count]) {
				width = [dividerProportions[[dividerProportions count]-1] doubleValue];
			} else {
				width = [dividerProportions[view] doubleValue];
			}
			
			if (width <= 0) width = 1.0;
			[realDividerWidths addObject: @(width)];
			
			totalWidth += width;
		}

		// Work out the actual widths to use, and size and add the views appropriately
        CGFloat proportion = remaining / totalWidth;

        // Insert the views
        NSSplitView* lastView = nil;
        for (view=0; view<nviews-1; view++) {
            // Garner some information about the views we're dealing with
            NSSplitView*   thisView = splitViews[view];
            IFProjectPane* pane     = projectPanes[view];
            NSView*        thisPane = [projectPanes[view] paneView];

            [pane setController: self viewIndex: view];
			
			viewWidth = floor(proportion * [realDividerWidths[view] doubleValue]);

            // Resize the splitview
            NSRect splitFrame;
            if (lastView != nil) {
                splitFrame = [lastView bounds];
                splitFrame.origin.x += viewWidth + dividerWidth;
                splitFrame.size.width = totalRemaining;
            } else {
                splitFrame = [panesView bounds];
            }
            [thisView setFrame: splitFrame];

            // Add it as a subview
            if (lastView != nil) {
                [lastView addSubview: thisView];
            } else {
                [panesView addSubview: thisView];
            }

            // Add the leftmost view
            NSRect paneFrame = [thisView bounds];
            paneFrame.size.width = viewWidth;

            [thisPane setFrame: paneFrame];
            [thisView addSubview: thisPane];
			[thisView setDelegate: self];

            lastView = thisView;

            // Update the amount of space remaining
            remaining -= viewWidth;
            totalRemaining -= viewWidth + dividerWidth;
        }

        // Final view
        NSView* finalPane = [[projectPanes lastObject] paneView];
        NSRect finalFrame = [lastView bounds];

        [[projectPanes lastObject] setController: self viewIndex: nviews-1];

        finalFrame.origin.x += viewWidth + dividerWidth;
        finalFrame.size.width = totalRemaining;
        [finalPane setFrame: finalFrame];
        
        [lastView addSubview: finalPane];
        [lastView adjustSubviews];
    }
}

- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification {
	// Update the preferences with the view widths
	int nviews = (int) [projectPanes count];
	int view;
	
	NSMutableArray* viewSizes = [NSMutableArray array];
	
    CGFloat totalWidth = [[self window] frame].size.width;
	
	for (view=0; view<nviews; view++) {
		IFProjectPane* pane = projectPanes[view];
		NSRect paneFrame = [[pane paneView] frame];
		
		[viewSizes addObject: @((CGFloat) (paneFrame.size.width/totalWidth))];
	}
	
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
					if ([possiblePane tabView] == firstView) {
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
			firstView = [firstView superview];
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
	SEL itemSelector = [menuItem action];
	BOOL isRunning = [[self runningGamePage] isRunningGame];

	if (itemSelector == @selector(stopProcess:)) {
		return isRunning;
	}

    BOOL selectedNoTestCase = [self isExtensionProject] && ((toolbarManager.testCases.count == 0) ||
                                                            (toolbarManager.currentTestCase == nil));
    BOOL selectedTestAllCase = [self isExtensionProject] && [self isTestAllCasesSelected];
    BOOL currentlyTesting = [self isCurrentlyTesting];

    if (itemSelector == @selector(testMe:)) {
        // If we are in an Extension Project, and there are no test cases to run, disable Go! (etc) menu items.
        if( selectedNoTestCase || currentlyTesting) {
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
		return ![[[self document] compiler] isRunning];
	}

	// Format options
	if (itemSelector == @selector(shiftLeft:) ||
		itemSelector == @selector(shiftRight:) ||
		itemSelector == @selector(renumberSections:)) {
		// First responder must be an NSTextView object
		if (![[[self window] firstResponder] isKindOfClass: [NSTextView class]])
			return NO;
	}

	if (itemSelector == @selector(commentOutSelection:)
		|| itemSelector == @selector(uncommentSelection:)) {
		// Must be an Inform 7 project (not supporting this for I6 unless someone asks or implements themselves :-)
		if (![[[self document] settings] usingNaturalInform])
			return NO;
		
		// First responder must be a NSTextView object
		if (![[[self window] firstResponder] isKindOfClass: [NSTextView class]])
			return NO;
		
		// There must be a non-zero length selection
		if ([(NSTextView*)[[self window] firstResponder] selectedRange].length == 0)
			return 0;
	}
	
	if (itemSelector == @selector(renumberSections:)) {
		// First responder must be an NSTextView object containing a NSTextStorage with some intel data
		if (![[[self window] firstResponder] isKindOfClass: [NSTextView class]])
			return NO;

		NSTextStorage* storage = (NSTextStorage*)[(NSTextView*)[[self window] firstResponder] textStorage];
		
		if ([IFSyntaxManager intelligenceDataForStorage: storage] == nil) return NO;
	}
	
	// Tabbing options
	if (itemSelector == @selector(tabSource:) 
	 || itemSelector == @selector(tabErrors:)
	 || itemSelector == @selector(tabIndex:)
	 || itemSelector == @selector(tabSkein:)
	 || itemSelector == @selector(tabGame:)
	 || itemSelector == @selector(tabDocumentation:)
	 || itemSelector == @selector(tabSettings:)
	 || itemSelector == @selector(switchPanes:)) {
		return [self currentTabView] != nil;
	}
	
	if (itemSelector == @selector(showIndexTab:)) {
		return [[projectPanes[0] indexPage] canSelectIndexTab: (int) [menuItem tag]];
	}
	
	// Heading options
	if (itemSelector == @selector(showNextSection:)
	 || itemSelector == @selector(showPreviousSection:)
	 || itemSelector == @selector(showCurrentSectionOnly:)
	 || itemSelector == @selector(showEntireSource:)
	 || itemSelector == @selector(showFewerHeadings:)
	 || itemSelector == @selector(showMoreHeadings:)) {
		// For any of these to work, the source page must be visible
		if (![[[self window] firstResponder] isKindOfClass: [NSTextView class]])
			return NO;
		
		if ([currentPane currentView] != IFSourcePane)
			return NO;
	}
	
	if (itemSelector == @selector(exportIFiction:)) {
		return [[[self document] settings] usingNaturalInform];
	}

    if (itemSelector == @selector(exportExtension:)) {
        return [[self document] isExtensionProject];
    }

	return YES;
}

-(int) getNumberOfTestCases {
    if ([self isExtensionProject]) {
        return [toolbarManager getNumberOfTestCases];
    }
    return 0;
}

-(NSString*) currentTestCase {
    if ([self isExtensionProject]) {
        // If we are doing "Test All", get the current test case based on index
        if (currentTestCaseIndex >= 0) {
            return [toolbarManager getTestCase: currentTestCaseIndex];
        }

        // Get the currently selected test case from the toolbar
        return [toolbarManager currentTestCase];
    }
    return nil;
}

- (void) performCompileWithRelease: (BOOL) release
                        forTesting: (BOOL) releaseForTesting
					   refreshOnly: (BOOL) onlyRefresh
                          testCase: (NSString*) testCase {
    IFProject* doc = [self document];

    // Remove temporary highlighting
    [self removeHighlightsOfStyle: IFLineStyleError];
    [self removeHighlightsOfStyle: IFLineStyleExecutionPoint];

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
        [self addProgressIndicator: [theCompiler progress]];
        [[theCompiler progress] startProgress];

        // Clear the console only on the first compilation of this run
        if (currentTestCaseIndex < 1) {
            [theCompiler clearConsole];
        }

        [theCompiler launch];
        isCompiling = YES;
    }
    else
    {
        NSString* version = [[doc settings] compilerVersion];
        NSString* message = [NSString stringWithFormat: [IFUtility localizedString: @"One possibility is that the project's language version '%@' is not available. Try setting the language version in Settings."], version];
        [IFUtility runAlertWindow: [self window]
                        localized: YES
                          warning: YES
                            title: [IFUtility localizedString: @"Could not launch compiler."]
                          message: @"%@", message];
    }

    // Show the Console pane if required
    if( ![self isTestAllCasesSelected] ) {
        if ( [[IFPreferences sharedPreferences] showConsoleDuringBuilds] ) {
            [projectPanes[1] selectViewOfType: IFErrorPane];
        }
    }
}

// == View selection functions ==

- (IBAction)saveDocument:(id)sender {
	// Need to call prepareToSave here to give the project panes a chance to shut down any editing operations that might be ongoing
	for( IFProjectPane* pane in projectPanes ) {
		[pane prepareToSave];
	}

    // Save the project, without user interaction.
    [[self document] saveDocumentWithoutUserInteraction];

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

- (BOOL) timestampsInChronologicalOrder: (NSURL*) first
                                 second: (NSURL*) second {
    // If the datestamps both exist, and the first timestamp is earlier or equal to the second.
    NSDictionary*  firstAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath: first.path  error: NULL];
    NSDictionary* secondAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath: second.path error: NULL];

    if( firstAttributes && secondAttributes ) {
        NSDate* firstDate  = [firstAttributes  objectForKey: NSFileModificationDate];
        NSDate* secondDate = [secondAttributes objectForKey: NSFileModificationDate];

        // Note that datestamps are only recorded to the second.
        if( [firstDate compare: secondDate] != NSOrderedDescending ) {
            return YES;
        }
    }
    return NO;
}

- (void) makeWithRelease: (BOOL) release
              forTesting: (BOOL) releaseForTesting
             refreshOnly: (BOOL) onlyRefresh
            forceCompile: (BOOL) forceCompile
               onSuccess: (SEL) onSuccess {
    BOOL needsToCompile = forceCompile;

    // If the debug setting to always compile is switched on, then always compile
    if(( !needsToCompile) && [[IFPreferences sharedPreferences] alwaysCompile]) {
        needsToCompile = YES;
    }

    // If the document has unsaved changes, always save and compile
    if( !needsToCompile && [[self document] hasUnautosavedChanges] ) {
        needsToCompile = YES;
    }

    // If we have changed test case in an extension project, always save and compile
    if( !needsToCompile && testCaseChangedSinceLastSuccessfulCompile ) {
        needsToCompile = YES;
    }

    if( !needsToCompile ) {
        NSURL* outputURL    = [[self document] buildOutputFileURL];
        NSURL* sourceURL    = [[self document] mainSourceFileURL];
        NSURL* settingsURL  = [[self document] settingsFileURL];

        // If the source timestamp is later than the output timestamp, then we need to compile
        needsToCompile = ![self timestampsInChronologicalOrder: sourceURL
                                                        second: outputURL];

        if( !needsToCompile ) {
            // If the settings timestamp is later than the output timestamp, then we need to compile
            needsToCompile = ![self timestampsInChronologicalOrder: settingsURL
                                                            second: outputURL];
        }
    }

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
        return ([toolbarManager currentTestCase] == nil);
    }
    return NO;
}

- (IBAction) testMe: (id) sender {
    if( [self isExtensionProject] ) {
        if( [self isTestAllCasesSelected] ) {
            // Run all test cases
            startTestCaseIndex = 0;
            endTestCaseIndex = [self getNumberOfTestCases] - 1;
        }
        else {
            // Run a specific test only
            startTestCaseIndex = [toolbarManager getTestCaseIndex];
            endTestCaseIndex = startTestCaseIndex;
        }

        // Compile and run each test case in turn
        if( currentTestCaseIndex == -1 ) {
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
        if (currentTestCaseIndex >= 0) {
            [[self document] selectSkein: currentTestCaseIndex];
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
	[self removeHighlightsOfStyle: IFLineStyleExecutionPoint];
}

- (IBAction) openMaterials: (id) sender {
    [[self document] openMaterials];
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
    [[self document] saveIFictionWithWindow: [self window]];
}

#pragma mark - Displaying a specific index tab

- (IBAction) showIndexTab: (id) sender {
	int tag = (int) [sender tag];
	
	for( IFProjectPane* pane in projectPanes ) {
		[[pane indexPage] switchToTab: tag];
	}
	
	[[self indexPane] selectViewOfType: IFIndexPane];
}

#pragma mark - Things to do after the compiler has finished

- (void) refreshIndexTabs {
	// Display the index pane
	[[self indexPane] selectViewOfType: IFIndexPane];
}

- (void) saveCompilerOutput {
	// Check to see if one of the compile controllers has already got a save location for the game
	IFCompilerController* paneController = [projectPanes[0] compilerController];
	NSString*               copyLocation = [paneController blorbLocation];

	// Show the 'success' pane
	[projectPanes[1] selectViewOfType: IFErrorPane];

	if (copyLocation != nil) {
        NSError* error;

		// Copy the result to the specified location (overwriting any existing file)
        [[NSFileManager defaultManager] removeItemAtPath: copyLocation
                                                   error: &error];
		[[NSFileManager defaultManager] copyItemAtPath: [[[self document] compiler] outputFile]
                                                toPath: copyLocation
                                                 error: &error];
	} else {
        [[self document] saveCompilerOutputWithWindow: [self window]];
	}
}

- (void) runCompilerOutputAndTest {
    // Set test commands
    if( [self isExtensionProject] ) {
        NSArray* testCommands = [[self document] testCommandsForExtensionTestCase: [self currentTestCase]];
        [self.gamePage setTestCommands: testCommands];
    }
    else {
        [self.gamePage setTestCommands: @[@"test me"]];
    }

    [self runCompilerOutput];
}


- (void) runCompilerOutput {
    [self.gamePage startRunningGame: [[self document] buildOutputFileURL].path];

    [toolbarManager validateVisibleItems];
}

- (void) runCompilerOutputAndReplay {
	skeinNodeStack = nil;
	
    [self.gamePage setSwitchToPage: YES];
    [self.gamePage setTestCommands: [self.document currentSkein].previousCommands];
	[self runCompilerOutput];
}

- (void) debugCompilerOutput {
	[self.gamePage activateDebug];
    [self.gamePage startRunningGame: [[self.document compiler] outputFile]];

    [toolbarManager validateVisibleItems];
}

- (void) createAndShowReport:(int) numTests reportURL:(NSURL*) reportURL {
    if( numTests > 1 ) {
        [[self document] generateCombinedReportForBaseInputURL: [[self document] baseReportURL]
                                                      numTests: numTests
                                                     outputURL: [[self document] combinedReportURL]];
    }
    else {
        // Copy from reportURL to [[self document] combinedReportURL];
        NSFileManager *fm = [NSFileManager defaultManager];
        NSError* err;
        if( [fm removeItemAtURL:[[self document] combinedReportURL] error: &err] ) {
            if (![fm copyItemAtURL:reportURL
                             toURL:[[self document] combinedReportURL]
                             error: &err] )
            {
                NSLog(@"Error copying file %@",[err localizedDescription]);
            }
        }
        else {
            NSLog(@"Error removing file %@",[err localizedDescription]);
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

    for (int x=0; x<[projectPanes count]; x++) {
        IFProjectPane* pane = projectPanes[x];

        [[pane compilerController] clearTabViews];
        [[pane compilerController] showContentsOfFilesIn: buildDir
                                                fromPath: [buildURL path]];
    }
}

- (void) compilerFinished: (NSNotification*) not {
    int exitCode = [[not userInfo][@"exitCode"] intValue];
    ECompilerProblemType problemType = [[not userInfo][@"problemType"] intValue];
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

	[self removeProgressIndicator: [[[self document] compiler] progress]];
	
	if (exitCode != 0 || [[not object] problemsURL] != nil) {
        if( ![self isTestAllCasesSelected] ) {
            // Show the errors pane if there was an error while compiling
            [projectPanes[1] selectViewOfType: IFErrorPane];
        }
    }

    // Re-read the contents of the directory, now that the compiler has written a bunch of files there
    [[self document] reloadDirectory];

	// Show the 'build results' files
    [self updateBuildResults];

	// Update the index tab(s)
	for (int x=0; x<[projectPanes count]; x++) {
        IFProjectPane* pane = projectPanes[x];
		[[pane indexPage] updateIndexView];
	}

	// Reload the index file
	[[self document] reloadIndexFile];
	
	// Update the inspector index
	[[IFIsFiles sharedIFIsFiles] updateFiles];
	[[IFIsIndex sharedIFIsIndex] updateIndexFrom: self];

    // Make a report if there was an error while compiling a test case
    NSURL* reportURL = nil;
    if( [self isCurrentlyTesting] ) {

        if( intestCode != nil ) {
            reportURL = [[self document] currentReportURL];

            [[self document] generateReportForTestCase: [self currentTestCase]
                                             errorCode: intestCode
                                              skeinURL: [[self document] currentSkeinURL]
                                           skeinNodeId: 0
                                            skeinNodes: 0
                                             outputURL: reportURL];
            [[self document] reloadSourceDirectory];
        }
    }

    if (exitCode == 0) {
        testCaseChangedSinceLastSuccessfulCompile = NO;
        // Success!
        [IFUtility performSelector: compileFinishedAction object: self];
    }

    isCompiling = NO;
    compileFinishedAction = nil;
    [toolbarManager validateVisibleItems];

    // If not successful, start the next test case
    if ((exitCode != 0) && [self isCurrentlyTesting]) {
        if( [self startNextTestCaseSoon] ) {
            return;
        }

        // All test cases finished.

        // Create a consolidated report and display it.
        if( !testAllProgress.isCancelled && (reportURL != nil) ) {
            [self createAndShowReport: numberOfTestCases reportURL: reportURL];
        }
    }
}

#pragma mark - Communication from the containing panes

- (IFProjectPane*) sourcePane {
	// Returns the current pane containing the source code (or an appropriate pane that source code can be displayed in)
    int paneToUse = 0;
    int x;
	
    for (x=0; x<[projectPanes count]; x++) {
        IFProjectPane* thisPane = projectPanes[x];
		
        if ([thisPane currentView] == IFSourcePane) {
            // Always use the first source pane found
            paneToUse = x;
            break;
        }
		
        if ([thisPane currentView] == IFErrorPane) {
            // Avoid a pane showing error messages
            paneToUse = x+1;
        }
    }
	
    if (paneToUse >= [projectPanes count]) {
        // All error views?
        paneToUse = 0;
    }

	return projectPanes[paneToUse];
}

- (IFProjectPane*) auxPane {
	// Returns the auxiliary pane: the one to use for displaying documentation, etc
    int paneToUse = -1;
    int x;
	
    for (x=0; x<[projectPanes count]; x++) {
        IFProjectPane* thisPane = projectPanes[x];
		
        if ([thisPane currentView] == IFDocumentationPane) {
			// Doc pane has priority
            paneToUse = x;
            break;
        }
    }

    // If no documentation pane available, choose something else.
	if (paneToUse == -1) {
		paneToUse = 1;
		for (x=(int)[projectPanes count]-1; x>=0; x--) {
			IFProjectPane* thisPane = projectPanes[x];
			
			if ([thisPane currentView] != IFSourcePane &&
				[thisPane currentView] != IFGamePane) {
				// Anything but the source or game...
				paneToUse = x;
				break;
			}
			
			if ([thisPane currentView] == IFSourcePane) {
				// Avoid a pane showing the source code
				paneToUse = x+1;
			}
		}
	}
	
    if (paneToUse >= [projectPanes count]) {
        // All source views?
        paneToUse = 0;
    }
	
	return projectPanes[paneToUse];
}

- (IFProjectPane*) indexPane {
	// Returns the current pane containing the index
    int x;
	
    for (x=0; x<[projectPanes count]; x++) {
        IFProjectPane* thisPane = projectPanes[x];
		
        if ([thisPane currentView] == IFIndexPane) {
			// This is the index pane
			return thisPane;
        }
    }
	
	// No index pane showing: use the aux pane
	return [self auxPane];
}

- (IFProjectPane*) oppositePane: (IFProjectPane*) pane {
	// Find this pane
	NSInteger index = [projectPanes indexOfObjectIdenticalTo: pane];
	if (index == NSNotFound) return nil;
	
	// Get it's 'opposite'
	NSInteger opposite = index-1;
	if (opposite < 0) opposite = [projectPanes count]-1;
	
	return projectPanes[opposite];
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
        for( NSWindowController* controller in [newDoc windowControllers] ) {
            [[controller window] makeKeyAndOrderFront: self];
        }
    }
}

- (BOOL) loadInform7Extension: (NSString*) filename {
    // Get the author and extension name
	NSArray* components = [filename pathComponents];
	if ([components count] != 2) {
		if ([filename characterAtIndex: 0] == '/' && [[NSFileManager defaultManager] fileExistsAtPath: filename]) {
            [self loadInform7ExtensionWithFullFilePath:filename];
			return YES;
		}
		return NO;
	}

	NSString* author = components[0];
	NSString* extension = components[1];

	// Search for this extension
	NSArray* possibleExtensions = [[IFExtensionsManager sharedNaturalInformExtensionsManager] filesInExtensionWithName: author];
	if ([possibleExtensions count] <= 0) return NO;

	for( NSString* extnFile in possibleExtensions ) {
		if ([[extnFile lastPathComponent] caseInsensitiveCompare: extension] == NSOrderedSame) {
			// This is the extension file we need to open
            [self loadInform7ExtensionWithFullFilePath: extnFile];
			return YES;
		}
	}

	return NO;
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
        IFSkeinPage* skeinPage = [pane skeinPage];
        [skeinPage selectSkeinItemWithNodeId: skeinNodeId];
    }
    return YES;
}

- (BOOL) selectSourceFile: (NSString*) fileName {
	if ([[self document] storageForFile: fileName] != nil) {
		// Load this file
		[projectPanes makeObjectsPerformSelector: @selector(showSourceFile:)
									  withObject: fileName];
	} else if (![self loadInform7Extension: fileName]) {
		// Display an error if we couldn't find the file
        [IFUtility runAlertWarningWindow: [self window]
                                   title: @"Unable to open source file"
                                 message: @"Unable to open source file description"];
	}

	lastFilename = [fileName copy];

    return YES;
}

- (IFSourcePage*) sourcePage {
	return [[self sourcePane] sourcePage];
}

- (NSString*) selectedSourceFile {
	return [[self sourcePage] currentFile];
}

- (void) moveToSourceFileLine: (NSInteger) line {
	IFProjectPane* thePane = [self sourcePane];

    [thePane selectViewOfType: IFSourcePane];
    [[thePane sourcePage] moveToLine: line];
    [[self window] makeFirstResponder: [thePane activeView]];
}

- (void) moveToSourceFilePosition: (NSInteger) location {
	IFProjectPane* thePane = [self sourcePane];
	
    [thePane selectViewOfType: IFSourcePane];
    [[thePane sourcePage] moveToLocation: location];
    [[self window] makeFirstResponder: [thePane activeView]];
}

- (void) selectSourceFileRange: (NSRange) range {
	IFProjectPane* thePane = [self sourcePane];
	
    [thePane selectViewOfType: IFSourcePane];
    [[thePane sourcePage] indicateRange: range];

    [[self window] makeFirstResponder: [thePane activeView]];
}

- (void) removeHighlightsInFile: (NSString*) file
						ofStyle: (IFLineStyle) style {
	file = [[self document] pathForSourceFile: file];
	
	NSMutableArray* lineHighlight = lineHighlighting[file];
	if (lineHighlight == nil) return;
	
	BOOL updated = NO;
	
	// Loop through each highlight, and remove any of this style
	int x;
	for (x=0; x<[lineHighlight count]; x++) {
		if ([lineHighlight[x][1] intValue] == style) {
			[lineHighlight removeObjectAtIndex: x];
			updated = YES;
			x--;
		}
	}
	
	if (updated) {
		for( IFProjectPane* pane in projectPanes ) {
			if ([[[self document] pathForSourceFile: [[pane sourcePage] currentFile]] isEqualToString: file]) {
				[[pane sourcePage] updateHighlightedLines];
			}
		}
	}
}

- (void) removeHighlightsOfStyle: (IFLineStyle) style {
	// Remove highlights in all files
	for( NSString* file in lineHighlighting ) {
		[self removeHighlightsInFile: file
							 ofStyle: style];
	}
}

- (void) removeAllTemporaryHighlights {
	if (!temporaryHighlights) return;
	
	int style;
	
	for (style = IFLineStyle_Temporary; style<IFLineStyle_LastTemporary; style++) {
		[self removeHighlightsOfStyle: style];
	}
	
	temporaryHighlights = NO;
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
	file = [[self document] pathForSourceFile: file];
	
	// See if there's a document that manages this file
	NSDocument* fileDocument = [[NSDocumentController sharedDocumentController] documentForURL: [NSURL fileURLWithPath: file]];
	if (fileDocument && fileDocument != [self document] && ![fileDocument isEqual: [self document]]) {

		// Pass this message on to this document's controllers
		for( id	docController in [fileDocument windowControllers] ) {
			// If this controller is capable of highlighting lines, tell it to do so
			if ([docController respondsToSelector: @selector(highlightSourceFileLine:inFile:style:)]) {
				[docController highlightSourceFileLine: line
												inFile: file
												 style: style];
			}
		}
		return;
	}
	
	// Create a new line highlight for this file
	NSMutableArray* lineHighlight = lineHighlighting[file];
	
	if (lineHighlight == nil) {
		lineHighlight = [NSMutableArray array];
		lineHighlighting[file] = lineHighlight;
	}
	
	[lineHighlight addObject: @[@(line), 
		@(style)]];
	
	// Display the highlight
	if (style >= IFLineStyle_Temporary && style < IFLineStyle_LastTemporary)
		temporaryHighlights = YES;
		
	for( IFProjectPane* pane in projectPanes ) {
		if ([[[self document] pathForSourceFile: [[pane sourcePage] currentFile]] isEqualToString: file]) {
			[[pane sourcePage] updateHighlightedLines];

			if (temporaryHighlights) {
				[[pane sourcePage] indicateLine: (int) line];
			}
		}
	}
}

- (NSArray*) highlightsForFile: (NSString*) file {
	file = [[self document] pathForSourceFile: file];
	
	return lineHighlighting[file];
}

#pragma mark - Debugging controls

- (IFProjectPane*) runningGamePane {
	// Return the pane that we're displaying/going to display the game in
	for( IFProjectPane* pane in projectPanes ) {
		if ([[pane gamePage] isRunningGame]) return pane;
	}

	return nil;
}

- (IFGamePage*) runningGamePage {
	return [[self runningGamePane] gamePage];
}

- (IFGamePage*) gamePage {
	return [projectPanes[1] gamePage];
}

- (void) restartRunning {
	// Perform actions to switch back to the game when we click on continue, etc
	[[self window] makeFirstResponder: [[self runningGamePage] zoomView]];
	[self removeHighlightsOfStyle: IFLineStyleExecutionPoint];	

	[toolbarManager validateVisibleItems];
}

- (void) pauseProcess: (id) sender {
	[[self runningGamePage] pauseRunningGame];
}

- (IFIntelFile*) currentIntelligence {
	return [[self sourcePage] currentIntelligence];
}

#pragma mark - Documentation controls

- (void) docIndex: (id) sender {
	[[[self auxPane] documentationPage] openURL: [NSURL URLWithString: @"inform:/index.html"]];
}

- (void) docRecipes: (id) sender {
	[[[self auxPane] documentationPage] openURL: [NSURL URLWithString: @"inform:/Rdoc1.html"]];
}

- (void) docExtensions: (id) sender {
	[[[self auxPane] extensionsPage] openURL: [NSURL URLWithString: @"inform://Extensions/Extensions.html"]];
}

#pragma mark - Adding files

- (void) addNewFile: (id) sender {
	IFNewProjectFile* npf = [[IFNewProjectFile alloc] initWithProjectController: self];

	NSString* newFile = [npf getNewFilename];
	if (newFile) {
		if (![(IFProject*)[self document] addFile: newFile]) {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.informativeText = [IFUtility localizedString: @"FileUnable - Description"
                                                       default: @"Inform was unable to create that file: most probably because a file already exists with that name"];
            alert.messageText = [IFUtility localizedString: @"Unable to create file"];
            [alert addButtonWithTitle:[IFUtility localizedString: @"FileUnable - Cancel"
                                                         default: @"Cancel"]];
            [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
               // do nothing.
            }];
		}
	}

	[[IFIsFiles sharedIFIsFiles] updateFiles];
}

#pragma mark - Skein delegate

- (void) stopGame {
    IFGamePage* gamePage = self.gamePage;

	if ([gamePage isRunningGame]) {
        [gamePage stopRunningGame];
	}
}

- (void) playToPoint: (IFSkeinItem*) point
		   fromPoint: (IFSkeinItem*) currentPoint {
    if ([self.gamePage isRunningGame]) {
		id<ZoomViewInputSource> inputSource = [IFSkein inputSourceFromSkeinItem: currentPoint
                                                                         toItem: point];
	
		ZoomView* zView = [[self runningGamePage] zoomView];
		GlkView* gView = [[self runningGamePage] glkView];
		
		if (zView != nil) {
			[zView setInputSource: inputSource];
		} else {
			[self setGlkInputSource: inputSource];
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

#pragma mark - Policy delegates

- (IFProjectPolicy*) generalPolicy {
	return policyManager.generalPolicy;
}

- (IFProjectPolicy*) docPolicy {
	return policyManager.docPolicy;
}

- (IFProjectPolicy*) extensionsPolicy {
	return policyManager.extensionsPolicy;
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

// (Grr, need to be able to make IFProjectPane the first responder or something, but it isn't
// listening to messages from the main menu. Or at least, it's not being called that way)
// This may not work the way the user expects if she has two source panes open. Blerh.

- (IFSourcePage*) activeSourcePage {
	if ([currentPane currentView] == IFSourcePane) {
		// The cursor is currently in a source pane
		return [currentPane sourcePage];
	} else {
		// The cursor is currently elsewhere: ie, there is no active source page
		return nil;
	}
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
        
        if((anchorTag != nil) && ([anchorTag length] > 0)) {
            urlString = [NSString stringWithFormat:@"inform:/%@#%@", [filename lastPathComponent], anchorTag];
        }
        else {
            urlString = [NSString stringWithFormat:@"inform:/%@", [filename lastPathComponent]];
        }
        
		[[[self auxPane] documentationPage] openURL: [NSURL URLWithString: urlString]];
	} else if (type == IFFindExtensions ) {
		// Show the appropriate extension source file
		[self selectSourceFile: filename];
        
        // Highlight the appropriate phrase
        NSDocument* newDoc = [[NSDocumentController sharedDocumentController] documentForURL: [NSURL fileURLWithPath: filename]];
        if( newDoc != nil ) {
            // Pass this message on to this document's controllers
            for( id	docController in [newDoc windowControllers] ) {
                // If this controller is capable of indicating lines, tell it to do so
                if ([docController respondsToSelector: @selector(indicateRange:)]) {
                    [docController indicateRange: NSMakeRange(location, [phrase length])];
                }
            }
        }
    } else {
		// Show the appropriate source file
		[self selectSourceFile: filename];
		[self selectSourceFileRange: NSMakeRange(location, [phrase length])];
	}
}

#pragma mark - Menu options

- (IBAction) shiftLeft: (id) sender {
    NSResponder* responder = [[self window] firstResponder];
    
	if ([responder isKindOfClass: [NSTextView class]]) {
        [sharedActions shiftLeftTextViewInDocument: [self document]
                                          textView: (NSTextView*) responder];
    }
}

- (IBAction) shiftRight: (id) sender {
    NSResponder* responder = [[self window] firstResponder];

	if ([responder isKindOfClass: [NSTextView class]]) {
        [sharedActions shiftRightTextViewInDocument: [self document]
                                           textView: (NSTextView*) responder];
    }
}

- (IBAction) renumberSections: (id) sender {
    NSResponder* responder = [[self window] firstResponder];
    
	if ([responder isKindOfClass: [NSTextView class]]) {
        [sharedActions renumberSectionsInDocument: [self document]
                                         textView: (NSTextView*) responder];
    }
}

- (void) commentOutSelection: (id) sender {
    NSResponder* responder = [[self window] firstResponder];
    
	if ([responder isKindOfClass: [NSTextView class]]) {
        [sharedActions commentOutSelectionInDocument: [self document]
                                            textView: (NSTextView*) responder];
    }
}

- (void) uncommentSelection: (id) sender {
    NSResponder* responder = [[self window] firstResponder];
    
	if ([responder isKindOfClass: [NSTextView class]]) {
        [sharedActions uncommentSelectionInDocument: [self document]
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
        int selectedIndex = (int) [button indexOfSelectedItem];
        testCaseChangedSinceLastSuccessfulCompile = YES;

        [[self document] selectSkein: selectedIndex-1];
    }
}

/* For an extension project, we install that extension, otherwise we call the app delegate's
 version to show an open dialog to install any extension */
- (IBAction) installExtension: (id) sender {
    if ([[self document] isExtensionProject]) {
        // This only applies in an Extension Project.
        // Save extension.i7x (without user interaction) and install it
        [self saveDocument: sender];

        IFProject* doc = [self document];
        NSString* finalPath = nil;
        IFExtensionResult result = [[IFExtensionsManager sharedNaturalInformExtensionsManager] installExtension: [doc mainSourcePathName]
                                                                                                      finalPath: &finalPath
                                                                                                          title: nil
                                                                                                         author: nil
                                                                                                        version: nil
                                                                                             showWarningPrompts: YES
                                                                                                         notify: YES];
        if (result != IFExtensionSuccess) {
            [IFUtility showExtensionError: result withWindow: [self window]];
        }
    } else {
        [((IFAppDelegate *) [NSApp delegate]) installExtension: sender];
    }
}

#pragma mark - UIDelegate methods

// We only implement a fairly limited subset of the UI methods, mainly to help show status
- (void)						webView:(WebView *)sender 
	 runJavaScriptAlertPanelWithMessage:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [IFUtility localizedString: @"JavaScript Alert"];
    alert.informativeText = message;
    [alert addButtonWithTitle: [IFUtility localizedString: @"Continue"]];
    [alert runModal];
}

#pragma mark - IFRuntimeErrorParser delegate methods

- (void) runtimeError: (NSString*) error {
	// The file that might contain the error
	NSString* errorFile = [NSString stringWithFormat: @"RTP_%@", error];
	
	// See if the file exists
	if ([[NSBundle mainBundle] pathForResource: errorFile
										ofType: @"html"] == nil) {
		// The error file cannot be found: use a default
		NSLog(@"Warning: run-time error file '%@.html' not found, using RTP_Unknown.html instead", errorFile);
		errorFile = @"RTP_Unknown";
	}
	
	// This URL is where the error file will reside
	NSURL* errorURL = [NSURL URLWithString: [NSString stringWithFormat: @"inform:/%@.html", errorFile]];

	// For each pane, add the runtime error message
	for( IFProjectPane* pane in projectPanes ) {
		[[pane compilerController] showRuntimeError: errorURL];
	}

	// Change the source view to the errors view (so we can see the text leading to the error as well as the error itself
	[projectPanes[0] selectViewOfType: IFErrorPane];
}

#pragma mark - Tabbing around

- (void) activateNearestTextView {
	// Start from the current tab view
	NSResponder* first = [self currentTabView];
	
	// Get the first responder
	if (first == nil) first = [[self window] firstResponder];
		
	// Go inside the tab view
	if ([first isKindOfClass: [NSTabView class]]) {
		// Is a tab view: try the view for the active tab item
		first = [[(NSTabView*)first selectedTabViewItem] view];
	}
	
	// Iterate past things that won't accept the first responder
	while (first != nil && [first isKindOfClass: [NSView class]] && ![(NSView*)first acceptsFirstResponder]) {
		if ([[(NSView*)first subviews] count] > 0) {
			first = [(NSView*)first subviews][0];
		} else {
			first = nil;
		}
	}
	
	if ([first isKindOfClass: [ZoomView class]]) {
		// Zoom view: use the contained text view
		first = [(ZoomView*)first textView];
	}
	
	if ([first isKindOfClass: [NSScrollView class]]) {
		// If a scroll view, then activate the document view
		NSScrollView* scroll = (NSScrollView*)first;
		
		first = [scroll documentView];
	} else if ([first isKindOfClass: [NSClipView class]]) {
		// Same for a clip view
		NSClipView* clip = (NSClipView*)first;
		
		first = [clip documentView];
	}
	
	if (first != nil && [first isKindOfClass: [NSText class]]) {
		// If the contents of the active scroll or clip view is a text view, then make that the first responder
		[[self window] makeFirstResponder: first];
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
	[[[self runningGamePane] tabView] selectTabViewItemWithIdentifier: [[IFGamePage class] description]];
	[[self window] makeFirstResponder: [[self runningGamePane] tabView]];
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
	[[self window] makeFirstResponder: [[[projectPanes[0] tabView] selectedTabViewItem] view]];
	[self activateNearestTextView];
}

- (IBAction) gotoRightPane: (id) sender {
	[[self window] makeFirstResponder: [[[projectPanes[1] tabView] selectedTabViewItem] view]];
	[self activateNearestTextView];
}

- (IBAction) switchPanes: (id) sender {
	NSTabView* newView = nil;
	
	if ([self currentTabView] == [(IFProjectPane*)projectPanes[0] tabView]) {
		newView = [projectPanes[1] tabView];
	} else {
		newView = [projectPanes[0] tabView];
	}

	if (newView != nil) {
		[[self window] makeFirstResponder: [[newView selectedTabViewItem] view]];
		[self activateNearestTextView];
	}
}

#pragma mark - Spell checking

- (void) setSourceSpellChecking: (BOOL) spellChecking {
	// Update the panes
	for( IFProjectPane* pane in projectPanes ) {
		[[pane sourcePage] setSpellChecking: [(IFAppDelegate *) [NSApp delegate] sourceSpellChecking]];
	}
}

#pragma mark - CocoaGlk -> skein gateway (GlkAutomation)

- (IBAction) glkTaskHasStarted: (id) sender {
	IFSkein* currentSkein = [[self document] currentSkein];
	
	[currentSkein interpreterRestart];
}

@synthesize glkInputSource;

- (void) receivedCharacters: (NSString*) characters
					 window: (int) windowNumber
				   fromView: (GlkView*) view {
	IFSkein* currentSkein = [[self document] currentSkein];
	
	[currentSkein outputText: characters];
}

- (void) userTyped: (NSString*) userInput
			window: (int) windowNumber
		 lineInput: (BOOL) isLineInput
		  fromView: (GlkView*) view {
	IFSkein* currentSkein = [[self document] currentSkein];

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
    IFSkein* currentSkein = [[self document] currentSkein];
    [currentSkein waitingForInput];
}

- (void) viewIsWaitingForInput: (GlkView*) view {
	// Only do anything if there's at least one view waiting for input
	if (![view canSendInput]) return;

    IFSkein* currentSkein = [[self document] currentSkein];
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
    IFSkein* currentSkein = [[self document] currentSkein];
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

- (void) fillNode: (IFSkeinItem*) item {
    if( item.children.count > 0 ) {
        for( IFSkeinItem* child in [[item children] reverseObjectEnumerator] ) {
            [self fillNode: child];
        }
        return;
    }

    // Add to the stack
    while( item.isTestSubItem ) {
        item = item.parent;
    }
    [skeinNodeStack addObject: item];
}

- (void) fillSkeinStack {
	skeinNodeStack = [[NSMutableArray alloc] init];
	
	[self fillNode: [[[self document] currentSkein] rootItem]];
}

- (void) runCompilerOutputAndEntireSkein {
	[self fillSkeinStack];
	[self inputSourceHasFinished: nil];
}

- (void) finishRunningTestCases {
    // Stop the current game
    [projectPanes makeObjectsPerformSelector: @selector(stopRunningGame)];

    // Show completion message
    if(testAllProgress.isCancelled) {
        [testAllProgress setMessage: [IFUtility localizedString:@"Tests cancelled"]];
    }
    else {
        [testAllProgress setMessage: [IFUtility localizedString:@"Tests completed"]];
    }
    [testAllProgress stopProgress];
    [self removeProgressIndicator: testAllProgress];

    // Reset variables
    numberOfTestCases = currentTestCaseIndex - startTestCaseIndex;
    currentTestCaseIndex = -1;

    // Update toolbar
    [toolbarManager validateVisibleItems];

    // Clear the skein
    [[self document] selectSkein: -1];
}

- (BOOL) startNextTestCase {
    if( currentTestCaseIndex == -1 ) {
        // Move to first test case
        currentTestCaseIndex = startTestCaseIndex;
    }
    else {
        // Move to next test case
        currentTestCaseIndex++;
    }

    // Did we reach the end of the test cases?
    if(( (currentTestCaseIndex > endTestCaseIndex) || [self currentTestCase] == nil ) || (testAllProgress.isCancelled)) {
        [self finishRunningTestCases];
        return NO;
    }

    int done  = currentTestCaseIndex - startTestCaseIndex + 1;
    int total = 1 + (endTestCaseIndex - startTestCaseIndex);
    CGFloat percentage = 100.0 * (CGFloat) done / (CGFloat) total;
    NSString* message;
    message = [NSString stringWithFormat: [IFUtility localizedString:@"Testing %d of %d"], done, total];
    [testAllProgress setPercentage: percentage];
    [testAllProgress setMessage: message];

    [self testMeInternal];
    return YES;
}

-(BOOL) startNextTestCaseSoon {
    if(( [self currentTestCase] == nil ) || (testAllProgress.isCancelled)) {
        [self finishRunningTestCases];
        return NO;
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
    NSString* intestCode = [[self document] reportStateForSkein];
    IFSkeinItem* reportItem = [[self document] nodeToReport];
    unsigned long skeinNodeId = reportItem.uniqueId;
    IFSkeinItem* activeItem = [[[self document] currentSkein] activeItem];
    int skeinNodes = 0;
    while( (activeItem != nil) && (activeItem.parent != nil) ) {
        activeItem = activeItem.parent;
        skeinNodes++;
    }

    if (skeinNodeStack != nil && [skeinNodeStack count] > 0) {
        // We are testing the entire skein.
        // Run the next set of commands on the skein stack.
        [self.gamePage setSwitchToPage: NO];
        [self.gamePage setPointToRunTo: [skeinNodeStack lastObject]];
        [self runCompilerOutput];
        [skeinNodeStack removeLastObject];
    }
    else if ( [self isCurrentlyTesting] ) {
        // Make a report
        NSURL* reportURL = [[self document] currentReportURL];
        [[self document] generateReportForTestCase: [self currentTestCase]
                                         errorCode: intestCode
                                          skeinURL: [[self document] currentSkeinURL]
                                       skeinNodeId: skeinNodeId
                                        skeinNodes: skeinNodes
                                         outputURL: reportURL];
        // Start next case
        if ([self startNextTestCase]) {
            return;
        }

        // All test cases finished. Create a consolidated report and display it.
        if(!testAllProgress.isCancelled) {
            [self createAndShowReport: numberOfTestCases reportURL: reportURL];
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
    [[self document] importIntoSkeinWithWindow: [self window]];
}

- (IBAction) exportExtension: (id) sender {
    [[self document] exportExtension: [self window]];
}

#pragma mark - Documentation

- (void) openDocUrl: (NSURL*) url {
	IFProjectPane* auxPane = [self auxPane];
	
	[auxPane selectViewOfType: IFDocumentationPane];
	[[auxPane documentationPage] openURL: url];
}

#pragma mark - Headers

- (void) intelFileChanged: (NSNotification*) not {
	// Must be the current intelligence object
	if ([not object] != [self currentIntelligence]) return;
	
	// Update the header controller
	[headerController updateFromIntelligence: (IFIntelFile*)[not object]];
}

@synthesize headerController;

#pragma mark - Moving around source headings
- (void) showHeadings: (id) sender {
	// Select the source page in the current tab
	[[self currentTabView] selectTabViewItemWithIdentifier: [[IFSourcePage class] description]];
	[self activateNearestTextView];	
	
	// Retrieve the page for the current tab
	IFSourcePage* sourcePage = [currentPane sourcePage];
	
	// Toggle the header page
	[sourcePage toggleHeaderPage: self];
}

- (void) showCurrentSectionOnly: (id) sender {
	// Select the source page in the current tab
	[[self currentTabView] selectTabViewItemWithIdentifier: [[IFSourcePage class] description]];
	[self activateNearestTextView];	
	
	// Retrieve the page for the current tab
	IFSourcePage* sourcePage = [currentPane sourcePage];
	
	[sourcePage showCurrentSectionOnly: self];
}

- (void) showFewerHeadings: (id) sender {
	// Select the source page in the current tab
	[[self currentTabView] selectTabViewItemWithIdentifier: [[IFSourcePage class] description]];
	[self activateNearestTextView];	
	
	// Retrieve the page for the current tab
	IFSourcePage* sourcePage = [currentPane sourcePage];
	
	[sourcePage showFewerHeadings: self];
}

- (void) showMoreHeadings: (id) sender {
	// Select the source page in the current tab
	[[self currentTabView] selectTabViewItemWithIdentifier: [[IFSourcePage class] description]];
	[self activateNearestTextView];	
	
	// Retrieve the page for the current tab
	IFSourcePage* sourcePage = [currentPane sourcePage];
	
	[sourcePage showMoreHeadings: self];
}

- (void) showEntireSource: (id) sender {
	// Select the source page in the current tab
	[[self currentTabView] selectTabViewItemWithIdentifier: [[IFSourcePage class] description]];
	[self activateNearestTextView];	
	
	// Retrieve the page for the current tab
	IFSourcePage* sourcePage = [currentPane sourcePage];
	
	[sourcePage showEntireSource: self];
}

- (void) showPreviousSection: (id) sender {
	// Select the source page in the current tab
	[[self currentTabView] selectTabViewItemWithIdentifier: [[IFSourcePage class] description]];
	[self activateNearestTextView];	
	
	// Retrieve the page for the current tab
	IFSourcePage* sourcePage = [currentPane sourcePage];
	
	// Show the previous section
	[sourcePage sourceFileShowPreviousSection: self];
}

- (void) showNextSection: (id) sender {
	// Select the source page in the current tab
	[[self currentTabView] selectTabViewItemWithIdentifier: [[IFSourcePage class] description]];
	[self activateNearestTextView];	
	
	// Retrieve the page for the current tab
	IFSourcePage* sourcePage = [currentPane sourcePage];
	
	// Show the next section
	[sourcePage sourceFileShowNextSection: self];
}

-(void) extensionUpdated: (NSString*) javascriptId {
    for(IFProjectPane* pane in projectPanes) {
        [pane extensionUpdated: javascriptId];
    }
}

-(BOOL) isRunningGame {
    return [[self runningGamePage] isRunningGame];
}

-(BOOL) isCompiling {
    return isCompiling;
}

// -- Split view delegate --
- (CGFloat)     splitView: (NSSplitView *) splitView
   constrainMinCoordinate: (CGFloat) proposedMinimumPosition
              ofSubviewAt: (NSInteger) dividerIndex
{
    if (proposedMinimumPosition < minDividerWidth) {
        proposedMinimumPosition = minDividerWidth;
    }

    return proposedMinimumPosition;
}

- (CGFloat)     splitView: (NSSplitView *) splitView
   constrainMaxCoordinate: (CGFloat) proposedMaximumPosition
              ofSubviewAt: (NSInteger) dividerIndex
{
    CGFloat limit = MAX(minDividerWidth, [splitView bounds].size.width - minDividerWidth);
    if (proposedMaximumPosition > limit) {
        proposedMaximumPosition = limit;
    }
    
    return proposedMaximumPosition;
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
