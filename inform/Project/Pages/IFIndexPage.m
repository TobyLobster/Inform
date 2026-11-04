//
//  IFIndexPage.m
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFIndexPage.h"
#import "IFPreferences.h"

#import "IFAppDelegate.h"
#import "IFUtility.h"
#import "IFProjectController.h"
#import "IFProject.h"
#import "IFPageBarCell.h"
#import "IFPageBarView.h"
#import "IFExtensionsManager.h"
#import "IFWebViewHelper.h"


@implementation IFIndexPage {
    /// \c YES if the index tab should be active
    BOOL indexAvailable;

    /// A reference count - number of 'machine' operations that might be affecting the index tab selection
    int indexMachineSelection;

    /// IFPageBarCells used to select index pages
    NSMutableArray<IFPageBarCell*>* indexCells;
    /// Dictionary of tab ids and their string names
    NSDictionary<NSString*,NSNumber*>* tabDictionary;

    WKWebView* webView;
    IFWebViewHelper* helper;
    int inhibitAddToHistory;
}

#pragma mark - Initialisation

- (instancetype) initWithProjectController: (IFProjectController*) controller
                                  withPane: (IFProjectPane*) pane {
	self = [super initWithNibName: @"Index"
				projectController: controller];
	
	if (self) {
        indexAvailable = NO;
        inhibitAddToHistory = 0;

        // Static dictionary mapping tab names to enum values
        tabDictionary = @{@"actions.html":    @(IFIndexActions),
                          @"phrasebook.html": @(IFIndexPhrasebook),
                          @"scenes.html":     @(IFIndexScenes),
                          @"contents.html":   @(IFIndexContents),
                          @"kinds.html":      @(IFIndexKinds),
                          @"rules.html":      @(IFIndexRules),
                          @"world.html":      @(IFIndexWorld),
                          @"welcome.html":    @(IFIndexWelcome)};

        // Create the webview
        helper = [[IFWebViewHelper alloc] initWithProjectController: controller withPane: pane];
        webView = [helper createWebViewWithFrame:self.view.bounds];

        // Set delegates
        webView.navigationDelegate = self;

        // Add the webview as a subview of the index page
        [self.view addSubview: webView];

        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(fontSizePreferenceChanged:)
                                                     name: IFPreferencesAppFontSizeDidChangeNotification
                                                   object: [IFPreferences sharedPreferences]];
	}

	return self;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

#pragma mark - Notifications

- (void) fontSizePreferenceChanged: (NSNotification*) not {
    [helper fontSizePreferenceChanged: webView];
}

#pragma mark - Details about this view

- (NSString*) title {
	return [IFUtility localizedString: @"Index Page Title"
                              default: @"Index"];
}

#pragma mark - Page validation

@synthesize indexAvailable;

- (BOOL) shouldShowPage {
	return indexAvailable;
}

#pragma mark - Helper functions

-(NSUInteger) indexOfItemWithTabId: (int) tabIdentifier {
    id identifier = @(tabIdentifier);
	NSInteger index = 0;
	for( IFPageBarCell* cell in indexCells ) {
		if ([cell.identifier isEqual: identifier]) return index;
		index++;
	}
	
	return NSNotFound;
}

- (BOOL) canSelectIndexTab: (int) tabIdentifier {
	if ([self indexOfItemWithTabId:tabIdentifier] == NSNotFound) {
		return NO;
	}
	return YES;
}

-(NSUInteger) tabIdOfItemWithFilename:(NSString *) theFile
{
    NSString* lowerFile = theFile.lowercaseString;
    
    NSNumber* integer = tabDictionary[lowerFile];
    if( integer == nil ) {
        return NSNotFound;
    }
    return integer.intValue;
}

-(NSString *) filenameOfItemWithTabId:(int) tabId
{
    for( NSString* key in tabDictionary)
    {
        if( (tabDictionary[key]).intValue == tabId ) {
            return key;
        }
    }
    return nil;
}


- (BOOL) requestRelativePath:(NSString *) relativePath {
    NSURL* indexDirURL = [(self.parent).document indexDirectoryURL];
    NSURL* fullFileURL = [indexDirURL URLByAppendingPathComponent: relativePath];

    BOOL isDir = NO;
    
    // Check that it exists and is a directory
    if (indexDirURL == nil) return NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath: indexDirURL.path
                                              isDirectory: &isDir]) return NO;
    if (!isDir) return NO;

    NSURLRequest* aRequest = [[NSURLRequest alloc] initWithURL: fullFileURL];
    //NSLog(@"self %@ Index page -requestRelativePath about to request a load of %@", self, aRequest.URL.absoluteString);
    [webView loadRequest: aRequest];
    //NSLog(@"self %@ Index page -requestRelativePath has requested a load of %@", self, aRequest.URL.absoluteString);

    return YES;
}

- (void) openHistoricalURL:(NSURL *) url {
    if (url == nil) return;

    // Because we are opening this URL as part of replaying history, we don't add it to the history itself.
    inhibitAddToHistory++;

    NSURLRequest* aRequest = [[NSURLRequest alloc] initWithURL:url];
    //NSLog(@"self %@ Index page -requestURL about to request a load of %@", self, url.absoluteString);
    [webView loadRequest: aRequest];
    //NSLog(@"self %@ Index page -requestURL has requested a load of %@", self, url.absoluteString);
}

- (void) switchToTab: (int) tabIdentifier {
	NSUInteger tabIndex = [self indexOfItemWithTabId:tabIdentifier];
    //NSLog(@"IFIndexPage -switchToTab with tabIdentifier=%d and tabIndex=%d", tabIdentifier, tabIndex);
	if (tabIndex != NSNotFound) {
        // Set a URL request going
        NSString* filename =[self filenameOfItemWithTabId:tabIdentifier];
        if( filename != nil ) {
            [self requestRelativePath:filename];
        }
    }
}

- (void) switchToTabWithObject: (id) sender {
    // Get the cell that was clicked on
    IFPageBarCell* cell = nil;
    
    if ([sender isKindOfClass: [IFPageBarCell class]]) cell = sender;
    else if ([sender isKindOfClass: [IFPageBarView class]]) cell = (IFPageBarCell*)[sender lastTrackedCell];

    int tabIdentifier = [cell.identifier intValue];
    [self switchToTab:tabIdentifier];
}

- (void) updateIndexView {
	indexAvailable = NO;
	
	// Refresh the copies of the index files in memory
	[(self.parent).document reloadIndexDirectory];

	// The index path
	NSString* indexPath = [NSString stringWithFormat: @"%@/Index", [(self.parent).document fileURL].path];
	BOOL isDir = NO;
	
	indexCells = [[NSMutableArray alloc] init];
	
	// Check that it exists and is a directory
	if (indexPath == nil) return;
	if (![[NSFileManager defaultManager] fileExistsAtPath: indexPath
											  isDirectory: &isDir]) return;
	if (!isDir) return;		

	// Create the tab view that will eventually go into the main view
	indexMachineSelection++;

	// Iterate through the files
    NSError* error;
	NSArray* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:indexPath error: &error];
	files = [files sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
	for( NSString* theFile in files ) {
		NSString* extension = theFile.pathExtension.lowercaseString;
		
		if ([extension isEqualToString: @"htm"] ||
			[extension isEqualToString: @"html"]) {
			// Create the tab
			IFPageBarCell* newTab = [[IFPageBarCell alloc] init];
			newTab.radioGroup = 128;

			// Choose an ID for this tab based on the filename
			NSUInteger tabId = [self tabIdOfItemWithFilename:theFile];
            if( tabId == IFIndexWelcome ) {
                newTab.image = [NSImage imageNamed:NSImageNameHomeTemplate];
            }
            else {
                NSString* label = [IFUtility localizedString: theFile
                                                     default: theFile.stringByDeletingPathExtension
                                                       table: @"CompilerOutput"];
                newTab.stringValue = label;
            }

            if( tabId != NSNotFound ) {
                newTab.identifier = @(tabId);
                newTab.target = self;
                newTab.action = @selector(switchToTabWithObject:);

                // Add the tab
                [indexCells insertObject: newTab
                                 atIndex: 0];
                indexAvailable = YES;
            }
		}
    }
    [self toolbarCellsHaveUpdated];

    // Sort tabs by ID
    NSSortDescriptor *sort=[NSSortDescriptor sortDescriptorWithKey:@"identifier" ascending:NO];
    [indexCells sortUsingDescriptors:@[sort]];

	indexMachineSelection--;

    [webView reload: self];
}

#pragma mark - Utility functions

#pragma mark - Switching cells

- (IBAction) switchToCell: (id) sender {
	if ([sender isKindOfClass: [IFPageBarCell class]]) {
        IFPageBarCell* cell = sender;
        [self switchToTab:[cell.identifier intValue]];
    }
}

- (void) didSwitchToPage {
    NSURL* url = webView.URL;
    LogHistory(@"HISTORY: Index Page: (didSwitchToPage) requestURL %@", [url absoluteString]);
	[self.history openHistoricalURL: url];

    // Highlight the indexCell to something appropriate for the new URL
    [self highlightAppropriateIndexCellForURL: url];
	[super didSwitchToPage];
}

-(void) highlightAppropriateIndexCellForURL:(NSURL*) url {
    NSString* lowerURL = url.absoluteString.lowercaseString;

    // Highlight the pane tab to something appropriate for the new URL
    for (IFPageBarCell*cell in indexCells) {
        cell.state = NSControlStateValueOff;
    }
    for(NSString *tabName in tabDictionary.keyEnumerator) {
        // is the string we are looking for
        if( [lowerURL rangeOfString:tabName].location != NSNotFound ) {
            //NSLog(@"Found tab %@", tabName);

            // Highlight the appropriate tab
            int tabIdentifier = (tabDictionary[tabName]).intValue;
            NSUInteger tabIndex = [self indexOfItemWithTabId:tabIdentifier];

            ((NSCell*)indexCells[tabIndex]).state = NSControlStateValueOn;
        }
    }
}

#pragma mark - WKNavigationDelegate methods
- (void)                    webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    // Allow everything for now
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)                webView:(WKWebView *)theWebView
  didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
    NSURL* url = theWebView.URL;
    LogHistory(@"HISTORY: Index Page: (didStartProvisionalLoadForFrame) requestURL %@", [url absoluteString]);
    if (inhibitAddToHistory <= 0) {
        [self.history switchToPage];
        [self.history openHistoricalURL: url];
    }

    // reduce the number of reasons to inhibit adding to history
    if (inhibitAddToHistory > 0) {
        inhibitAddToHistory--;
    } else {
        inhibitAddToHistory = 0;
    }

    // Highlight the indexCell to something appropriate for the new URL
    [self highlightAppropriateIndexCellForURL:url];
}

#pragma mark - The page bar

- (NSArray*) toolbarCells {
	if (indexCells == nil) return @[];
	return indexCells;
}

@end
