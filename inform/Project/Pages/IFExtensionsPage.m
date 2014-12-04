//
//  IFExtensionsPage.m
//  Inform-xc2
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFExtensionsPage.h"
#import "IFJSProject.h"
#import "IFPreferences.h"
#import "IFMaintenanceTask.h"
#import "IFAppDelegate.h"
#import "IFUtility.h"
#import "IFExtensionsManager.h"

@implementation IFExtensionsPage

// = Initialisation =

- (id) initWithProjectController: (IFProjectController*) controller {
	self = [super initWithNibName: @"Documentation"
				projectController: controller];
	
	if (self) {
        reloadingBecauseCensusCompleted = false;

		homeCell = [[IFPageBarCell alloc] initImageCell:[NSImage imageNamed:NSImageNameHomeTemplate]];
		[homeCell setTarget: self];
		[homeCell setAction: @selector(showHome:)];

		definitionsCell = [[IFPageBarCell alloc] initTextCell: [IFUtility localizedString: @"ExtensionDefinitions"
                                                                                  default: @"Definitions"]];
		[definitionsCell setTarget: self];
		[definitionsCell setAction: @selector(showDefinitions:)];

		publicLibraryCell = [[IFPageBarCell alloc] initTextCell: [IFUtility localizedString: @"ExtensionPublicLibrary"
                                                                                    default: @"Public Library"]];
		[publicLibraryCell setTarget: self];
		[publicLibraryCell setAction: @selector(showPublicLibrary:)];

        // Static dictionary mapping tab names to cells
        tabDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:
                         homeCell,          @"inform://Extensions/Extensions.html",
                         definitionsCell,   @"inform://Extensions/ExtIndex.html",
                         publicLibraryCell, [[IFUtility publicLibraryURL] absoluteString],
                         nil];

		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(preferencesChanged:)
													 name: IFPreferencesAppFontSizeDidChangeNotification
												   object: [IFPreferences sharedPreferences]];
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(censusCompleted:)
													 name: IFCensusFinishedNotification
												   object: nil];
		
		if ((int)[[NSApp delegate] isWebKitAvailable]) {
			// Create the view for the documentation tab
			wView = [[WebView alloc] init];
			[wView setTextSizeMultiplier: [[IFPreferences sharedPreferences] appFontSizeMultiplier]];
			[wView setResourceLoadDelegate: self];
			[wView setFrameLoadDelegate: self];
			
			[wView setFrame: [view bounds]];
			[wView setAutoresizingMask: (NSUInteger) (NSViewWidthSizable|NSViewHeightSizable)];
			[view addSubview: wView];
			
            NSURL* url = [NSURL URLWithString: @"inform://Extensions/Extensions.html"];
            NSURLRequest* urlRequest = [[NSURLRequest alloc] initWithURL: url];
			[[wView mainFrame] loadRequest: urlRequest];
            [urlRequest release];
		} else {
			wView = nil;
		}		
		
		if ([[NSApp delegate] isWebKitAvailable]) {
			[wView setPolicyDelegate: [parent extensionsPolicy]];
			
			[wView setUIDelegate: parent];
			[wView setHostWindow: [parent window]];
		}
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	[wView release];
    wView = nil;
	
	[homeCell release];
    [definitionsCell release];
    [publicLibraryCell release];
    
	[super dealloc];
}

// = Details about this view =

- (NSString*) title {
	return [IFUtility localizedString: @"Extensions Page Title"
                              default: @"Extensions"];
}

// = Updating extensions =

- (void) censusCompleted: (NSNotification*) not {
    reloadingBecauseCensusCompleted = true;
	// Force the documentation view to reload (the 'installed extensions' page may be updated)
	[wView reload: self];
    reloadingBecauseCensusCompleted = false;
}

// = Preferences =

- (void) preferencesChanged: (NSNotification*) not {
	[wView setTextSizeMultiplier: [[IFPreferences sharedPreferences] appFontSizeMultiplier]];
}

// = Documentation =

- (void) openURL: (NSURL*) url  {
	[self switchToPage];
	
	[[wView mainFrame] loadRequest: [[[NSURLRequest alloc] initWithURL: url] autorelease]];
}

- (void) openURLWithString: (NSString*) urlString {
	if (urlString == nil) return;
	[self openURL: [NSURL URLWithString: urlString]];
}

- (void) highlightTabForURL:(NSString*) urlString {
    for (NSString*key in tabDictionary) {
        if( [key caseInsensitiveCompare:urlString] == NSOrderedSame ) {
            [[tabDictionary objectForKey:key] setState:NSOnState];
        }
        else {
            [[tabDictionary objectForKey:key] setState:NSOffState];
        }
    }
}

-(void) loadFailurePage: (WebFrame*) frame {
    if( loadingFailureWebPage ) {
        return;
    }

    NSURL* url = [NSURL URLWithString: @"inform:/pl404.html"];
    NSURLRequest* urlRequest = [NSURLRequest requestWithURL: url];
    [frame loadRequest: urlRequest];
    loadingFailureWebPage = true;
}

// = WebResourceLoadDelegate methods =

- (void)			webView:(WebView *)sender 
				   resource:(id)identifier 
	didFailLoadingWithError:(NSError *)error 
			 fromDataSource:(WebDataSource *)dataSource {
    NSString *urlString = [error.userInfo objectForKey:@"NSErrorFailingURLStringKey"];

    if (error.code == NSURLErrorCancelled) {
        //NSLog(@"IFExtensionsPage: load of URL %@ was cancelled", urlString);
        loadingFailureWebPage = NO;
        return;
    }
	NSLog(@"IFExtensionsPage: failed to load URL %@ with error: %@", urlString, [error localizedDescription]);
    [self loadFailurePage: [wView mainFrame]];
}

// = WebFrameLoadDelegate methods =

- (void)					webView: (WebView *) sender
	didStartProvisionalLoadForFrame: (WebFrame *) frame {
    // When opening a new URL in the main frame, record it as part of the history for this page
    NSURL* url;
    WebDataSource* wds = nil;
    if ([frame provisionalDataSource] ) {
        wds = [frame provisionalDataSource];
    } else {
        wds = [frame dataSource];
    }
    url = [[wds request] URL];
    url = [[url copy] autorelease];

    // Highlight appropriate tab
    [self highlightTabForURL:[url absoluteString]];

	if (frame == [wView mainFrame]) {
        if ([self pageIsVisible]) {
            if( !reloadingBecauseCensusCompleted )
            {
                LogHistory(@"HISTORY: Documentation Page: (didStartProvisionalLoadForFrame) URL %@", [url absoluteString]);
                [[self history] switchToPage];
                [(IFExtensionsPage*)[self history] openURLWithString: [url absoluteString]];
            }
        }
    }
}

- (void)            webView: (WebView *) sender
      didCommitLoadForFrame: (WebFrame *) frame {
	if (frame == [wView mainFrame]) {
        WebDataSource* wds = nil;
        if ([frame provisionalDataSource] ) {
            wds = [frame provisionalDataSource];
        } else {
            wds = [frame dataSource];
        }

        NSURLResponse* response = [wds response];
        if( [response isKindOfClass:[NSHTTPURLResponse class]] ) {
            NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*) response;
            int statusCode = [httpResponse statusCode];
            if( statusCode >= 400 ) {
                [frame stopLoading];

                [self loadFailurePage: frame];
            }
        }
    }
}

- (void)                 webView: (WebView *) sender
                        resource: (id) identifier
  didFinishLoadingFromDataSource: (WebDataSource *) dataSource {
    loadingFailureWebPage = NO;
}

- (void)        webView: (WebView *) sender
   didClearWindowObject: (WebScriptObject *) windowObject
               forFrame: (WebFrame *) frame {
	if (otherPane) {
		// Attach the JavaScript object to the opposing view
		IFJSProject* js = [[IFJSProject alloc] initWithPane: otherPane];
		
		// Attach it to the script object
		[[sender windowScriptObject] setValue: [js autorelease]
									   forKey: @"Project"];
	}
}

// = History =

- (void) didSwitchToPage {
	WebFrame* frame = [wView mainFrame];
	NSURL* url;
	if ([frame provisionalDataSource]) {
		url = [[[frame provisionalDataSource] request] URL];
	} else {
		url = [[[frame dataSource] request] URL];
	}
	NSString* urlString = [url absoluteString];
	
    LogHistory(@"HISTORY: Documentation Page: (didSwitchToPage) URL %@", urlString);
	[[self history] openURLWithString: urlString];
}

// = Page bar cells =

- (NSArray*) toolbarCells {
	return [NSArray arrayWithObjects: publicLibraryCell, definitionsCell, homeCell, nil];
}

-(NSString*) urlStringForCell:(IFPageBarCell*) cell {
    for (NSString* key in tabDictionary) {
        if( [tabDictionary objectForKey:key] == cell ) {
            return key;
        }
    }
    return nil;
}

- (void) showHome: (id) sender {
	[self openURL: [NSURL URLWithString: [self urlStringForCell:homeCell]]];
}

- (void) showDefinitions: (id) sender {
	[self openURL: [NSURL URLWithString: [self urlStringForCell:definitionsCell]]];
}

- (void) showPublicLibrary: (id) sender {
	[self openURL: [NSURL URLWithString: [self urlStringForCell:publicLibraryCell]]];
}

- (void) extensionUpdated:(NSString*) javascriptId {
    NSString* js = [NSString stringWithFormat:@"window.downloadSucceeded(%@);", javascriptId];
    //NSLog(@"Calling javascript: %@", js);
    [wView stringByEvaluatingJavaScriptFromString: js];
}

- (void) willClose {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

@end
