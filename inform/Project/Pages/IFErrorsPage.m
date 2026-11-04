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
#import "IFPreferences.h"
#import "IFSettingsController.h"
#import "IFCompilerSettings.h"
#import "IFCompilerController.h"
#import "IFPageBarCell.h"
#import "IFPageBarView.h"

@implementation IFErrorsPage {
    /// The compiler controller object
    IFCompilerController* compilerController;
    int inhibitAddToHistory;
    IFProjectPane * pane;

    /// Cells used to select the pages in the compiler controller
    NSMutableArray* pageCells;
}

#pragma mark - Initialisation

- (instancetype) initWithProjectController: (IFProjectController*) controller
                                  withPane: (IFProjectPane*) thePane {
	self = [super initWithNibName: @"Errors"
				projectController: controller];
	
	if (self) {
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(fontSizePreferenceChanged:)
                                                     name: IFPreferencesAppFontSizeDidChangeNotification
                                                   object: [IFPreferences sharedPreferences]];

        inhibitAddToHistory = 0;
        self->pane = thePane;
	}
	
	return self;
}

#pragma mark - Details about this view

- (NSString*) title {
	return [IFUtility localizedString: @"Errors Page Title"
                              default: @"Errors"];
}

#pragma mark - Preferences

- (void) fontSizePreferenceChanged: (NSNotification*) not {
    // TODO
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
                                   style: IFLineStyleError];
}

- (void) viewSetHasUpdated: (IFCompilerController*) sender {
	if (sender != compilerController) return;
	
	// Clear out the current set of cells
	pageCells = [[NSMutableArray alloc] init];
	
    NSArray* tabs = compilerController.viewTabs;
    
	// Show no pages if there is only one
	if (tabs.count == 0) {
		[self toolbarCellsHaveUpdated];
		return;
	}
	
	// Rebuild the set of cells for this compiler
	//int selectedIndex = [compilerController viewIndex];
	//int currentIndex = [tabs count]-1;

	for( IFCompilerTab* tab in [tabs reverseObjectEnumerator] ) {
		// Create the cell for this name
		IFPageBarCell* newCell = [[IFPageBarCell alloc] initTextCell: tab.name];
		
		newCell.target = self;
		newCell.action = @selector(switchToErrorPage:);
		newCell.identifier = @((int)tab.tabId);
		newCell.radioGroup = 128;
		
        if( compilerController.selectedTabId == tab.tabId ) {
			newCell.state = NSControlStateValueOn;
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
    [self.history switchToPageWithTabId:tabId];

	// Turn the newly selected cell on
	if (pageCells.count == 0) return;
	
	for( IFPageBarCell* cell in pageCells ) {
		if (compilerController.selectedTabId == [cell.identifier intValue]) {
			cell.state = NSControlStateValueOn;
		} else {
			cell.state = NSControlStateValueOff;
		}
	}
}

- (IBAction) switchToErrorPage: (id) sender {
	// Get the cell that was clicked on
	IFPageBarCell* cell = nil;
	
	if ([sender isKindOfClass: [IFPageBarCell class]]) cell = sender;
	else if ([sender isKindOfClass: [IFPageBarView class]]) cell = (IFPageBarCell*)[sender lastTrackedCell];

	// Order the compiler controller to switch to the specified page
	IFCompilerTabId tabId = (IFCompilerTabId) [cell.identifier intValue];
	[compilerController switchToViewWithTabId: tabId];
}

#pragma mark -  Setting some interface building values

@synthesize compilerController;

#pragma mark - WKNavigationDelegate
- (void)                    webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    // Allow everything for now
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)                webView:(WKWebView *)webView
  didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation {

    // Highlight appropriate tab
    //[self highlightTabForURL: webView.URL.absoluteString];

    // Add to history...
    // ... except when reloading after the census
    // ... except on initial load
    // ... except when clicking the forward or back arrows

    // Each time we get here will remove one of these exceptions if present.

    if (self.pageIsVisible) {
        if (inhibitAddToHistory <= 0) {
            LogHistory(@"HISTORY: Compiler Controller Page: (didStartProvisionalNavigation) URL %@", webView.URL.absoluteString);
            [self.history switchToPage];
            [(IFErrorsPage*)self.history openHistoricalURL: webView.URL];
        }
    }

    // reduce the number of reasons to inhibit adding to history
    if (inhibitAddToHistory > 0) {
        inhibitAddToHistory--;
    } else {
        inhibitAddToHistory = 0;
    }
}


- (void) openURL: (NSURL*) url  {
    [self switchToPage];

    [compilerController.currentWebView loadRequest: [[NSURLRequest alloc] initWithURL: url]];
}

- (void) openHistoricalURL: (NSURL*) url {
    if (url == nil) return;

    // Because we are opening this URL as part of replaying history, we don't add it to the history itself.
    inhibitAddToHistory++;
    [self openURL: url];
}

#pragma mark - History

- (void) didSwitchToPage {
    LogHistory(@"HISTORY: Errors Page: (didSwitchToPage) tab %d", (int) [compilerController selectedTabId]);
	[self.history switchToPageWithTabId: compilerController.selectedTabId];
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
