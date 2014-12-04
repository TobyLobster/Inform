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
#import "IFInspectorWindow.h"
#import "IFNewProjectFile.h"
#import "IFIsIndex.h"
#import "IFWelcomeWindow.h"
#import "IFInform7MutableString.h"
#import "IFFindInFilesController.h"
#import "IFSyntaxManager.h"
#import "IFSingleController.h"
#import "IFToolbarManager.h"

#import "IFPreferences.h"
#import "IFSingleFile.h"
#import "IFNaturalIntel.h"

#import "IFIsFiles.h"
#import "IFIsWatch.h"
#import "IFIsBreakpoints.h"

#import "IFExtensionsManager.h"

#import "IFI7OutputSettings.h"
#import "IFOutputSettings.h"

#import "IFCustomPopup.h"
#import "IFImageCache.h"
#import "IFUtility.h"

 // = Preferences =

static NSString* IFSplitViewSizes = @"IFSplitViewSizes";
static float minDividerWidth = 75.0f;

// = Private methods =

@interface IFProjectController(Private)

- (void) refreshIndexTabs;
- (void) runCompilerOutput;
- (void) runCompilerOutputAndReplay;
- (IFGamePage*) gamePage;

@end

// Subclass a split view to make a thinner divider
@interface ThinSplitView : NSSplitView
- (CGFloat)dividerThickness;
@end

@implementation ThinSplitView
- (CGFloat)dividerThickness { return 3; }
@end


@implementation IFProjectController

// == Toolbar items ==

+ (void) initialize {
	// Register our preferences
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	[defaults registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys: 
		[NSArray arrayWithObjects: [NSNumber numberWithFloat: 0.5], [NSNumber numberWithFloat: 0.5], nil], IFSplitViewSizes,
		nil]];

}

// == Initialistion ==

- (id) init {
    self = [super initWithWindowNibName:@"Project"];

    if (self) {
        projectPanes = [[NSMutableArray alloc] init];
        splitViews   = [[NSMutableArray alloc] init];
		
		lineHighlighting = [[NSMutableDictionary alloc] init];
        
        isCompiling = NO;
        [self setShouldCloseDocument: NO];
		
		generalPolicy = [[IFProjectPolicy alloc] initWithProjectController: self];
		docPolicy = [[IFProjectPolicy alloc] initWithProjectController: self];
		[docPolicy setRedirectToDocs: YES];
		[docPolicy setRedirectToExtensionDocs: NO];
		extensionsPolicy = [[IFProjectPolicy alloc] initWithProjectController: self];
		[extensionsPolicy setRedirectToDocs: NO];
		[extensionsPolicy setRedirectToExtensionDocs: YES];
		
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(intelFileChanged:)
													 name: IFIntelFileHasChangedNotification
												   object: nil];
        
		headerController = [[IFHeaderController alloc] init];
        betweenWindowLoadedAndBecomingMain = NO;
        
        sharedActions = [[IFSourceSharedActions alloc] init];

        toolbarManager = [[IFToolbarManager alloc] initWithProjectController: self];
    }

    return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];

    [toolbarManager release];
    [projectPanes release];
    [splitViews release];
	
	[lastFilename release];
	
	[lineHighlighting release];
	
	[generalPolicy release];
	[docPolicy release];
    [extensionsPolicy release];

	[processingSyntax release];
	
	[skeinNodeStack release];
	[headerController release];
	
    [sharedActions release];

    [super dealloc];
}

- (void) updateSettings {
    [toolbarManager updateSettings];
}

- (BOOL) safeToSwitchTabs {
    return !betweenWindowLoadedAndBecomingMain;
}

- (void) windowDidLoad {
	[self setWindowFrameAutosaveName: @"ProjectWindow"];
	[[self window] setFrameAutosaveName: @"ProjectWindow"];
	[IFWelcomeWindow hideWelcomeWindow];
	
    betweenWindowLoadedAndBecomingMain = YES;
}

- (void)windowDidBecomeMain:(NSNotification *)notification {
    betweenWindowLoadedAndBecomingMain = NO;
    // Hide the debug menu if we're not making a project where debugging is available
	[[[NSApp delegate] debugMenu] setHidden: ![self canDebug]];
    
    [[self window] setAcceptsMouseMovedEvents:YES];
}

- (void) windowWillClose: (NSNotification*) not {
	// Perform shutdown
	[[self gamePage] stopRunningGame];
	
	for( IFProjectPane* pane in projectPanes ) {
		[pane willClose];
	}
	
	[projectPanes release];
    projectPanes = nil;
    
	[splitViews release];
    splitViews = nil;
	
	[panesView removeFromSuperview];
    panesView = nil;
}

- (void) awakeFromNib {
	// Register for breakpoints updates
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(updatedBreakpoints:)
												 name: IFProjectBreakpointsChangedNotification
											   object: [self document]];
	
	[self updatedBreakpoints: nil];
	
	// Register for syntax reading events
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(syntaxUpdateStarted:)
												 name: IFProjectStartedBuildingSyntaxNotification
											   object: [self document]];
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(syntaxUpdateFinished:)
												 name: IFProjectFinishedBuildingSyntaxNotification
											   object: [self document]];

    // Setup the default panes
    [projectPanes removeAllObjects];
    [projectPanes addObject: [IFProjectPane standardPane]];
    [projectPanes addObject: [IFProjectPane standardPane]];

    [self layoutPanes];
	
    [[projectPanes objectAtIndex: 0] selectViewOfType: IFSourcePane];
    [[projectPanes objectAtIndex: 1] selectViewOfType: IFDocumentationPane];

	[[[projectPanes objectAtIndex: 0] sourcePage] setSpellChecking: [[NSApp delegate] sourceSpellChecking]];
    [[[projectPanes objectAtIndex: 1] sourcePage] setSpellChecking: [[NSApp delegate] sourceSpellChecking]];

    // Monitor for compiler finished notifications
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(compilerFinished:)
                                                 name: IFCompilerFinishedNotification
                                               object: [[self document] compiler]];

	// Monitor for skein changed notifications
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(skeinChanged:)
												 name: ZoomSkeinChangedNotification
											   object: [[self document] skein]];
	
    // Fullscreen mode
    SInt32 MacVersion;
    if( Gestalt( gestaltSystemVersion, &MacVersion ) == noErr )
    {
        if( MacVersion >= 0x1070 ) {
            // Add fullscreen capability. Only available on Lion (10.7) or above
            [[self window] setCollectionBehavior:[[self window] collectionBehavior] | NSWindowCollectionBehaviorFullScreenPrimary];
        }
    }

    // Create the view switch toolbar
    [toolbarManager setToolbar];
    
	// Tell the document to reload its syntax
	[[self document] rebuildSyntaxMatchers];
}

// == Project pane layout ==

- (void) layoutPanes {
    if ([projectPanes count] == 0) {
        return;
    }

    [projectPanes makeObjectsPerformSelector: @selector(removeFromSuperview)];
    [splitViews makeObjectsPerformSelector: @selector(removeFromSuperview)];
    [splitViews removeAllObjects];
    [[panesView subviews] makeObjectsPerformSelector:
        @selector(removeFromSuperview)];

    if ([projectPanes count] == 1) {
        // Just one pane
        IFProjectPane* firstPane = [projectPanes objectAtIndex: 0];

        [firstPane setController: self];
        
        [[firstPane paneView] setFrame: [panesView bounds]];
        [panesView addSubview: [firstPane paneView]];
    } else {
        // Create the splitViews
        int view, nviews;
        double dividerWidth = 5;

        nviews = [projectPanes count];
        for (view=0; view<nviews-1; view++) {
            NSSplitView* newView = [[ThinSplitView alloc] init];

            [newView setVertical: YES];
            [newView setDelegate: self];
            [newView setAutoresizingMask: (NSUInteger) (NSViewWidthSizable|NSViewHeightSizable)];

            dividerWidth = [newView dividerThickness];

            [splitViews addObject: [newView autorelease]];
        }

        // Remaining space for other dividers
        double remaining = [panesView bounds].size.width - dividerWidth*(double)(nviews-1);
        double totalRemaining = [panesView bounds].size.width;
        double viewWidth = floor(remaining / (double)nviews);
		
		// Work out the widths of the dividers using the preferences
		NSMutableArray* realDividerWidths = [NSMutableArray array];
		NSArray* dividerProportions = [[NSUserDefaults standardUserDefaults] objectForKey: IFSplitViewSizes];
		
		if (![dividerProportions isKindOfClass: [NSArray class]] || [dividerProportions count] <= 0) 
			dividerProportions = [NSArray arrayWithObject: [NSNumber numberWithFloat: 1.0]];
		
		float totalWidth = 0;
		
		for (view=0; view<nviews; view++) {
			float width;
			
			if (view >= [dividerProportions count]) {
				width = [[dividerProportions objectAtIndex: [dividerProportions count]-1] floatValue];
			} else {
				width = [[dividerProportions objectAtIndex: view] floatValue];
			}
			
			if (width <= 0) width = 1.0;
			[realDividerWidths addObject: [NSNumber numberWithFloat: width]];
			
			totalWidth += width;
		}
		
		// Work out the actual widths to use, and size and add the views appropriately
		float proportion = remaining / totalWidth;

        //NSRect paneBounds = [panesView bounds];
        
        // Insert the views
        NSSplitView* lastView = nil;
        for (view=0; view<nviews-1; view++) {
            // Garner some information about the views we're dealing with
            NSSplitView*   thisView = [splitViews objectAtIndex: view];
            IFProjectPane* pane     = [projectPanes objectAtIndex: view];
            NSView*        thisPane = [[projectPanes objectAtIndex: view] paneView];

            [pane setController: self];
			
			viewWidth = floorf(proportion * [[realDividerWidths objectAtIndex: view] floatValue]);

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
                //[lastView adjustSubviews];
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

        [[projectPanes lastObject] setController: self];

        finalFrame.origin.x += viewWidth + dividerWidth;
        finalFrame.size.width = totalRemaining;
        [finalPane setFrame: finalFrame];
        
        [lastView addSubview: finalPane];
        [lastView adjustSubviews];
    }
}

- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification {
	// Update the preferences with the view widths
	int nviews = [projectPanes count];
	int view;
	
	NSMutableArray* viewSizes = [NSMutableArray array];
	
	float totalWidth = [[self window] frame].size.width;
	
	for (view=0; view<nviews; view++) {
		IFProjectPane* pane = [projectPanes objectAtIndex: view];
		NSRect paneFrame = [[pane paneView] frame];
		
		[viewSizes addObject: [NSNumber numberWithFloat: paneFrame.size.width/totalWidth]];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject: viewSizes
											  forKey: IFSplitViewSizes];
}


// == Toolbar item validation ==

- (BOOL) canDebug {
	// Can only debug Z-Code Inform 6 games
	return ![[[self document] settings] usingNaturalInform] && [[[self document] settings] zcodeVersion] < 16;
}

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
	BOOL isRunning = [[self gamePage] isRunningGame];
		
	if (itemSelector == @selector(continueProcess:) ||
		itemSelector == @selector(stepOverProcess:) ||
		itemSelector == @selector(stepIntoProcess:) ||
		itemSelector == @selector(stepOutProcess:)) {
		return isRunning?waitingAtBreakpoint:NO;
	}
	
	if (itemSelector == @selector(pauseProcess:) &&
		![self canDebug]) {
		return NO;
	}
			
	if (itemSelector == @selector(stopProcess:) ||
		itemSelector == @selector(pauseProcess:)) {
		return isRunning;
	}
	
	if (itemSelector == @selector(compileAndDebug:) ||
		  itemSelector == @selector(setBreakpoint:) ||
		  itemSelector == @selector(deleteBreakpoint:)) {
		if (![self canDebug]) {
            [menuItem setHidden: YES];
			return NO;
		} else {
			[menuItem setHidden: NO];
		}
	}
	
	if (itemSelector == @selector(compile:) || 
		itemSelector == @selector(release:) ||
		itemSelector == @selector(compileAndRun:) ||
		itemSelector == @selector(compileAndDebug:) ||
		itemSelector == @selector(replayUsingSkein:) ||
		itemSelector == @selector(compileAndRefresh:)) {
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
	
	if (itemSelector == @selector(lastCommand:) ||
		itemSelector == @selector(lastCommandInSkein:)) {
		return [[[[[self skeinPane] skeinPage] skeinView] skein] activeItem] != nil;
	}
	
	// Tabbing options
	if (itemSelector == @selector(tabSource:) 
		|| itemSelector == @selector(tabErrors:)
		|| itemSelector == @selector(tabIndex:)
		|| itemSelector == @selector(tabSkein:)
		|| itemSelector == @selector(tabTranscript:)
		|| itemSelector == @selector(tabGame:)
		|| itemSelector == @selector(tabDocumentation:)
		|| itemSelector == @selector(tabSettings:)
		|| itemSelector == @selector(switchPanes:)) {
		return [self currentTabView] != nil;
	}
	
	if (itemSelector == @selector(showIndexTab:)) {
		return [[[projectPanes objectAtIndex: 0] indexPage] canSelectIndexTab: [menuItem tag]];
	}
	
	// Heading options
	if (itemSelector	== @selector(showNextSection:)
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
	
	return YES;
}

// == View selection functions ==

- (void) performCompileWithRelease: (BOOL) release
                        forTesting: (BOOL) releaseForTesting
					   refreshOnly: (BOOL) onlyRefresh {
    IFProject* doc = [self document];
    BOOL buildBlorb = YES;
    
    if ([[doc settings] usingNaturalInform]) {
        IFI7OutputSettings* outputSettings = (IFI7OutputSettings*)[[doc settings] settingForClass: [IFI7OutputSettings class]];
        buildBlorb = [outputSettings createBlorbForRelease] && release;
    }
    else {
        IFOutputSettings* outputSettings = (IFOutputSettings*)[[doc settings] settingForClass: [IFOutputSettings class]];
        buildBlorb = [outputSettings createBlorbForRelease] && release;
    }
    
	
	[self removeHighlightsOfStyle: IFLineStyleError];
	[self removeHighlightsOfStyle: IFLineStyleExecutionPoint];
		
    // Save the project, without user interaction.
    // Note: We don't call [doc saveDocument: self]; because from 10.5 and upwards this performs
    // checks to see if the file has changed since last opened or saved, and shows a user dialog if so.
    // This is a problem for our application because the compiler output adds folders / files to the
    // saved bundle, making it look like it's changed.
    NSError* error;
    if( [doc fileURL] != nil ) {
        [doc saveToURL: [doc fileURL]
                ofType: [doc fileType]
      forSaveOperation: NSSaveOperation
                 error: &error];
    }
    
    [projectPanes makeObjectsPerformSelector: @selector(stopRunningGame)];
	
	[toolbarManager validateVisibleItems];
    
    // Set up the compiler
    IFCompiler* theCompiler = [doc compiler];
	[theCompiler setBuildForRelease: release
                         forTesting: releaseForTesting];
    [theCompiler setSettings: [doc settings]];
	
    if (![doc singleFile]) {
        
        // Create materials folder, in a sandbox friendly way
        [doc createMaterials];
        
        [theCompiler setOutputFile: [NSString stringWithFormat: @"%@/Build/output.%@",
            [[doc fileURL] path],
			[[doc settings] zcodeVersion]==256?@"ulx":[NSString stringWithFormat: @"z%i", [[doc settings] zcodeVersion]]]];
		
        if ([[doc settings] usingNaturalInform]) {
            [theCompiler setInputFile: [NSString stringWithFormat: @"%@",
                [[doc fileURL] path]]];
        } else {
            [theCompiler setInputFile: [NSString stringWithFormat: @"%@/Source/%@",
                [[doc fileURL] path], [doc mainSourceFile]]];
        }
        
        [theCompiler setDirectory: [NSString stringWithFormat: @"%@/Build", [[doc fileURL] path]]];
    } else {
        [theCompiler setInputFile: [NSString stringWithFormat: @"%@",
            [[doc fileURL] path]]];
        
        [theCompiler setDirectory: [NSString stringWithFormat: @"%@", [[[doc fileURL] path] stringByDeletingLastPathComponent]]];
		buildBlorb = NO;
    }
	
    // Time to go!
	[self addProgressIndicator: [theCompiler progress]];
    [[theCompiler progress] startProgress];
	
	if (onlyRefresh) {
		[theCompiler addNaturalInformStage];
		[theCompiler prepareForLaunchWithBlorbStage: NO];
	} else {
		[theCompiler prepareForLaunchWithBlorbStage: buildBlorb];
	}

    [theCompiler launch];
    
    isCompiling = YES;
	
    if ( [[IFPreferences sharedPreferences] showConsoleDuringBuilds] ) {
         [[projectPanes objectAtIndex: 1] selectViewOfType: IFErrorPane];
    }
}

- (IBAction)saveDocument:(id)sender {
	// Need to call prepareToCompile here as well to give the project pane a chance to shut down any editing operations that might be ongoing
	for( IFProjectPane* pane in projectPanes ) {
		[pane prepareToCompile];
	}

    NSDocument* doc = [self document];

    // Save the project, without user interaction.
    // Note: We don't call [doc saveDocument: self]; because from 10.5 and upwards this performs
    // checks to see if the file has changed since last opened or saved, and shows a user dialog if so.
    // This is a problem for our application because the compiler output adds folders / files to the
    // saved bundle, making it look like it's changed.
    NSError* error;
    if( [doc fileURL] != nil ) {
        [doc saveToURL: [doc fileURL]
                ofType: [doc fileType]
      forSaveOperation: NSSaveOperation
                 error: &error];
    }
}

- (IBAction) release: (id) sender {
    compileFinishedAction = @selector(saveCompilerOutput);
	[self performCompileWithRelease: YES
                         forTesting: NO
						refreshOnly: NO];
}

- (IBAction) releaseForTesting: (id) sender {
    compileFinishedAction = @selector(saveCompilerOutput);
	[self performCompileWithRelease: YES
                         forTesting: YES
						refreshOnly: NO];
}

- (IBAction) compile: (id) sender {
    compileFinishedAction = @selector(saveCompilerOutput);
	[self performCompileWithRelease: NO
                         forTesting: NO
						refreshOnly: NO];
}

- (IBAction) compileAndRefresh: (id) sender {
	compileFinishedAction = @selector(refreshIndexTabs);
	if (!noChangesSinceLastRefresh 
		|| [[IFPreferences sharedPreferences] runBuildSh]) {
		[self performCompileWithRelease: NO
                             forTesting: NO
							refreshOnly: YES];
	} else {
		[self refreshIndexTabs];
	}
}

- (IBAction) compileAndRun: (id) sender {
	[[[projectPanes objectAtIndex: 1] gamePage] setPointToRunTo: nil];
	[[[projectPanes objectAtIndex: 1] gamePage] setTestMe: NO];
    compileFinishedAction = @selector(runCompilerOutput);
	
	// Only actually compile if there are undo actions added since the last compile
    [self performCompileWithRelease: NO
                         forTesting: NO
                        refreshOnly: NO];

	waitingAtBreakpoint = NO;
}

- (IBAction) testMe: (id) sender {
	[[[projectPanes objectAtIndex: 1] gamePage] setPointToRunTo: nil];
	[[[projectPanes objectAtIndex: 1] gamePage] setTestMe: YES];
    compileFinishedAction = @selector(runCompilerOutput);
	
    [self performCompileWithRelease: NO
                         forTesting: NO
                        refreshOnly: NO];
	
	waitingAtBreakpoint = NO;
}

- (IBAction) replayUsingSkein: (id) sender {
    compileFinishedAction = @selector(runCompilerOutputAndReplay);
	
    [self performCompileWithRelease: NO
                         forTesting: NO
                        refreshOnly: NO];
	
	waitingAtBreakpoint = NO;
}

- (IBAction) replayEntireSkein: (id) sender {
	compileFinishedAction = @selector(runCompilerOutputAndEntireSkein);
	
	// Always recompile
	[self performCompileWithRelease: NO
                         forTesting: NO
						refreshOnly: NO];
	
	waitingAtBreakpoint = NO;
}

- (IBAction) compileAndDebug: (id) sender {
	[[[projectPanes objectAtIndex: 1] gamePage] setPointToRunTo: nil];
	[[[projectPanes objectAtIndex: 1] gamePage] setTestMe: NO];
	compileFinishedAction = @selector(debugCompilerOutput);
    [self performCompileWithRelease: NO
                         forTesting: NO
						refreshOnly: NO];
	
	waitingAtBreakpoint = NO;
}

- (IBAction) stopProcess: (id) sender {
	[projectPanes makeObjectsPerformSelector: @selector(stopRunningGame)];
	[self removeHighlightsOfStyle: IFLineStyleExecutionPoint];
}

- (IBAction) openMaterials: (id) sender {
	// Work out where the materials folder is located
	NSString* materialsPath = [[self document] materialsPath];
	
	// Create the folder if necessary
    IFProject* doc = [self document];
    if (![doc singleFile]) {
        
        // Create materials folder, in a sandbox friendly way, with an icon
        [doc createMaterials];
    }

	// Open the folder if it exists
	BOOL isDir;
	if ([[NSFileManager defaultManager] fileExistsAtPath: materialsPath
											 isDirectory: &isDir]) {
		if (!isDir) {
			// Odd; the materials folder is a file. We open the containing path so the user can see this and correct it if they like
			[[NSWorkspace sharedWorkspace] openFile: [materialsPath stringByDeletingLastPathComponent]];
		} else {
			[[NSWorkspace sharedWorkspace] openFile: materialsPath];
		}
	}
}

- (IBAction) exportIFiction: (id) sender {
	// Compile and export the iFiction metadata
	compileFinishedAction = @selector(saveIFiction);
	
	// Presumably we need a full compile to generate the metadata?
	[self performCompileWithRelease: NO
                         forTesting: NO
						refreshOnly: NO];
}

- (void) saveIFiction {
	// IFiction compilation has finished
	noChangesSinceLastCompile = noChangesSinceLastRefresh = YES;
	
	// Work out where the iFiction file should be
	NSString* iFictionPath = [[[self document] fileName] stringByAppendingPathComponent: @"Metadata.ifiction"];
	
	// Prompt the user to save the iFiction file if it exists
	if ([[NSFileManager defaultManager] fileExistsAtPath: iFictionPath]) {
		NSString* file = [[[self document] fileName] lastPathComponent];
		file = [file stringByDeletingPathExtension];
		
		// Setup a save panel
		NSSavePanel* panel = [NSSavePanel savePanel];
		
		[panel setAccessoryView: nil];
		[panel setAllowedFileTypes:[NSArray arrayWithObject:@"iFiction"]];
		[panel setCanSelectHiddenExtension: YES];
		[panel setDelegate: self];
		[panel setPrompt: @"Save iFiction record"];
		[panel setTreatsFilePackagesAsDirectories: NO];
        [panel setDirectoryURL:[NSURL fileURLWithPath:[[[self document] fileName] stringByDeletingLastPathComponent]]]; // FIXME: preferences
        [panel setNameFieldStringValue:file];
		
		// Show it
        [panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result)
         {
             // Copy the file to the specified path
             if (result == NSOKButton) {
                 NSString* filepath = [[[panel URL] path] stringByResolvingSymlinksInPath];
                 NSError* error;
                 [[NSFileManager defaultManager] copyItemAtPath:iFictionPath toPath:filepath error:&error];
                 
                 // Hide the file extension if the user has requested it
                 NSMutableDictionary* attributes = [[[NSFileManager defaultManager] attributesOfItemAtPath:filepath error:&error] mutableCopy];
                 [attributes setObject: [NSNumber numberWithBool: [panel isExtensionHidden]]
                                forKey: NSFileExtensionHidden];
                 [[NSFileManager defaultManager] setAttributes: attributes
                                                  ofItemAtPath: filepath error:&error];
                 [attributes release];
             }
         }];
	} else {
		// Oops, failed to generate an iFiction record
        [IFUtility runAlertWarningWindow: [self window]
                                   title: @"The compiler failed to produce an iFiction record"
                                 message: @"The compiler failed to create an iFiction record; check the errors page to see why."];
	}
}

// = Displaying a specific index tab =

- (IBAction) showIndexTab: (id) sender {
	int tag = [sender tag];
	
	for( IFProjectPane* pane in projectPanes ) {
		[[pane indexPage] switchToTab: tag];
	}
	
	[[self indexPane] selectViewOfType: IFIndexPane];
}

// = Things to do after the compiler has finished =

- (void) refreshIndexTabs {
	// Display the index pane
	[[self indexPane] selectViewOfType: IFIndexPane];
	noChangesSinceLastRefresh = YES;
}

- (void) saveCompilerOutput {
	// Check to see if one of the compile controllers has already got a save location for the game
	IFCompilerController* paneController = [[projectPanes objectAtIndex: 0] compilerController];
	NSString* copyLocation = [paneController blorbLocation];
	
	// Show the 'success' pane
	[[projectPanes objectAtIndex: 1] selectViewOfType: IFErrorPane];
	
	if (copyLocation != nil) {
        NSError* error;
		// Copy the result to the specified location (overwriting any existing file)
		if ([[NSFileManager defaultManager] fileExistsAtPath: copyLocation]) {
			[[NSFileManager defaultManager] removeItemAtPath: copyLocation
                                                       error: &error];
		}
		
		[[NSFileManager defaultManager] copyItemAtPath: [[[self document] compiler] outputFile]
                                                toPath: copyLocation
                                                 error: &error];
	} else {	
		// Setup a save panel
		NSSavePanel* panel = [NSSavePanel savePanel];
		//IFCompilerSettings* settings = [[self document] settings];

		NSString* file = [[[self document] fileName] lastPathComponent];
		file = [file stringByDeletingPathExtension];

		[panel setAccessoryView: nil];
		//[panel setRequiredFileType: [settings fileExtension]];
		[panel setAllowedFileTypes:[NSArray arrayWithObject:[[[[self document] compiler] outputFile] pathExtension]]];
		[panel setCanSelectHiddenExtension: YES];
		[panel setDelegate: self];
		[panel setPrompt: @"Save"];
		[panel setTreatsFilePackagesAsDirectories: NO];
        [panel setNameFieldStringValue:file];
        //NSArray* urls = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
        //[panel setDirectoryURL:[urls objectAtIndex:0]]; // FIXME: preferences

		// Show it
        [panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result)
         {
             if (result == NSOKButton) {
                 NSError* error;
                 NSString* whereToSave = [[panel URL] path];
                 
                 // If the file already exists, then delete it
                 if ([[NSFileManager defaultManager] fileExistsAtPath: whereToSave]) {
                     if (![[NSFileManager defaultManager] removeItemAtPath: whereToSave
                                                                     error: &error]) {
                         // File failed to delete
                         [[NSRunLoop currentRunLoop] performSelector: @selector(failedToSave:)
                                                              target: self
                                                            argument: whereToSave
                                                               order: 128
                                                               modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
                     }
                 }
                 
                 // Copy the file
                 if (![[NSFileManager defaultManager] copyItemAtPath: [[[self document] compiler] outputFile]
                                                              toPath: whereToSave
                                                               error: &error]) {
                     // File failed to save
                     [[NSRunLoop currentRunLoop] performSelector: @selector(failedToSave:)
                                                          target: self
                                                        argument: whereToSave
                                                           order: 128
                                                           modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
                 }
             } else {
                 // Change nothing
             }
         }];
	}
}

- (void) runCompilerOutput {
	waitingAtBreakpoint = NO;
	noChangesSinceLastCompile = noChangesSinceLastRefresh = YES;
    [[[projectPanes objectAtIndex: 1] gamePage] startRunningGame: [[[self document] compiler] outputFile]];
    
    [toolbarManager validateVisibleItems];
}

- (void) runCompilerOutputAndReplay {
	[skeinNodeStack release]; skeinNodeStack = nil;
	
	noChangesSinceLastCompile = noChangesSinceLastRefresh = YES;
	[[[projectPanes objectAtIndex: 1] gamePage] setPointToRunTo: [[[self document] skein] activeItem]];
	[[[projectPanes objectAtIndex: 1] gamePage] setTestMe: NO];
	[self runCompilerOutput];
}

- (void) debugCompilerOutput {
	waitingAtBreakpoint = NO;
	noChangesSinceLastCompile = YES;
	[[[projectPanes objectAtIndex: 1] gamePage] activateDebug];
    [[[projectPanes objectAtIndex: 1] gamePage] startRunningGame: [[[self document] compiler] outputFile]];

    [toolbarManager validateVisibleItems];
}

- (void) compilerFinished: (NSNotification*) not {
    int exitCode = [[[not userInfo] objectForKey: @"exitCode"] intValue];

    NSFileWrapper* buildDir;
	
	[self removeProgressIndicator: [[[self document] compiler] progress]];
	
	if (exitCode != 0 || [[not object] problemsURL] != nil) {
		// Show the errors pane if there was an error while compiling
		[[projectPanes objectAtIndex: 1] selectViewOfType: IFErrorPane];
	}

	// Show the 'build results' file
	NSString* buildPath = [NSString stringWithFormat: @"%@/Build", [[self document] fileName]];
    buildDir = [[NSFileWrapper alloc] initWithPath: buildPath];
    [buildDir autorelease];

    int x;
    for (x=0; x<[projectPanes count]; x++) {
        IFProjectPane* pane = [projectPanes objectAtIndex: x];

        [[pane compilerController] showContentsOfFilesIn: buildDir
												fromPath: buildPath];
    }
	
	// Update the index tab(s) (if there's anything to update)
	for (x=0; x<[projectPanes count]; x++) {
        IFProjectPane* pane = [projectPanes objectAtIndex: x];
		[[pane indexPage] updateIndexView];
	}

	// Reload the index file
	[[self document] reloadIndexFile];
	
	// Update the index in the controller
	[[IFIsFiles sharedIFIsFiles] updateFiles];
	[[IFIsIndex sharedIFIsIndex] updateIndexFrom: self];

    if (exitCode == 0) {
        // Success!
        if ([self respondsToSelector: compileFinishedAction]) {
            [self performSelector: compileFinishedAction];
        }
    }

    isCompiling = NO;
    [toolbarManager validateVisibleItems];

	// Update the document syntax files
	[[self document] rebuildSyntaxMatchers];
}

- (void)compilerFaultAlertDidEnd: (NSWindow *)sheet
                      returnCode:(int)returnCode
                     contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertDefaultReturn) {
        [[NSRunLoop currentRunLoop] performSelector: @selector(saveCompilerOutput)
											 target: self
										   argument: nil
											  order: 128
											  modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]]; // Try agin
    } else {
        // Do nothing
    }
}

- (void) failedToSave: (NSString*)whereToSave {
	// Report that a file failed to save
	NSBeginAlertSheet([IFUtility localizedString: @"Unable to save file"],
					  [IFUtility localizedString: @"Retry"],
					  [IFUtility localizedString: @"Cancel"], nil,
					  [self window], self,
					  @selector(compilerFaultAlertDidEnd:returnCode:contextInfo:),
					  nil, nil,
					  [IFUtility localizedString: @"An error was encountered while trying to save the file '%@'"],
					  [whereToSave lastPathComponent]);
}

// = Communication from the containing panes =
- (IFProjectPane*) sourcePane {
	// Returns the current pane containing the source code (or an appropriate pane that source code can be displayed in)
    int paneToUse = 0;
    int x;
	
    for (x=0; x<[projectPanes count]; x++) {
        IFProjectPane* thisPane = [projectPanes objectAtIndex: x];
		
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

	return [projectPanes objectAtIndex: paneToUse];
}

- (IFProjectPane*) auxPane {
	// Returns the auxiliary pane: the one to use for displaying documentation, etc
    int paneToUse = -1;
    int x;
	
    for (x=0; x<[projectPanes count]; x++) {
        IFProjectPane* thisPane = [projectPanes objectAtIndex: x];
		
        if ([thisPane currentView] == IFDocumentationPane) {
			// Doc pane has priority
            paneToUse = x;
            break;
        }
    }
	
	if (paneToUse == -1) {
		paneToUse = 1;
		for (x=[projectPanes count]-1; x>=0; x--) {
			IFProjectPane* thisPane = [projectPanes objectAtIndex: x];
			
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
	
	return [projectPanes objectAtIndex: paneToUse];
}

- (IFProjectPane*) indexPane {
	// Returns the current pane containing the index
    int x;
	
    for (x=0; x<[projectPanes count]; x++) {
        IFProjectPane* thisPane = [projectPanes objectAtIndex: x];
		
        if ([thisPane currentView] == IFIndexPane) {
			// This is the index pane
			return thisPane;
        }
    }
	
	// No index pane showing: use the aux pane
	return [self auxPane];
}

- (IFProjectPane*) transcriptPane: (BOOL) canBeSkein {
	// Returns the current pane containing the transcript
    int x;
	IFProjectPane* skeinPane = nil;
	IFProjectPane* notSkeinPane = nil;
	
    for (x=0; x<[projectPanes count]; x++) {
        IFProjectPane* thisPane = [projectPanes objectAtIndex: x];
		
        if ([thisPane currentView] == IFTranscriptPane) {
			// This is the transcript pane
			return thisPane;
        } else if ([thisPane currentView] == IFSkeinPane) {
			skeinPane = thisPane;
		} else {
			notSkeinPane = thisPane;
		}
    }
	
	// If canBeSkein is off, then use the pane that does not contain the skein
	if (!canBeSkein && skeinPane && notSkeinPane) return notSkeinPane;
	
	// No transcript pane showing: use the auxilary pane
	return [self auxPane];
}

- (IFProjectPane*) oppositePane: (IFProjectPane*) pane {
	// Find this pane
	int index = [projectPanes indexOfObjectIdenticalTo: pane];
	if (index == NSNotFound) return nil;
	
	// Get it's 'opposite'
	int opposite = index-1;
	if (opposite < 0) opposite = [projectPanes count]-1;
	
	return [projectPanes objectAtIndex: opposite];
}

- (IFProjectPane*) skeinPane {
	// Returns the current pane containing the skein
    int x;
	
    for (x=0; x<[projectPanes count]; x++) {
        IFProjectPane* thisPane = [projectPanes objectAtIndex: x];
		
        if ([thisPane currentView] == IFSkeinPane) {
			// This is the skein pane
			return thisPane;
        }
    }
	
	// No skein pane showing: use the auxilary pane
	return [self auxPane];
}

- (BOOL) loadNaturalInformExtension: (NSString*) filename {
	// Get the author and extension name
	NSArray* components = [filename pathComponents];
	if ([components count] != 2) {
		if ([filename characterAtIndex: 0] == '/' && [[NSFileManager defaultManager] fileExistsAtPath: filename]) {
			// Try to find the old document
			NSDocument* newDoc = [[NSDocumentController sharedDocumentController] documentForFileName: filename];

			if (newDoc == nil) {
				// Not loaded yet: load the extension in
                NSError* error;
				newDoc = [[IFSingleFile alloc] initWithContentsOfURL: [NSURL fileURLWithPath:filename]
															  ofType: @"Inform 7 extension"
                                                               error: &error];

				[[NSDocumentController sharedDocumentController] addDocument: newDoc];
				[newDoc makeWindowControllers];
				[newDoc showWindows];
                [newDoc autorelease];
			} else {
				// Force it to the front
				for( NSWindowController* controller in [newDoc windowControllers] ) {
					[[controller window] makeKeyAndOrderFront: self];
				}
			}
			
			return YES;
		}
		
		return NO;
	}
	
	NSString* author = [components objectAtIndex: 0];
	NSString* extension = [components objectAtIndex: 1];
	
	// Search for this extension
	NSArray* possibleExtensions = [[IFExtensionsManager sharedNaturalInformExtensionsManager] filesInExtensionWithName: author];
	if ([possibleExtensions count] <= 0) return NO;
	
	for( NSString* extnFile in possibleExtensions ) {
		if ([[extnFile lastPathComponent] caseInsensitiveCompare: extension] == NSOrderedSame) {
			// This is the extension file we need to open
			
			// Try to find the old document
			NSDocument* newDoc = [[NSDocumentController sharedDocumentController] documentForFileName: extnFile];
			
			if (newDoc == nil) {
                // If it doesn't exist, then construct it
                NSError* error;
				newDoc = [[IFSingleFile alloc] initWithContentsOfURL: [NSURL fileURLWithPath:extnFile]
                                                              ofType: @"Inform 7 extension"
                                                               error: &error];
				
				[[NSDocumentController sharedDocumentController] addDocument: newDoc];
				[newDoc makeWindowControllers];
				[newDoc showWindows];
                [newDoc autorelease];
			} else {
				// Force it to the front
				for( NSWindowController* controller in [newDoc windowControllers] ) {
					[[controller window] makeKeyAndOrderFront: self];
				}
			}
			
			return YES;
		}
	}
	
	return NO;
}

- (BOOL) selectSourceFile: (NSString*) fileName {
	if ([[self document] storageForFile: fileName] != nil) {
		// Load this file
		[projectPanes makeObjectsPerformSelector: @selector(showSourceFile:)
									  withObject: fileName];

		// Display a warning if this is a temporary file
		if (![lastFilename isEqualToString: fileName] && [[self document] fileIsTemporary: fileName]) {
            [IFUtility runAlertWarningWindow: [self window]
                                       title: @"Opening temporary file"
                                     message: @"You are opening a temporary file"];
		}
	} else if (![self loadNaturalInformExtension: fileName]) {
		// Display an error if we couldn't find the file
        [IFUtility runAlertWarningWindow: [self window]
                                   title: @"Unable to open source file"
                                 message: @"Unable to open source file description"];
	}

	[lastFilename release];
	lastFilename = [fileName copy];

    return YES;
}

- (IFSourcePage*) sourcePage {
	return [[self sourcePane] sourcePage];
}

- (NSString*) selectedSourceFile {
	return [[self sourcePage] currentFile];
}

- (void) moveToSourceFileLine: (int) line {
	IFProjectPane* thePane = [self sourcePane];

    [thePane selectViewOfType: IFSourcePane];
    [[thePane sourcePage] moveToLine: line];
    [[self window] makeFirstResponder: [thePane activeView]];
}

- (void) moveToSourceFilePosition: (int) location {
	IFProjectPane* thePane = [self sourcePane];
	
    [thePane selectViewOfType: IFSourcePane];
    [[thePane sourcePage] moveToLocation: location];
    [[self window] makeFirstResponder: [thePane activeView]];
}

- (void) selectSourceFileRange: (NSRange) range {
	IFProjectPane* thePane = [self sourcePane];
	
    [thePane selectViewOfType: IFSourcePane];
    //[[thePane sourcePage] selectRange: range];
    [[thePane sourcePage] indicateRange: range];

    [[self window] makeFirstResponder: [thePane activeView]];
}

- (void) removeHighlightsInFile: (NSString*) file
						ofStyle: (enum lineStyle) style {
	file = [[self document] pathForFile: file];
	
	NSMutableArray* lineHighlight = [lineHighlighting objectForKey: file];
	if (lineHighlight == nil) return;
	
	BOOL updated = NO;
	
	// Loop through each highlight, and remove any of this style
	int x;
	for (x=0; x<[lineHighlight count]; x++) {
		if ([[[lineHighlight objectAtIndex: x] objectAtIndex: 1] intValue] == style) {
			[lineHighlight removeObjectAtIndex: x];
			updated = YES;
			x--;
		}
	}
	
	if (updated) {
		for( IFProjectPane* pane in projectPanes ) {
			if ([[[self document] pathForFile: [[pane sourcePage] currentFile]] isEqualToString: file]) {
				[[pane sourcePage] updateHighlightedLines];
			}
		}
	}
}

- (void) removeHighlightsOfStyle: (enum lineStyle) style {
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

- (void) highlightSourceFileLine: (int) line
						  inFile: (NSString*) file {
    [self highlightSourceFileLine: line
						   inFile: file
                            style: IFLineStyleNeutral];
}

- (void) highlightSourceFileLine: (int) line
						  inFile: (NSString*) file
                           style: (enum lineStyle) style {
	// Get the 'true' path to this file
	file = [[self document] pathForFile: file];
	
	// See if there's a document that manages this file
	NSDocument* fileDocument = [[NSDocumentController sharedDocumentController] documentForFileName: file];
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
	NSMutableArray* lineHighlight = [lineHighlighting objectForKey: file];
	
	if (lineHighlight == nil) {
		lineHighlight = [NSMutableArray array];
		[lineHighlighting setObject: lineHighlight
							 forKey: file];
	}
	
	[lineHighlight addObject: [NSArray arrayWithObjects: [NSNumber numberWithInt: line], 
		[NSNumber numberWithInt: style], 
		nil]];
	
	// Display the highlight
	if (style >= IFLineStyle_Temporary && style < IFLineStyle_LastTemporary)
		temporaryHighlights = YES;
		
	for( IFProjectPane* pane in projectPanes ) {
		if ([[[self document] pathForFile: [[pane sourcePage] currentFile]] isEqualToString: file]) {
			[[pane sourcePage] updateHighlightedLines];

			if (temporaryHighlights) {
				[[pane sourcePage] indicateLine: line];
			}
		}
	}
}

- (NSArray*) highlightsForFile: (NSString*) file {
	file = [[self document] pathForFile: file];
	
	return [lineHighlighting objectForKey: file];
}

// = Debugging controls =

- (IFProjectPane*) gamePane {
	// Return the pane that we're displaying/going to display the game in
	for( IFProjectPane* pane in projectPanes ) {
		if ([[pane gamePage] isRunningGame]) return pane;
	}
	
	return nil;
}

- (IFGamePage*) gamePage {
	return [[self gamePane] gamePage];
}

- (void) restartRunning {
	// Perform actions to switch back to the game when we click on continue, etc
	[[self window] makeFirstResponder: [[self gamePage] zoomView]];
	[self removeHighlightsOfStyle: IFLineStyleExecutionPoint];	

	[toolbarManager validateVisibleItems];
}

- (void) pauseProcess: (id) sender {
	[[self gamePage] pauseRunningGame];
}

- (void) continueProcess: (id) sender {
	BOOL isRunning = [[self gamePage] isRunningGame];

	if (isRunning && waitingAtBreakpoint) {
		waitingAtBreakpoint = NO;
		[self restartRunning];
		[[[[self gamePage] zoomView] zMachine] continueFromBreakpoint];
	}
}

- (void) stepOverProcess: (id) sender {
	BOOL isRunning = [[self gamePage] isRunningGame];

	if (isRunning && waitingAtBreakpoint) {
		waitingAtBreakpoint = NO;
		[self restartRunning];
		[[[[self gamePage] zoomView] zMachine] stepFromBreakpoint];
	}
}

- (void) stepOutProcess: (id) sender {
	BOOL isRunning = [[self gamePage] isRunningGame];

	if (isRunning && waitingAtBreakpoint) {
		waitingAtBreakpoint = NO;
		[self restartRunning];
		[[[[self gamePage] zoomView] zMachine] finishFromBreakpoint];
	}
}

- (void) stepIntoProcess: (id) sender {
	BOOL isRunning = [[self gamePage] isRunningGame];

	if (isRunning && waitingAtBreakpoint) {
		waitingAtBreakpoint = NO;
		[self restartRunning];
		[[[[self gamePage] zoomView] zMachine] stepIntoFromBreakpoint];
	}
}

- (void) hitBreakpoint: (int) pc {
	// Retrieve the game view
	IFGamePage* gamePane = [self gamePage];
	ZoomView* zView = [gamePane zoomView];
	
	NSString* filename = [[zView zMachine] sourceFileForAddress: pc];
	int line_no = [[zView zMachine] lineForAddress: pc];
	int char_no = [[zView zMachine] characterForAddress: pc];
		
	if (line_no > -1 && filename != nil) {
		[[self sourcePage] showSourceFile: filename];
		
		if (char_no > -1)
			[[self sourcePage] moveToLine: line_no
								character: char_no];
		else
			[[self sourcePage] moveToLine: line_no];
		[self removeHighlightsOfStyle: IFLineStyleExecutionPoint];
		[self highlightSourceFileLine: line_no
							   inFile: filename
								style: IFLineStyleExecutionPoint];
		[[self window] makeFirstResponder: [[self sourcePane] activeView]];
	}
	
	waitingAtBreakpoint = YES;
	
	[toolbarManager validateVisibleItems];
}

- (NSString*) pathToIndexFile {
	IFProject* proj = [self document];
	
	NSString* buildPath = [NSString stringWithFormat: @"%@/Build", [[proj fileURL] path]];
	NSString* indexPath = [buildPath stringByAppendingPathComponent: @"index.html"];
	
	if ([[NSFileManager defaultManager] fileExistsAtPath: indexPath])
		return indexPath;
	else
		return nil;
}

- (IFIntelFile*) currentIntelligence {
	return [[self sourcePage] currentIntelligence];
}

// = Documentation controls =
- (void) docIndex: (id) sender {
	[[[self auxPane] documentationPage] openURL: [NSURL URLWithString: @"inform:/index.html"]];
}

- (void) docRecipes: (id) sender {
	[[[self auxPane] documentationPage] openURL: [NSURL URLWithString: @"inform:/Rdoc1.html"]];
}

- (void) docExtensions: (id) sender {
	[[[self auxPane] extensionsPage] openURL: [NSURL URLWithString: @"inform://Extensions/Extensions.html"]];
}

// = Adding files =
- (void) addNewFile: (id) sender {
	IFNewProjectFile* npf = [[IFNewProjectFile alloc] initWithProjectController: self];
	
	NSString* newFile = [npf getNewFilename];
	if (newFile) {
		if (![(IFProject*)[self document] addFile: newFile]) {
			NSBeginAlertSheet([IFUtility localizedString: @"Unable to create file"],
							  [IFUtility localizedString: @"FileUnable - Cancel"
                                                 default: @"Cancel"], nil, nil,
							  [self window], nil, nil, nil, nil,
                              @"%@",
							  [IFUtility localizedString: @"FileUnable - Description"
                                                 default: @"Inform was unable to create that file: most probably because a file already exists with that name"]);
		}
	}
	
	[[IFIsFiles sharedIFIsFiles] updateFiles];
	[npf release];
}

// = Skein delegate =

- (void) restartGame {
	if ([[[projectPanes objectAtIndex: 1] gamePage] isRunningGame]) {
		[[[projectPanes objectAtIndex: 1] gamePage] setPointToRunTo: nil];
		[[[projectPanes objectAtIndex: 1] gamePage] setTestMe: NO];
		[self runCompilerOutput];
	} else {
		//[self compileAndRun: self]; -- we do this when 'playToPoint' is called
	}
}

- (void) playToPoint: (ZoomSkeinItem*) point
		   fromPoint: (ZoomSkeinItem*) currentPoint {
	if ([[[projectPanes objectAtIndex: 1] gamePage] isRunningGame]) {
		id inputSource = [ZoomSkein inputSourceFromSkeinItem: currentPoint
													  toItem: point];
	
		ZoomView* zView = [[self gamePage] zoomView];
		GlkView* gView = [[self gamePage] glkView];
		
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
		[[[projectPanes objectAtIndex: 1] gamePage] setPointToRunTo: point];
		[[[projectPanes objectAtIndex: 1] gamePage] setTestMe: NO];
	}
}

- (void) moveTranscriptToPoint: (ZoomSkeinItem*) point {
	// Set all the transcript views to the right item
	for( IFProjectPane* pane in projectPanes ) {
		[[[pane transcriptPage] transcriptLayout] transcriptToPoint: point];
		[[[pane transcriptPage] transcriptView] scrollToItem: point];
		[[[pane skeinPage] skeinView] highlightSkeinLine: point];
	}
}

- (void) transcriptToPoint: (ZoomSkeinItem*) point
			   switchViews: (BOOL) switchViews {
	// Select the transcript in the appropriate pane
	if (switchViews) {
		IFProjectPane* transcriptPane = [self transcriptPane: NO];
		[transcriptPane selectViewOfType: IFTranscriptPane];
	}
	
	[self moveTranscriptToPoint: point];
	
	// Highlight the item in the transcript view and skein view
	for( IFProjectPane* pane in projectPanes ) {
		[[[pane transcriptPage] transcriptView] setHighlightedItem: point];
	}
}

- (void) transcriptToPoint: (ZoomSkeinItem*) point {
	[self transcriptToPoint: point
				switchViews: YES];
}

- (void) cantDeleteActiveBranch {
    [IFUtility runAlertWarningWindow: [self window]
                               title: @"Can't delete active branch"
                             message: @"Can't delete active branch explanation"];
}

- (void) cantEditRootItem {
    [IFUtility runAlertWarningWindow: [self window]
                               title: @"Can't edit root item"
                             message: @"Can't edit root item explanation"];
}

- (void) skeinChanged: (NSNotification*) not {
	ZoomSkein* skein = [[self document] skein];
	
	if ([skein activeItem] != lastActiveItem) {
		[self moveTranscriptToPoint: [skein activeItem]];
		
		lastActiveItem = [skein activeItem];
		
		// Highlight the item in the transcript view
		for( IFProjectPane* pane in projectPanes ) {
			[[[pane transcriptPage] transcriptView] setHighlightedItem: nil];
			[[[pane transcriptPage] transcriptView] setActiveItem: lastActiveItem];
		}
	}
}

// = Policy delegates =

- (IFProjectPolicy*) generalPolicy {
	return generalPolicy;
}

- (IFProjectPolicy*) docPolicy {
	return docPolicy;
}

- (IFProjectPolicy*) extensionsPolicy {
	return extensionsPolicy;
}

// = Displaying progress =

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
				percentage: (float) newPercentage {
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

// = Debugging =

- (IBAction) showWatchpoints: (id) sender {
	[[IFInspectorWindow sharedInspectorWindow] showWindow: self];
	[[IFInspectorWindow sharedInspectorWindow] showInspectorWithKey: IFIsWatchInspector];
}

- (IBAction) showBreakpoints: (id) sender {
	[[IFInspectorWindow sharedInspectorWindow] showWindow: self];
	[[IFInspectorWindow sharedInspectorWindow] showInspectorWithKey: IFIsBreakpointsInspector];
}

// = Breakpoints =

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

- (IBAction) setBreakpoint: (id) sender {
	[[self activeSourcePage] setBreakpoint: sender];
}

- (IBAction) deleteBreakpoint: (id) sender {
	[[self activeSourcePage] deleteBreakpoint: sender];
}

- (void) updatedBreakpoints: (NSNotification*) not {
	// Update the breakpoint highlights
	[self removeHighlightsOfStyle: IFLineStyleBreakpoint];
	
	int x;
	
	for (x=0; x<[[self document] breakpointCount]; x++) {
		int line = [[self document] lineForBreakpointAtIndex: x];
		NSString* file = [[self document] fileForBreakpointAtIndex: x];
		
		[self highlightSourceFileLine: line+1
							   inFile: file
								style: IFLineStyleBreakpoint];
	}
}

// = Dealing with search panels =

- (void) searchSelectedItemAtLocation: (int) location
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
        NSDocument* newDoc = [[NSDocumentController sharedDocumentController] documentForFileName: filename];
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
		//[self moveToSourceFilePosition: location];
	}
}

// = Menu options =

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

// = Searching =

- (IBAction) searchDocs: (id) sender {
	if ( ([sender stringValue] == nil) ||
        ([[sender stringValue] isEqualToString: @""]) ) return;
    
    [[IFFindInFilesController sharedFindInFilesController] showFindInFilesWindow: self];
    [[IFFindInFilesController sharedFindInFilesController] startFindInFilesSearchWithPhrase: [sender stringValue]
                                                                           withLocationType: (IFFindLocation) (IFFindDocumentationBasic | IFFindDocumentationSource | IFFindDocumentationDefinitions)
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

// == The transcript menu ==

- (IBAction) lastCommand: (id) sender {
	// Display the transcript
	IFProjectPane* transcriptPane = [self transcriptPane: YES];
	IFTranscriptView* transcriptView = [[transcriptPane transcriptPage] transcriptView];

	if ([[[transcriptView transcriptLayout] skein] activeItem] == nil) {
		// No active item to show
		NSBeep();
		return;
	}
		
	// Scroll to the 'active' item in the transcript
	[transcriptPane selectViewOfType: IFTranscriptPane];
	[[transcriptView transcriptLayout] transcriptToPoint: [[[transcriptView transcriptLayout] skein] activeItem]];
	[transcriptView scrollToItem: [[[transcriptView transcriptLayout] skein] activeItem]];
}

- (IBAction) lastCommandInSkein: (id) sender {
	// Display the skein
	IFProjectPane* skeinPane = [self skeinPane];
	ZoomSkeinView* skeinView = [[skeinPane skeinPage] skeinView];

	if ([[skeinView skein] activeItem] == nil) {
		// No active item to show
		NSBeep();
		return;
	}
		
	// Scroll to the 'active' item in the skein
	[skeinPane selectViewOfType: IFSkeinPane];
	[skeinView scrollToItem: [[skeinView skein] activeItem]];
}

- (ZoomSkeinItem*) currentTranscriptCommand: (BOOL) preferBottom {
	// Get the 'current' command: the command presently at the top/bottom of the window (or the selected command if it's visible)
	IFProjectPane* transcriptPane = [self transcriptPane: YES];
	IFTranscriptView* transcriptView = [[transcriptPane transcriptPage] transcriptView];
	
	// Get the items that are currently showing in the transcript view
	ZoomSkeinItem* highlighted = [transcriptView highlightedItem];
	NSRect visibleRect = [transcriptView visibleRect];
	NSArray* visibleItems = [[transcriptView transcriptLayout] itemsInRect: visibleRect];
	
	// Some trivial cases
	if ([visibleItems count] <= 0) return nil;
	if ([visibleItems count] == 1) return [[visibleItems objectAtIndex: 0] skeinItem];
	if ([visibleItems count] == 2) return [[visibleItems objectAtIndex: preferBottom?1:0] skeinItem];
	
	// If the highlighted item is showing, then return that as the current item
	for( IFTranscriptItem* item in visibleItems ) {
		if ([item skeinItem] == highlighted) return highlighted;
	}
	
	// Return the upper/lower item depending on the value of preferBottom
	if (preferBottom) {
		return [[visibleItems objectAtIndex: [visibleItems count]-2] skeinItem];
	} else {
		return [[visibleItems objectAtIndex: 1] skeinItem];
	}
}

- (IBAction) lastChangedCommand: (id) sender {
	// Display the transcript
	IFProjectPane* transcriptPane = [self transcriptPane: YES];
	IFTranscriptView* transcriptView = [[transcriptPane transcriptPage] transcriptView];
	
	ZoomSkeinItem* currentItem = [self currentTranscriptCommand: NO];

	if (!currentItem) {
		// Can do nothing if there's no current items
		NSBeep();
		return;
	}
	
	// Find the last item
	IFTranscriptItem* lastItem = [[transcriptView transcriptLayout] lastChanged:
		[[transcriptView transcriptLayout] itemForItem: currentItem]];
	
	if (!lastItem) {
		// No previous item
		NSBeep();
		return;
	}
	
	// Move to the last item
	[transcriptView scrollToItem: [lastItem skeinItem]];
	[transcriptView setHighlightedItem: [lastItem skeinItem]];
}

- (IBAction) nextChangedCommand: (id) sender {
	// Display the transcript
	IFProjectPane* transcriptPane = [self transcriptPane: YES];
	IFTranscriptView* transcriptView = [[transcriptPane transcriptPage] transcriptView];
	
	ZoomSkeinItem* currentItem = [self currentTranscriptCommand: NO];
	
	if (!currentItem) {
		// Can do nothing if there's no current items
		NSBeep();
		return;
	}
	
	// Find the next item
	IFTranscriptItem* nextItem = [[transcriptView transcriptLayout] nextChanged: 
		[[transcriptView transcriptLayout] itemForItem: currentItem]];
	
	if (!nextItem) {
		// No previous item
		NSBeep();
		return;
	}
	
	// Move to the next item
	[transcriptView scrollToItem: [nextItem skeinItem]];
	[transcriptView setHighlightedItem: [nextItem skeinItem]];
}

- (IBAction) lastDifference: (id) sender {
	// Display the transcript
	IFProjectPane* transcriptPane = [self transcriptPane: YES];
	IFTranscriptView* transcriptView = [[transcriptPane transcriptPage] transcriptView];
	
	ZoomSkeinItem* currentItem = [self currentTranscriptCommand: NO];
	
	if (!currentItem) {
		// Can do nothing if there's no current items
		NSBeep();
		return;
	}
	
	// Find the last item
	IFTranscriptItem* lastItem = [[transcriptView transcriptLayout] lastDiff:
		[[transcriptView transcriptLayout] itemForItem: currentItem]];
	
	if (!lastItem) {
		// No previous item
		NSBeep();
		return;
	}
	
	// Move to the last item
	[transcriptView scrollToItem: [lastItem skeinItem]];
	[transcriptView setHighlightedItem: [lastItem skeinItem]];
}

- (IBAction) nextDifference: (id) sender {
	// Display the transcript
	IFProjectPane* transcriptPane = [self transcriptPane: YES];
	IFTranscriptView* transcriptView = [[transcriptPane transcriptPage] transcriptView];
	
	ZoomSkeinItem* currentItem = [self currentTranscriptCommand: NO];
	
	if (!currentItem) {
		// Can do nothing if there's no current items
		NSBeep();
		return;
	}
	
	// Find the next item
	IFTranscriptItem* nextItem = [[transcriptView transcriptLayout] nextDiff:
		[[transcriptView transcriptLayout] itemForItem: currentItem]];
	
	if (!nextItem) {
		// No previous item
		NSBeep();
		return;
	}
	
	// Move to the next item
	[transcriptView scrollToItem: [nextItem skeinItem]];
	[transcriptView setHighlightedItem: [nextItem skeinItem]];
}

- (IBAction) nextDifferenceBySkein: (id) sender {
	// Display the transcript
	IFProjectPane* transcriptPane = [self transcriptPane: YES];
	
	ZoomSkeinItem* currentItem = [self currentTranscriptCommand: NO];
	
	// Find the next item
	ZoomSkeinItem* nextSkeinItem = [currentItem nextDiff];
	if (!nextSkeinItem) nextSkeinItem = [[[[self document] skein] rootItem] nextDiff];
	
	if (!nextSkeinItem) {
		// No previous item
		NSBeep();
		return;
	}
	
	// Highlight this item
	for( IFProjectPane* pane in projectPanes ) {
		[[[pane transcriptPage] transcriptLayout] transcriptToPoint: nextSkeinItem];
		[[[pane transcriptPage] transcriptView] scrollToItem: nextSkeinItem];
		[[[pane transcriptPage] transcriptView] setHighlightedItem: nextSkeinItem];
		[[[pane skeinPage] skeinView] scrollToItem: nextSkeinItem];
	}

	[transcriptPane selectViewOfType: IFTranscriptPane];
}

// = UIDelegate methods =

// We only implement a fairly limited subset of the UI methods, mainly to help show status
- (void)						webView:(WebView *)sender 
	 runJavaScriptAlertPanelWithMessage:(NSString *)message {
	NSRunAlertPanel([IFUtility localizedString: @"JavaScript Alert"],
					message,
					[IFUtility localizedString: @"Continue"],
					nil, nil);
}

// = IFRuntimeErrorParser delegate methods =

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
	[[projectPanes objectAtIndex: 0] selectViewOfType: IFErrorPane];
}

// = The index menu =

- (void) updateWithSiblingsOfSymbol: (IFIntelSymbol*) symbol
							   menu: (NSMenu*) menu {
	//NSFont* smallFont = [NSFont systemFontOfSize: [NSFont smallSystemFontSize]];
	//NSDictionary* smallAttributes = [NSDictionary dictionaryWithObjectsAndKeys: smallFont, NSFontAttributeName, nil];
	
	while (symbol != nil) {
		// Last character of index item names is a newline character
		NSString* symbolName = [symbol name];
		symbolName = [symbolName substringToIndex: [symbolName length]-1];
		
		NSRange dashRange = [symbolName rangeOfString: @" - "];
		if (dashRange.location != NSNotFound && dashRange.location + 5 < [symbolName length]) {
			symbolName = [symbolName substringFromIndex: dashRange.location+3];
		}
		
		// Add the current symbol as a new menu item
		/*
		NSMenuItem* symbolItem = [[NSMenuItem alloc] init];
		[symbolItem setAttributedTitle: [[[NSAttributedString alloc] initWithString: symbolName
																		 attributes: smallAttributes]
			autorelease]];
		[symbolItem setRepresentedObject: symbol];
		[symbolItem setTarget: self];
		[symbolItem setAction: @selector(selectedIndexItem:)];

		[menu addItem: [symbolItem autorelease]];
		 */
		
		[menu addItemWithTitle: symbolName
						action: @selector(selectedIndexItem:)
				 keyEquivalent: @""];
		NSMenuItem* symbolItem = [[menu itemArray] lastObject];
		[symbolItem setRepresentedObject: symbol];
		
		// Process any children of this element into a submenu
		IFIntelSymbol* child = [symbol child];
		
		if (child != nil) {
			NSMenu* submenu = [[NSMenu alloc] init];
			[symbolItem setSubmenu: [submenu autorelease]];
			
			[self updateWithSiblingsOfSymbol: child
										menu: submenu];
		}

		// Move to the next sibling of this symbol
		symbol = [symbol sibling];
	}
}

- (void) selectedIndexItem: (id) sender {
	IFIntelSymbol* selectedItem = [sender representedObject];
	int lineNumber = [[self currentIntelligence] lineForSymbol: selectedItem]+1;
	
	if (lineNumber != NSNotFound) {
		[self removeAllTemporaryHighlights];
		[self highlightSourceFileLine: lineNumber
							   inFile: [[self sourcePage] currentFile]
								style: IFLineStyleHighlight];
		[self moveToSourceFileLine: lineNumber];
	}
}

// = Tabbing around =

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
			first = [[(NSView*)first subviews] objectAtIndex: 0];
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

- (IBAction) tabTranscript: (id) sender {
	[[self currentTabView] selectTabViewItemWithIdentifier: [[IFTranscriptPage class] description]];
	[self activateNearestTextView];
}

- (IBAction) tabGame: (id) sender {
	[[[self gamePane] tabView] selectTabViewItemWithIdentifier: [[IFGamePage class] description]];
	[[self window] makeFirstResponder: [[self gamePane] tabView]];
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
	[[self window] makeFirstResponder: [[[[projectPanes objectAtIndex: 0] tabView] selectedTabViewItem] view]];
	[self activateNearestTextView];
}

- (IBAction) gotoRightPane: (id) sender {
	[[self window] makeFirstResponder: [[[[projectPanes objectAtIndex: 1] tabView] selectedTabViewItem] view]];
	[self activateNearestTextView];
}

- (IBAction) switchPanes: (id) sender {
	NSTabView* newView = nil;
	
	if ([self currentTabView] == [(IFProjectPane*)[projectPanes objectAtIndex: 0] tabView]) {
		newView = [[projectPanes objectAtIndex: 1] tabView];
	} else {
		newView = [[projectPanes objectAtIndex: 0] tabView];
	}

	if (newView != nil) {
		[[self window] makeFirstResponder: [[newView selectedTabViewItem] view]];
		[self activateNearestTextView];
	}
}

// = Spell checking =

- (void) setSourceSpellChecking: (BOOL) spellChecking {
	// Update the panes
	for( IFProjectPane* pane in projectPanes ) {
		[[pane sourcePage] setSpellChecking: [[NSApp delegate] sourceSpellChecking]];
	}
}

// = CocoaGlk -> skein gateway (GlkAutomation) =

- (IBAction) glkTaskHasStarted: (id) sender {
	ZoomSkein* skein = [[self document] skein];
	
	[skein zoomInterpreterRestart];	
}

- (void) setGlkInputSource: (id) newSource {
	[glkInputSource release];
	glkInputSource = [newSource retain];
}

- (void) receivedCharacters: (NSString*) characters
					 window: (int) windowNumber
				   fromView: (GlkView*) view {
	ZoomSkein* skein = [[self document] skein];
	
	[skein outputText: characters];
}

- (void) userTyped: (NSString*) userInput
			window: (int) windowNumber
		 lineInput: (BOOL) isLineInput
		  fromView: (GlkView*) view {
	ZoomSkein* skein = [[self document] skein];

	[skein zoomWaitingForInput];
	if (isLineInput) {
		[skein inputCommand: userInput];
	} else {
		[skein inputCharacter: userInput];
	}
}

- (void) userClickedAtXPos: (int) xpos
					  ypos: (int) ypos
					window: (int) windowNumber
				  fromView: (GlkView*) view {
}

- (void) viewWaiting: (GlkView*) view {
	// Do nothing
}

- (void) viewIsWaitingForInput: (GlkView*) view {
	// Only do anything if there's at least one view waiting for input
	if (![view canSendInput]) return;
	
	// Get the next command from the input source (which is a zoom-style input source)
	NSString* nextCommand = [glkInputSource nextCommand];
	
	if (nextCommand == nil) {
		[view removeAutomationObject: self];
		[view addOutputReceiver: self];
		[view setAlwaysPageOnMore: NO];
		
		[self inputSourceHasFinished: nil];
		return;
	}
	
	// TODO: fix the window rotation so that it actually works
	[view sendCharacters: nextCommand
				toWindow: 0];
}

- (IBAction) showFindInFiles: (id) sender {
    [[IFFindInFilesController sharedFindInFilesController] showFindInFilesWindow: self];
}

// = The find action =

- (void) performFindPanelAction: (id) sender {
	// TODO: [[self currentTabView] performFindPanelAction: sender];
}

// = Running the entire skein =

//
// To save time, we actually only ensure that we visit notes with an actual commentary
// (ie, blessed nodes in the transcript). This will update everything that we can
// display some useful state for.
//

//
// A future extension could also store branch points and use ZoomView's autosave feature to avoid having
// to replay the entire game. Unfortunately, there's no equivalent for glulx (and seeing as Zoom is very
// fast and glulx is very slow, it's probably not worth it except as a fun toy)
//

- (BOOL) fillNode: (ZoomSkeinItem*) item {
	BOOL filled = NO;
	
	// See if any of this item's children adds a node to the stack
	for( ZoomSkeinItem* child in [item children] ) {
		if ([self fillNode: child]) {
			filled = YES;
		}
	}
	
	// If this node caused something to get filled, then return YES
	if (filled) return YES;
	
	// If this node has some commentary, then add it to the stack
	if ([item commentary] != nil && [[item commentary] length] > 0) {
		[skeinNodeStack addObject: item];
		return YES;
	} else {
		return NO;
	}
}

- (void) fillSkeinStack {
	// Chooses endpoints suitable for the skein stack so that we visit all of the nodes that have a commentary
	[skeinNodeStack release];
	skeinNodeStack = [[NSMutableArray alloc] init];
	
	[self fillNode: [[[self document] skein] rootItem]];
}

- (void) runCompilerOutputAndEntireSkein {
	noChangesSinceLastCompile = noChangesSinceLastRefresh = YES;
	
	[self fillSkeinStack];
	[self inputSourceHasFinished: nil];
}

- (void) inputSourceHasFinished: (id) source {
	if (skeinNodeStack != nil && [skeinNodeStack count] > 0) {
		// Run the next source on the skein
		[[[projectPanes objectAtIndex: 1] gamePage] setPointToRunTo: [skeinNodeStack lastObject]];
		[self runCompilerOutput];
		[skeinNodeStack removeLastObject];
	} else if (skeinNodeStack != nil) {
		[self nextDifferenceBySkein: self];
	}
}

// = Importing skein information =

- (ZoomSkein*) skeinFromRecording: (NSString*) path {
	// Read the file
	NSData* fileData = [[NSData alloc] initWithContentsOfFile: path];
	NSString* fileString = [[NSString alloc] initWithData: fileData
												 encoding: NSUTF8StringEncoding];
	[fileData release];
	
	if (fileString == nil) return nil;
	
	// Pull out the lines from the file
	[fileString autorelease];
	
	int lineStart = 0;
	int pos = 0;
	int len = [fileString length];
	
	// Maximum length of 500k characters
	if (len > 500000) return nil;
	
	NSMutableArray* lines = [NSMutableArray array];
	
	for (pos=0; pos<len; pos++) {
		// Get the next character
		unichar lineChar = [fileString characterAtIndex: pos];
		
		// Check for a newline
		if (lineChar == '\n' || lineChar == '\r') {
			// Maximum line length of 50 characters
			if (pos - lineStart > 50) return nil;
			
			// Maximum 10,000 moves
			if ([lines count] >= 10000) return nil;
			
			// Get the current line
			NSString* thisLine = [fileString substringWithRange: NSMakeRange(lineStart, pos-lineStart)];
			[lines addObject: thisLine];
			
			// Deal with <CR><LF> and <LF><CR> sequences
			if (pos+1 < len) {
				if (lineChar == '\r' && [fileString characterAtIndex: pos+1] == '\n') pos++;
				else if (lineChar == '\n' && [fileString characterAtIndex: pos+1] == '\r') pos++;
			}
			
			// Store the start of the next line
			lineStart = pos+1;
		}
	}
	
	// Must be at least one line in the file
	if ([lines count] < 1) return nil;
	
	// Build the new skein
	ZoomSkein* newSkein = [[[ZoomSkein alloc] init] autorelease];
	
	[newSkein setActiveItem: [newSkein rootItem]];
	
	for( NSString* line in lines ) {
		[newSkein inputCommand: line];
	}
	
	// Label the final line
	[[newSkein activeItem] setAnnotation: [NSString stringWithFormat: @"Recording: %@", [[path lastPathComponent] stringByDeletingPathExtension]]];
	
	return newSkein;
}

- (void) showSkeinLoadError: (NSString*) message {
	NSBeginAlertSheet([IFUtility localizedString: @"Could not import skein"],
					  [IFUtility localizedString: @"Cancel"],
					   nil,
					   nil,
					   [self window],
					   nil,
					   nil,
					   nil,
					   nil,
                       @"%@",
					   message);
}

- (IBAction) importIntoSkein: (id) sender {
	// We can currently import .rec files, .txt files, zoomSave packages and .skein files
	// In the case of .rec/.txt files, they must be <300k, be valid UTF-8 and have less than 10000 lines
	// of a length no more than 50 characters each. (Anything else probably isn't a recording)

	// Set up an open panel
	NSOpenPanel* importPanel = [NSOpenPanel openPanel];
	
	[importPanel setAccessoryView: nil];
	[importPanel setCanChooseFiles: YES];
	[importPanel setCanChooseDirectories: NO];
	[importPanel setResolvesAliases: YES];
	[importPanel setAllowsMultipleSelection: NO];
	[importPanel setTitle: [IFUtility localizedString:@"Choose a recording, skein or Zoom save game file"]];
    [importPanel setAllowedFileTypes: [NSArray arrayWithObjects: @"rec", @"txt", @"zoomSave", @"skein", nil]];
	
	// Display the panel
    [importPanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result)
     {
         if (result == NSOKButton) {
             NSString* path = [[importPanel URL] path];
             NSString* extn = [[path pathExtension] lowercaseString];
             
             ZoomSkein* loadedSkein = nil;
             NSString* loadError = nil;
             
             if ([extn isEqualToString: @"txt"] || [extn isEqualToString: @"rec"]) {
                 loadedSkein = [self skeinFromRecording: path];
                 
                 loadError = [IFUtility localizedString: @"Recording Skein Load Failure" default: nil];
             } else if ([extn isEqualToString: @"skein"]) {
                 loadedSkein = [[[ZoomSkein alloc] init] autorelease];
                 
                 BOOL parsed = [loadedSkein parseXmlData: [NSData dataWithContentsOfFile: path]];
                 if (!parsed) loadedSkein = nil;
             } else if ([extn isEqualToString: @"zoomsave"]) {
                 loadedSkein = [[[ZoomSkein alloc] init] autorelease];
                 
                 BOOL parsed = [loadedSkein parseXmlData: [NSData dataWithContentsOfFile: [path stringByAppendingPathComponent: @"Skein.skein"]]];
                 if (!parsed) loadedSkein = nil;
             }
             
             if (loadedSkein != nil) {
                 // Merge the new skein into the current skein
                 for( ZoomSkeinItem* child in [[loadedSkein rootItem] children] ) {
                     [[child retain] autorelease];
                     [child removeFromParent];
                     
                     [child setTemporary: YES];
                     [[[[self document] skein] rootItem] addChild: child];
                 }
                 
                 [[[self document] skein] zoomSkeinChanged];
             } else {
                 if (loadError == nil)
                     loadError = [IFUtility localizedString: @"Skein Load Failure" default: nil];
                 
                 [[NSRunLoop currentRunLoop] performSelector: @selector(showSkeinLoadError:)
                                                      target: self 
                                                    argument: loadError
                                                       order: 32
                                                       modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
             }
         }
     }];
}

// = Documentation =

- (void) openDocUrl: (NSURL*) url {
	IFProjectPane* auxPane = [self auxPane];
	
	[auxPane selectViewOfType: IFDocumentationPane];
	[[auxPane documentationPage] openURL: url];
}

// = The syntax matcher =

- (void) syntaxUpdateStarted: (NSNotification*) not {
	if (!processingSyntax) {
		processingSyntax = [[IFProgress alloc] initWithPriority: IFProgressPrioritySyntax
                                               showsProgressBar: YES
                                                      canCancel: NO];
		[self addProgressIndicator: processingSyntax];
        [processingSyntax startProgress];

		[processingSyntax setMessage: [IFUtility localizedString: @"Generating syntax tables"]];
	}
}

- (void) syntaxUpdateFinished: (NSNotification*) not {
	if (processingSyntax) {
		[processingSyntax setMessage: @""];
		[self removeProgressIndicator: processingSyntax];
		[processingSyntax autorelease];
		processingSyntax = nil;
	}
}


// = Headers =

- (void) intelFileChanged: (NSNotification*) not {
	// Must be the current intelligence object
	if ([not object] != [self currentIntelligence]) return;
	
	// Update the header controller
	[headerController updateFromIntelligence: (IFIntelFile*)[not object]];
}

- (IFHeaderController*) headerController {
	return headerController;
}

// = Moving around source headings =

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
    return [[self gamePage] isRunningGame];
}

-(BOOL) isWaitingAtBreakpoint {
    return waitingAtBreakpoint;
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
    float limit = MAX(minDividerWidth, [splitView bounds].size.width - minDividerWidth);
    if (proposedMaximumPosition > limit) {
        proposedMaximumPosition = limit;
    }
    
    return proposedMaximumPosition;
}

- (BOOL)    splitView: (NSSplitView *) splitView
   canCollapseSubview: (NSView *) subview {
    return NO;
}

@end
