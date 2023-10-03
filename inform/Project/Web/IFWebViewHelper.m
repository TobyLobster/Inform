//
//  IFWebViewHelper.m
//  Inform
//
//  Created by Toby Nelson on 04/05/2023.
//

#import <Cocoa/Cocoa.h>

#import "IFWebViewHelper.h"
#import "IFUtility.h"
#import "IFPreferences.h"
#import "IFAppDelegate.h"
#import "IFSourcePage.h"
#import "IFProjectController.h"
#import "IFCompilerSettings.h"
#import "IFProject.h"

@implementation IFWebViewHelper {
    __weak IFProjectController* projectController;
    __weak IFProjectPane* pane;
    __weak IFCompilerSettings* settings;

    NSMutableCharacterSet *escapeCharset;
    NSError* genericError;
}

#pragma mark - Initialisation

- (instancetype) initWithProjectController: (IFProjectController*) theProjectController
                                  withPane: (IFProjectPane*) newPane {
    self = [super init];

    if (self) {
        projectController = theProjectController;
        pane = newPane;

        escapeCharset = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
        [escapeCharset removeCharactersInString:@"!*'();:@&=+$,/?%#[]"];

        genericError = [NSError errorWithDomain:INFORM_ERROR_DOMAIN code: 0 userInfo: nil];
    }

    return self;
}

- (void) dealloc {
    pane = nil;
}

- (WKWebView *) createWebViewWithFrame:(CGRect) frame {
    // Create the web view for the documentation tab

    // First the configuration:
    WKWebViewConfiguration* config = [[WKWebViewConfiguration alloc] init];

    // Handle 'inform:' scheme
    [config setURLSchemeHandler: self
                   forURLScheme: @"inform"];
    [config setURLSchemeHandler: self
                   forURLScheme: @"source"];
    [config setURLSchemeHandler: self
                   forURLScheme: @"skein"];

    // We recieve messages from Javascript
    [config.userContentController addScriptMessageHandler: self
                                                     name: @"scriptHandler"];

    // We inject Javascript to post appropriate messages
    NSURL* resourceURL = [[NSBundle mainBundle] URLForResource:@"messages_to_objc" withExtension: @"js"];
    NSError* error;
    NSString* javascriptTemplate = [NSString stringWithContentsOfURL:resourceURL encoding:NSUTF8StringEncoding error: &error];

    // We inject Javascript to initially resize based on font size preference
    float fontSizeMultiplier = [IFPreferences sharedPreferences].appFontSizeMultiplier;
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
    WKWebView* wView = [[WKWebView alloc] initWithFrame:frame configuration: config];
    wView.autoresizingMask = (NSUInteger) (NSViewWidthSizable|NSViewHeightSizable);

    // Set delegates
    wView.UIDelegate = self;

    return wView;
}

#pragma mark - WKUIDelegate
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
-(NSURL*) urlFromLibraryURL: (NSURL*) url
                   frameURL: (NSURL*) frameURL {
    // Replace the "library:" prefix of the URL string with the URL for the enclosing document
    // frame URL looks like: "inform:/fake/index.html"
    // Our URL looks like "library:/payloads/Emily%20Short/Transit%20System.i7x"
    // We transform this into "inform:/fake/payloads/Emily%20Short/Transit%20System.i7x"

    if (( frameURL.path != nil ) && ( url.path != nil )) {
        // Remove last object from path, and add in the other path
        NSArray* framePathComponents = [frameURL.path componentsSeparatedByString:@"/"];
        NSArray* urlPathComponents   = [url.path componentsSeparatedByString:@"/"];

        NSMutableArray* newPath = [[NSMutableArray alloc] initWithArray: framePathComponents ];
        if( newPath.count > 0 ) {
            [newPath removeObjectAtIndex:0];    // remove first '/' component
        }
        if( newPath.count > 0 ) {
            [newPath removeLastObject];         // remove final path comonent "index.html"
        }

        NSMutableArray* urlPath = [[NSMutableArray alloc] initWithArray: urlPathComponents ];
        if( urlPath.count > 0 ) {
            [urlPath removeObjectAtIndex:0];    // remove first '/' component
        }

        [newPath addObjectsFromArray: urlPath];

        // Escape encode the paths, as they were (unhelpfully) unescaped with the .path method
        for(NSInteger index = 0; index < newPath.count; index++) {
            NSString* escapedString = [newPath[index] stringByAddingPercentEncodingWithAllowedCharacters: escapeCharset];
            newPath[index] = escapedString;
        }

        // Create the new URL string
        NSMutableString* newUrlString = [[NSMutableString alloc] initWithFormat: @"%@:/", frameURL.scheme];
        if( frameURL.host != nil ) {
            [newUrlString appendString: @"/"];
            [newUrlString appendString: frameURL.host];
            [newUrlString appendString: @"/"];
        }
        [newUrlString appendString: [newPath componentsJoinedByString:@"/"]];

        NSURL* newURL = [[NSURL alloc] initWithString: newUrlString];
        return newURL;
    }
    return nil;
}

- (NSDictionary *)explodeString:(NSString *) string
                      innerGlue:(NSString *) innerGlue
                      outerGlue:(NSString *) outerGlue {
    // Explode based on outer glue
    NSArray *firstExplode = [string componentsSeparatedByString:outerGlue];
    NSArray *secondExplode;

    // Explode based on inner glue
    NSInteger count = firstExplode.count;
    NSMutableDictionary *returnDictionary = [NSMutableDictionary dictionaryWithCapacity:count];
    for (NSInteger i = 0; i < count; i++) {
        secondExplode = [(NSString *)firstExplode[i] componentsSeparatedByString:innerGlue];
        if (secondExplode.count == 2) {
            returnDictionary[secondExplode[0]] = secondExplode[1];
        }
    }
    return returnDictionary;
}


- (void)    webView: (WKWebView *)webView
 startURLSchemeTask: (id <WKURLSchemeTask>)task {
    NSURL* customURL = task.request.URL;
    NSString* mimeType;
    NSError* error;

    if ([customURL.scheme isEqualTo: @"inform"]) {
        NSData* data = [self loadDataForInformURL: customURL
                                returningMimeType: &mimeType
                                   returningError: &error];
        if (data) {
            NSURLResponse *response = [[NSURLResponse alloc] initWithURL: customURL
                                                                MIMEType: mimeType
                                                   expectedContentLength: data.length
                                                        textEncodingName: nil];
            [task didReceiveResponse: response];
            [task didReceiveData: data];
            [task didFinish];
        } else if (error != nil) {
            [task didFailWithError: error];
        } else {
            [task didFailWithError: genericError];
        }
    } else if ([customURL.scheme isEqualTo: @"source"]) {
        // Format is 'source file name#line number'
        NSArray* results = [IFUtility decodeSourceSchemeURL: customURL];
        IFProject* project = projectController.document;
        results = [project redirectLinksToExtensionSourceCode: results];
        if( results == nil ) {
            [task didFailWithError: genericError];
            return;
        }
        NSString* sourceFile = results[0];
        int lineNumber = [results[1] intValue];

        if (![projectController selectSourceFile: sourceFile]) {
            [task didFailWithError: genericError];
            return;
        }

        if (lineNumber >= 0) [projectController moveToSourceFileLine: lineNumber];
        [projectController removeHighlightsOfStyle: IFLineStyleError];
        [projectController highlightSourceFileLine: lineNumber
                                            inFile: sourceFile
                                             style: IFLineStyleError];

        // Finished
        [task didFailWithError: genericError];
        return;
    }
    else if ([customURL.scheme isEqualTo: @"skein"]) {
        // Format is e.g. 'skein:1003?case=B'
        NSArray* results = [IFUtility decodeSkeinSchemeURL: customURL];
        if( results == nil ) {
            [task didFailWithError: genericError];
            return;
        }
        NSString* testCase = results[0];
        NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
        unsigned long skeinNodeId = [formatter numberFromString:results[1]].unsignedLongValue;

        // Move to the appropriate place in the file
        if (![projectController showTestCase: testCase skeinNode: skeinNodeId]) {
            NSLog(@"Can't select test case '%@'", testCase);
            [task didFailWithError: genericError];
            return;
        }

        // Finished
        [task didFailWithError: genericError];
        return;
    }
    else if ([customURL.scheme isEqualTo: @"library"]) {
        // We have found a "library:" URL. These are used for links that will install an
        // extension from the public library. Clicking on one starts the installation.
        IFExtensionsManager* mgr = [IFExtensionsManager sharedNaturalInformExtensionsManager];
        if( mgr ) {
            NSURL* url = webView.URL;
            NSURL* frameURL = webView.webFrame.dataSource.request.URL;
            NSURL* newURL = [self urlFromLibraryURL: url
                                           frameURL: frameURL];

            if ( newURL != nil ) {
                // Query at the end of the URL may have id=<number> on the end
                NSDictionary *queryDict = [self explodeString: url.query
                                                    innerGlue: @"="
                                                    outerGlue: @"&"];
                NSString* javascriptId = queryDict[@"id"];

                // Remove last object from path, and add in the other path
                [mgr downloadAndInstallExtension: newURL
                                          window: webView.window
                                  notifyDelegate: projectController
                                    javascriptId: javascriptId];
            }
            else {
                NSLog(@"URL '%@' could not be transformed using frameURL '%@'", url, frameURL);
            }
        }
        [task didFailWithError: genericError];
        return;
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

    // Remove any initial '/', to cope with "inform://..."
    if ([urlPath startsWith:@"/"]) {
        urlPath = [urlPath substringFromIndex: 1];
    }
    NSArray* components = urlPath.pathComponents;

    // Accept either the host or the path specifier containing 'extensions'
    bool hostIsExtensions = [host.lowercaseString isEqualToString: @"extensions"];
    bool firstComponentIsExtensions = (components != nil && components.count > 1 &&
                                       [[components[0] lowercaseString] isEqualToString: @"extensions"]);
    if ( hostIsExtensions || firstComponentIsExtensions) {
        NSEnumerator* componentEnum = [components objectEnumerator];
        NSString* pathComponent;
        IFProject *project = projectController.document;

        if (project.useNewExtensions) {
            // Get the project's materials folder
            path = project.materialsDirectoryURL.path;

            // Add "Extensions" if needed
            if ((hostIsExtensions) && (!firstComponentIsExtensions)) {
                path = [path stringByAppendingPathComponent: @"Extensions"];
            }
        } else {
            // Get external Documentation folder
            path = [IFUtility pathForInformExternalDocumentation];
        }

        while ((pathComponent = [componentEnum nextObject])) {
            path = [path stringByAppendingPathComponent: pathComponent];
        }

        // Check if the file exists
        if (![[NSFileManager defaultManager] fileExistsAtPath: path]) {
            path = nil;
        }
    } else {
        // Try using Inform Core external directory (if preference set)
        IFPreferences* prefs = [IFPreferences sharedPreferences];
        if (prefs.useExternalInformCoreDirectory) {
            // D/resources/App HTML
            // First look for resource in external directory, and if that fails, try the en.lproj directory
            path = [[prefs.externalInformCoreDirectory stringByAppendingPathComponent:@"Resources"] stringByAppendingPathComponent:@"App HTML"];
            path = [path stringByAppendingPathComponent: urlPath];
            if (![[NSFileManager defaultManager] fileExistsAtPath: path]) {
                path = [[[prefs.externalInformCoreDirectory stringByAppendingPathComponent:@"Resources"] stringByAppendingPathComponent:@"App HTML"] stringByAppendingPathComponent:@"en.lproj"];
                path = [path stringByAppendingPathComponent: urlPath];
                if (![[NSFileManager defaultManager] fileExistsAtPath: path]) {
                    NSLog(@"Warning: (Trying External Inform Core Directory) When trying to resolve URL '%@' I converted it to filepath '%@', but this file was not found here.\n", url, path);
                    path = nil;
                }
            }
        }

        if (path == nil) {
            // Try using pathForResource:ofType:
            // Advantage of this is that it will allow for localisation at some point in the future
            path = [[NSBundle mainBundle] pathForResource: urlPath.lastPathComponent.stringByDeletingPathExtension
                                                   ofType: urlPath.pathExtension
                                              inDirectory: urlPath.stringByDeletingLastPathComponent];
        }
    }

    if (path == nil) {
        // Check if the file is in an asset catalog.
        NSString *assetCheckPath = urlPath.stringByDeletingPathExtension;
        if ([assetCheckPath endsWithCaseInsensitive: @"@2x"]) {
            assetCheckPath = [assetCheckPath stringByReplacing:@"@2x" with:@""];
        }
        NSImage *img = [NSImage imageNamed: assetCheckPath];

        if (img != nil) {
            //Just output TIFF: it uses the least amount of code:
            NSData *urlData = img.TIFFRepresentation;

            //Which means a TIFF MIME type. Regardless of extension.
            *mimeType = @"image/tiff";
            return urlData;
        }
    }

    if (path == nil) {
        // If that fails, then just append to the resourcePath of the main bundle
        path = [[[NSBundle mainBundle].resourcePath stringByAppendingString: @"/"] stringByAppendingString: urlPath];
    }

    // Check that this is the right kind of URL for us
    if (path == nil || ![url.scheme isEqualToString: @"inform"]) {
        // Doh - not a valid inform: URL
        *error = [NSError errorWithDomain: NSURLErrorDomain
                                     code: NSURLErrorBadURL
                                 userInfo: @{NSURLErrorFailingURLErrorKey: url}];
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
                                 userInfo: @{NSURLErrorFailingURLErrorKey: url}];
        return nil;
    }

    // Load up the data
    NSData* urlData = [NSData dataWithContentsOfFile: path];
    if (urlData == nil) {
        *error = [NSError errorWithDomain: NSURLErrorDomain
                                     code: NSURLErrorCannotOpenFile
                                 userInfo: @{NSURLErrorFailingURLErrorKey: url}];
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
        if ([path.pathExtension isEqualToString: @"gif"]) {
            ourType = @"image/gif";
        } else if ([path.pathExtension isEqualToString: @"jpeg"] ||
                   [path.pathExtension isEqualToString: @"jpg"]) {
            ourType = @"image/jpeg";
        } else if ([path.pathExtension isEqualToString: @"png"]) {
            ourType = @"image/png";
        } else if ([path.pathExtension isEqualToString: @"tiff"] ||
                   [path.pathExtension isEqualToString: @"tif"]) {
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
    NSDictionary * commands = @{ @"selectView": @1,
                                 @"confirmAction": @0,
                                 @"install": @1,
                                 @"modernise": @1,
                                 @"uninstall": @1,
                                 @"test": @3,
                                 @"createNewProject": @2,
                                 @"pasteCode": @1,
                                 @"openFile": @1,
                                 @"openURL": @1,
                                 @"askInterfaceForLocalVersionAuthor": @3,
                                 @"askInterfaceForLocalVersionTextAuthor": @2,
                                 @"downloadMultipleExtensions": @1
                               };
    if (list.count == 0) {
        return;
    }
    if (commands[list[0]] == nil) {
        return;
    }
    if((long) list.count <= (long) commands[list[0]]) {
        return;
    }
    if ([@"selectView" isEqualToString: list[0]]) {
        [self selectView: list[1]];
    } else if ([@"confirmAction" isEqualToString: list[0]]) {
        [self confirmAction];
    } else if ([@"install" isEqualToString: list[0]]) {
        [self install: list[1]];
    } else if ([@"uninstall" isEqualToString: list[0]]) {
        [self uninstall: list[1]];
    } else if ([@"modernise" isEqualToString: list[0]]) {
        [self modernise: list[1]];
    } else if ([@"test" isEqualToString: list[0]]) {
        [self test: list[1] command: list[2] testcase: list[3]];
    } else if ([@"createNewProject" isEqualToString: list[0]]) {
        [self createNewProject: list[1]
                         story: list[2]];
    } else if ([@"pasteCode" isEqualToString: list[0]]) {
        [self pasteCode: list[1]];
    } else if ([@"openFile" isEqualToString: list[0]]) {
        [self openFile: list[1]];
    } else if ([@"openURL" isEqualToString: list[0]]) {
        [self openUrl: list[1]];
    } else if ([@"askInterfaceForLocalVersionAuthor" isEqualToString: list[0]]) {
        [self askInterfaceForLocalVersionAuthor: list[1]
                                          title: list[2]
                                      available: list[3]
                                compilerVersion: settings.compilerVersion];
    } else if ([@"askInterfaceForLocalVersionTextAuthor" isEqualToString: list[0]]) {
        [self askInterfaceForLocalVersionTextAuthor: list[1]
                                              title: list[2]
                                    compilerVersion: settings.compilerVersion];
    } else if ([@"downloadMultipleExtensions" isEqualToString: list[0]]) {
        [self downloadMultipleExtensions: list[1]];
    }
}

- (void) selectView: (NSString*) view {
    view = view.lowercaseString;

    if ([view isEqualToString: @"source"]) {
        [projectController.sourcePane selectViewOfType: IFSourcePane];
    } else if ([view isEqualToString: @"error"]) {
        [pane selectViewOfType: IFErrorPane];
    } else if ([view isEqualToString: @"game"]) {
        [pane selectViewOfType: IFGamePane];
    } else if ([view isEqualToString: @"documentation"]) {
        [pane selectViewOfType: IFDocumentationPane];
    } else if ([view isEqualToString: @"index"]) {
        [pane selectViewOfType: IFIndexPane];
    } else if ([view isEqualToString: @"skein"]) {
        [pane selectViewOfType: IFSkeinPane];
    } else {
        // Other view types are not supported at present
    }
}

- (void) confirmAction {
    // Install/Uninstall the extension that was last run through inbuild
    [projectController confirmInbuildAction];
}

- (void) install: (NSString*) extension {
    // Install the extension
    [projectController installExtension: extension];
}

- (void) modernise: (NSString*) extension {
    // Modernise the extension
    [projectController moderniseExtension: extension];
}

- (void) uninstall: (NSString*) extension {
    // Install the extension
    [projectController uninstallExtension: extension];
}

- (void) test: (NSString*) extension
      command: (NSString*) command
     testcase: (NSString*) testcase {
    // Test the extension
    [projectController testExtension: extension
                             command: command
                            testcase: testcase];
}

- (void) createNewProject: (NSString *)title
                    story: (NSString *)story {
    title = [IFUtility unescapeString: title];
    story = [IFUtility unescapeString: story];

    [(IFAppDelegate *) NSApp.delegate createNewProject: title
                                                   story: story];
}

- (void) pasteCode: (NSString*) code {
    [projectController.sourcePane.sourcePage pasteSourceCode: [IFUtility unescapeString: code]];
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
                                     available: (NSString*) availableVersion
                               compilerVersion: (NSString*) compilerVersion {
    IFExtensionsManager* mgr = [IFExtensionsManager sharedNaturalInformExtensionsManager];
    author = author.lowercaseString;
    title = title.lowercaseString;

    IFSemVer* versionAvailable = [[IFSemVer alloc] initWithString: availableVersion];

    for( IFExtensionInfo* info in [mgr availableExtensionsWithCompilerVersion: compilerVersion] ) {
        // NSLog(@"Got installed extension %@ by %@", [info title], info.author);
        if( [(info.author).lowercaseString isEqualToString: author] ) {
            if( [[IFExtensionInfo canonicalTitle:info.displayName].lowercaseString isEqualToString: title] ) {
                // We have this extension
                if( info.isBuiltIn ) {
                    //NSLog(@"Found %@ by %@ BUILT IN", title, author);
                    return @"!";
                }

                IFSemVer* versionLocal = info.semver;

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
                                             title: (NSString*) title
                                   compilerVersion: (NSString*) compilerVersion {
    IFExtensionsManager* mgr = [IFExtensionsManager sharedNaturalInformExtensionsManager];
    author = author.lowercaseString;
    title = title.lowercaseString;

    for( IFExtensionInfo* info in [mgr availableExtensionsWithCompilerVersion: compilerVersion] ) {
        if( [(info.author).lowercaseString isEqualToString: author] ) {
            if( [[IFExtensionInfo canonicalTitle: info.displayName].lowercaseString isEqualToString: title] ) {
                return info.safeVersion;
            }
        }
    }

    // Not found
    return @"";
}

-(void) downloadMultipleExtensions:(NSArray*) array {
    for(int index = 0; index < array.count; index += 3) {
        NSString* item      = array[index];
        NSString* urlString = array[index + 1];
        //NSString* version   = [array objectAtIndex: index + 2];
        //NSLog(@"item is %@ for url %@ version %@", item, urlString, version);

        NSURL* frameURL = [IFUtility publicLibraryURL];
        NSURL* realURL = [self urlFromLibraryURL: [NSURL URLWithString: urlString]
                                        frameURL: frameURL];

        [[IFExtensionsManager sharedNaturalInformExtensionsManager] downloadAndInstallExtension: realURL
                                                                                         window: pane.controller.window
                                                                                 notifyDelegate: pane.controller
                                                                                   javascriptId: item];
    }
}

#pragma mark - Preferences

- (void) fontSizePreferenceChanged: (WKWebView*) wView {
    float fontSizeMultiplier = [IFPreferences sharedPreferences].appFontSizeMultiplier;
    NSString* js = [NSString stringWithFormat: @"document.body.style.zoom = '%.2f'", fontSizeMultiplier];
    [wView evaluateJavaScript: js completionHandler:nil];
}

@end
