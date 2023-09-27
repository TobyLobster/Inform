//
//  IFDocumentationPage.m
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFDocumentationPage.h"
#import "IFProjectPane.h"
#import "IFPreferences.h"
#import "IFUtility.h"
#import "IFProjectController.h"
#import "IFPageBarCell.h"
#import "IFWebViewHelper.h"

@implementation IFDocumentationPage {
    // The documentation view
    /// The web view that displays the documentation
    WKWebView* wView;
    IFWebViewHelper* helper;

    // Page cells
    /// The 'table of contents' cell
    IFPageBarCell* contentsCell;
    /// The 'Examples' cell
    IFPageBarCell* examplesCell;
    /// The 'General Index' cell
    IFPageBarCell* generalIndexCell;
    /// Maps URL paths to cells
    NSDictionary* tabDictionary;

    int inhibitAddToHistory;
}

#pragma mark - Initialisation =

- (instancetype) initWithProjectController: (IFProjectController*) controller
                                  withPane: (IFProjectPane*) pane {
    self = [super initWithNibName: @"Documentation"
                projectController: controller];

    if (self) {
        inhibitAddToHistory = 0;

        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(fontSizePreferenceChanged:)
                                                     name: IFPreferencesAppFontSizeDidChangeNotification
                                                   object: [IFPreferences sharedPreferences]];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(censusCompleted:)
                                                     name: IFCensusFinishedNotification
                                                   object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(censusCompleted:)
                                                     name: IFCensusFinishedButDontUpdateExtensionsWebPageNotification
                                                   object: nil];

        helper = [[IFWebViewHelper alloc] initWithProjectController: self.parent
                                                           withPane: [controller oppositePane: pane]];
        wView = [helper createWebViewWithFrame: (self.view).bounds];

        // Set delegates
        wView.navigationDelegate = self;

        // Add to view hieracrchy
        [self.view addSubview: wView];

        // Go to initial page
        inhibitAddToHistory++;
        NSURL* url = [NSURL URLWithString: @"inform:/index.html"];
        NSURLRequest* urlRequest = [[NSURLRequest alloc] initWithURL: url];
        [wView loadRequest: urlRequest];

        // UI tabs
        contentsCell = [[IFPageBarCell alloc] initImageCell:[NSImage imageNamed:NSImageNameHomeTemplate]];
        contentsCell.target = self;
        contentsCell.action = @selector(showToc:);

        examplesCell = [[IFPageBarCell alloc] initTextCell: [IFUtility localizedString: @"Example Docs" default: @"Examples"]];
        examplesCell.target = self;
        examplesCell.action = @selector(showExamples:);

        generalIndexCell = [[IFPageBarCell alloc] initTextCell: [IFUtility localizedString: @"General Index Docs"
                                                                                   default: @"General Index"]];
        generalIndexCell.target = self;
        generalIndexCell.action = @selector(showGeneralIndex:);

        // Static dictionary mapping tab names to cells
        tabDictionary = @{@"inform:/index.html": contentsCell,
                          @"inform:/examples_alphabetical.html": examplesCell,
                          @"inform:/general_index.html": generalIndexCell};
    }

    return self;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

#pragma mark - Details about this view

- (NSString*) title {
    return [IFUtility localizedString: @"Documentation Page Title"
                              default: @"Documentation"];
}

#pragma mark - Updating extensions

- (void) censusCompleted: (NSNotification*) not {
    inhibitAddToHistory++;
    // Force the documentation view to reload (the 'installed extensions' page may be updated)
    [wView reload: self];
}

#pragma mark - Preferences

- (void) fontSizePreferenceChanged: (NSNotification*) not {
    [helper fontSizePreferenceChanged: wView];
}

#pragma mark - Documentation

- (void) openURL: (NSURL*) url  {
    [self switchToPage];

    [wView loadRequest: [[NSURLRequest alloc] initWithURL: url]];
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
            ((IFPageBarCell*) tabDictionary[key]).state = NSControlStateValueOn;
        }
        else {
            ((IFPageBarCell*) tabDictionary[key]).state = NSControlStateValueOff;
        }
    }
}

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
    [self highlightTabForURL: webView.URL.absoluteString];

    // Add to history...
    // ... except when reloading after the census
    // ... except on initial load
    // ... except when clicking the forward or back arrows

    // Each time we get here will remove one of these exceptions if present.

    if (self.pageIsVisible) {
        if (inhibitAddToHistory <= 0) {
            LogHistory(@"HISTORY: Documentation Page: (didStartProvisionalNavigation) URL %@", webView.URL.absoluteString);
            [self.history switchToPage];
            [(IFDocumentationPage*)self.history openHistoricalURL: webView.URL];
        }
    }

    // reduce the number of reasons to inhibit adding to history
    if (inhibitAddToHistory > 0) {
        inhibitAddToHistory--;
    } else {
        inhibitAddToHistory = 0;
    }
}

#pragma mark - History

- (void) didSwitchToPage {
    NSURL* url = wView.URL;

    LogHistory(@"HISTORY: Documentation Page: (didSwitchToPage) URL %@", url.absoluteString);
    [self.history openHistoricalURL: url];
    [wView reload: self];
}

#pragma mark - Page bar cells

- (NSArray*) toolbarCells {
    return @[generalIndexCell, examplesCell, contentsCell];
}

-(NSString*) urlStringForCell:(IFPageBarCell*) cell {
    for (NSString* key in tabDictionary) {
        if( tabDictionary[key] == cell ) {
            return key;
        }
    }
    return nil;
}

- (void) showToc: (id) sender {
    [self openURL: [NSURL URLWithString: [self urlStringForCell:contentsCell]]];
}

- (void) showExamples: (id) sender {
    [self openURL: [NSURL URLWithString: [self urlStringForCell:examplesCell]]];
}

- (void) showGeneralIndex: (id) sender {
    [self openURL: [NSURL URLWithString: [self urlStringForCell:generalIndexCell]]];
}

- (void) willClose {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

@end
