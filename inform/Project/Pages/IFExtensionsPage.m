//
//  IFExtensionsPage.m
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFExtensionsPage.h"
#import "IFPreferences.h"
#import "IFMaintenanceTask.h"
#import "IFAppDelegate.h"
#import "IFUtility.h"
#import "IFExtensionsManager.h"
#import "IFProjectController.h"
#import "IFPageBarCell.h"
#import "IFProject.h"
#import "IFWebViewHelper.h"

@implementation IFExtensionsPage {
    // The documentation view
    /// The web view that displays the documentation
    WKWebView* wView;
    IFWebViewHelper* helper;

    // Page cells
    /// The 'Home' cell
    IFPageBarCell* homeCell;
    /// The 'Public Library' cell
    IFPageBarCell* publicLibraryCell;
    /// Maps URL paths to cells
    NSDictionary* tabDictionary;

    bool loadingFailureWebPage;

    int inhibitAddToHistory;
}

#pragma mark - Initialisation

- (instancetype) initWithProjectController: (IFProjectController*) controller
                                  withPane: (IFProjectPane*) pane {
	self = [super initWithNibName: @"Documentation"
				projectController: controller];
	
	if (self) {
        inhibitAddToHistory = 0;
        loadingFailureWebPage = false;

		homeCell = [[IFPageBarCell alloc] initImageCell:[NSImage imageNamed:NSImageNameHomeTemplate]];
		homeCell.target = self;
		homeCell.action = @selector(showHome:);

		publicLibraryCell = [[IFPageBarCell alloc] initTextCell: [IFUtility localizedString: @"ExtensionPublicLibrary"
                                                                                    default: @"Public Library"]];
		publicLibraryCell.target = self;
		publicLibraryCell.action = @selector(showPublicLibrary:);

        // Static dictionary mapping tab names to cells
        IFProject* project = (self.parent).document;
        NSString* extensions;
        if (project.useNewExtensions) {
            extensions = @"inform://Extensions/Reserved/Documentation/Extensions.html";
        } else {
            extensions = @"inform://Extensions/Extensions.html";
        }
        tabDictionary = @{ extensions: homeCell,
                           [IFUtility publicLibraryURL].absoluteString: publicLibraryCell };

		[[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(fontSizePreferenceChanged:)
													 name: IFPreferencesAppFontSizeDidChangeNotification
												   object: [IFPreferences sharedPreferences]];
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(censusCompleted:)
													 name: IFCensusFinishedNotification
												   object: nil];

        helper = [[IFWebViewHelper alloc] initWithProjectController: controller
                                                           withPane: [controller oppositePane: pane]];
        wView = [helper createWebViewWithFrame: (self.view).bounds];

        // Set delegates
        wView.navigationDelegate = self;

        // Add to view hieracrchy
        [self.view addSubview: wView];

        NSURL* url = [NSURL URLWithString: extensions];
        NSURLRequest* urlRequest = [[NSURLRequest alloc] initWithURL: url];
        [wView loadRequest: urlRequest];
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
    wView = nil;
	
    
}

#pragma mark - Details about this view

- (NSString*) title {
	return [IFUtility localizedString: @"Extensions Page Title"
                              default: @"Extensions"];
}

#pragma mark - Updating extensions

- (void) censusCompleted: (NSNotification*) not {
    inhibitAddToHistory++;
	// Force the documentation view to reload (the 'installed extensions' page may be updated)
	[wView reload: self];
}

#pragma mark - Documentation

- (void) openURL: (NSURL*) url  {
    NSAssert(url != nil, @"Bad URL");

    [self switchToPage];

    NSURLRequest* urlRequest = [[NSURLRequest alloc] initWithURL: url];
    [wView loadRequest: urlRequest];
}

- (void) openHistoricalURL: (NSURL*) url {
    if (url == nil) return;

    // Because we are opening this URL as part of replaying history, we don't add it to the history itself.
    inhibitAddToHistory++;
    [self openURL: url];
}

- (void) highlightTabForURL:(NSString*) urlString {
    for (NSString*key in tabDictionary) {
        if( [key caseInsensitiveCompare:urlString] == NSOrderedSame ) {
            ((IFPageBarCell*)tabDictionary[key]).state = NSControlStateValueOn;
        }
        else {
            ((IFPageBarCell*)tabDictionary[key]).state = NSControlStateValueOff;
        }
    }
}

-(void) loadFailurePage: (NSString *) urlString {
    if( loadingFailureWebPage ) {
        return;
    }
    NSURL* url;

    // Default to public library error
    IFProject* project = (self.parent).document;
    url = [NSURL URLWithString: @"inform:/pl404.html"];

    if (![urlString isEqualToString:[IFUtility publicLibraryURL].absoluteString]) {
        if (project.useNewExtensions) {
            // If the file doesn't exist, then show a default error page
            NSString* path = [NSBundle mainBundle].resourcePath;
            path = [IFUtility pathForInformInternalAppSupport:@""];
            path = [path stringByAppendingPathComponent: @"HTML"];
            path = [path stringByAppendingPathComponent: @"NoExtensions.html"];
            url = [NSURL fileURLWithPath: path];
        }
    }

    inhibitAddToHistory++;
    NSURLRequest* urlRequest = [[NSURLRequest alloc] initWithURL: url];

    [wView loadRequest: urlRequest];
    loadingFailureWebPage = true;
}

#pragma mark - WKNavigationDelegate
- (void)                    webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    // Allow everything for now
    decisionHandler(WKNavigationActionPolicyAllow);

    //NSURL *u1 = webView.URL;
    //NSURL *u2 = navigationAction.request.URL; //If changing URLs this one will be different
}

- (void)                webView:(WKWebView *)webView
  didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation {

    // Highlight appropriate tab
    [self highlightTabForURL: webView.URL.absoluteString];

    // Add to history...
    // ... except when reloading after the census
    // ... except on initial load
    // ... except when clicking the forward or back arrows
    // ... except when going to the error page

    // Each time we get here will remove one of these exceptions if present.

    if (self.pageIsVisible) {
        if (inhibitAddToHistory <= 0) {
            LogHistory(@"HISTORY: Extensions Page: (didStartProvisionalLoadForFrame) URL %@", [webView.URL absoluteString]);
            [self.history switchToPage];
            [(IFExtensionsPage*)self.history openHistoricalURL: webView.URL];
        }
    }

    // reduce the number of reasons to inhibit adding to history
    if (inhibitAddToHistory > 0) {
        inhibitAddToHistory--;
    } else {
        inhibitAddToHistory = 0;
    }
}

-(void)                  webView: (WKWebView *) webView
    didFailProvisionalNavigation: (WKNavigation *) navigation
                       withError: (NSError *) error {
    NSString* urlString = nil;

    NSURL *url = (error.userInfo)[NSURLErrorFailingURLErrorKey];
    if (url) {
        urlString = url.absoluteString;
    } else {
        urlString = (error.userInfo)[NSURLErrorFailingURLStringErrorKey];
    }

    if (error.code == NSURLErrorCancelled) {
        //NSLog(@"IFExtensionsPage: load of URL %@ was cancelled", urlString);
        loadingFailureWebPage = false;
        return;
    }
    if (![error.domain isEqualToString: INFORM_ERROR_DOMAIN]) {
        NSLog(@"IFExtensionsPage: failed to load URL %@ (provisional) with error: %@", urlString, error.localizedDescription);
        [self loadFailurePage: urlString];
    }
}

-(void)       webView: (WKWebView *) webView
    didFailNavigation: (WKNavigation *) navigation
            withError: (NSError *) error {
    NSString* urlString = nil;

    NSURL *url = (error.userInfo)[NSURLErrorFailingURLErrorKey];
    if (url) {
        urlString = url.absoluteString;
    } else {
        urlString = (error.userInfo)[NSURLErrorFailingURLStringErrorKey];
    }

    if (error.code == NSURLErrorCancelled) {
        //NSLog(@"IFExtensionsPage: load of URL %@ was cancelled", urlString);
        loadingFailureWebPage = false;
        return;
    }
    NSLog(@"IFExtensionsPage: failed to load URL %@ with error: %@", urlString, error.localizedDescription);
    [self loadFailurePage: urlString];
}

-(void)         webView:(WKWebView *)webView
    didFinishNavigation:(WKNavigation *)navigation {
    loadingFailureWebPage = false;
}

#pragma mark - History

- (void) didSwitchToPage {
    NSURL* url = wView.URL;

    LogHistory(@"HISTORY: Extensions Page: (didSwitchToPage) URL %@", urlString);
	[self.history openHistoricalURL: url];
    [wView reload: self];
}

#pragma mark - Preferences

- (void) fontSizePreferenceChanged: (NSNotification*) not {
    [helper fontSizePreferenceChanged: wView];
}

#pragma mark - Page bar cells

- (NSArray*) toolbarCells {
	return @[publicLibraryCell, homeCell];
}

-(NSString*) urlStringForCell:(IFPageBarCell*) cell {
    for (NSString* key in tabDictionary) {
        if( tabDictionary[key] == cell ) {
            return key;
        }
    }
    return nil;
}

- (void) showHome: (id) sender {
	[self openURL: [NSURL URLWithString: [self urlStringForCell:homeCell]]];
}

- (void) showPublicLibrary: (id) sender {
	[self openURL: [NSURL URLWithString: [self urlStringForCell:publicLibraryCell]]];
}

- (void) extensionUpdated:(NSString*) javascriptId {
    NSString* js = [NSString stringWithFormat:@"window.downloadSucceeded(%@);", javascriptId];
    //NSLog(@"Calling javascript: %@", js);
    [wView evaluateJavaScript: js completionHandler:nil];
}

- (void) willClose {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

@end
