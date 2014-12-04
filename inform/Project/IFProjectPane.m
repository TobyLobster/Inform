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

#import "IFIsFiles.h"
#import "IFIsWatch.h"

#import "IFPreferences.h"

#import "IFJSProject.h"
#import "IFRuntimeErrorParser.h"
#import "IFMaintenanceTask.h"

#import "IFGlkResources.h"

#import "IFHistoryEvent.h"

#import "IFImageCache.h"
#import "NSBundle+IFBundleExtensions.h"

static NSDictionary* IFSyntaxAttributes[256];

@implementation IFProjectPane

+ (IFProjectPane*) standardPane {
    return [[[self alloc] init] autorelease];
}

+ (void) initialize {
    NSFont* systemFont       = [NSFont systemFontOfSize: 11];
    NSFont* smallFont        = [NSFont boldSystemFontOfSize: 9];
    NSFont* boldSystemFont   = [NSFont boldSystemFontOfSize: 11];
    NSFont* headerSystemFont = [NSFont boldSystemFontOfSize: 12];
    NSFont* monospaceFont    = [NSFont fontWithName: @"Monaco"
                                               size: 9];
	
	[[ZoomPreferences globalPreferences] setDisplayWarnings: YES];
	    
    // Default style
    NSDictionary* defaultStyle = [[NSDictionary dictionaryWithObjectsAndKeys:
        systemFont,           NSFontAttributeName,
        [NSColor blackColor], NSForegroundColorAttributeName,
        nil] retain];
    int x;
    
    for (x=0; x<256; x++) {
        IFSyntaxAttributes[x] = defaultStyle;
    }
    
    // This set of styles will eventually be the 'colourful' set
    // We also need a 'no styles' set (probably just turn off the highlighter, gives
    // speed advantages), and a 'subtle' set (styles indicated only by font changes)
    
    // Styles for various kinds of code
    IFSyntaxAttributes[IFSyntaxString] = [[NSDictionary dictionaryWithObjectsAndKeys:
        systemFont, NSFontAttributeName,
        [NSColor colorWithDeviceRed: 0.53 green: 0.08 blue: 0.08 alpha: 1.0], NSForegroundColorAttributeName,
		[NSNumber numberWithInt: 0], NSLigatureAttributeName,
        nil] retain];
    IFSyntaxAttributes[IFSyntaxComment] = [[NSDictionary dictionaryWithObjectsAndKeys:
        smallFont, NSFontAttributeName,
        [NSColor colorWithDeviceRed: 0.14 green: 0.43 blue: 0.14 alpha: 1.0], NSForegroundColorAttributeName,
		[NSNumber numberWithInt: 0], NSLigatureAttributeName,
        nil] retain];
    IFSyntaxAttributes[IFSyntaxMonospace] = [[NSDictionary dictionaryWithObjectsAndKeys:
        monospaceFont, NSFontAttributeName,
        [NSColor blackColor], NSForegroundColorAttributeName,
		[NSNumber numberWithInt: 0], NSLigatureAttributeName,
        nil] retain];
    
    // Inform 6 syntax types
    IFSyntaxAttributes[IFSyntaxDirective] = [[NSDictionary dictionaryWithObjectsAndKeys:
        systemFont, NSFontAttributeName,
        [NSColor colorWithDeviceRed: 0.20 green: 0.08 blue: 0.53 alpha: 1.0], NSForegroundColorAttributeName,
		[NSNumber numberWithInt: 0], NSLigatureAttributeName,
        nil] retain];
    IFSyntaxAttributes[IFSyntaxProperty] = [[NSDictionary dictionaryWithObjectsAndKeys:
        boldSystemFont, NSFontAttributeName,
        [NSColor colorWithDeviceRed: 0.08 green: 0.08 blue: 0.53 alpha: 1.0], NSForegroundColorAttributeName,
		[NSNumber numberWithInt: 0], NSLigatureAttributeName,
        nil] retain];
    IFSyntaxAttributes[IFSyntaxFunction] = [[NSDictionary dictionaryWithObjectsAndKeys:
        boldSystemFont, NSFontAttributeName,
        [NSColor colorWithDeviceRed: 0.08 green: 0.53 blue: 0.53 alpha: 1.0], NSForegroundColorAttributeName,
		[NSNumber numberWithInt: 0], NSLigatureAttributeName,
        nil] retain];
    IFSyntaxAttributes[IFSyntaxCode] = [[NSDictionary dictionaryWithObjectsAndKeys:
        boldSystemFont, NSFontAttributeName,
        [NSColor colorWithDeviceRed: 0.46 green: 0.06 blue: 0.31 alpha: 1.0], NSForegroundColorAttributeName,
		[NSNumber numberWithInt: 0], NSLigatureAttributeName,
        nil] retain];
    IFSyntaxAttributes[IFSyntaxAssembly] = [[NSDictionary dictionaryWithObjectsAndKeys:
        boldSystemFont, NSFontAttributeName,
        [NSColor colorWithDeviceRed: 0.46 green: 0.31 blue: 0.31 alpha: 1.0], NSForegroundColorAttributeName,
		[NSNumber numberWithInt: 0], NSLigatureAttributeName,
        nil] retain];
    IFSyntaxAttributes[IFSyntaxCodeAlpha] = [[NSDictionary dictionaryWithObjectsAndKeys:
        systemFont, NSFontAttributeName,
        [NSColor colorWithDeviceRed: 0.4 green: 0.4 blue: 0.3 alpha: 1.0], NSForegroundColorAttributeName,
		[NSNumber numberWithInt: 0], NSLigatureAttributeName,
        nil] retain];
    IFSyntaxAttributes[IFSyntaxEscapeCharacter] = [[NSDictionary dictionaryWithObjectsAndKeys:
        boldSystemFont, NSFontAttributeName,
        [NSColor colorWithDeviceRed: 0.73 green: 0.2 blue: 0.73 alpha: 1.0], NSForegroundColorAttributeName,
		[NSNumber numberWithInt: 0], NSLigatureAttributeName,
        nil] retain];
	
	// Natural Inform tab stops
	NSMutableParagraphStyle* tabStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[tabStyle autorelease];

	NSMutableArray* tabStops = [NSMutableArray array];
	for (x=0; x<48; x++) {
		NSTextTab* tab = [[NSTextTab alloc] initWithType: NSLeftTabStopType
												location: 64.0*(x+1)];
		[tabStops addObject: tab];
		[tab release];
	}
	[tabStyle setTabStops: tabStops];
	
    // Natural inform syntax types
	IFSyntaxAttributes[IFSyntaxNaturalInform] = [[NSDictionary dictionaryWithObjectsAndKeys:
        systemFont, NSFontAttributeName, 
        [NSColor blackColor], NSForegroundColorAttributeName,
		tabStyle, NSParagraphStyleAttributeName,
        nil] retain];	
    IFSyntaxAttributes[IFSyntaxHeading] = [[NSDictionary dictionaryWithObjectsAndKeys:
        headerSystemFont, NSFontAttributeName,
		[NSColor blackColor], NSForegroundColorAttributeName,
		tabStyle, NSParagraphStyleAttributeName,
        nil] retain];
	IFSyntaxAttributes[IFSyntaxGameText] = [[NSDictionary dictionaryWithObjectsAndKeys:
        boldSystemFont, NSFontAttributeName,
        [NSColor colorWithDeviceRed: 0.0 green: 0.3 blue: 0.6 alpha: 1.0], NSForegroundColorAttributeName,
		tabStyle, NSParagraphStyleAttributeName,
        nil] retain];	
	IFSyntaxAttributes[IFSyntaxSubstitution] = [[NSDictionary dictionaryWithObjectsAndKeys:
		systemFont, NSFontAttributeName,
        [NSColor colorWithDeviceRed: 0.3 green: 0.3 blue: 1.0 alpha: 1.0], NSForegroundColorAttributeName,
		tabStyle, NSParagraphStyleAttributeName,
        nil] retain];	
	
	// The 'plain' style is a bit of a special case. It's used for files that we want to run the syntax
	// highlighter on, but where we want the user to be able to set styles. The user will be able to set
	// certain styles even for things that are affected by the highlighter.
	IFSyntaxAttributes[IFSyntaxPlain] = [[NSDictionary dictionary] retain];
}

- (id) init {
    self = [super init];

    if (self) {
        parent = nil;
        awake = NO;
		
		pages = [[NSMutableArray alloc] init];
		
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
	[transcriptPage finished];
	[gamePage finished];
	[documentationPage finished];
    [extensionsPage finished];
	[settingsPage finished];

	[sourcePage release];
	[errorsPage release];
	[indexPage release];
	[skeinPage release];
	[transcriptPage release];
	[gamePage release];
	[documentationPage release];
    [extensionsPage release];
	[settingsPage release];

	[pages makeObjectsPerformSelector: @selector(setRecorder:)
						   withObject: nil];
	[pages makeObjectsPerformSelector: @selector(setOtherPane:)
						   withObject: nil];
	[pages release];

	[history release];
	[backCell release];
	[forwardCell release];
	[lastEvent release];

    [[NSNotificationCenter defaultCenter] removeObserver: self];

    [paneView release];

    [super dealloc];
}

+ (NSDictionary*) attributeForStyle: (IFSyntaxStyle) style {
	return [[[IFPreferences sharedPreferences] styles] objectAtIndex: (unsigned)style];
	// return IFSyntaxAttributes[style];
}

- (NSView*) paneView {
    if (!awake) {
        [NSBundle oldLoadNibNamed: @"ProjectPane"
                            owner: self];
    }
    
    return paneView;
}

- (NSView*) activeView {
    switch ([self currentView]) {
        case IFSourcePane:
            return [sourcePage activeView];
        default:
            return [[tabView selectedTabViewItem] view];
    }
}

- (void) removeFromSuperview {
    [paneView removeFromSuperview];
}

- (void) setupFromController {
    IFProject* doc;
	
    doc = [parent document];
	
	// Remove the first tab view item - which we can't do in interface builder :-/
	[tabView removeTabViewItem: [[tabView tabViewItems] objectAtIndex: 0]];
	
	// Source page
	sourcePage = [[IFSourcePage alloc] initWithProjectController: parent];
	[self addPage: sourcePage];

	[sourcePage showSourceFile: [doc mainSourceFile]];
	[sourcePage updateHighlightedLines];
	
	// Errors page
	errorsPage = [[IFErrorsPage alloc] initWithProjectController: parent];
	[self addPage: errorsPage];
    
	// Compiler (lives on the errors page)
    [[errorsPage compilerController] setCompiler: [doc compiler]];
	
	// Index page
	indexPage = [[IFIndexPage alloc] initWithProjectController: parent];
	[self addPage: indexPage];
	
	[indexPage updateIndexView];
    // Start on the welcome page
    [indexPage switchToTab:IFIndexWelcome];
	
	// Skein page
	skeinPage = [[IFSkeinPage alloc] initWithProjectController: parent];
	[self addPage: skeinPage];
	
	// Transcript page
	transcriptPage = [[IFTranscriptPage alloc] initWithProjectController: parent];
	[self addPage: transcriptPage];
	
	// Game page
	gamePage = [[IFGamePage alloc] initWithProjectController: parent];
	[self addPage: gamePage];
	
	// Documentation page
	documentationPage = [[IFDocumentationPage alloc] initWithProjectController: parent];
	[self addPage: documentationPage];
    LogHistory(@"HISTORY: ProjectPane (%@): (setupFromController) documentationPage:showToc", self);
	[(IFDocumentationPage*)[documentationPage history] showToc: self];
	
    // Extensions page
    extensionsPage = [[IFExtensionsPage alloc] initWithProjectController: parent];
	[self addPage: extensionsPage];
    LogHistory(@"HISTORY: ProjectPane (%@): (setupFromController) extensionsPage:showHome", self);
	[(IFExtensionsPage*)[extensionsPage history] showHome: self];
    
	// Settings
	settingsPage = [[IFSettingsPage alloc] initWithProjectController: parent];
	[self addPage: settingsPage];
	
    [settingsPage updateSettings];
	
	// Misc stuff

	// Resize the tab view so that the only margin is on the left
	NSView* tabViewParent = [tabView superview];
	NSView* tabViewClient = [[tabView selectedTabViewItem] view];
	
	NSRect clientRect = [tabViewParent convertRect: [tabViewClient bounds]
										  fromView: tabViewClient];
	NSRect parentRect = [tabViewParent bounds];
	NSRect tabRect = [tabView frame];
	
	//float leftMissing = NSMinX(clientRect) - NSMinX(parentRect);
	float topMissing = NSMinY(clientRect) - NSMinY(parentRect);
	float bottomMissing = NSMaxY(parentRect) - NSMaxY(clientRect);

	//tabRect.origin.x -= leftMissing;
	//tabRect.size.width += leftMissing;
	tabRect.origin.y -= topMissing;
	tabRect.size.height += topMissing + bottomMissing;

	[tabView setFrame: tabRect];
	
	[[self history] selectViewOfType: IFSourcePane];
}

- (void) awakeFromNib {
    awake = YES;
	    	
    if (parent) {
        [self setupFromController];
        [gamePage stopRunningGame];
    }
	
    [tabView setDelegate: self];
	
	// Set up the backwards/forwards buttons
	backCell = [[IFPageBarCell alloc] initImageCell: [IFImageCache loadResourceImage: @"App/PageBar/BackArrow.png"]];
	forwardCell = [[IFPageBarCell alloc] initImageCell: [IFImageCache loadResourceImage: @"App/PageBar/ForeArrow.png"]];
	
	[backCell setKeyEquivalent: @"-"];
	[forwardCell setKeyEquivalent: @"="];
	
	[backCell setTarget: self];
	[forwardCell setTarget: self];
	[backCell setAction: @selector(goBackwards:)];
	[forwardCell setAction: @selector(goForwards:)];
	
	[pageBar setLeftCells: [NSArray arrayWithObjects: backCell, forwardCell, nil]];
}

- (void) setController: (IFProjectController*) p {
    if (!awake) {
        [NSBundle oldLoadNibNamed: @"ProjectPane"
                            owner: self];
    }

    // (Don't need to retain parent, as the parent 'owns' us)
    // Don't need to release for similar reasons.
    parent = p;

    if (awake) {
        [self setupFromController];
    }
}

- (IFProjectController*) controller {
    return parent;
}

- (void) willClose {
	// The history might reference this object (or cause a circular reference some other way), so we destroy it now
	[history release]; history = nil;
	[lastEvent release]; lastEvent = nil;
	historyPos = 0;
    
    for( IFPage* page in pages ) {
        if( [page respondsToSelector:@selector(willClose)] ) {
            [page willClose];
        }
    }
}

- (NSTabViewItem*) tabViewItemForPage: (IFPage*) page {
	return [tabView tabViewItemAtIndex: [tabView indexOfTabViewItemWithIdentifier: [page identifier]]];
}

- (IFPage*) pageForTabViewItem: (NSTabViewItem*) item {
	NSString* identifier = [item identifier];
	for( IFPage* page in pages ) {
		if ([[page identifier] isEqualToString: identifier]) {
			return page;
		}
	}
	
	return nil;
}

- (void) selectViewOfType: (enum IFProjectPaneType) pane {
    if (!awake) {
        [NSBundle oldLoadNibNamed: @"ProjectPane"
                            owner: self];
    }
    
    NSTabViewItem* toSelect = nil;
    switch (pane) {
        case IFSourcePane:
            toSelect = [self tabViewItemForPage: sourcePage];
            break;

        case IFErrorPane:
            toSelect = [self tabViewItemForPage: errorsPage];
            break;

        case IFGamePane:
            toSelect = [self tabViewItemForPage: gamePage];
            break;

        case IFDocumentationPane:
            toSelect = [self tabViewItemForPage: documentationPage];
            break;
			
		case IFIndexPane:
            toSelect = [self tabViewItemForPage: indexPage];
			break;
			
		case IFSkeinPane:
			toSelect = [self tabViewItemForPage: skeinPage];
			break;
			
		case IFTranscriptPane:
			toSelect = [self tabViewItemForPage: transcriptPage];
			break;
			
        case IFExtensionsPane:
            toSelect = [self tabViewItemForPage: extensionsPage];
            break;
			
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
    NSTabViewItem* selectedView = [tabView selectedTabViewItem];

    if ([[selectedView identifier] isEqualTo: [sourcePage identifier]]) {
        return IFSourcePane;
    } else if ([[selectedView identifier] isEqualTo: [errorsPage identifier]]) {
        return IFErrorPane;
    } else if ([[selectedView identifier] isEqualTo: [gamePage identifier]]) {
        return IFGamePane;
    } else if ([[selectedView identifier] isEqualTo: [documentationPage identifier]]) {
        return IFDocumentationPane;
	} else if ([[selectedView identifier] isEqualTo: [indexPage identifier]]) {
		return IFIndexPane;
	} else if ([[selectedView identifier] isEqualTo: [skeinPage identifier]]) {
		return IFSkeinPane;
	} else if ([[selectedView identifier] isEqualTo: [transcriptPage identifier]]) {
		return IFTranscriptPane;
    } else if ([[selectedView identifier] isEqualTo: [extensionsPage identifier]]) {
        return IFExtensionsPane;
    } else {
        return IFSourcePane;
    }
}

- (void) setIsActive: (BOOL) isActive {
	[pageBar setIsActive: isActive];
}

- (IFCompilerController*) compilerController {
    return [errorsPage compilerController];
}

// = Menu actions =

- (BOOL)validateMenuItem:(NSMenuItem*) menuItem {
	// Can't add breakpoints if we're not showing the source view
	// (Moot: this never gets called at any point where it is useful at the moment)
	if ([menuItem action] == @selector(setBreakpoint:) ||
		[menuItem action] == @selector(deleteBreakpoint:)) {
		return [self currentView]==IFSourcePane;
	}
	
	return YES;
}

// = The source view =

- (void) prepareToCompile {
	[sourcePage prepareToCompile];
}

- (void) showSourceFile: (NSString*) file {
	[[self sourcePage] showSourceFile: file];
}

// = The pages =

- (IFSourcePage*) sourcePage {
	return sourcePage;
}

- (IFErrorsPage*) errorsPage {
	return errorsPage;
}

- (IFIndexPage*) indexPage {
	return indexPage;
}

- (IFSkeinPage*) skeinPage {
	return skeinPage;
}

- (IFTranscriptPage*) transcriptPage {
	return transcriptPage;
}

- (IFGamePage*) gamePage {
	return gamePage;
}

- (IFDocumentationPage*) documentationPage {
	return documentationPage;
}

- (IFExtensionsPage*) extensionsPage {
	return extensionsPage;
}

- (IFSettingsPage*) settingsPage {
	return settingsPage;
}

// = The game page =

- (void) stopRunningGame {
	[gamePage stopRunningGame];
}

// = Tab view delegate =

- (BOOL)            tabView: (NSTabView *)view 
    shouldSelectTabViewItem: (NSTabViewItem *)item {
	// Get the identifier for this tab page
	id identifier = [item identifier];
	if (identifier == nil) return YES;
	
	// Find the associated IFPage object
    IFPage* page = nil;
	for( IFPage* possiblePage in pages ) {
		if ([[possiblePage identifier] isEqual: identifier]) {
            page = possiblePage;
			break;
		}
	}

	if (page != nil) {
        // HACK: When Lion auto-restores documents, it wants to switch pages to something random.
        // We stop the madness here.
        if( ![parent safeToSwitchTabs] ) {
            return NO;
        }
		return [page shouldShowPage];
	}
	
	return YES;
}

- (void) selectTabViewItem: (NSTabViewItem*) item {
	[tabView selectTabViewItem: item];
}

- (void) activatePage: (IFPage*) page {
	// Select the active view for the specified page
	[[parent window] makeFirstResponder: [page activeView]];
}

- (void)        tabView: (NSTabView *)thisTabView
  willSelectTabViewItem: (NSTabViewItem *)tabViewItem {
	IFPage* page		= [self pageForTabViewItem: tabViewItem];
	IFPage* lastPage	= [self pageForTabViewItem: [thisTabView selectedTabViewItem]];
	
	// Record in the history
    LogHistory(@"HISTORY: Project Pane (%@): (willSelectTabViewItem) page %@ tabViewItem %@", self, page, tabViewItem);
	[[self history] selectTabViewItem: tabViewItem];
	[[self history] activatePage: page];

	// Notify the page that it has been selected
	[page setPageIsVisible: YES];
	[lastPage setPageIsVisible: NO];
	[lastPage didSwitchAwayFromPage];
	[page didSwitchToPage];
	
	// Update the right-hand page bar cells
	[pageBar setRightCells: [[self pageForTabViewItem: tabViewItem] toolbarCells]];
}

// = The tab view =

- (NSTabView*) tabView {
	return tabView;
}

// = Find =

- (void) performFindPanelAction: (id) sender {
	NSLog(@"Bing!");
}

// = Dealing with pages =

- (void) refreshToolbarCells: (NSNotification*) not {
	// Work out which page we're updating
	IFPage* page = [not object];
	
	// Refresh the page bar cells
	if (page == [self pageForTabViewItem: [tabView selectedTabViewItem]]) {
		[pageBar setRightCells: [page toolbarCells]];
	}
}

- (void) switchToPage: (NSNotification*) not {
	// Work out which page we're switching to, and the optional page that must be showing for the switch to occur
	NSString* identifier = [[not userInfo] objectForKey: @"Identifier"];
	NSString* fromPage = [[not userInfo] objectForKey: @"OldPageIdentifier"];

	// If no 'to' page is specified, then switch to the sending object
	if (identifier == nil) identifier = [(IFPage*)[not object] identifier];
	
	// If a 'from' page is specified, then the current page must be that page, or the switch won't take place
	if (fromPage != nil) {
		id currentPage = [[tabView selectedTabViewItem] identifier];
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
	[newPage setThisPane: self];
	[newPage setOtherPane: [parent oppositePane: self]];
	[newPage setRecorder: self];
	
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
	NSTabViewItem* newItem = [[NSTabViewItem alloc] initWithIdentifier: [newPage identifier]];
	[newItem setLabel: [newPage title]];

	[tabView addTabViewItem: [newItem autorelease]];

	if ([[newItem view] frame].size.width <= 0) {
		[[newItem view] setFrameSize: NSMakeSize(1280, 1024)];
	}
	[[newPage view] setFrame: [[newItem view] bounds]];
	[[newItem view] addSubview: [newPage view]];
}

// = The history =

- (void) updateHistoryControls {
	if (historyPos <= 0) {
		[backCell setEnabled: NO];
	} else {
		[backCell setEnabled: YES];
	}
	
	if (historyPos >= [history count]-1) {
		[forwardCell setEnabled: NO];
	} else {
		[forwardCell setEnabled: YES];
	}
}

- (void) clearLastEvent {
	[lastEvent release];
	lastEvent = nil;
}

- (void) addHistoryEvent: (IFHistoryEvent*) newEvent {
    LogHistory(@"HISTORY: Project Pane (%@): (addHistoryEvent) %@", self, newEvent);
	if (newEvent == nil) return;
	
	// If we've gone backwards in the history, then remove the 'forward' history items
	if (historyPos != [history count]-1) {
		[history removeObjectsInRange: NSMakeRange(historyPos+1, [history count]-(historyPos+1))];
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
											  modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
	}
	
	[lastEvent autorelease];
	lastEvent = [newEvent retain];
	
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
		
		event = [newEvent autorelease];
	}
	
	return event;
}

- (void) addHistoryInvocation: (NSInvocation*) invoke {
	if (replaying) return;
	
	// Construct a new event based on the invocation
	IFHistoryEvent* newEvent = [[IFHistoryEvent alloc] initWithInvocation: invoke];
	[self addHistoryEvent: newEvent];
	
	[newEvent release];
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
		
		event = [newEvent autorelease];
	}
	
	// Return a suitable proxy
	[event setTarget: self];
	return [event proxy];
}

- (void) goBackwards: (id) sender {
	if (historyPos <= 0) return;
	
	
	replaying = YES;
	[[history objectAtIndex: historyPos-1] replay];
	historyPos--;
	replaying = NO;
	
	[self updateHistoryControls];
}

- (void) goForwards: (id) sender {
	if (historyPos >= [history count]-1) return;
	
	
	replaying = YES;
	[[history objectAtIndex: historyPos+1] replay];
	historyPos++;
	replaying = NO;
	
	[self updateHistoryControls];
}

// Extension updated
-(void) extensionUpdated:(NSString*) javascriptId {
    [extensionsPage extensionUpdated: javascriptId];
}

@end
