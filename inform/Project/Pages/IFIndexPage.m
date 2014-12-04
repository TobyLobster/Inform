//
//  IFIndexPage.m
//  Inform-xc2
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFIndexPage.h"
#import "IFPreferences.h"

#import "IFAppDelegate.h"
#import "IFJSProject.h"
#import "IFUtility.h"

@implementation IFIndexPage

// = Initialisation =

- (id) initWithProjectController: (IFProjectController*) controller {
	self = [super initWithNibName: @"Index"
				projectController: controller];
	
	if (self) {
        indexAvailable = NO;

        // Static dictionary mapping tab names to enum values
        tabDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:
                      [NSNumber numberWithInt:IFIndexActions],    @"actions.html",
                      [NSNumber numberWithInt:IFIndexPhrasebook], @"phrasebook.html",
                      [NSNumber numberWithInt:IFIndexScenes],     @"scenes.html",
                      [NSNumber numberWithInt:IFIndexContents],   @"contents.html",
                      [NSNumber numberWithInt:IFIndexKinds],      @"kinds.html",
                      [NSNumber numberWithInt:IFIndexRules],      @"rules.html",
                      [NSNumber numberWithInt:IFIndexWorld],      @"world.html",
                      [NSNumber numberWithInt:IFIndexWelcome],    @"welcome.html",
                      nil];

        // Create the webview (could probably be in the nib)
        webView = [[WebView alloc] initWithFrame: [[self view] bounds]];
        [webView setAutoresizingMask: (NSUInteger) (NSViewWidthSizable|NSViewHeightSizable)];
        [webView setTextSizeMultiplier: [[IFPreferences sharedPreferences] appFontSizeMultiplier]];
        [webView setHostWindow: [parent window]];
        [webView setPolicyDelegate: [parent docPolicy]];
        [webView setFrameLoadDelegate: self];

        // Add the webview as a subview of the index page
        [[self view] addSubview: webView];
	}

	return self;
}

- (void) dealloc {
	[indexCells release];
    [webView release];
    [tabDictionary release];

	[super dealloc];
}

// = Details about this view =
- (NSString*) title {
	return [IFUtility localizedString: @"Index Page Title"
                              default: @"Index"];
}

// = Page validation =
- (BOOL) indexAvailable {
	return indexAvailable;
}

- (BOOL) shouldShowPage {
	return indexAvailable;
}

// = Helper functions =
-(int) indexOfItemWithTabId: (int) tabIdentifier {
    id identifier = [NSNumber numberWithInt: tabIdentifier];
	int index = 0;
	for( IFPageBarCell* cell in indexCells ) {
		if ([[cell identifier] isEqual: identifier]) return index;
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

-(int) tabIdOfItemWithFilename:(NSString *) theFile
{
    NSString* lowerFile = [theFile lowercaseString];
    
    NSNumber* integer = [tabDictionary objectForKey:lowerFile];
    if( integer == nil ) {
        return NSNotFound;
    }
    return [integer intValue];
}

-(NSString *) filenameOfItemWithTabId:(int) tabId
{
    for( NSString* key in tabDictionary)
    {
        if( [[tabDictionary objectForKey:key] intValue] == tabId ) {
            return key;
        }
    }
    return nil;
}


- (BOOL) requestRelativePath:(NSString *) relativePath {
    NSString* indexPath = [NSString stringWithFormat: @"%@/Index", [[parent document] fileName]];
    NSString* fullPath = [indexPath stringByAppendingPathComponent: relativePath];

    BOOL isDir = NO;
    
    // Check that it exists and is a directory
    if (indexPath == nil) return NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath: indexPath
                                              isDirectory: &isDir]) return NO;
    if (!isDir) return NO;

    NSURLRequest* aRequest = [[[NSURLRequest alloc] initWithURL: [IFProjectPolicy fileURLWithPath: fullPath]] autorelease];
    //NSLog(@"self %@ Index page -requestRelativePath about to request a load of %@", self, aRequest.URL.absoluteString);
    [[webView mainFrame] loadRequest: aRequest];
    //NSLog(@"self %@ Index page -requestRelativePath has requested a load of %@", self, aRequest.URL.absoluteString);

    return YES;
}

- (BOOL) requestURL:(NSURL *) url {
    
    NSURLRequest* aRequest = [[[NSURLRequest alloc] initWithURL:url] autorelease];
    //NSLog(@"self %@ Index page -requestURL about to request a load of %@", self, aRequest.URL.absoluteString);
    [[webView mainFrame] loadRequest: aRequest];
    //NSLog(@"self %@ Index page -requestURL has requested a load of %@", self, aRequest.URL.absoluteString);
    
    return YES;
}

- (void) switchToTab: (int) tabIdentifier {
	int tabIndex = [self indexOfItemWithTabId:tabIdentifier];
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

    int tabIdentifier = [[cell identifier] intValue];
    [self switchToTab:tabIdentifier];
}

- (void) updateIndexView {
	indexAvailable = NO;
	
	if (![IFAppDelegate isWebKitAvailable]) return;
	
	// Refresh the copies of the index files in memory
	[[parent document] reloadIndexDirectory];

	// The index path
	NSString* indexPath = [NSString stringWithFormat: @"%@/Index", [[parent document] fileName]];
	BOOL isDir = NO;
	
	if (indexCells) [indexCells release];
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
		NSString* extension = [[theFile pathExtension] lowercaseString];
		
		if ([extension isEqualToString: @"htm"] ||
			[extension isEqualToString: @"html"]) {
			// Create the tab
			IFPageBarCell* newTab = [[[IFPageBarCell alloc] init] autorelease];
			[newTab setRadioGroup: 128];

			// Choose an ID for this tab based on the filename
			int tabId = [self tabIdOfItemWithFilename:theFile];
            if( tabId == IFIndexWelcome ) {
                [newTab setImage:[NSImage imageNamed:NSImageNameHomeTemplate]];
            }
            else {
                NSString* label = [IFUtility localizedString: theFile
                                                     default: [theFile stringByDeletingPathExtension]
                                                       table: @"CompilerOutput"];
                [newTab setStringValue: label];
            }

            if( tabId != NSNotFound ) {
                [newTab setIdentifier: [NSNumber numberWithInt: tabId]];
                [newTab setTarget: self];
                [newTab setAction: @selector(switchToTabWithObject:)];

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
    [indexCells sortUsingDescriptors:[NSArray arrayWithObject:sort]];

	indexMachineSelection--;
}

// = Utility functions =

- (NSURLRequest*) request {
    WebFrame*	mainFrame = [webView mainFrame];
    if ([mainFrame provisionalDataSource]) {
        return [[mainFrame provisionalDataSource] request];
    }
    return [[mainFrame dataSource] request];
}

// = Switching cells =
- (IBAction) switchToCell: (id) sender {
	if ([sender isKindOfClass: [IFPageBarCell class]]) {
        IFPageBarCell* cell = sender;
        [self switchToTab:[[cell identifier] intValue]];
    }
}

- (void) didSwitchToPage {
    LogHistory(@"HISTORY: Index Page: (didSwitchToPage) requestURL %@", [[[self request] URL] absoluteString]);
	[[self history] requestURL:[[self request] URL]];
	[super didSwitchToPage];
}

// = WebFrameLoadDelegate methods =
- (NSString*) titleForFrame: (WebFrame*) frame {
    return @"Index";
}

- (void)					webView: (WebView *) sender
	didStartProvisionalLoadForFrame: (WebFrame *) frame {
    // When opening a new URL in the main frame, record it as part of the history for this page
    NSURL* url = [[[frame provisionalDataSource] request] URL];
    url = [[url copy] autorelease];
    LogHistory(@"HISTORY: Index Page: (didStartProvisionalLoadForFrame) requestURL %@", [url absoluteString]);
    [[self history] switchToPage];
    [[self history] requestURL:url];
    // NSLog(@"IFIndexPage -didStartProvisionalLoadForFrame: Recording history action URL %@ with Title %@", [url absoluteString], [self titleForFrame: frame]);

    NSString* lowerURL = [[url absoluteString] lowercaseString];

    // Highlight the pane tab to something appropriate for the new URL
    for (IFPageBarCell*cell in indexCells) {
        [cell setState: NSOffState];
    }
    for(NSString *tabName in tabDictionary.keyEnumerator) {
        // is the string we are looking for
        if( [lowerURL rangeOfString:tabName].location != NSNotFound ) {
            //NSLog(@"Found tab %@", tabName);

            // Highlight the appropriate tab
            int tabIdentifier = [[tabDictionary objectForKey:tabName] intValue];
            int tabIndex = [self indexOfItemWithTabId:tabIdentifier];

            [[indexCells objectAtIndex: tabIndex] setState: NSOnState];
        }
    }
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

// = The page bar =

- (NSArray*) toolbarCells {
	if (indexCells == nil) return [NSArray array];
	return indexCells;
}

@end
