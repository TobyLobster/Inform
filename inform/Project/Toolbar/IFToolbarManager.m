//
//  IFToolbarManager.m
//  Inform
//
//  Created by Toby Nelson in 2014
//

#import "IFToolbarManager.h"
#import "IFToolbarStatusView.h"
#import "IFToolbarStatusSpacingView.h"
#import "IFToolbar.h"
#import "IFCompilerSettings.h"
#import "IFProject.h"
#import "IFImageCache.h"
#import "IFUtility.h"

 // = Preferences =

@implementation IFToolbarManager

// == Toolbar items ==

static NSToolbarItem* compileItem			= nil;
static NSToolbarItem* compileAndRunItem		= nil;
static NSToolbarItem* replayItem			= nil;
static NSToolbarItem* compileAndDebugItem	= nil;
static NSToolbarItem* releaseItem			= nil;
static NSToolbarItem* refreshIndexItem		= nil;

static NSToolbarItem* stopItem				= nil;
static NSToolbarItem* pauseItem				= nil;

static NSToolbarItem* continueItem			= nil;
static NSToolbarItem* stepItem				= nil;
static NSToolbarItem* stepOverItem			= nil;
static NSToolbarItem* stepOutItem			= nil;

static NSToolbarItem* watchItem				= nil;
static NSToolbarItem* breakpointItem		= nil;

static NSToolbarItem* searchDocsItem		= nil;
static NSToolbarItem* searchProjectItem		= nil;
static NSToolbarItem* toolbarStatusSpacingPaletteItem = nil;
static NSToolbarItem*              toolbarStatusSpacingItem  = nil;
static IFToolbarStatusSpacingView* toolbarStatusSpacingView  = nil;

static NSDictionary*  itemDictionary = nil;

static const float toolbarStatusWidth = 360.0f;

+ (void) initialize {
	// Create the toolbar items
    compileItem         = [[NSToolbarItem alloc] initWithItemIdentifier: @"compileItem"];
    compileAndRunItem   = [[NSToolbarItem alloc] initWithItemIdentifier: @"compileAndRunItem"];
    compileAndDebugItem = [[NSToolbarItem alloc] initWithItemIdentifier: @"compileAndDebugItem"];
    releaseItem         = [[NSToolbarItem alloc] initWithItemIdentifier: @"releaseItem"];
	replayItem          = [[NSToolbarItem alloc] initWithItemIdentifier: @"replayItem"];
	refreshIndexItem    = [[NSToolbarItem alloc] initWithItemIdentifier: @"refreshIndexItem"];
	
    stopItem            = [[NSToolbarItem alloc] initWithItemIdentifier: @"stopItem"];
    continueItem        = [[NSToolbarItem alloc] initWithItemIdentifier: @"continueItem"];
    pauseItem           = [[NSToolbarItem alloc] initWithItemIdentifier: @"pauseItem"];

	stepItem            = [[NSToolbarItem alloc] initWithItemIdentifier: @"stepItem"];
    stepOverItem        = [[NSToolbarItem alloc] initWithItemIdentifier: @"stepOverItem"];
    stepOutItem         = [[NSToolbarItem alloc] initWithItemIdentifier: @"stepOutItem"];
	
	watchItem           = [[NSToolbarItem alloc] initWithItemIdentifier: @"watchItem"];
    breakpointItem      = [[NSToolbarItem alloc] initWithItemIdentifier: @"breakpointItem"];
	
	searchDocsItem      = [[NSToolbarItem alloc] initWithItemIdentifier: @"searchDocsItem"];
	searchProjectItem   = [[NSToolbarItem alloc] initWithItemIdentifier: @"searchProjectItem"];

    toolbarStatusSpacingPaletteItem = [[NSToolbarItem alloc] initWithItemIdentifier: @"toolbarStatusSpacingPaletteItem"];
    
    toolbarStatusSpacingItem = [[NSToolbarItem alloc] initWithItemIdentifier: @"toolbarStatusSpacingItem"];
    toolbarStatusSpacingView = [[IFToolbarStatusSpacingView alloc] initWithFrame:NSMakeRect(0, 0, 1, 30)];
    
    itemDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:
        compileItem,            @"compileItem",
        compileAndRunItem,      @"compileAndRunItem",
		replayItem,             @"replayItem",
		refreshIndexItem,       @"refreshIndexItem",
		compileAndDebugItem,    @"compileAndDebugItem",
        releaseItem,            @"releaseItem",
		stopItem,               @"stopItem",
		pauseItem,              @"pauseItem",
		continueItem,           @"continueItem",
		stepItem,               @"stepItem",
		stepOverItem,           @"stepOverItem",
		stepOutItem,            @"stepOutItem",
		watchItem,              @"watchItem",
		breakpointItem,         @"breakpointItem",
		searchDocsItem,         @"searchDocsItem",
		searchProjectItem,      @"searchProjectItem",
        toolbarStatusSpacingItem, @"toolbarStatusSpacingItem",
        toolbarStatusSpacingPaletteItem, @"toolbarStatusSpacingPaletteItem",    // Item used for the customization palette
        nil];

	// Images
	[compileItem            setImage: [IFImageCache loadResourceImage: @"App/Toolbar/compile.png"]];
	[compileAndRunItem      setImage: [IFImageCache loadResourceImage: @"run.tiff"]];
	[compileAndDebugItem    setImage: [IFImageCache loadResourceImage: @"App/Toolbar/debug.png"]];
	[releaseItem            setImage: [IFImageCache loadResourceImage: @"release.tiff"]];
	[replayItem             setImage: [IFImageCache loadResourceImage: @"replay.tiff"]];
	[refreshIndexItem       setImage: [IFImageCache loadResourceImage: @"App/Toolbar/refresh_index.png"]];
	
	[stopItem               setImage: [IFImageCache loadResourceImage: @"App/Toolbar/stop.png"]];
	[pauseItem              setImage: [IFImageCache loadResourceImage: @"App/Toolbar/pause.png"]];
	[continueItem           setImage: [IFImageCache loadResourceImage: @"App/Toolbar/continue.png"]];
	
	[stepItem               setImage: [IFImageCache loadResourceImage: @"App/Toolbar/step.png"]];
	[stepOverItem           setImage: [IFImageCache loadResourceImage: @"App/Toolbar/stepover.png"]];
	[stepOutItem            setImage: [IFImageCache loadResourceImage: @"App/Toolbar/stepout.png"]];
	
	[watchItem              setImage: [IFImageCache loadResourceImage: @"App/Toolbar/watch.png"]];
	[breakpointItem         setImage: [IFImageCache loadResourceImage: @"App/Toolbar/breakpoint.png"]];

    [toolbarStatusSpacingPaletteItem setImage: [IFImageCache loadResourceImage: @"App/Toolbar/status.png"]];

	// Labels
    [compileItem         setLabel: [IFUtility localizedString: @"Compile"]];
    [compileAndRunItem   setLabel: [IFUtility localizedString: @"Go!"]];
	[compileAndDebugItem setLabel: [IFUtility localizedString: @"Debug"]];
    [releaseItem         setLabel: [IFUtility localizedString: @"Release"]];
    [replayItem          setLabel: [IFUtility localizedString: @"Replay"]];
    [refreshIndexItem    setLabel: [IFUtility localizedString: @"Refresh Index"]];
	
	[stepItem            setLabel: [IFUtility localizedString: @"Step"]];
	[stepOverItem        setLabel: [IFUtility localizedString: @"Step over"]];
	[stepOutItem         setLabel: [IFUtility localizedString: @"Step out"]];
	
	[stopItem            setLabel: [IFUtility localizedString: @"Stop"]];
	[pauseItem           setLabel: [IFUtility localizedString: @"Pause"]];
	[continueItem        setLabel: [IFUtility localizedString: @"Continue"]];

	[watchItem           setLabel: [IFUtility localizedString: @"Watch"]];
	[breakpointItem      setLabel: [IFUtility localizedString: @"Breakpoints"]];
	

	[searchDocsItem      setLabel: [IFUtility localizedString: @"Search Documentation"]];
	[searchProjectItem   setLabel: [IFUtility localizedString: @"Search Project"]];

    [toolbarStatusSpacingItem setMinSize: NSMakeSize(10, 1)];
    [toolbarStatusSpacingItem setMaxSize: NSMakeSize(10000, 1)];
    [toolbarStatusSpacingItem setView: toolbarStatusSpacingView];
    [toolbarStatusSpacingItem setLabel: @""];
    
    // Set palette labels
    for(NSToolbarItem* item in [itemDictionary objectEnumerator]) {
        [item setPaletteLabel:[item label]];
    }
    
    // Special case - this shows "Status" when on the customization palette
    [toolbarStatusSpacingPaletteItem setLabel: @""];
    [toolbarStatusSpacingPaletteItem setPaletteLabel: [IFUtility localizedString: @"Status"]];

	// The tooltips
    [compileItem            setToolTip: [IFUtility localizedString: @"CompileTip"   default: nil]];
    [compileAndRunItem      setToolTip: [IFUtility localizedString: @"GoTip"        default: nil]];
	[compileAndDebugItem    setToolTip: [IFUtility localizedString: @"DebugTip"     default: nil]];
    [releaseItem            setToolTip: [IFUtility localizedString: @"ReleaseTip"   default: nil]];
	[replayItem             setToolTip: [IFUtility localizedString: @"ReplayTip"    default: nil]];
	
	[stepItem               setToolTip: [IFUtility localizedString: @"StepTip"      default: nil]];
	[stepOverItem           setToolTip: [IFUtility localizedString: @"StepOverTip"  default: nil]];
	[stepOutItem            setToolTip: [IFUtility localizedString: @"StepOutTip"   default: nil]];
	
	[stopItem               setToolTip: [IFUtility localizedString: @"StopTip"      default: nil]];
	[pauseItem              setToolTip: [IFUtility localizedString: @"PauseTip"     default: nil]];
	[continueItem           setToolTip: [IFUtility localizedString: @"ContinueTip"  default: nil]];
	
	[watchItem              setToolTip: [IFUtility localizedString: @"WatchTip"         default: nil]];
	[breakpointItem         setToolTip: [IFUtility localizedString: @"BreakpointsTip"   default: nil]];

	[searchDocsItem         setToolTip: [IFUtility localizedString: @"SearchDocsTip"    default: nil]];
	[searchProjectItem      setToolTip: [IFUtility localizedString: @"SearchProjectTip" default: nil]];
	
	[refreshIndexItem       setToolTip: [IFUtility localizedString: @"RefreshIndexTip"  default: nil]];
	
    // The action heroes
    [compileItem            setAction: @selector(compile:)];
    [compileAndRunItem      setAction: @selector(compileAndRun:)];
    [compileAndDebugItem    setAction: @selector(compileAndDebug:)];
    [releaseItem            setAction: @selector(release:)];
    [replayItem             setAction: @selector(replayUsingSkein:)];
    [refreshIndexItem       setAction: @selector(compileAndRefresh:)];
	
    [stopItem               setAction: @selector(stopProcess:)];
	[pauseItem              setAction: @selector(pauseProcess:)];
	
	[continueItem           setAction: @selector(continueProcess:)];
	[stepItem               setAction: @selector(stepIntoProcess:)];
	[stepOverItem           setAction: @selector(stepOverProcess:)];
	[stepOutItem            setAction: @selector(stepOutProcess:)];
	
	[watchItem              setAction: @selector(showWatchpoints:)];
	[breakpointItem         setAction: @selector(showBreakpoints:)];
}

// == Initialistion ==

- (id) initWithProjectController:(IFProjectController*) pc {
    self = [super init];

    if (self) {
        toolbar = nil;
        projectController = pc;
        toolbarStatusView   = [[IFToolbarStatusView alloc] initWithFrame: NSMakeRect(0, 0, toolbarStatusWidth, 50)];
        [toolbarStatusView setDelegate: self];

        // Progress
		progressObjects = [[NSMutableArray alloc] init];
        
        // Register for settings updates
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(updateSettings)
                                                     name: IFSettingNotification
                                                   object: [[projectController document] settings]];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(windowDidResize:)
                                                     name: NSWindowDidResizeNotification
                                                   object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(toolbarChangedVisibility:)
                                                     name: IFToolbarChangedVisibility
                                                   object: nil];
        if (floor(NSAppKitVersionNumber) >= NSAppKitVersionNumber10_7) {
            // Only 10.7 Lion or later has Full Screen support
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
    if( [notification object] == projectController.window ) {
        [toolbarStatusView removeFromSuperview];
    }
}

-(void) didEnterFullScreen:(NSNotification*) notification {
    if( [notification object] == projectController.window ) {
        [self adjustToolbarStatusView];
    }
}

-(void) willExitFullScreen:(NSNotification*) notification {
    if( [notification object] == projectController.window ) {
        [toolbarStatusView removeFromSuperview];
    }
}

-(void) didExitFullScreen:(NSNotification*) notification {
    if( [notification object] == projectController.window ) {
        [self adjustToolbarStatusView];
    }
}

-(void) toolbarChangedVisibility:(NSNotification*) notification {
    if( [notification object] == toolbar ) {
        [self adjustToolbarStatusView];
    }
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];

	[progressObjects makeObjectsPerformSelector: @selector(setDelegate:)
										withObject: nil];
	[progressObjects release];

    [toolbar release];
    [super dealloc];
}

- (void) updateSettings {
	// Update the toolbar if required
	NSString* toolbarIdentifier = [self toolbarIdentifier];
	
	if (![[toolbar identifier] isEqualToString: toolbarIdentifier]) {
		[toolbar autorelease];
		
		toolbar = [[IFToolbar alloc] initWithIdentifier: toolbarIdentifier];

		[toolbar setDelegate: self];
		[toolbar setAllowsUserCustomization: YES];
		[toolbar setAutosavesConfiguration: YES];

		[projectController.window setToolbar: toolbar];
	}
}

-(NSView*) toolbarStatusViewParent {
    // Find the parent view, the superview of our status view. Sadly, if window is in fullscreen
    // mode, the parent view is different than normal mode.
    // See http://stackoverflow.com/questions/6169255/is-it-possible-to-draw-in-the-label-area-of-nstoolbar
    BOOL isFullscreen = (([projectController.window styleMask] & NSFullScreenWindowMask) == NSFullScreenWindowMask);
    if( isFullscreen ) {
        return [toolbarView superview];
    }
    
    return [projectController.window.contentView superview];
}

// This function keeps the toolbar status view in the right place on the toolbar.
// Called when anything relevant changes, e.g.:
//      (a) the window changes size,
//      (b) the window goes fullscreen or back, or
//      (c) when the toolbar visibility changes.
-(void) adjustToolbarStatusView {
    // Find the toolbar view. The toolbar view isn't easily available. We have to search the
    // subviews of the content view to find it. Once we've found it, we remember it.
    if( toolbarView == nil ) {
        for( NSView* subview in [[projectController.window.contentView superview] subviews] ) {
            if( [subview isKindOfClass: NSClassFromString(@"NSToolbarView")] ) {
                toolbarView = subview;
                break;
            }
        }
    }

    // Get appropriate parent for the view
    NSView* parentView = [self toolbarStatusViewParent];

    if( toolbarView ) {
        // Position our view within the toolbar
        NSRect toolbarRect = [parentView convertRect: [toolbarView bounds]
                                            fromView: toolbarView];

        // Calculate the ideal frame to centre the toolbar status view in the toolbar
        NSRect newFrame = toolbarRect;
        newFrame.origin.x = (toolbarRect.size.width / 2) - (toolbarStatusView.frame.size.width / 2);
        newFrame.origin.y = newFrame.origin.y;
        newFrame.origin.y += 6.0f;
        newFrame.size.height -= 7.0f;
        newFrame.size.width = toolbarStatusView.frame.size.width;

        // If we are small in height, give us some more room
        if( newFrame.size.height < 18 ) {
            float increment = 18 - newFrame.size.height;
            newFrame.origin.y -= increment;
            newFrame.size.height = 18;
        }

        newFrame.origin.x = floorf(newFrame.origin.x);
        newFrame.origin.y = floorf(newFrame.origin.y);
        newFrame.size.width = floorf(newFrame.size.width);
        newFrame.size.height = floorf(newFrame.size.height);
        
        // Make sure we position ourselves within the bounds of the special IFToolbarStatusSpacingView item
        BOOL found = NO;
        NSPoint startPoint;
        NSPoint endPoint;
        for(NSToolbarItem* item in [toolbar items]) {
            if( [[item view] isKindOfClass: [IFToolbarStatusSpacingView class] ] ) {
                startPoint = [item view].bounds.origin;
                endPoint = NSMakePoint([item view].bounds.origin.x + [item view].bounds.size.width,
                                       [item view].bounds.origin.y + [item view].bounds.size.height);

                startPoint = [[item view] convertPoint: startPoint
                                                toView: parentView];
                endPoint = [[item view] convertPoint: endPoint
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

        [toolbarStatusView setFrame: newFrame];
        [toolbarStatusView setNeedsDisplay:YES];
        [toolbarView setNeedsDisplay:YES];
    }
    
    // Update visibility
    if( [toolbar isVisible] && [toolbarStatusView superview] == nil ) {
        [parentView addSubview: toolbarStatusView
                    positioned: NSWindowAbove
                    relativeTo: nil];
    } else if (![toolbar isVisible] && [toolbarStatusView superview] != nil ) {
        [toolbarStatusView removeFromSuperview];
    }
}

-(NSString*) toolbarIdentifier {
    // Create the view switch toolbar
	if ([[projectController.document settings] usingNaturalInform]) {
		return @"IFInform7Toolbar";
	} else {
        return @"IFInform6Toolbar";
	}
    
}

- (void) setToolbar {
    // Create the view switch toolbar
    toolbar = [[IFToolbar alloc] initWithIdentifier: [self toolbarIdentifier]];
	
    [toolbar setDelegate: self];
    [toolbar setAllowsUserCustomization: YES];
	[toolbar setAutosavesConfiguration: YES];
    
    [projectController.window setToolbar: toolbar];

    [self adjustToolbarStatusView];
}

// == Toolbar delegate functions ==

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
	NSToolbarItem* item = [[[itemDictionary objectForKey: itemIdentifier] copy] autorelease];

	// The search views need to be set up here
	if ([itemIdentifier isEqualToString: @"searchDocsItem"]) {
		NSSearchField* searchDocs = [[NSSearchField alloc] initWithFrame: NSMakeRect(0,0,150,22)];
		[[searchDocs cell] setPlaceholderString: [IFUtility localizedString: @"Documentation"]];

		[item setMinSize: NSMakeSize(100, 22)];
		[item setMaxSize: NSMakeSize(150, 22)];
		[item setView: [searchDocs autorelease]];
		[searchDocs sizeToFit];
        [[searchDocs cell] setScrollable:YES];
		
		[searchDocs setContinuous: NO];
		[[searchDocs cell] setSendsWholeSearchString: YES];
		[searchDocs setTarget: projectController];
		[searchDocs setAction: @selector(searchDocs:)];

		[item setLabel: nil];
		
		return item;
	} else if ([itemIdentifier isEqualToString: @"searchProjectItem"]) {
		NSSearchField* searchProject = [[NSSearchField alloc] initWithFrame: NSMakeRect(0,0,150,22)];
		[[searchProject cell] setPlaceholderString: [IFUtility localizedString: @"Project"]];
		
		[item setMinSize: NSMakeSize(100, 22)];
		[item setMaxSize: NSMakeSize(150, 22)];
		[item setView: [searchProject autorelease]];
		[searchProject sizeToFit];
        [[searchProject cell] setScrollable:YES];

		[searchProject setContinuous: NO];
		[[searchProject cell] setSendsWholeSearchString: YES];
		[searchProject setTarget: projectController];
		[searchProject setAction: @selector(searchProject:)];
		
		[item setLabel: nil];
		
		return item;
    }
	
	return item;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar {
    return [NSArray arrayWithObjects:
        @"compileItem",
        @"compileAndRunItem",
        @"replayItem",
        @"compileAndDebugItem",
        @"refreshIndexItem",
        @"pauseItem",
        @"continueItem",
        @"stepItem",
		@"stepOverItem",
        @"stepOutItem",
        @"stopItem",
        @"watchItem",
        @"breakpointItem",
        @"searchDocsItem",
        @"searchProjectItem",
        @"toolbarStatusSpacingItem",
		NSToolbarSpaceItemIdentifier,
        NSToolbarFlexibleSpaceItemIdentifier,
		@"releaseItem",
        nil];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)tb {
	if ([[tb identifier] isEqualToString: @"IFInform7Toolbar"]) {
		return [NSArray arrayWithObjects:
                @"compileAndRunItem",
                @"replayItem",
                @"releaseItem",
                @"searchProjectItem",
                @"toolbarStatusSpacingItem",
                @"searchDocsItem",
                nil];
	} else {
		return [NSArray arrayWithObjects:
                @"compileAndRunItem",
                @"replayItem",
                @"compileAndDebugItem",
                @"pauseItem",
                @"continueItem",
                @"stepOutItem",
                @"stepOverItem",
                @"stepItem",
                @"releaseItem",
                @"toolbarStatusSpacingItem",
                @"breakpointItem",
                @"watchItem",
                nil];
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
	if ([[item itemIdentifier] isEqualToString: [pauseItem itemIdentifier]] &&
		!projectController.canDebug) {
		return NO;
	}
	
	if ([[item itemIdentifier] isEqualToString: [stopItem itemIdentifier]] ||
		[[item itemIdentifier] isEqualToString: [pauseItem itemIdentifier]]) {
		return projectController.isRunningGame;
	}
	
	if ([[item itemIdentifier] isEqualToString: [continueItem itemIdentifier]] || 
		[[item itemIdentifier] isEqualToString: [stepOutItem itemIdentifier]]  || 
		[[item itemIdentifier] isEqualToString: [stepOverItem itemIdentifier]] || 
		[[item itemIdentifier] isEqualToString: [stepItem itemIdentifier]]) {
		return projectController.isRunningGame ? projectController.isWaitingAtBreakpoint : NO;
	}

	SEL itemSelector = [item action];
	
	if (itemSelector == @selector(compileAndDebug:) &&
		!projectController.canDebug) {
		return NO;
	}

	if (itemSelector == @selector(compile:) || 
		itemSelector == @selector(release:) ||
		itemSelector == @selector(compileAndRun:) ||
		itemSelector == @selector(compileAndDebug:) ||
		itemSelector == @selector(replayUsingSkein:) ||
		itemSelector == @selector(compileAndRefresh:)) {
		return ![projectController isCompiling];
	}

	return YES;
}

- (void) validateVisibleItems {
    [toolbar validateVisibleItems];
}

- (void) windowDidResize: (NSNotification*) notification {
    NSWindow* window = [notification object];
    if( window == [projectController window] ) {
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
        BOOL isActive = [progress isInProgress];
        if (isActive == active ) {
            if( [progress priority] > bestPriority ) {
                bestPriority = [progress priority];
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

    [toolbarStatusView canCancel: [best canCancel]];
	if ((best != nil) && ([best showsProgressBar])) {
        // Enable progress bar
        [toolbarStatusView startProgress];
    }
	else {
        // Disable progress bar
        [toolbarStatusView stopProgress];
	}

	[toolbarStatusView setProgressMaxValue: 100.0f];
	
	// Set percentage
    float currentProgress = [best percentage];
	if (currentProgress > 0.0f) {
        [toolbarStatusView updateProgress: currentProgress];
		[toolbarStatusView setProgressIndeterminate: NO];
	} else {
		[toolbarStatusView setProgressIndeterminate: YES];
	}
    
    if ([best message]) {
        [toolbarStatusView showMessage: [best message]];
    }

    // Make sure parent redraws (avoids blocky edges where semi-transparent pixels are repeatedly redrawn)
    [[self toolbarStatusViewParent] setNeedsDisplay: YES];
}

- (void) addProgressIndicator: (IFProgress*) indicator {
	[indicator setDelegate: self];
	[progressObjects addObject: indicator];
	
	[self updateProgress];
}

- (void) removeProgressIndicator: (IFProgress*) indicator {
	[indicator setDelegate: nil];
	[progressObjects removeObjectIdenticalTo: indicator];
	
	[self updateProgress];
}

- (void) progressIndicator: (IFProgress*) indicator
				percentage: (float) newPercentage {
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

@end
