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
#import "IFProjectController.h"
#import "IFImageCache.h"
#import "IFUtility.h"
#import "IFProgress.h"

 // = Preferences =

@implementation IFToolbarManager {
    // The toolbar
    NSToolbar* toolbar;
    NSView*    toolbarView;
    float      toolbarViewTitlebarHeight;

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
static NSToolbarItem* compileAndDebugItem	= nil;
static NSToolbarItem* releaseItem			= nil;
static NSToolbarItem* refreshIndexItem		= nil;

static NSToolbarItem* testSelectorItem      = nil;
static NSToolbarItem* installExtensionItem	= nil;
static NSToolbarItem* testItem              = nil;

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

static NSDictionary*  itemDictionary        = nil;
static const float    toolbarStatusWidth    = 360.0f;

+ (void) initialize {
	// Create the toolbar items
    compileItem         = [[NSToolbarItem alloc] initWithItemIdentifier: @"compileItem"];
    compileAndRunItem   = [[NSToolbarItem alloc] initWithItemIdentifier: @"compileAndRunItem"];
    compileAndDebugItem = [[NSToolbarItem alloc] initWithItemIdentifier: @"compileAndDebugItem"];
    releaseItem         = [[NSToolbarItem alloc] initWithItemIdentifier: @"releaseItem"];
	replayItem          = [[NSToolbarItem alloc] initWithItemIdentifier: @"replayItem"];
	refreshIndexItem    = [[NSToolbarItem alloc] initWithItemIdentifier: @"refreshIndexItem"];

    testSelectorItem    = [[NSToolbarItem alloc] initWithItemIdentifier: @"testSelectorItem"];
    installExtensionItem= [[NSToolbarItem alloc] initWithItemIdentifier: @"installExtensionItem"];
    testItem            = [[NSToolbarItem alloc] initWithItemIdentifier: @"testItem"];

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
    
    itemDictionary = @{ @"compileItem":                     compileItem,
                        @"compileAndRunItem":               compileAndRunItem,
                        @"replayItem":                      replayItem,
                        @"refreshIndexItem":                refreshIndexItem,
                        @"compileAndDebugItem":             compileAndDebugItem,
                        @"releaseItem":                     releaseItem,
                        @"testSelectorItem":                testSelectorItem,
                        @"installExtensionItem":            installExtensionItem,
                        @"testItem":                        testItem,
                        @"stopItem":                        stopItem,
                        @"pauseItem":                       pauseItem,
                        @"continueItem":                    continueItem,
                        @"stepItem":                        stepItem,
                        @"stepOverItem":                    stepOverItem,
                        @"stepOutItem":                     stepOutItem,
                        @"watchItem":                       watchItem,
                        @"breakpointItem":                  breakpointItem,
                        @"searchDocsItem":                  searchDocsItem,
                        @"searchProjectItem":               searchProjectItem,
                        @"toolbarStatusSpacingItem":        toolbarStatusSpacingItem,
                        @"toolbarStatusSpacingPaletteItem": toolbarStatusSpacingPaletteItem };

	// Images
	[compileItem            setImage: [NSImage imageNamed: @"App/Toolbar/compile"]];
	[compileAndRunItem      setImage: [NSImage imageNamed: @"App/Toolbar/run"]];
	[compileAndDebugItem    setImage: [NSImage imageNamed: @"App/Toolbar/debug"]];
	[releaseItem            setImage: [NSImage imageNamed: @"App/Toolbar/release"]];
    [installExtensionItem   setImage: [NSImage imageNamed: @"App/Toolbar/install"]];
    [testItem               setImage: [NSImage imageNamed: @"App/Toolbar/test"]];
	[replayItem             setImage: [NSImage imageNamed: @"App/Toolbar/replay"]];
	[refreshIndexItem       setImage: [NSImage imageNamed: @"App/Toolbar/refresh_index"]];
	
	[stopItem               setImage: [NSImage imageNamed: @"App/Toolbar/stop"]];
	[pauseItem              setImage: [NSImage imageNamed: @"App/Toolbar/pause"]];
	[continueItem           setImage: [NSImage imageNamed: @"App/Toolbar/continue"]];
	
	[stepItem               setImage: [NSImage imageNamed: @"App/Toolbar/step"]];
	[stepOverItem           setImage: [NSImage imageNamed: @"App/Toolbar/stepover"]];
	[stepOutItem            setImage: [NSImage imageNamed: @"App/Toolbar/stepout"]];
	
	[watchItem              setImage: [NSImage imageNamed: @"App/Toolbar/watch"]];
	[breakpointItem         setImage: [NSImage imageNamed: @"App/Toolbar/breakpoint"]];

    [toolbarStatusSpacingPaletteItem setImage: [NSImage imageNamed: @"App/Toolbar/status"]];

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
	
    [testSelectorItem     setLabel: [IFUtility localizedString: @"Test Case"]];
    [installExtensionItem setLabel: [IFUtility localizedString: @"Install Extension"]];
    [testItem             setLabel: [IFUtility localizedString: @"Test"]];

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
    [testSelectorItem       setToolTip: [IFUtility localizedString: @"TestSelectorTip"  default: nil]];
    [installExtensionItem   setToolTip: [IFUtility localizedString: @"InstallExtensionTip"  default: nil]];
    [testItem               setToolTip: [IFUtility localizedString: @"TestTip"              default: nil]];

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
    [testSelectorItem       setAction: @selector(testSelector:)];
    [installExtensionItem   setAction: @selector(installExtension:)];
    [testItem               setAction: @selector(testMe:)];

}

// == Initialisation ==
- (instancetype)init { self = [super init]; return self; }

- (instancetype) initWithProjectController:(IFProjectController*) pc {
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
                                                 selector: @selector(windowDidResize:)
                                                     name: NSWindowDidResizeNotification
                                                   object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(toolbarChangedVisibility:)
                                                     name: IFToolbarChangedVisibility
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
}

- (void) updateSettings {
	// Update the toolbar if required
	NSString* toolbarIdentifier = [self toolbarIdentifier];
	
	if (![[toolbar identifier] isEqualToString: toolbarIdentifier]) {
		
		toolbar = [[IFToolbar alloc] initWithIdentifier: toolbarIdentifier];

		[toolbar setDelegate: self];
		[toolbar setAllowsUserCustomization: YES];
		[toolbar setAutosavesConfiguration: YES];

		[projectController.window setToolbar: toolbar];
	}
}

-(NSView*) toolbarStatusViewParent {
    // Support for 10.11 and above
    if( [IFUtility hasUpdatedToolbarFeature] ) {
        return [[projectController.window standardWindowButton:NSWindowCloseButton] superview];
    }

    // Support for 10.6.8 to 10.10.X
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
            // 10.9 and earlier has an NSToolbarView
            if( [subview isKindOfClass: NSClassFromString(@"NSToolbarView")]) {
                toolbarView = subview;
                toolbarViewTitlebarHeight = 0.0f;
                break;
            }

            // 10.10 Yosemite has an NSTitlebarContainerView instead of NSToolbarView
            if([subview isKindOfClass: NSClassFromString(@"NSTitlebarContainerView")]) {
                toolbarView = subview;
                toolbarViewTitlebarHeight = 20.0f;
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

        //newFrame.origin.y -= toolbarViewTitlebarHeight;
        newFrame.size.height -= toolbarViewTitlebarHeight;

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
        if( [projectController.document projectFileType] == IFFileTypeInform7ExtensionProject ) {
            return @"IFInform7ExtensionProjectToolbar";
        }
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
	NSToolbarItem* item = [itemDictionary[itemIdentifier] copy];

	// The search views need to be set up here
	if ([itemIdentifier isEqualToString: @"searchDocsItem"]) {
		NSSearchField* searchDocs = [[NSSearchField alloc] initWithFrame: NSMakeRect(0,0,130,22)];
		[[searchDocs cell] setPlaceholderString: [IFUtility localizedString: @"Documentation"]];

		[item setMinSize: NSMakeSize(70, 22)];
		[item setMaxSize: NSMakeSize(150, 22)];
		[item setView: searchDocs];
		[searchDocs sizeToFit];
        [[searchDocs cell] setScrollable:YES];

		[searchDocs setContinuous: NO];
		[(NSSearchFieldCell*) [searchDocs cell] setSendsWholeSearchString: YES];
		[searchDocs setTarget: projectController];
		[searchDocs setAction: @selector(searchDocs:)];

		[item setLabel: @""];

		return item;
	} else if ([itemIdentifier isEqualToString: @"searchProjectItem"]) {
		NSSearchField* searchProject = [[NSSearchField alloc] initWithFrame: NSMakeRect(0,0,130,22)];
		[[searchProject cell] setPlaceholderString: [IFUtility localizedString: @"Project"]];

		[item setMinSize: NSMakeSize(70, 22)];
		[item setMaxSize: NSMakeSize(150, 22)];
		[item setView: searchProject];
		[searchProject sizeToFit];
        [[searchProject cell] setScrollable:YES];

		[searchProject setContinuous: NO];
		[(NSSearchFieldCell*) [searchProject cell] setSendsWholeSearchString: YES];
		[searchProject setTarget: projectController];
		[searchProject setAction: @selector(searchProject:)];

		[item setLabel: @""];

		return item;
    } else if ([itemIdentifier isEqualToString: @"testSelectorItem"]) {
        testCasesPopUpButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 190, 22)];
        [item setMinSize: NSMakeSize(100, 22)];
        [item setMaxSize: NSMakeSize(190, 22)];
        [item setView: testCasesPopUpButton];
        [testCasesPopUpButton setTarget: projectController];
        [testCasesPopUpButton setAction: @selector(testSelector:)];
    }

	return item;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar {
    return @[@"compileItem",
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
             @"testSelectorItem"];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)tb {
    NSString* identifier = [tb identifier];
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
                 @"compileAndDebugItem",
                 @"pauseItem",
                 @"continueItem",
                 @"stepOutItem",
                 @"stepOverItem",
                 @"stepItem",
                 @"releaseItem",
                 @"toolbarStatusSpacingItem",
                 @"breakpointItem",
                 @"watchItem"];
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
    SEL itemSelector = [item action];
    NSString* itemIdentifier = [item itemIdentifier];

    if ([itemIdentifier isEqualToString: [pauseItem itemIdentifier]] &&
		!projectController.canDebug) {
		return NO;
	}
	
	if ([itemIdentifier isEqualToString: [stopItem itemIdentifier]] ||
		[itemIdentifier isEqualToString: [pauseItem itemIdentifier]]) {
		return projectController.isRunningGame;
	}
	
	if ([itemIdentifier isEqualToString: [continueItem itemIdentifier]] ||
		[itemIdentifier isEqualToString: [stepOutItem itemIdentifier]]  ||
		[itemIdentifier isEqualToString: [stepOverItem itemIdentifier]] ||
		[itemIdentifier isEqualToString: [stepItem itemIdentifier]]) {
		return projectController.isRunningGame ? projectController.isWaitingAtBreakpoint : NO;
	}

	if (itemSelector == @selector(compileAndDebug:) &&
		!projectController.canDebug) {
		return NO;
	}

    if( itemSelector == @selector(testMe:) ) {
        if( [testCases count] == 0 ) {
            return NO;
        }
        if( [projectController isCurrentlyTesting] ) {
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

        BOOL isExtensionProject = [projectController.document projectFileType] == IFFileTypeInform7ExtensionProject;
        BOOL selectedNoTestCase = isExtensionProject && ((testCases.count == 0) ||
                                                         ([self currentTestCase] == nil));

        // If we are in an Extension Project, and there are no test cases to run, disable Go! (etc) buttons.
        if( selectedNoTestCase ) {
            return NO;
        }
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

    [toolbarStatusView canCancel: [best canCancel] && ![best isCancelled]];
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

-(void) setIsExtensionProject:(BOOL) isExtensionProject {
    toolbarStatusView.isExtensionProject = isExtensionProject;
}

-(void) setTestCases:(NSArray*) testCasesArray {
    if( testCasesPopUpButton != nil ) {
        // Remember current selected item
        NSString* selectedTitle = [[testCasesPopUpButton selectedItem] title];

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
            if( [testCasesPopUpButton selectedItem] == nil ) {
                if( [[testCasesPopUpButton itemArray] count] > 0 ) {
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
    int selectedIndex = (int) [testCasesPopUpButton indexOfSelectedItem];
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
