//
//  IFToolbarManager.m
//  Inform
//
//  Created by Toby Nelson in 2014
//

#import "IFToolbarManager.h"
#import "IFToolbarStatusView.h"
#import "IFCompilerSettings.h"
#import "IFProject.h"
#import "IFProjectController.h"
#import "IFUtility.h"
#import "IFProgress.h"
#import "Inform-Swift.h"

@interface IFToolbarManager () <IFProgressDelegate>

@end

 #pragma mark - Preferences

@implementation IFToolbarManager {
    // The toolbar
    NSToolbar* toolbar;
    NSView*    toolbarView;
    CGFloat    toolbarViewTitlebarHeight;

    IFToolbarStatusView* toolbarStatusView;

    // Progress indicators
    NSMutableArray* progressObjects;
}

@synthesize testCasesPopUpButton;
@synthesize goButton;
@synthesize testCases;
@synthesize projectController;

// == Toolbar items ==

static NSToolbarItem* compileItem			= nil;
static NSToolbarItem* compileAndRunItem		= nil;
static NSToolbarItem* replayItem			= nil;
static NSToolbarItem* releaseItem			= nil;
static NSToolbarItem* refreshIndexItem		= nil;

static NSToolbarItem* testSelectorItem      = nil;
static NSToolbarItem* installExtensionItem	= nil;
static NSToolbarItem* testItem              = nil;

static NSToolbarItem* stopItem				= nil;

static NSToolbarItem* searchDocsItem		= nil;
static NSToolbarItem* searchProjectItem		= nil;
static NSToolbarItem* toolbarStatusSpacingPaletteItem = nil;
static NSToolbarItem*              toolbarStatusSpacingItem  = nil;
static IFToolbarStatusSpacingView* toolbarStatusSpacingView  = nil;

static NSDictionary*  itemDictionary        = nil;
static const CGFloat  toolbarStatusWidth    = 300.0f;

+ (void) initialize {
	// Create the toolbar items
    compileItem         = [[NSToolbarItem alloc] initWithItemIdentifier: @"compileItem"];
    compileAndRunItem   = [[NSToolbarItem alloc] initWithItemIdentifier: @"compileAndRunItem"];
    releaseItem         = [[NSToolbarItem alloc] initWithItemIdentifier: @"releaseItem"];
	replayItem          = [[NSToolbarItem alloc] initWithItemIdentifier: @"replayItem"];
	refreshIndexItem    = [[NSToolbarItem alloc] initWithItemIdentifier: @"refreshIndexItem"];

    testSelectorItem    = [[NSToolbarItem alloc] initWithItemIdentifier: @"testSelectorItem"];
    installExtensionItem= [[NSToolbarItem alloc] initWithItemIdentifier: @"installExtensionItem"];
    testItem            = [[NSToolbarItem alloc] initWithItemIdentifier: @"testItem"];

    stopItem            = [[NSToolbarItem alloc] initWithItemIdentifier: @"stopItem"];

	searchDocsItem      = [[NSToolbarItem alloc] initWithItemIdentifier: @"searchDocsItem"];
	searchProjectItem   = [[NSToolbarItem alloc] initWithItemIdentifier: @"searchProjectItem"];

    toolbarStatusSpacingPaletteItem = [[NSToolbarItem alloc] initWithItemIdentifier: @"toolbarStatusSpacingPaletteItem"];
    
    toolbarStatusSpacingItem = [[NSToolbarItem alloc] initWithItemIdentifier: @"toolbarStatusSpacingItem"];
    toolbarStatusSpacingView = [[IFToolbarStatusSpacingView alloc] initWithFrame:NSMakeRect(0, 0, 1, 30)];
    
    itemDictionary = @{ @"compileItem":                     compileItem,
                        @"compileAndRunItem":               compileAndRunItem,
                        @"replayItem":                      replayItem,
                        @"refreshIndexItem":                refreshIndexItem,
                        @"releaseItem":                     releaseItem,
                        @"testSelectorItem":                testSelectorItem,
                        @"installExtensionItem":            installExtensionItem,
                        @"testItem":                        testItem,
                        @"stopItem":                        stopItem,
                        @"searchDocsItem":                  searchDocsItem,
                        @"searchProjectItem":               searchProjectItem,
                        @"toolbarStatusSpacingItem":        toolbarStatusSpacingItem,
                        @"toolbarStatusSpacingPaletteItem": toolbarStatusSpacingPaletteItem };

	// Images
	compileItem.image = [NSImage imageNamed: @"App/Toolbar/compile"];
	compileAndRunItem.image = [NSImage imageNamed: @"App/Toolbar/run"];
	releaseItem.image = [NSImage imageNamed: @"App/Toolbar/release"];
    installExtensionItem.image = [NSImage imageNamed: @"App/Toolbar/install"];
    testItem.image = [NSImage imageNamed: @"App/Toolbar/test"];
	replayItem.image = [NSImage imageNamed: @"App/Toolbar/replay"];
	refreshIndexItem.image = [NSImage imageNamed: @"App/Toolbar/refresh_index"];
	
	stopItem.image = [NSImage imageNamed: @"App/Toolbar/stop"];

    toolbarStatusSpacingPaletteItem.image = [NSImage imageNamed: @"App/Toolbar/status"];

	// Labels
    compileItem.label = [IFUtility localizedString: @"Compile"];
    compileAndRunItem.label = [IFUtility localizedString: @"Go!"];
    releaseItem.label = [IFUtility localizedString: @"Release"];
    replayItem.label = [IFUtility localizedString: @"Replay"];
    refreshIndexItem.label = [IFUtility localizedString: @"Refresh Index"];
	
	stopItem.label = [IFUtility localizedString: @"Stop"];

    testSelectorItem.label = [IFUtility localizedString: @"Test Case"];
    installExtensionItem.label = [IFUtility localizedString: @"Install Extension"];
    testItem.label = [IFUtility localizedString: @"Test"];

	searchDocsItem.label = [IFUtility localizedString: @"Search Documentation"];
	searchProjectItem.label = [IFUtility localizedString: @"Search Project"];

    toolbarStatusSpacingItem.minSize = NSMakeSize(10, 1);
    toolbarStatusSpacingItem.maxSize = NSMakeSize(10000, 1);
    toolbarStatusSpacingItem.view = toolbarStatusSpacingView;
    toolbarStatusSpacingItem.label = @"";

    // Set palette labels
    for(NSToolbarItem* item in [itemDictionary objectEnumerator]) {
        item.paletteLabel = item.label;
    }
    
    // Special case - this shows "Status" when on the customization palette
    toolbarStatusSpacingPaletteItem.label = @"";
    toolbarStatusSpacingPaletteItem.paletteLabel = [IFUtility localizedString: @"Status"];

	// The tooltips
    compileItem.toolTip = [IFUtility localizedString: @"CompileTip"   default: nil];
    compileAndRunItem.toolTip = [IFUtility localizedString: @"GoTip"        default: nil];
    releaseItem.toolTip = [IFUtility localizedString: @"ReleaseTip"   default: nil];
	replayItem.toolTip = [IFUtility localizedString: @"ReplayTip"    default: nil];
	
	stopItem.toolTip = [IFUtility localizedString: @"StopTip"      default: nil];

	searchDocsItem.toolTip = [IFUtility localizedString: @"SearchDocsTip"    default: nil];
	searchProjectItem.toolTip = [IFUtility localizedString: @"SearchProjectTip" default: nil];
	
	refreshIndexItem.toolTip = [IFUtility localizedString: @"RefreshIndexTip"  default: nil];
    testSelectorItem.toolTip = [IFUtility localizedString: @"TestSelectorTip"  default: nil];
    installExtensionItem.toolTip = [IFUtility localizedString: @"InstallExtensionTip"  default: nil];
    testItem.toolTip = [IFUtility localizedString: @"TestTip"              default: nil];

    // The action heroes
    compileItem.action = @selector(compile:);
    compileAndRunItem.action = @selector(compileAndRun:);
    releaseItem.action = @selector(release:);
    replayItem.action = @selector(replayUsingSkein:);
    refreshIndexItem.action = @selector(compileAndRefresh:);
	
    stopItem.action = @selector(stopProcess:);
    testSelectorItem.action = @selector(testSelector:);
    installExtensionItem.action = @selector(installLegacyExtension:);
    testItem.action = @selector(testMe:);

}

// == Initialisation ==
- (instancetype)init { self = [super init]; return self; }

- (instancetype) initWithProjectController:(IFProjectController*) pc {
    self = [super init];

    if (self) {
        toolbar = nil;
        projectController = pc;
        toolbarStatusView   = [[IFToolbarStatusView alloc] initWithFrame: NSMakeRect(0, 0, toolbarStatusWidth, 32)];
        toolbarStatusView.delegate = self;

        // Progress
		progressObjects = [[NSMutableArray alloc] init];
        
        // Register for settings updates
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(windowDidResize:)
                                                     name: NSWindowDidResizeNotification
                                                   object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(toolbarChangedVisibility:)
                                                     name: IFToolbar.ChangedVisibility
                                                   object: nil];

        // Only 10.7 Lion or later has Full Screen support
        if( [IFUtility hasFullscreenSupportFeature] ) {
            [[NSNotificationCenter defaultCenter] addObserver: self
                                                     selector: @selector(willEnterFullScreen:)
                                                         name: NSWindowWillEnterFullScreenNotification
                                                       object: nil];
            [[NSNotificationCenter defaultCenter] addObserver: self
                                                     selector: @selector(didEnterFullScreen:)
                                                         name: NSWindowDidEnterFullScreenNotification
                                                       object: nil];
            [[NSNotificationCenter defaultCenter] addObserver: self
                                                     selector: @selector(willExitFullScreen:)
                                                         name: NSWindowWillExitFullScreenNotification
                                                       object: nil];
            [[NSNotificationCenter defaultCenter] addObserver: self
                                                     selector: @selector(didExitFullScreen:)
                                                         name: NSWindowDidExitFullScreenNotification
                                                       object: nil];
        }
    }

    return self;
}

-(void) willEnterFullScreen:(NSNotification*) notification {
    if( notification.object == projectController.window ) {
        [toolbarStatusView removeFromSuperview];
    }
}

-(void) didEnterFullScreen:(NSNotification*) notification {
    if( notification.object == projectController.window ) {
        [self adjustToolbarStatusView];
    }
}

-(void) willExitFullScreen:(NSNotification*) notification {
    if( notification.object == projectController.window ) {
        [toolbarStatusView removeFromSuperview];
    }
}

-(void) didExitFullScreen:(NSNotification*) notification {
    if( notification.object == projectController.window ) {
        [self adjustToolbarStatusView];
    }
}

-(void) toolbarChangedVisibility:(NSNotification*) notification {
    if( notification.object == toolbar ) {
        [self adjustToolbarStatusView];
    }
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];

	[progressObjects makeObjectsPerformSelector: @selector(setDelegate:)
										withObject: nil];
}

- (void) updateSettings {
	// Update the toolbar if required
	NSString* toolbarIdentifier = self.toolbarIdentifier;
	
	if (![toolbar.identifier isEqualToString: toolbarIdentifier]) {
		
		toolbar = [[IFToolbar alloc] initWithIdentifier: toolbarIdentifier];

		toolbar.delegate = self;
		[toolbar setAllowsUserCustomization: YES];
		[toolbar setAutosavesConfiguration: YES];

		(projectController.window).toolbar = toolbar;
	}
}

-(NSView*) toolbarStatusViewParent {
    // Support for 10.11 and above
    if( [IFUtility hasUpdatedToolbarFeature] ) {
        return [projectController.window standardWindowButton:NSWindowCloseButton].superview;
    }

    // Support for 10.6.8 to 10.10.X
    // Find the parent view, the superview of our status view. Sadly, if window is in fullscreen
    // mode, the parent view is different than normal mode.
    // See http://stackoverflow.com/questions/6169255/is-it-possible-to-draw-in-the-label-area-of-nstoolbar
    BOOL isFullscreen = (((projectController.window).styleMask & NSWindowStyleMaskFullScreen) == NSWindowStyleMaskFullScreen);
    if( isFullscreen ) {
        return toolbarView.superview;
    }

    return (projectController.window.contentView).superview;
}

// This function keeps the toolbar status view in the right place on the toolbar.
// Called when anything relevant changes, e.g.:
//      (a) the window changes size,
//      (b) the window goes fullscreen or back, or
//      (c) when the toolbar visibility changes.
-(void) adjustToolbarStatusView {
    //windowFrame = NSWindow.contentRectForFrameRect(self.frame, styleMask: self.styleMask)
    //toolbarHeight = NSHeight(windowFrame) - NSHeight(self.contentView.frame)

    // Default to 20 pixels
    toolbarViewTitlebarHeight = 20.0f;

    // Find the toolbar view. The toolbar view isn't easily available. We have to search the
    // subviews of the content view to find it. Once we've found it, we remember it.
    if( toolbarView == nil ) {
        for( NSView* subview in (projectController.window.contentView).superview.subviews ) {
            // 10.9 and earlier? has an NSToolbarView
            if( [subview isKindOfClass: NSClassFromString(@"NSToolbarView")]) {
                toolbarView = subview;
                // toolbarViewTitlebarHeight = 0.0f;
                break;
            }

            // 10.10 Yosemite has an NSTitlebarContainerView instead of NSToolbarView
            if([subview isKindOfClass: NSClassFromString(@"NSTitlebarContainerView")]) {
                toolbarView = subview;
                break;
            }
        }
    }

    // Get appropriate parent for the view
    NSView* parentView = [self toolbarStatusViewParent];

    if( toolbarView ) {
        // Position our view within the toolbar
        NSRect toolbarRect = [parentView convertRect: toolbarView.bounds
                                            fromView: toolbarView];

        // Calculate the ideal frame to centre the toolbar status view in the toolbar
        NSRect newFrame = toolbarRect;
        newFrame.origin.x = (toolbarRect.size.width / 2) - (toolbarStatusView.frame.size.width / 2);
        newFrame.origin.y = newFrame.origin.y;
        float deltaHeight = -2.0f;
        newFrame.origin.y += 15.0f - deltaHeight/2;
        newFrame.size.width = toolbarStatusView.frame.size.width;

        newFrame.size.height = 30.0f;

        newFrame.origin.x = floor(newFrame.origin.x);
        newFrame.origin.y = floor(newFrame.origin.y);
        newFrame.size.width = floor(newFrame.size.width);
        newFrame.size.height = floor(newFrame.size.height);
        
        // Make sure we position ourselves within the bounds of the special IFToolbarStatusSpacingView item
        BOOL found = NO;
        NSPoint startPoint;
        NSPoint endPoint;
        for(NSToolbarItem* item in toolbar.items) {
            if( [item.view isKindOfClass: [IFToolbarStatusSpacingView class] ] ) {
                startPoint = item.view.bounds.origin;
                endPoint = NSMakePoint(item.view.bounds.origin.x + item.view.bounds.size.width,
                                       item.view.bounds.origin.y + item.view.bounds.size.height);

                startPoint = [item.view convertPoint: startPoint
                                                toView: parentView];
                endPoint = [item.view convertPoint: endPoint
                                              toView: parentView];
                found = YES;
                break;
            }
        }

        if( found ) {
            if( newFrame.origin.x < startPoint.x ) {
                newFrame.origin.x = startPoint.x;
            }
            if( (newFrame.origin.x + newFrame.size.width) > endPoint.x ) {
                // Hide - not enough room to show it
                [toolbarStatusView removeFromSuperview];
                return;
            }
        } else {
            // Hide - no IFToolbarStatusSpacingView, so not wanted
            [toolbarStatusView removeFromSuperview];
            return;
        }

        toolbarStatusView.frame = newFrame;
        [toolbarStatusView setNeedsDisplay:YES];
        [toolbarView setNeedsDisplay:YES];
    }
    
    // Update visibility
    if( toolbar.visible && toolbarStatusView.superview == nil ) {
        [parentView addSubview: toolbarStatusView
                    positioned: NSWindowAbove
                    relativeTo: nil];
    } else if (!toolbar.visible && toolbarStatusView.superview != nil ) {
        [toolbarStatusView removeFromSuperview];
    }
}

-(NSString*) toolbarIdentifier {
    // Create the view switch toolbar
    if( [projectController.document projectFileType] == IFFileTypeInform7ExtensionProject ) {
        return @"IFInform7ExtensionProjectToolbar";
    }
    return @"IFInform7Toolbar";
}

- (void) setToolbar {
    // Create the view switch toolbar
    toolbar = [[IFToolbar alloc] initWithIdentifier: self.toolbarIdentifier];
	
    toolbar.delegate = self;
    [toolbar setAllowsUserCustomization: NO];
	[toolbar setAutosavesConfiguration: NO];
    toolbar.displayMode = NSToolbarDisplayModeIconAndLabel;

    (projectController.window).toolbar = toolbar;

    // Remove all items from the context menu
    if ((projectController.window).contentView != nil) {
        if((projectController.window).contentView.superview != nil) {
            NSMenu* context_menu = (projectController.window).contentView.superview.menu;
            if (context_menu != nil) {
                [context_menu removeAllItems];
            }
        }
    }

    [self adjustToolbarStatusView];
}

#pragma mark - Toolbar delegate functions

- (NSToolbarItem *)toolbar: (NSToolbar *) toolbar
     itemForItemIdentifier: (NSString *)  itemIdentifier
 willBeInsertedIntoToolbar: (BOOL)        flag {
    // NSToolbar items can't be shared between windows, so we create copies.

    // Our custom spacing item ("Status") looks different on the customisation palette compared
    // to the real toolbar. Swap out the item if needed so we get to see the "Status" image.
    if ([itemIdentifier isEqualToString:@"toolbarStatusSpacingItem"]) {
        // If this item is for the customisation palette...
        if( flag == NO ) {
            // ... then use the palette version
            itemIdentifier = @"toolbarStatusSpacingPaletteItem";
        }
    }
    
    if ([itemIdentifier isEqualToString:@"toolbarStatusSpacingPaletteItem"]) {
        // If this item is not for the customisation palette...
        if( flag == YES ) {
            // ... then use the normal version
            itemIdentifier = @"toolbarStatusSpacingItem";
        }
    }

    // Make a copy of the item
	NSToolbarItem* item = [itemDictionary[itemIdentifier] copy];

	// The search views need to be set up here
	if ([itemIdentifier isEqualToString: @"searchDocsItem"]) {
		NSSearchField* searchDocs = [[NSSearchField alloc] initWithFrame: NSMakeRect(0,0,130,22)];
		[searchDocs.cell setPlaceholderString: [IFUtility localizedString: @"Documentation"]];

		item.minSize = NSMakeSize(70, 22);
		item.maxSize = NSMakeSize(150, 22);
		item.view = searchDocs;
		[searchDocs sizeToFit];
        [searchDocs.cell setScrollable:YES];

		[searchDocs setContinuous: NO];
		[(NSSearchFieldCell*) searchDocs.cell setSendsWholeSearchString: YES];
		searchDocs.target = projectController;
		searchDocs.action = @selector(searchDocs:);

		item.label = @"";

		return item;
	} else if ([itemIdentifier isEqualToString: @"searchProjectItem"]) {
		NSSearchField* searchProject = [[NSSearchField alloc] initWithFrame: NSMakeRect(0,0,130,22)];
		[searchProject.cell setPlaceholderString: [IFUtility localizedString: @"Project"]];

		item.minSize = NSMakeSize(70, 22);
		item.maxSize = NSMakeSize(150, 22);
		item.view = searchProject;
		[searchProject sizeToFit];
        [searchProject.cell setScrollable:YES];

		[searchProject setContinuous: NO];
		[(NSSearchFieldCell*) searchProject.cell setSendsWholeSearchString: YES];
		searchProject.target = projectController;
		searchProject.action = @selector(searchProject:);

		item.label = @"";

		return item;
    } else if ([itemIdentifier isEqualToString: @"testSelectorItem"]) {
        testCasesPopUpButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 190, 22)];
        item.minSize = NSMakeSize(100, 22);
        item.maxSize = NSMakeSize(190, 22);
        item.view = testCasesPopUpButton;
        testCasesPopUpButton.target = projectController;
        testCasesPopUpButton.action = @selector(testSelector:);
    }

	return item;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar {
    return @[@"compileItem",
             @"compileAndRunItem",
             @"replayItem",
             @"refreshIndexItem",
             @"stopItem",
             @"searchDocsItem",
             @"searchProjectItem",
             @"toolbarStatusSpacingItem",
             NSToolbarSpaceItemIdentifier,
             NSToolbarFlexibleSpaceItemIdentifier,
             @"releaseItem",
             @"testSelectorItem"];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)tb {
    NSString* identifier = tb.identifier;
	if ([identifier isEqualToString: @"IFInform7Toolbar"]) {
		return @[@"compileAndRunItem",
                 @"replayItem",
                 @"releaseItem",
                 @"searchProjectItem",
                 @"toolbarStatusSpacingItem",
                 @"searchDocsItem"];
    } else if ([identifier isEqualToString: @"IFInform7ExtensionProjectToolbar"]) {
        return @[@"compileAndRunItem",
                 @"testItem",
                 @"testSelectorItem",
                 @"installExtensionItem",
                 @"toolbarStatusSpacingItem",
                 @"searchProjectItem",
                 @"searchDocsItem",
                 ];
    }
    else {
        // Inform 6 toolbar items
		return @[@"compileAndRunItem",
                 @"replayItem",
                 @"releaseItem",
                 @"toolbarStatusSpacingItem"];
	}
}

- (void)toolbarWillAddItem:(NSNotification *)notification {
    [self adjustToolbarStatusView];
    [toolbarStatusView updateToolbar];
}

- (void)toolbarDidRemoveItem:(NSNotification *)notification {
    [self adjustToolbarStatusView];
    [toolbarStatusView updateToolbar];
}


// == Toolbar item validation ==

- (BOOL) validateToolbarItem: (NSToolbarItem*) item {
    SEL itemSelector = item.action;
    NSString* itemIdentifier = item.itemIdentifier;

	if ([itemIdentifier isEqualToString: stopItem.itemIdentifier]) {
		return projectController.isRunningGame;
	}
	
    if( itemSelector == @selector(testMe:) ) {
        if( testCases.count == 0 ) {
            return NO;
        }
        if( projectController.currentlyTesting ) {
            return NO;
        }
    }

	if (itemSelector == @selector(compile:) ||
		itemSelector == @selector(release:) ||
        itemSelector == @selector(releaseForTesting:) ||
		itemSelector == @selector(compileAndRun:) ||
		itemSelector == @selector(replayUsingSkein:) ||
		itemSelector == @selector(compileAndRefresh:)) {

        BOOL isExtensionProject = [projectController.document projectFileType] == IFFileTypeInform7ExtensionProject;
        BOOL selectedNoTestCase = isExtensionProject && ((testCases.count == 0) ||
                                                         (self.currentTestCase == nil));

        // If we are in an Extension Project, and there are no test cases to run, disable Go! (etc) buttons.
        if( selectedNoTestCase ) {
            return NO;
        }
		return !projectController.compiling;
	}

	return YES;
}

- (void) validateVisibleItems {
    [toolbar validateVisibleItems];
}

- (void) windowDidResize: (NSNotification*) notification {
    NSWindow* window = notification.object;
    if( window == projectController.window ) {
        // Adjust toolbar status window appropriately
        [self adjustToolbarStatusView];
    }
}

-(void) showMessage: (NSString *)message {
    [toolbarStatusView showMessage: message];
}

- (IFProgress*) findBestProgressThatIsActive:(BOOL) active {
    IFProgress* best = nil;
    int         bestPriority = 0;

    for( IFProgress* progress in progressObjects ) {
        BOOL isActive = progress.inProgress;
        if (isActive == active ) {
            if( progress.priority > bestPriority ) {
                bestPriority = progress.priority;
                best = progress;
            }
        }
    }
    return best;
}

- (IFProgress*) currentProgress {
    // Find the highest priority active object, or failing that, the best inactive one
    IFProgress* best = [self findBestProgressThatIsActive: YES];

    if( best == nil ) {
        best = [self findBestProgressThatIsActive: NO];
    }
    return best;
}

- (void) updateProgress {
    IFProgress* best = [self currentProgress];

    [toolbarStatusView canCancel: best.canCancel && !best.cancelled];
	if ((best != nil) && (best.showsProgressBar)) {
        // Enable progress bar
        [toolbarStatusView startProgress];
    }
	else {
        // Disable progress bar
        [toolbarStatusView stopProgress];
	}

	[toolbarStatusView setProgressMaxValue: 100.0f];
	
	// Set percentage
    CGFloat currentProgress = best.percentage;
	if (currentProgress > 0.0f) {
        [toolbarStatusView updateProgress: currentProgress];
		[toolbarStatusView setProgressIndeterminate: NO];
	} else {
		[toolbarStatusView setProgressIndeterminate: YES];
	}
    
    if (best.message) {
        [toolbarStatusView showMessage: best.message];
    }

    // Make sure parent redraws (avoids blocky edges where semi-transparent pixels are repeatedly redrawn)
    [[self toolbarStatusViewParent] setNeedsDisplay: YES];
}

- (void) addProgressIndicator: (IFProgress*) indicator {
	indicator.delegate = self;
	[progressObjects addObject: indicator];
	
	[self updateProgress];
}

- (void) removeProgressIndicator: (IFProgress*) indicator {
	[indicator setDelegate: nil];
	[progressObjects removeObjectIdenticalTo: indicator];
	
	[self updateProgress];
}

- (void) progressIndicator: (IFProgress*) indicator
				percentage: (CGFloat) newPercentage {
	[self updateProgress];
}

- (void) progressIndicator: (IFProgress*) indicator
				   message: (NSString*) newMessage {
	[self updateProgress];
}

- (void) progressIndicatorStartStory: (IFProgress*) indicator {
    [toolbarStatusView startStory];

    // Make sure parent redraws (avoids blocky edges where semi-transparent pixels are repeatedly redrawn)
    [[self toolbarStatusViewParent] setNeedsDisplay: YES];
}

- (void) progressIndicatorStopStory: (IFProgress*) indicator {
    [toolbarStatusView stopStory];
    
    // Make sure parent redraws (avoids blocky edges where semi-transparent pixels are repeatedly redrawn)
    [[self toolbarStatusViewParent] setNeedsDisplay: YES];
}

- (void) progressIndicatorStartProgress: (IFProgress*) indicator {
	[self updateProgress];
}

- (void) progressIndicatorStopProgress: (IFProgress*) indicator {
    [self updateProgress];
}

// Information passed back from view

-(void) cancelProgress {
    [[self currentProgress] cancelProgress];

    // Make sure parent redraws (avoids blocky edges where semi-transparent pixels are repeatedly redrawn)
    [[self toolbarStatusViewParent] setNeedsDisplay: YES];
}

-(void) redrawToolbar {
    [self adjustToolbarStatusView];
}

-(void) setIsExtensionProject:(BOOL) isExtensionProject {
    toolbarStatusView.isExtensionProject = isExtensionProject;
}

-(void) setTestCases:(NSArray*) testCasesArray {
    if( testCasesPopUpButton != nil ) {
        // Remember current selected item
        NSString* selectedTitle = testCasesPopUpButton.selectedItem.title;

        // Remove all items, then repopulate
        [testCasesPopUpButton removeAllItems];

        if( testCasesArray.count > 0 ) {
            [testCasesPopUpButton addItemWithTitle: [IFUtility localizedString:@"Test All"]];
        }

        for( NSDictionary*  item in testCasesArray ) {
            NSString* title = item[@"testTitle"];
            title = [title stringByTrimmingCharactersInString:@"\""];
            [testCasesPopUpButton addItemWithTitle: title];
        }

        if( selectedTitle != nil ) {
            // Restore current selected item
            [testCasesPopUpButton selectItemWithTitle: selectedTitle];

            // If that didn't work, select the first item
            if( testCasesPopUpButton.selectedItem == nil ) {
                if( testCasesPopUpButton.itemArray.count > 0 ) {
                    [testCasesPopUpButton selectItemAtIndex:0];
                }
            }
        }
    }
    testCases = testCasesArray;
}

-(BOOL) selectTestCase:(NSString*) testCase {
    for(int i = 0; i < testCases.count; i++) {
        if( [testCases[i][@"testKey"] isEqualToStringCaseInsensitive: testCase] ) {
            [testCasesPopUpButton selectItemAtIndex: 1+i];

            [projectController testSelector:testCasesPopUpButton];

            return YES;
        }
    }
    return NO;
}


-(int) getNumberOfTestCases {
    if( !testCases ) {
        return 0;
    }
    return (int) testCases.count;
}


-(NSString*) getTestCase:(int) index {
    if( !testCases ) {
        return nil;
    }
    if( index >= testCases.count ) {
        return nil;
    }
    return testCases[index][@"testKey"];
}

-(int) getTestCaseIndex {
    int selectedIndex = (int) testCasesPopUpButton.indexOfSelectedItem;
    if( selectedIndex < 0 ) {
        return -1;
    }
    if( selectedIndex == 0 ) {
        // Test all case
        return -1;
    }

    selectedIndex--;
    return selectedIndex;
}

-(NSString*) currentTestCase {
    int selectedIndex = [self getTestCaseIndex];
    if( selectedIndex < 0 ) {
        return nil;
    }
    if( selectedIndex >= testCases.count ) {
        return nil;
    }
    return testCases[selectedIndex][@"testKey"];
}

@end
