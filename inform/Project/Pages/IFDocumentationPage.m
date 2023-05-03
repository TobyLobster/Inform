//
//  IFDocumentationPage.m
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFDocumentationPage.h"
#import "IFJSProject.h"
#import "IFPreferences.h"
#import "IFMaintenanceTask.h"
#import "IFAppDelegate.h"
#import "IFUtility.h"
#import "IFExtensionsManager.h"
#import "IFProjectController.h"
#import "IFPageBarCell.h"
#import "IFProjectPolicy.h"

@implementation IFDocumentationPage {
    // The documentation view
    /// The web view that displays the documentation
    WKWebView* wView;

    // Page cells
    /// The 'table of contents' cell
    IFPageBarCell* contentsCell;
    /// The 'Examples' cell
    IFPageBarCell* examplesCell;
    /// The 'General Index' cell
    IFPageBarCell* generalIndexCell;
    /// Maps URL paths to cells
    NSDictionary* tabDictionary;

    bool reloadingBecauseCensusCompleted;
}

#pragma mark - Initialisation =

- (instancetype) initWithProjectController: (IFProjectController*) controller {
	self = [super initWithNibName: @"Documentation"
				projectController: controller];
	
	if (self) {
        reloadingBecauseCensusCompleted = false;

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

        // Create the web view for the documentation tab
        WKWebViewConfiguration* config = [[WKWebViewConfiguration alloc] init];
        [config setURLSchemeHandler: self forURLScheme: @"inform"];

        wView = [[WKWebView alloc] initWithFrame:[self.view bounds] configuration: config];
        // TODO: [wView setTextSizeMultiplier: [[IFPreferences sharedPreferences] appFontSizeMultiplier]];

        [wView setAutoresizingMask: (NSUInteger) (NSViewWidthSizable|NSViewHeightSizable)];
        [self.view addSubview: wView];

        NSURL* url = [NSURL URLWithString: @"inform:/index.html"];
        NSURLRequest* urlRequest = [[NSURLRequest alloc] initWithURL: url];
        [wView loadRequest: urlRequest];
        [wView setNavigationDelegate: self];
        [wView setUIDelegate: self];
        // TODO: [wView setHostWindow: [self.parent window]];

		contentsCell = [[IFPageBarCell alloc] initImageCell:[NSImage imageNamed:NSImageNameHomeTemplate]];
		[contentsCell setTarget: self];
		[contentsCell setAction: @selector(showToc:)];

		examplesCell = [[IFPageBarCell alloc] initTextCell: [IFUtility localizedString: @"Example Docs" default: @"Examples"]];
		[examplesCell setTarget: self];
		[examplesCell setAction: @selector(showExamples:)];

		generalIndexCell = [[IFPageBarCell alloc] initTextCell: [IFUtility localizedString: @"General Index Docs"
                                                                                   default: @"General Index"]];
		[generalIndexCell setTarget: self];
		[generalIndexCell setAction: @selector(showGeneralIndex:)];

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
    reloadingBecauseCensusCompleted = true;
	// Force the documentation view to reload (the 'installed extensions' page may be updated)
	[wView reload: self];
    reloadingBecauseCensusCompleted = false;
}

#pragma mark - Preferences

- (void) fontSizePreferenceChanged: (NSNotification*) not {
	// TODO: [wView setTextSizeMultiplier: [[IFPreferences sharedPreferences] appFontSizeMultiplier]];
}

#pragma mark - Documentation

- (void) openURL: (NSURL*) url  {
	[self switchToPage];
	
	[wView loadRequest: [[NSURLRequest alloc] initWithURL: url]];
}

- (void) openURLWithString: (NSString*) urlString {
	if (urlString == nil) return;
	[self openURL: [NSURL URLWithString: urlString]];
}

- (void) highlightTabForURL:(NSString*) urlString {
    for (NSString*key in tabDictionary) {
        if( [key caseInsensitiveCompare:urlString] == NSOrderedSame ) {
            [(IFPageBarCell*) tabDictionary[key] setState:NSControlStateValueOn];
        }
        else {
            [(IFPageBarCell*) tabDictionary[key] setState:NSControlStateValueOff];
        }
    }
}

#pragma mark - WKNavigationDelegate
- (void)                    webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    // TODO: Allow everything for now, but be more selective later?
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)                webView:(WKWebView *)webView
  didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation {

    // Highlight appropriate tab
    [self highlightTabForURL: webView.URL.absoluteString];

    if ([self pageIsVisible]) {
        if( !reloadingBecauseCensusCompleted )
        {
            LogHistory(@"HISTORY: Documentation Page: (didStartProvisionalNavigation) URL %@", webView.URL.absoluteString);
            [[self history] switchToPage];
            [(IFDocumentationPage*)[self history] openURLWithString: webView.URL.absoluteString];
        }
    }
}

#pragma mark - WKUIDelegate
-(WKWebView*)           webView:(WKWebView *)webView
 createWebViewWithConfiguration:(WKWebViewConfiguration *)inConfig
            forNavigationAction:(WKNavigationAction *)navigationAction
                 windowFeatures:(WKWindowFeatures *)windowFeatures
{
    [wView removeFromSuperview];

    wView = [[WKWebView alloc] initWithFrame:self.view.frame configuration:inConfig];

    if (!navigationAction.targetFrame.isMainFrame) {
        NSURLRequest* req = navigationAction.request;
        [wView loadRequest:req];
    }

    wView.navigationDelegate = self;
    wView.UIDelegate = self;
    [wView setFrame: self.view.frame];
    [wView setAutoresizingMask: (NSUInteger) (NSViewWidthSizable|NSViewHeightSizable)];
    [self.view addSubview:wView];

    return wView;
}

- (void)                    webView:(WKWebView *)webView
 runJavaScriptAlertPanelWithMessage:(NSString *)message
                   initiatedByFrame:(WKFrameInfo *)frame
                  completionHandler:(void (^)(void))completionHandler {

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [IFUtility localizedString: @"JavaScript Alert"];
    alert.informativeText = message;
    [alert addButtonWithTitle: [IFUtility localizedString: @"Continue"]];
    [alert runModal];

    completionHandler();
}

#pragma mark - WKURLSchemeHandler
- (void)    webView:(WKWebView *)webView
 startURLSchemeTask:(id <WKURLSchemeTask>)task {
    NSURL* customFileURL = task.request.URL;
    NSString *str = customFileURL.absoluteString;
    NSString* mimeType;
    NSError* error;
    NSLog(@"Found URL %@\n", str);

    if ([str containsString:@"inform:"]) {
        NSData* data = [self loadDataForInformURL: customFileURL
                                returningMimeType: &mimeType
                                   returningError: &error];
        if (data) {
            NSURLResponse *response = [[NSURLResponse alloc] initWithURL: customFileURL
                                                                MIMEType: mimeType
                                                   expectedContentLength: data.length
                                                        textEncodingName: nil];
            [task didReceiveResponse: response];
            [task didReceiveData: data];
            [task didFinish];
        } else if (error != nil) {
            [task didFailWithError: error];
        }
    }
}

-(NSData*) loadDataForInformURL: (NSURL*) url
              returningMimeType: (NSString* __autoreleasing *) mimeType
                 returningError: (NSError* __autoreleasing *) error {
    NSString* urlPath = url.path;
    NSString* host    = url.host;
    NSString* path;

    NSArray* components = [urlPath pathComponents];

    // Accept either the host or the path specifier containing 'extensions'
    if ([[host lowercaseString] isEqualToString: @"extensions"] ||
            (components != nil && [components count] > 1 &&
             [[components[0] lowercaseString] isEqualToString: @"extensions"])) {
        int skip = 0;
        int x;

        if (![[host lowercaseString] isEqualToString: @"extensions"])
            skip = 1;

        // Try the library directories
        NSEnumerator* componentEnum = [components objectEnumerator];
        NSString* pathComponent;

        path = [IFUtility pathForInformExternalDocumentation];
        for (x=0; x<skip; x++) [componentEnum nextObject];
        while ((pathComponent = [componentEnum nextObject])) {
            path = [path stringByAppendingPathComponent: pathComponent];
        }

        if (![[NSFileManager defaultManager] fileExistsAtPath: path]) {
            path = nil;
        }
    } else {
        // Try using pathForResource:ofType:
        // Advantage of this is that it will allow for localisation at some point in the future
        path = [[NSBundle mainBundle] pathForResource: [[urlPath lastPathComponent] stringByDeletingPathExtension]
                                               ofType: [urlPath pathExtension]
                                          inDirectory: [urlPath stringByDeletingLastPathComponent]];
    }

    // Check if the file is in an asset catalog.
    NSString *assetCheckPath = [urlPath stringByDeletingPathExtension];
    if ([assetCheckPath endsWithCaseInsensitive: @"@2x"]) {
        assetCheckPath = [assetCheckPath stringByReplacing:@"@2x" with:@""];
    }
    NSImage *img = [NSImage imageNamed: assetCheckPath];

    if (path == nil && img != nil) {
        //Just output TIFF: it uses the least amount of code:
        NSData *urlData = [img TIFFRepresentation];

        //Which means a TIFF MIME type. Regardless of extension.
        *mimeType = @"image/tiff";
        return urlData;
    }

    if (path == nil) {
        // If that fails, then just append to the resourcePath of the main bundle
        path = [[[[NSBundle mainBundle] resourcePath] stringByAppendingString: @"/"] stringByAppendingString: urlPath];
    }

    // Check that this is the right kind of URL for us
    if (path == nil || ![[url scheme] isEqualToString: @"inform"]) {
        // Doh - not a valid inform: URL
        *error = [NSError errorWithDomain: NSURLErrorDomain
                                     code: NSURLErrorBadURL
                                 userInfo: nil];
        return nil;
    }

    // Check that the file exists and is not a directory
    BOOL isDir = YES;
    if (![[NSFileManager defaultManager] fileExistsAtPath: path
                                              isDirectory: &isDir]) {
        isDir = YES;
    }

    if (isDir) {
        *error = [NSError errorWithDomain: NSURLErrorDomain
                                     code: NSURLErrorFileDoesNotExist
                                 userInfo: nil];
        return nil;
    }

    // Load up the data
    NSData* urlData = [NSData dataWithContentsOfFile: path];
    if (urlData == nil) {
        *error = [NSError errorWithDomain: NSURLErrorDomain
                                     code: NSURLErrorCannotOpenFile
                                 userInfo: nil];
        return nil;
    }

    // Work out the MIME type
    NSString* ourType = nil;
    do {
        NSString *pathExt = path.pathExtension;
        CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)pathExt, kUTTypeData);
        if (!uti) {
            break;
        }

        ourType = CFBridgingRelease(UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType));
        CFRelease(uti);
    } while (false);

    if (ourType == nil) {
        ourType = @"text/html";
        if ([[path pathExtension] isEqualToString: @"gif"]) {
            ourType = @"image/gif";
        } else if ([[path pathExtension] isEqualToString: @"jpeg"] ||
                   [[path pathExtension] isEqualToString: @"jpg"]) {
            ourType = @"image/jpeg";
        } else if ([[path pathExtension] isEqualToString: @"png"]) {
            ourType = @"image/png";
        } else if ([[path pathExtension] isEqualToString: @"tiff"] ||
                   [[path pathExtension] isEqualToString: @"tif"]) {
            ourType = @"image/tiff";
        }
    }

    // Create the response
    *mimeType = ourType;
    *error = nil;
    return urlData;
}

#pragma mark - WebResourceLoadDelegate methods

/* TODO
- (void)			webView:(WebView *)sender
				   resource:(id)identifier 
	didFailLoadingWithError:(NSError *)error 
			 fromDataSource:(WebDataSource *)dataSource {
    NSString *urlString = (error.userInfo)[@"NSErrorFailingURLStringKey"];

    if (error.code == NSURLErrorCancelled) {
        //NSLog(@"IFDocumentationPage: load of URL %@ was cancelled", urlString);
        return;
    }
	NSLog(@"IFDocumentationPage: failed to load URL %@ with error: %@", urlString, [error localizedDescription]);
}

#pragma mark - WebFrameLoadDelegate methods
- (void)					webView:(WKWebView *)sender
	didStartProvisionalLoadForFrame:(WKFrameInfo *)frame {
    // When opening a new URL in the main frame, record it as part of the history for this page
    NSURL* url;
    if ([frame provisionalDataSource]) {
        url = [[[frame provisionalDataSource] request] URL];
    } else {
        url = [[[frame dataSource] request] URL];
    }
    
    url = [url copy];

    // Highlight appropriate tab
    [self highlightTabForURL:[url absoluteString]];

	if (frame == [wView mainFrame] && [self pageIsVisible]) {
        if( !reloadingBecauseCensusCompleted )
        {
            LogHistory(@"HISTORY: Documentation Page: (didStartProvisionalLoadForFrame) URL %@", [url absoluteString]);
            [[self history] switchToPage];
            [(IFDocumentationPage*)[self history] openURLWithString: [url absoluteString]];
        }
	}
}

- (void)        webView: (WebView *) sender
   didClearWindowObject: (WebScriptObject *) windowObject
               forFrame: (WebFrame *) frame {
	if (self.otherPane) {
		// Attach the JavaScript object to the opposing view
		IFJSProject* js = [[IFJSProject alloc] initWithPane: self.otherPane];
		
		// Attach it to the script object
		[[sender windowScriptObject] setValue: js
									   forKey: @"Project"];
	}
}
*/

#pragma mark - History

- (void) didSwitchToPage {
	NSString* urlString = wView.URL.absoluteString;
	
    LogHistory(@"HISTORY: Documentation Page: (didSwitchToPage) URL %@", urlString);
	[[self history] openURLWithString: urlString];
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
