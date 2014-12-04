//
//  IFErrorsPage.m
//  Inform-xc2
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFErrorsPage.h"
#import "IFUtility.h"

@implementation IFErrorsPage

// = Initialisation =

- (id) initWithProjectController: (IFProjectController*) controller {
	self = [super initWithNibName: @"Errors"
				projectController: controller];
	
	if (self) {
		
	}
	
	return self;
}

- (void) dealloc {
	[compilerController release];
	[pageCells release];
	
	[super dealloc];
}

// = Details about this view =

- (NSString*) title {
	return [IFUtility localizedString: @"Errors Page Title"
                              default: @"Errors"];
}

// = IFCompilerController delegate methods =

- (void) errorMessageHighlighted: (IFCompilerController*) sender
                          atLine: (int) line
                          inFile: (NSString*) file {
    if (![parent selectSourceFile: file]) {
        // Maybe implement me: show an error alert?
        return;
    }
    
    [parent moveToSourceFileLine: line];
	[parent removeHighlightsOfStyle: IFLineStyleError];
    [parent highlightSourceFileLine: line
							 inFile: file
							  style: IFLineStyleError]; // FIXME: error level?. Filename?
}

- (BOOL) handleURLRequest: (NSURLRequest*) req {
	[[[parent auxPane] documentationPage] openURL: [[[req URL] copy] autorelease]];
	
	return YES;
}

- (void) viewSetHasUpdated: (IFCompilerController*) sender {
	if (sender != compilerController) return;
	
	// Clear out the current set of cells
	[pageCells release];
	pageCells = [[NSMutableArray alloc] init];
	
    NSArray* tabs = [compilerController viewTabs];
    
	// Show no pages if there is only one
	if ([tabs count] == 0) {
		[self toolbarCellsHaveUpdated];
		return;
	}
	
	// Rebuild the set of cells for this compiler
	//int selectedIndex = [compilerController viewIndex];
	//int currentIndex = [tabs count]-1;

	for( IFCompilerTab* tab in [tabs reverseObjectEnumerator] ) {
		// Create the cell for this name
		IFPageBarCell* newCell = [[IFPageBarCell alloc] initTextCell: tab->name];
		
		[newCell setTarget: self];
		[newCell setAction: @selector(switchToErrorPage:)];
		[newCell setIdentifier: [NSNumber numberWithInt: (int)tab->tabId]];
		[newCell setRadioGroup: 128];
		
        if( [compilerController selectedTabId] == tab->tabId ) {
			[newCell setState: NSOnState];
		}
		
		[pageCells addObject: [newCell autorelease]];
	}

    // Sort pageCells based on ids
    NSSortDescriptor *sort=[NSSortDescriptor sortDescriptorWithKey:@"identifier" ascending:NO];
    [pageCells sortUsingDescriptors:[NSArray arrayWithObject:sort]];

	// Update the cells being displayed
	[self toolbarCellsHaveUpdated];
}

- (void) switchToPageWithTabId: (IFCompilerTabId) tabId {
	[self switchToPage];
	[compilerController switchToViewWithTabId: tabId];
}

- (void) compiler: (IFCompilerController*) sender
   switchedToView: (int) viewIndex {
	if (sender != compilerController) return;
	
	// Remember this in the history
    IFCompilerTabId tabId = [compilerController tabIdWithTabIndex: viewIndex];
    LogHistory(@"HISTORY: Errors Page: (switchedToView) tab %d", (int) tabId);
    [[self history] switchToPageWithTabId:tabId];

	// Turn the newly selected cell on
	if ([pageCells count] == 0) return;
	
	for( IFPageBarCell* cell in pageCells ) {
		if ([compilerController selectedTabId] == [[cell identifier] intValue]) {
			[cell setState: NSOnState];
		} else {
			[cell setState: NSOffState];
		}
	}
}

- (IBAction) switchToErrorPage: (id) sender {
	// Get the cell that was clicked on
	IFPageBarCell* cell = nil;
	
	if ([sender isKindOfClass: [IFPageBarCell class]]) cell = sender;
	else if ([sender isKindOfClass: [IFPageBarView class]]) cell = (IFPageBarCell*)[sender lastTrackedCell];

	// Order the compiler controller to switch to the specified page
	IFCompilerTabId tabId = (IFCompilerTabId) [[cell identifier] intValue];
	[compilerController switchToViewWithTabId: tabId];
}

// = Setting some interface building values =

// (These need to be released, so implement getters/setters)

- (IFCompilerController*) compilerController {
	return compilerController;
}

- (void) setCompilerController: (IFCompilerController*) controller {
	[compilerController release];
	compilerController = [controller retain];
}

// = History =

- (void) didSwitchToPage {
    LogHistory(@"HISTORY: Errors Page: (didSwitchToPage) tab %d", (int) [compilerController selectedTabId]);
	[[self history] switchToPageWithTabId: [compilerController selectedTabId]];
	[super didSwitchToPage];
}

// = The page bar =

- (NSArray*) toolbarCells {
	if (pageCells == nil) return [NSArray array];
	return pageCells;
}

- (BOOL)splitView:(NSSplitView *)splitView shouldHideDividerAtIndex:(NSInteger)dividerIndex
{
    if( [[[parent document] settings] usingNaturalInform] ) {
        return YES;
    }
    return NO;
}

@end
