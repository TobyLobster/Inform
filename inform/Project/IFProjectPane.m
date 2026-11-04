//
//  IFProjectPane.m
//  Inform
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "IFProjectPane.h"
#import "IFProject.h"
#import "IFProjectController.h"
#import "IFAppDelegate.h"
#import "IFCompilerController.h"

#import "IFSourcePage.h"
#import "IFErrorsPage.h"
#import "IFIndexPage.h"
#import "IFSkeinPage.h"
#import "IFGamePage.h"
#import "IFDocumentationPage.h"
#import "IFExtensionsPage.h"
#import "IFSettingsPage.h"

#import "IFPreferences.h"

#import "IFRuntimeErrorParser.h"
#import "IFMaintenanceTask.h"

#import "IFGlkResources.h"

#import "IFHistoryEvent.h"
#import "IFPageBarCell.h"
#import "IFPageBarView.h"

#import "NSBundle+IFBundleExtensions.h"
#import <ZoomView/ZoomView.h>
#import <ZoomView/ZoomView-Swift.h>


static NSDictionary* IFSyntaxAttributes[256];

@implementation IFProjectPane {
    // Outlets
    /// The main pane view
    NSView*    paneView;
    /// The tab view
    NSTabView* tabView;

    // The page bar
    /// The page toolbar
    IBOutlet IFPageBarView* pageBar;

    /// The 'forward' button
    IFPageBarCell* forwardCell;
    /// The 'backwards' button
    IFPageBarCell* backCell;

    // History
    /// The history actions for this object
    NSMutableArray<IFHistoryEvent*>* history;
    /// The last history event created
    IFHistoryEvent* lastEvent;
    /// The position that we are in the history
    NSInteger       historyPos;
    /// If true, then new history items are not created
    BOOL            replaying;

    // The pages
    /// Pages being managed by this control
    NSMutableArray<IFPage*>* pages;

    // The pages
    /// The source page
    IFSourcePage*           sourcePage;
    /// The errors page
    IFErrorsPage*           errorsPage;
    /// The index page
    IFIndexPage*            indexPage;
    /// The skein page
    IFSkeinPage*            skeinPage;
    /// The game page
    IFGamePage*             gamePage;
    /// The documentation page
    IFDocumentationPage*    documentationPage;
    /// The extensions page
    IFExtensionsPage*       extensionsPage;
    /// The settings page
    IFSettingsPage*         settingsPage;

    IFProjectController *   controller;

    // Other variables
    /// \c YES if we've loaded from the nib and initialised properly
    BOOL awake;
    /// The 'parent' project controller (not retained)
    __weak IFProjectController* parent;
}


+ (IFProjectPane*) standardPane {
    return [[self alloc] init];
}

+ (void) initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
    NSFont* systemFont       = [NSFont systemFontOfSize: 11];
    NSFont* smallFont        = [NSFont boldSystemFontOfSize: 9];
    NSFont* boldSystemFont   = [NSFont boldSystemFontOfSize: 11];
    NSFont* headerSystemFont = [NSFont boldSystemFontOfSize: 12];
    NSFont* monospaceFont    = [NSFont fontWithName: @"Monaco"
                                               size: 9];

	[[ZoomPreferences globalPreferences] setDisplayWarnings: YES];

    // Default style
    NSDictionary* defaultStyle = @{NSFontAttributeName: systemFont,
        NSForegroundColorAttributeName: [NSColor textColor]};

    for (int x = 0; x < 256; x++) {
        IFSyntaxAttributes[x] = defaultStyle;
    }

    // Styles for various kinds of code
    IFSyntaxAttributes[IFSyntaxString]          = @{ NSFontAttributeName:            systemFont,
                                                     NSForegroundColorAttributeName: [NSColor colorWithDeviceRed: 0.53 green: 0.08 blue: 0.08 alpha: 1.0],
                                                     NSLigatureAttributeName:        @0 };
    IFSyntaxAttributes[IFSyntaxComment]         = @{ NSFontAttributeName:            smallFont,
                                                     NSForegroundColorAttributeName: [NSColor colorWithDeviceRed: 0.14 green: 0.43 blue: 0.14 alpha: 1.0],
                                                     NSLigatureAttributeName:        @0 };
    IFSyntaxAttributes[IFSyntaxMonospace]       = @{ NSFontAttributeName:            monospaceFont,
                                                     NSForegroundColorAttributeName: [NSColor blackColor],
                                                     NSLigatureAttributeName:        @0 };

    // Inform 6 syntax types
    IFSyntaxAttributes[IFSyntaxDirective]       = @{ NSFontAttributeName:            systemFont,
                                                     NSForegroundColorAttributeName: [NSColor colorWithDeviceRed: 0.20 green: 0.08 blue: 0.53 alpha: 1.0],
                                                     NSLigatureAttributeName:        @0};
    IFSyntaxAttributes[IFSyntaxProperty]        = @{ NSFontAttributeName:            boldSystemFont,
                                                     NSForegroundColorAttributeName: [NSColor colorWithDeviceRed: 0.08 green: 0.08 blue: 0.53 alpha: 1.0],
                                                     NSLigatureAttributeName:        @0};
    IFSyntaxAttributes[IFSyntaxFunction]        = @{ NSFontAttributeName:            boldSystemFont,
                                                     NSForegroundColorAttributeName: [NSColor colorWithDeviceRed: 0.08 green: 0.53 blue: 0.53 alpha: 1.0],
                                                     NSLigatureAttributeName:        @0};
    IFSyntaxAttributes[IFSyntaxCode]            = @{ NSFontAttributeName:            boldSystemFont,
                                                     NSForegroundColorAttributeName: [NSColor colorWithDeviceRed: 0.46 green: 0.06 blue: 0.31 alpha: 1.0],
                                                     NSLigatureAttributeName:        @0};
    IFSyntaxAttributes[IFSyntaxAssembly]        = @{ NSFontAttributeName:            boldSystemFont,
                                                     NSForegroundColorAttributeName: [NSColor colorWithDeviceRed: 0.46 green: 0.31 blue: 0.31 alpha: 1.0],
                                                     NSLigatureAttributeName:        @0};
    IFSyntaxAttributes[IFSyntaxCodeAlpha]       = @{ NSFontAttributeName:            systemFont,
                                                     NSForegroundColorAttributeName: [NSColor colorWithDeviceRed: 0.4 green: 0.4 blue: 0.3 alpha: 1.0],
                                                     NSLigatureAttributeName:        @0};
    IFSyntaxAttributes[IFSyntaxEscapeCharacter] = @{ NSFontAttributeName:            boldSystemFont,
                                                     NSForegroundColorAttributeName: [NSColor colorWithDeviceRed: 0.73 green: 0.2 blue: 0.73 alpha: 1.0],
                                                     NSLigatureAttributeName:        @0};

	// Natural Inform tab stops
	NSMutableParagraphStyle* tabStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];

	NSMutableArray* tabStops = [NSMutableArray array];
	for (int x = 0; x < 48; x++) {
		NSTextTab* tab = [[NSTextTab alloc] initWithType: NSLeftTabStopType
												location: 64.0 * (x+1)];
		[tabStops addObject: tab];
	}
	tabStyle.tabStops = tabStops;

    // Natural inform syntax types
	IFSyntaxAttributes[IFSyntaxNaturalInform] = @{ NSFontAttributeName:            systemFont,
                                                   NSForegroundColorAttributeName: [NSColor textColor],
                                                   NSParagraphStyleAttributeName:  tabStyle};
    IFSyntaxAttributes[IFSyntaxHeading]       = @{ NSFontAttributeName:            headerSystemFont,
                                                   NSForegroundColorAttributeName: [NSColor textColor],
                                                   NSParagraphStyleAttributeName:  tabStyle};
	IFSyntaxAttributes[IFSyntaxGameText]      = @{ NSFontAttributeName:            boldSystemFont,
                                                   NSForegroundColorAttributeName: [NSColor colorWithDeviceRed: 0.0 green: 0.3 blue: 0.6 alpha: 1.0],
                                                   NSParagraphStyleAttributeName:  tabStyle};
	IFSyntaxAttributes[IFSyntaxSubstitution]  = @{ NSFontAttributeName:            systemFont,
                                                   NSForegroundColorAttributeName: [NSColor systemPurpleColor],
                                                   NSParagraphStyleAttributeName:  tabStyle};

	// The 'plain' style is a bit of a special case. It's used for files that we want to run the syntax
	// highlighter on, but where we want the user to be able to set styles. The user will be able to set
	// certain styles even for things that are affected by the highlighter.
	IFSyntaxAttributes[IFSyntaxPlain] = @{NSForegroundColorAttributeName: [NSColor textColor]};
    });
}

- (instancetype) init {
    self = [super init];

    if (self) {
        parent  = nil;
        awake   = NO;
		
		pages   = [[NSMutableArray alloc] init];
		history = [[NSMutableArray alloc] init];
		historyPos = -1;
    }

    return self;
}

- (void) dealloc {
	[sourcePage finished];
	[errorsPage finished];
	[indexPage finished];
	[skeinPage finished];
	[gamePage finished];
	[documentationPage finished];
    [extensionsPage finished];
	[settingsPage finished];

	[pages makeObjectsPerformSelector: @selector(setRecorder:)  withObject: nil];
	[pages makeObjectsPerformSelector: @selector(setOtherPane:) withObject: nil];

    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

+ (NSDictionary*) attributeForStyle: (IFSyntaxStyle) style {
	return [IFPreferences sharedPreferences].styles[(unsigned)style];
}

@synthesize paneView;
- (NSView*) paneView {
    if (!awake) {
        [NSBundle customLoadNib: @"ProjectPane"
                          owner: self];
    }
    
    return paneView;
}

- (NSView*) activeView {
    switch (self.currentView) {
        case IFSourcePane:  return sourcePage.activeView;
        default:            return tabView.selectedTabViewItem.view;
    }
}

- (void) removeFromSuperview {
    [paneView removeFromSuperview];
}

- (void) setupFromControllerWithViewIndex:(NSInteger) viewIndex {
    IFProject* doc;
    IFProjectController* ourParent = parent;
	
    doc = ourParent.document;
	
	// Remove the first tab view item - which we can't do in interface builder :-/
	[tabView removeTabViewItem: tabView.tabViewItems[0]];
	
	// Source page
	sourcePage = [[IFSourcePage alloc] initWithProjectController: ourParent];
	[self addPage: sourcePage];

    if( doc.mainSourceFile != nil ) {
        [sourcePage showSourceFile: doc.mainSourceFile];
        [sourcePage updateHighlightedLines];
    }

	// Errors page
	errorsPage = [[IFErrorsPage alloc] initWithProjectController: ourParent
                                                        withPane: self];
	[self addPage: errorsPage];
    
	// Compiler (lives on the errors page)
    errorsPage.compilerController.compiler = doc.compiler;
    [errorsPage.compilerController setProjectController: ourParent withPane: self];

    // Game page
    if( viewIndex == 1 ) {
        gamePage = [[IFGamePage alloc] initWithProjectController: ourParent];
        [self addPage: gamePage];
    }
    
    // Skein page
    skeinPage = [[IFSkeinPage alloc] initWithProjectController: ourParent
                                                      withPane: self];
    [self addPage: skeinPage];
    
	// Index page
    indexPage = [[IFIndexPage alloc] initWithProjectController: ourParent
                                                      withPane: self];
	[self addPage: indexPage];
	
	[indexPage updateIndexView];
    // Start on the welcome page
    [indexPage switchToTab:IFIndexWelcome];
	
	// Documentation page
    documentationPage = [[IFDocumentationPage alloc] initWithProjectController: ourParent
                                                                      withPane: self];
	[self addPage: documentationPage];
    LogHistory(@"HISTORY: ProjectPane (%@): (setupFromController) documentationPage:showToc", self);
	[(IFDocumentationPage*)documentationPage.history showToc: self];
	
    // Extensions page
    extensionsPage = [[IFExtensionsPage alloc] initWithProjectController: ourParent
                                                                withPane: self];
	[self addPage: extensionsPage];
    LogHistory(@"HISTORY: ProjectPane (%@): (setupFromController) extensionsPage:showHome", self);
	[(IFExtensionsPage*)extensionsPage.history showHome: self];

	// Settings
	settingsPage = [[IFSettingsPage alloc] initWithProjectController: ourParent];
	[self addPage: settingsPage];

    [settingsPage updateSettings];

	// Misc stuff

	// Resize the tab view so that the only margin is on the left
	NSView* tabViewParent = tabView.superview;
	NSView* tabViewClient = tabView.selectedTabViewItem.view;

	NSRect clientRect   = [tabViewParent convertRect: tabViewClient.bounds
                                            fromView: tabViewClient];
	NSRect parentRect   = tabViewParent.bounds;
	NSRect tabRect      = tabView.frame;

	//float leftMissing = NSMinX(clientRect) - NSMinX(parentRect);
	CGFloat topMissing    = NSMinY(clientRect) - NSMinY(parentRect);
    CGFloat bottomMissing = NSMaxY(parentRect) - NSMaxY(clientRect);

	//tabRect.origin.x -= leftMissing;
	//tabRect.size.width += leftMissing;
	tabRect.origin.y -= topMissing;
	tabRect.size.height += topMissing + bottomMissing;

	tabView.frame = tabRect;

	[self.history selectViewOfType: IFSourcePane];
}

- (void) awakeFromNib {
    awake = YES;

    if (parent) {
        [self setupFromControllerWithViewIndex:0];
        [gamePage stopRunningGame];
    }
	
    tabView.delegate = self;
	
	// Set up the backwards/forwards buttons
	backCell    = [[IFPageBarCell alloc] initImageCell: [NSImage imageNamed: NSImageNameGoBackTemplate]];
	forwardCell = [[IFPageBarCell alloc] initImageCell: [NSImage imageNamed: NSImageNameGoForwardTemplate]];

	[backCell    setKeyEquivalent: @"-"];
	[forwardCell setKeyEquivalent: @"="];

	backCell.target = self;
	forwardCell.target = self;
	backCell.action = @selector(goBackwards:);
	forwardCell.action = @selector(goForwards:);

	[pageBar setLeftCells: @[backCell, forwardCell]];
}

@synthesize controller;

- (void) setController: (IFProjectController*) p
             viewIndex: (NSInteger) viewIndex {
    if (!awake) {
        [NSBundle customLoadNib: @"ProjectPane"
                          owner: self];
    }

    parent = p;

    if (awake) {
        [self setupFromControllerWithViewIndex: viewIndex];
    }
}

- (void) willClose {
	// The history might reference this object (or cause a circular reference some other way), so we destroy it now
	history     = nil;
	lastEvent   = nil;
	historyPos  = 0;

    for( IFPage* page in pages ) {
        if( [page respondsToSelector:@selector(willClose)] ) {
            [page willClose];
        }
    }
}

- (NSTabViewItem*) tabViewItemForPage: (IFPage*) page {
	return [tabView tabViewItemAtIndex: [tabView indexOfTabViewItemWithIdentifier: page.identifier]];
}

- (IFPage*) pageForTabViewItem: (NSTabViewItem*) item {
	NSString* identifier = item.identifier;
	for( IFPage* page in pages ) {
		if ([page.identifier isEqualToString: identifier]) {
			return page;
		}
	}

	return nil;
}

- (void) selectViewOfType: (enum IFProjectPaneType) pane {
    if (!awake) {
        [NSBundle customLoadNib: @"ProjectPane"
                          owner: self];
    }
    
    NSTabViewItem* toSelect = nil;
    switch (pane) {
        case IFSourcePane:        toSelect = [self tabViewItemForPage: sourcePage];        break;
        case IFErrorPane:         toSelect = [self tabViewItemForPage: errorsPage];        break;
        case IFGamePane:          toSelect = [self tabViewItemForPage: gamePage];          break;
        case IFDocumentationPane: toSelect = [self tabViewItemForPage: documentationPage]; break;
		case IFIndexPane:         toSelect = [self tabViewItemForPage: indexPage];         break;
		case IFSkeinPane:         toSelect = [self tabViewItemForPage: skeinPage];         break;
        case IFExtensionsPane:    toSelect = [self tabViewItemForPage: extensionsPage];    break;
		case IFUnknownPane:
			// No idea
			break;
    }

    if (toSelect) {
        [tabView selectTabViewItem: toSelect];
    } else {
        NSLog(@"Unable to select pane");
    }
}

- (enum IFProjectPaneType) currentView {
    id selectedId = tabView.selectedTabViewItem.identifier;

    if ([selectedId isEqualTo: sourcePage.identifier])        return IFSourcePane;
    if ([selectedId isEqualTo: errorsPage.identifier])        return IFErrorPane;
    if ([selectedId isEqualTo: gamePage.identifier])          return IFGamePane;
    if ([selectedId isEqualTo: documentationPage.identifier]) return IFDocumentationPane;
	if ([selectedId isEqualTo: indexPage.identifier])         return IFIndexPane;
	if ([selectedId isEqualTo: skeinPage.identifier])         return IFSkeinPane;
    if ([selectedId isEqualTo: extensionsPage.identifier])    return IFExtensionsPane;

    return IFSourcePane;
}

- (void) setIsActive: (BOOL) isActive {
	[pageBar setIsActive: isActive];
}

- (IFCompilerController*) compilerController {
    return errorsPage.compilerController;
}

#pragma mark - Menu actions

- (BOOL)validateMenuItem:(NSMenuItem*) menuItem {
	return YES;
}

#pragma mark - The source view

- (void) prepareToSave {
	[sourcePage prepareToSave];
}

- (void) showSourceFile: (NSString*) file {
	[self.sourcePage showSourceFile: file];
}

#pragma mark - The pages

@synthesize sourcePage;
@synthesize errorsPage;
@synthesize indexPage;
@synthesize skeinPage;
@synthesize gamePage;
@synthesize documentationPage;
@synthesize extensionsPage;
@synthesize settingsPage;

#pragma mark - The game page

- (void) stopRunningGame {
	[gamePage stopRunningGame];
}

#pragma mark - Tab view delegate

- (BOOL)            tabView: (NSTabView *)view 
    shouldSelectTabViewItem: (NSTabViewItem *)item {
	// Get the identifier for this tab page
	id identifier = item.identifier;
	if (identifier == nil) return YES;
	
	// Find the associated IFPage object
    IFPage* page = nil;
	for( IFPage* possiblePage in pages ) {
		if ([possiblePage.identifier isEqual: identifier]) {
            page = possiblePage;
			break;
		}
	}

	if (page != nil) {
        // HACK: When Lion auto-restores documents, it wants to switch pages to something random.
        // We stop the madness here.
        if( !parent.safeToSwitchTabs ) {
            return NO;
        }
		return page.shouldShowPage;
	}
	
	return YES;
}

- (void) selectTabViewItem: (NSTabViewItem*) item {
	[tabView selectTabViewItem: item];
}

- (void) activatePage: (IFPage*) page {
	// Select the active view for the specified page
	[parent.window makeFirstResponder: page.activeView];
}

- (void)        tabView: (NSTabView *)thisTabView
  willSelectTabViewItem: (NSTabViewItem *)tabViewItem {
	IFPage* page		= [self pageForTabViewItem: tabViewItem];
	IFPage* lastPage	= [self pageForTabViewItem: thisTabView.selectedTabViewItem];
	
	// Record in the history
    LogHistory(@"HISTORY: Project Pane (%@): (willSelectTabViewItem) page %@ tabViewItem %@", self, page, tabViewItem);
	[self.history selectTabViewItem: tabViewItem];
	[self.history activatePage: page];

	// Notify the page that it has been selected
	[page setPageIsVisible: YES];
	[lastPage setPageIsVisible: NO];
	[lastPage didSwitchAwayFromPage];
	[page didSwitchToPage];
	
	// Update the right-hand page bar cells
	[pageBar setRightCells: [self pageForTabViewItem: tabViewItem].toolbarCells];
}

#pragma mark - The tab view

@synthesize tabView;

#pragma mark - Find

- (void) performFindPanelAction: (id) sender {
}

#pragma mark - Dealing with pages

- (void) refreshToolbarCells: (NSNotification*) not {
	// Work out which page we're updating
	IFPage* page = not.object;
	
	// Refresh the page bar cells
	if (page == [self pageForTabViewItem: tabView.selectedTabViewItem]) {
		[pageBar setRightCells: page.toolbarCells];
	}
}

- (void) switchToPage: (NSNotification*) not {
	// Work out which page we're switching to, and the optional page that must be showing for the switch to occur
	NSString* identifier = not.userInfo[@"Identifier"];
	NSString* fromPage = not.userInfo[@"OldPageIdentifier"];

	// If no 'to' page is specified, then switch to the sending object
	if (identifier == nil) identifier = ((IFPage*)not.object).identifier;
	
	// If a 'from' page is specified, then the current page must be that page, or the switch won't take place
	if (fromPage != nil) {
		id currentPage = tabView.selectedTabViewItem.identifier;
		if (![fromPage isEqualTo: currentPage]) {
			return;
		}
	}

	// Select the page
	[tabView selectTabViewItem: [tabView tabViewItemAtIndex: [tabView indexOfTabViewItemWithIdentifier: identifier]]];
}

- (void) addPage: (IFPage*) newPage {
	// Add this page to the list of pages being managed by this control
	[pages addObject: newPage];
	newPage.thisPane = self;
	newPage.otherPane = [parent oppositePane: self];
	newPage.recorder = self;

	// Register for notifications from this page
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(switchToPage:)
												 name: IFSwitchToPageNotification
											   object: newPage];
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(refreshToolbarCells:)
												 name: IFUpdatePageBarCellsNotification
											   object: newPage];

	// Add the page to the tab view
	NSTabViewItem* newItem = [[NSTabViewItem alloc] initWithIdentifier: newPage.identifier];
	newItem.label = newPage.title;

	[tabView addTabViewItem: newItem];

	if (newItem.view.frame.size.width <= 0) {
		[newItem.view setFrameSize: NSMakeSize(1280, 1024)];
	}
	newPage.view.frame = newItem.view.bounds;
	[newItem.view addSubview: newPage.view];
}

#pragma mark - The history

- (void) updateHistoryControls {
	if (historyPos <= 0) {
		[backCell setEnabled: NO];
	} else {
		[backCell setEnabled: YES];
	}

	if (historyPos >= history.count-1) {
		[forwardCell setEnabled: NO];
	} else {
		[forwardCell setEnabled: YES];
	}
}

- (void) clearLastEvent {
	lastEvent = nil;
}

- (void) addHistoryEvent: (IFHistoryEvent*) newEvent {
    LogHistory(@"HISTORY: Project Pane (%@): (addHistoryEvent) %@", self, newEvent);
	if (newEvent == nil) return;
	
	// If we've gone backwards in the history, then remove the 'forward' history items
	if (historyPos != history.count-1) {
		[history removeObjectsInRange: NSMakeRange(historyPos+1, history.count-(historyPos+1))];
	}
	
	// Add the new history item
	[history addObject: newEvent];
	historyPos++;
	
	// Record it as the last event
	if (lastEvent == nil) {
		[[NSRunLoop currentRunLoop] performSelector: @selector(clearLastEvent)
											 target: self
										   argument: nil
											  order: 99
											  modes: @[NSDefaultRunLoopMode]];
	}
	
	lastEvent = newEvent;
	
	[self updateHistoryControls];
}

- (IFHistoryEvent*) historyEvent {
	if (replaying) return nil;
	
	IFHistoryEvent* event;
	if (lastEvent) {
		event = lastEvent;
	} else {
		// Construct a new event based on this obejct
		IFHistoryEvent* newEvent = [[IFHistoryEvent alloc] initWithObject: self];
		[self addHistoryEvent: newEvent];
		
		event = newEvent;
	}
	
	return event;
}

- (void) addHistoryInvocation: (NSInvocation*) invoke {
	if (replaying) return;
	
	// Construct a new event based on the invocation
	IFHistoryEvent* newEvent = [[IFHistoryEvent alloc] initWithInvocation: invoke];
	[self addHistoryEvent: newEvent];
}

- (id) history {
	if (replaying) return nil;
	
	IFHistoryEvent* event;
	if (lastEvent) {
		event = lastEvent;
	} else {
		// Construct a new event based on this obejct
		IFHistoryEvent* newEvent = [[IFHistoryEvent alloc] initWithObject: self];
		[self addHistoryEvent: newEvent];
		
		event = newEvent;
	}
	
	// Return a suitable proxy
	event.target = self;
	return event.proxy;
}

- (void) goBackwards: (id) sender {
	if (historyPos <= 0) return;
	
	
	replaying = YES;
	[history[historyPos-1] replay];
	historyPos--;
	replaying = NO;
	
	[self updateHistoryControls];
}

- (void) goForwards: (id) sender {
	if (historyPos >= history.count-1) return;
	
	
	replaying = YES;
	[history[historyPos+1] replay];
	historyPos++;
	replaying = NO;
	
	[self updateHistoryControls];
}

// Extension updated
-(void) extensionUpdated:(NSString*) javascriptId {
    [extensionsPage extensionUpdated: javascriptId];
}

@end
