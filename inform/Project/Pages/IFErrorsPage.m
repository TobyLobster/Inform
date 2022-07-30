//
//  IFErrorsPage.m
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFErrorsPage.h"
#import "IFUtility.h"
#import "IFDocumentationPage.h"
#import "IFProjectController.h"
#import "IFProjectPane.h"
#import "IFSettingsController.h"
#import "IFCompilerSettings.h"
#import "IFCompilerController.h"
#import "IFPageBarCell.h"
#import "IFPageBarView.h"

@implementation IFErrorsPage {
    /// The compiler controller object
    IFCompilerController* compilerController;

    /// Cells used to select the pages in the compiler controller
    NSMutableArray* pageCells;
}

#pragma mark - Initialisation

- (instancetype) initWithProjectController: (IFProjectController*) controller {
	self = [super initWithNibName: @"Errors"
				projectController: controller];
	
	if (self) {
		
	}
	
	return self;
}

#pragma mark - Details about this view

- (NSString*) title {
	return [IFUtility localizedString: @"Errors Page Title"
                              default: @"Errors"];
}

#pragma mark - IFCompilerController delegate methods

- (void) errorMessageHighlighted: (IFCompilerController*) sender
                          atLine: (int) line
                          inFile: (NSString*) file {
    if (![self.parent selectSourceFile: file]) {
        // Maybe implement me: show an error alert?
        return;
    }
    
    [self.parent moveToSourceFileLine: line];
	[self.parent removeHighlightsOfStyle: IFLineStyleError];
    [self.parent highlightSourceFileLine: line
							 inFile: file
							  style: IFLineStyleError]; // FIXME: error level?. Filename?
}

- (BOOL) handleURLRequest: (NSURLRequest*) req {
	[[[self.parent auxPane] documentationPage] openURL: [[req URL] copy]];
	
	return YES;
}

- (void) viewSetHasUpdated: (IFCompilerController*) sender {
	if (sender != compilerController) return;
	
	// Clear out the current set of cells
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
		IFPageBarCell* newCell = [[IFPageBarCell alloc] initTextCell: tab.name];
		
		[newCell setTarget: self];
		[newCell setAction: @selector(switchToErrorPage:)];
		[newCell setIdentifier: @((int)tab.tabId)];
		[newCell setRadioGroup: 128];
		
        if( [compilerController selectedTabId] == tab.tabId ) {
			[newCell setState: NSControlStateValueOn];
		}
		
		[pageCells addObject: newCell];
	}

    // Sort pageCells based on ids
    NSSortDescriptor *sort=[NSSortDescriptor sortDescriptorWithKey:@"identifier" ascending:NO];
    [pageCells sortUsingDescriptors:@[sort]];

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
			[cell setState: NSControlStateValueOn];
		} else {
			[cell setState: NSControlStateValueOff];
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

#pragma mark -  Setting some interface building values

@synthesize compilerController;

#pragma mark - History

- (void) didSwitchToPage {
    LogHistory(@"HISTORY: Errors Page: (didSwitchToPage) tab %d", (int) [compilerController selectedTabId]);
	[[self history] switchToPageWithTabId: [compilerController selectedTabId]];
	[super didSwitchToPage];
}

#pragma mark - The page bar

- (NSArray*) toolbarCells {
	if (pageCells == nil) return @[];
	return pageCells;
}

- (BOOL)splitView:(NSSplitView *)splitView shouldHideDividerAtIndex:(NSInteger)dividerIndex
{
    return YES;
}

@end
