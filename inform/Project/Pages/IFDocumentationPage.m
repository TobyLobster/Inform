//
//  IFDocumentationPage.m
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFDocumentationPage.h"
#import "IFProjectPane.h"
#import "IFSourcePage.h"
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

    int inhibitAddToHistory;
}

#pragma mark - Initialisation =

- (instancetype) initWithProjectController: (IFProjectController*) controller {
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

        // Create the web view for the documentation tab

        // First the configuration:
        WKWebViewConfiguration* config = [[WKWebViewConfiguration alloc] init];

        // Handle inform: sceme
        [config setURLSchemeHandler: self forURLScheme: @"inform"];

        // We recieve messages from Javascript
        [config.userContentController addScriptMessageHandler: self name: @"scriptHandler"];

        // We inject Javascript to post appropriate messages
        NSURL* resourceURL = [[NSBundle mainBundle] URLForResource:@"messages_to_objc" withExtension: @"js"];
        NSError* error;
        NSString* javascriptTemplate = [NSString stringWithContentsOfURL:resourceURL encoding:NSUTF8StringEncoding error: &error];

        // We inject Javascript to initially resize based on font size preference
        float fontSizeMultiplier = [[IFPreferences sharedPreferences] appFontSizeMultiplier];
        NSString* js = [NSString stringWithFormat: @"window.addEventListener(\"load\",function () { document.body.style.zoom = '%.2f'; }, false);", fontSizeMultiplier];

        // Inject both the message template and the font size Javascript
        NSString* javascriptInjection = [NSString stringWithFormat: @"%@%@", js, javascriptTemplate];
        WKUserScript *userScript = [[WKUserScript alloc] initWithSource: javascriptInjection
                                                          injectionTime: WKUserScriptInjectionTimeAtDocumentStart
                                                       forMainFrameOnly: true];
        [config.userContentController addUserScript: userScript];

        // Javascript code like the following now posts a message to us that we recieve in Objective C land:
        //      window.webkit.messageHandlers.scriptHandler.postMessage(["functionName", "param1", "param2"]):

        // Create the view itself
        wView = [[WKWebView alloc] initWithFrame:[self.view bounds] configuration: config];
        [wView setAutoresizingMask: (NSUInteger) (NSViewWidthSizable|NSViewHeightSizable)];
        [self.view addSubview: wView];

        // Set delegates
        [wView setNavigationDelegate: self];
        [wView setUIDelegate: self];

        // Go to initial page
        inhibitAddToHistory++;
        NSURL* url = [NSURL URLWithString: @"inform:/index.html"];
        NSURLRequest* urlRequest = [[NSURLRequest alloc] initWithURL: url];
        [wView loadRequest: urlRequest];

        // UI tabs
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
    inhibitAddToHistory++;
	// Force the documentation view to reload (the 'installed extensions' page may be updated)
	[wView reload: self];
}

#pragma mark - Preferences

- (void) fontSizePreferenceChanged: (NSNotification*) not {
    float fontSizeMultiplier = [[IFPreferences sharedPreferences] appFontSizeMultiplier];
    NSString* js = [NSString stringWithFormat: @"document.body.style.zoom = '%.2f'", fontSizeMultiplier];
    [wView evaluateJavaScript: js completionHandler:nil];
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

    if ([self pageIsVisible]) {
        if (inhibitAddToHistory <= 0) {
            LogHistory(@"HISTORY: Documentation Page: (didStartProvisionalNavigation) URL %@", webView.URL.absoluteString);
            [[self history] switchToPage];
            [(IFDocumentationPage*)[self history] openHistoricalURL: webView.URL];
        }
    }

    // reduce the number of reasons to inhibit adding to history
    if (inhibitAddToHistory > 0) {
        inhibitAddToHistory--;
    } else {
        inhibitAddToHistory = 0;
    }
}

#pragma mark - WKUIDelegate
/* Not needed - used for popups?
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
*/

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

-       (void)webView:(nonnull WKWebView *) webView
    stopURLSchemeTask:(nonnull id<WKURLSchemeTask>) urlSchemeTask {
    // Nothing to do
    return;
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

#pragma mark - WKScriptMessageHandler methods

- (void)userContentController: (WKUserContentController *) userContentController
      didReceiveScriptMessage: (WKScriptMessage *) message {
    NSArray * list = (NSArray*) message.body;

    //NSLog(@"%@", list);

    // Check for correct number of parameter required
    NSDictionary * commands = @{ @"createNewProject": @2,
                                 @"pasteCode": @1,
                                 @"openFile": @1,
                                 @"openURL": @1,
                                 @"askInterfaceForLocalVersionAuthor": @3,
                                 @"askInterfaceForLocalVersionTextAuthor": @2,
                                 @"downloadMultipleExtensions": @1
                               };
    if ([list count] == 0) {
        return;
    }
    if (commands[list[0]] == nil) {
        return;
    }
    if((long) [list count] <= (long) commands[list[0]]) {
        return;
    }
    if ([@"selectView" isEqualToString: list[0]]) {
        [self selectView: list[1]];
    } else if ([@"createNewProject" isEqualToString: list[0]]) {
        [self createNewProject: list[1]
                         story: list[2]];
    } else if ([@"pasteCode" isEqualToString: list[0]]) {
        [self pasteCode: list[1]];
    } else if ([@"openFile" isEqualToString: list[0]]) {
        [self openFile: list[1]];
    } else if ([@"openURL" isEqualToString: list[0]]) {
        [self openURL: list[1]];
    } else if ([@"askInterfaceForLocalVersionAuthor" isEqualToString: list[0]]) {
        [self askInterfaceForLocalVersionAuthor: list[1]
                                          title: list[2]
                                      available: list[3]];
    } else if ([@"askInterfaceForLocalVersionTextAuthor" isEqualToString: list[0]]) {
        [self askInterfaceForLocalVersionTextAuthor: list[1]
                                              title: list[2]];
    } else if ([@"downloadMultipleExtensions" isEqualToString: list[0]]) {
        [self downloadMultipleExtensions: list[1]];
    }
}

- (void) selectView: (NSString*) view {
    view = [view lowercaseString];

    if ([view isEqualToString: @"source"]) {
        [self.otherPane selectViewOfType: IFSourcePane];
    } else if ([view isEqualToString: @"error"]) {
        [self.otherPane selectViewOfType: IFErrorPane];
    } else if ([view isEqualToString: @"game"]) {
        [self.otherPane selectViewOfType: IFGamePane];
    } else if ([view isEqualToString: @"documentation"]) {
        [self.otherPane selectViewOfType: IFDocumentationPane];
    } else if ([view isEqualToString: @"index"]) {
        [self.otherPane selectViewOfType: IFIndexPane];
    } else if ([view isEqualToString: @"skein"]) {
        [self.otherPane selectViewOfType: IFSkeinPane];
    } else {
        // Other view types are not supported at present
    }
}

- (void) createNewProject: (NSString *)title
                    story: (NSString *)story {
    title = [IFUtility unescapeString: title];
    story = [IFUtility unescapeString: story];

    [(IFAppDelegate *) [NSApp delegate] createNewProject: title
                                 story: story];
}

- (void) pasteCode: (NSString*) code {
    [[self.otherPane sourcePage] pasteSourceCode: [IFUtility unescapeString: code]];
}

- (void) openFile: (NSString*) filename {
    [[NSWorkspace sharedWorkspace] openFile: filename];

//    NSString* dir = [filename stringByDeletingLastPathComponent];
//    [[NSWorkspace sharedWorkspace] selectFile: filename
//                     inFileViewerRootedAtPath: dir];
}

- (void) openUrl: (NSString*) url {
    if (![[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: url]]) {
        NSLog(@"Could not open URL: %@", url);
    }
}

-(NSString*) askInterfaceForLocalVersionAuthor: (NSString*) author
                                         title: (NSString*) title
                                     available: (NSString*) availableVersion {
    IFExtensionsManager* mgr = [IFExtensionsManager sharedNaturalInformExtensionsManager];
    author = [author lowercaseString];
    title = [title lowercaseString];

    IFSemVer* versionAvailable = [[IFSemVer alloc] initWithString: availableVersion];

    for( IFExtensionInfo* info in [mgr availableExtensions] ) {
        // NSLog(@"Got installed extension %@ by %@", [info title], info.author);
        if( [[info.author lowercaseString] isEqualToString: author] ) {
            if( [[[IFExtensionInfo canonicalTitle:info.displayName] lowercaseString] isEqualToString: title] ) {
                // We have this extension
                if( info.isBuiltIn ) {
                    //NSLog(@"Found %@ by %@ BUILT IN", title, author);
                    return @"!";
                }

                IFSemVer* versionLocal = [info semver];

                int result = [versionLocal cmp:versionAvailable];

                if( result == 0) {
                    //NSLog(@"Found %@ by %@ version %@ EQUAL", title, author, version);
                    return @"=";
                }
                if( result < 0 ) {
                    //NSLog(@"Found %@ by %@ version %@ <", title, author, version);
                    return @"<";
                }
                //NSLog(@"Found %@ by %@ version %@ >", title, author, version);
                return @">";
            }
        }
    }

    // Not found
    //NSLog(@"Looked for %@ by %@ NOT-FOUND", title, author);
    return @"";
}

-(NSString*) askInterfaceForLocalVersionTextAuthor: (NSString*) author
                                             title: (NSString*) title {
    IFExtensionsManager* mgr = [IFExtensionsManager sharedNaturalInformExtensionsManager];
    author = [author lowercaseString];
    title = [title lowercaseString];

    for( IFExtensionInfo* info in [mgr availableExtensions] ) {
        if( [[info.author lowercaseString] isEqualToString: author] ) {
            if( [[[IFExtensionInfo canonicalTitle: info.displayName] lowercaseString] isEqualToString: title] ) {
                return [info safeVersion];
            }
        }
    }

    // Not found
    return @"";
}

-(NSString*) askInterfaceForMD5HashAuthor: (NSString*) author
                                    title: (NSString*) title {
    // Not used yet
    return @"";
}

-(void) downloadMultipleExtensions:(NSArray*) array {
    for(int index = 0; index < [array count]; index += 3) {
        NSString* item      = array[index];
        NSString* urlString = array[index + 1];
        //NSString* version   = [array objectAtIndex: index + 2];
        //NSLog(@"item is %@ for url %@ version %@", item, urlString, version);

        NSURL* frameURL = [IFUtility publicLibraryURL];
        NSURL* realURL = [IFProjectPolicy urlFromLibraryURL: [NSURL URLWithString: urlString]
                                                   frameURL: frameURL];

        [[IFExtensionsManager sharedNaturalInformExtensionsManager] downloadAndInstallExtension: realURL
                                                                                         window: [[self.otherPane controller] window]
                                                                                 notifyDelegate: [self.otherPane controller]
                                                                                   javascriptId: item];
    }
}


#pragma mark - History

- (void) didSwitchToPage {
	NSURL* url = wView.URL;
	
    LogHistory(@"HISTORY: Documentation Page: (didSwitchToPage) URL %@", url.absoluteString);
	[[self history] openHistoricalURL: url];
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
