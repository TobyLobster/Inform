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
#import "IFJSProject.h"
#import "IFUtility.h"
#import "IFProjectController.h"
#import "IFProject.h"
#import "IFPageBarCell.h"
#import "IFPageBarView.h"
#import "IFExtensionsManager.h"


@implementation IFIndexPage {
    /// \c YES if the index tab should be active
    BOOL indexAvailable;

    /// A reference count - number of 'machine' operations that might be affecting the index tab selection
    int indexMachineSelection;

    /// IFPageBarCells used to select index pages
    NSMutableArray<IFPageBarCell*>* indexCells;
    /// Dictionary of tab ids and their string names
    NSDictionary<NSString*,NSNumber*>* tabDictionary;

    WebView* webView;
}

#pragma mark - Initialisation

- (instancetype) initWithProjectController: (IFProjectController*) controller {
	self = [super initWithNibName: @"Index"
				projectController: controller];
	
	if (self) {
        indexAvailable = NO;

        // Static dictionary mapping tab names to enum values
        tabDictionary = @{@"actions.html":    @(IFIndexActions),
                          @"phrasebook.html": @(IFIndexPhrasebook),
                          @"scenes.html":     @(IFIndexScenes),
                          @"contents.html":   @(IFIndexContents),
                          @"kinds.html":      @(IFIndexKinds),
                          @"rules.html":      @(IFIndexRules),
                          @"world.html":      @(IFIndexWorld),
                          @"welcome.html":    @(IFIndexWelcome)};

        // Create the webview (could probably be in the nib)
        webView = [[WebView alloc] initWithFrame: [[self view] bounds]];
        [webView setAutoresizingMask: (NSViewWidthSizable|NSViewHeightSizable)];
        [webView setTextSizeMultiplier: [[IFPreferences sharedPreferences] appFontSizeMultiplier]];
        [webView setHostWindow: [self.parent window]];
        [webView setPolicyDelegate: (id<WebPolicyDelegate>) [self.parent docPolicy]];
        [webView setFrameLoadDelegate: self];

        // Add the webview as a subview of the index page
        [[self view] addSubview: webView];

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

-(NSUInteger) tabIdOfItemWithFilename:(NSString *) theFile
{
    NSString* lowerFile = [theFile lowercaseString];
    
    NSNumber* integer = tabDictionary[lowerFile];
    if( integer == nil ) {
        return NSNotFound;
    }
    return [integer intValue];
}

-(NSString *) filenameOfItemWithTabId:(int) tabId
{
    for( NSString* key in tabDictionary)
    {
        if( [tabDictionary[key] intValue] == tabId ) {
            return key;
        }
    }
    return nil;
}


- (BOOL) requestRelativePath:(NSString *) relativePath {
    NSURL* indexDirURL = [[self.parent document] indexDirectoryURL];
    NSURL* fullFileURL = [indexDirURL URLByAppendingPathComponent: relativePath];

    BOOL isDir = NO;
    
    // Check that it exists and is a directory
    if (indexDirURL == nil) return NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath: indexDirURL.path
                                              isDirectory: &isDir]) return NO;
    if (!isDir) return NO;

    NSURLRequest* aRequest = [[NSURLRequest alloc] initWithURL: fullFileURL];
    //NSLog(@"self %@ Index page -requestRelativePath about to request a load of %@", self, aRequest.URL.absoluteString);
    [[webView mainFrame] loadRequest: aRequest];
    //NSLog(@"self %@ Index page -requestRelativePath has requested a load of %@", self, aRequest.URL.absoluteString);

    return YES;
}

- (BOOL) requestURL:(NSURL *) url {
    
    NSURLRequest* aRequest = [[NSURLRequest alloc] initWithURL:url];
    //NSLog(@"self %@ Index page -requestURL about to request a load of %@", self, aRequest.URL.absoluteString);
    [[webView mainFrame] loadRequest: aRequest];
    //NSLog(@"self %@ Index page -requestURL has requested a load of %@", self, aRequest.URL.absoluteString);
    
    return YES;
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

    int tabIdentifier = [[cell identifier] intValue];
    [self switchToTab:tabIdentifier];
}

- (void) updateIndexView {
	indexAvailable = NO;
	
	// Refresh the copies of the index files in memory
	[[self.parent document] reloadIndexDirectory];

	// The index path
	NSString* indexPath = [NSString stringWithFormat: @"%@/Index", [[self.parent document] fileURL].path];
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
		NSString* extension = [[theFile pathExtension] lowercaseString];
		
		if ([extension isEqualToString: @"htm"] ||
			[extension isEqualToString: @"html"]) {
			// Create the tab
			IFPageBarCell* newTab = [[IFPageBarCell alloc] init];
			[newTab setRadioGroup: 128];

			// Choose an ID for this tab based on the filename
			NSUInteger tabId = [self tabIdOfItemWithFilename:theFile];
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
                [newTab setIdentifier: @(tabId)];
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
    [indexCells sortUsingDescriptors:@[sort]];

	indexMachineSelection--;

    [webView reload: self];
}

#pragma mark - Preferences

- (void) fontSizePreferenceChanged: (NSNotification*) not {
    [webView setTextSizeMultiplier: [[IFPreferences sharedPreferences] appFontSizeMultiplier]];
}

#pragma mark - Utility functions

- (NSURLRequest*) request {
    WebFrame*	mainFrame = [webView mainFrame];
    if ([mainFrame provisionalDataSource]) {
        return [[mainFrame provisionalDataSource] request];
    }
    return [[mainFrame dataSource] request];
}

#pragma mark - Switching cells

- (IBAction) switchToCell: (id) sender {
	if ([sender isKindOfClass: [IFPageBarCell class]]) {
        IFPageBarCell* cell = sender;
        [self switchToTab:[[cell identifier] intValue]];
    }
}

- (void) didSwitchToPage {
    NSURL* url = [[self request] URL];
    LogHistory(@"HISTORY: Index Page: (didSwitchToPage) requestURL %@", [url absoluteString]);
	[[self history] requestURL: url];

    // Highlight the indexCell to something appropriate for the new URL
    [self highlightAppropriateIndexCellForURL: url];
	[super didSwitchToPage];
}

#pragma mark - WebFrameLoadDelegate methods

- (NSString*) titleForFrame: (WebFrame*) frame {
    return @"Index";
}

-(void) highlightAppropriateIndexCellForURL:(NSURL*) url {
    NSString* lowerURL = [[url absoluteString] lowercaseString];

    // Highlight the pane tab to something appropriate for the new URL
    for (IFPageBarCell*cell in indexCells) {
        [cell setState: NSControlStateValueOff];
    }
    for(NSString *tabName in tabDictionary.keyEnumerator) {
        // is the string we are looking for
        if( [lowerURL rangeOfString:tabName].location != NSNotFound ) {
            //NSLog(@"Found tab %@", tabName);

            // Highlight the appropriate tab
            int tabIdentifier = [tabDictionary[tabName] intValue];
            NSUInteger tabIndex = [self indexOfItemWithTabId:tabIdentifier];

            [(NSCell*)indexCells[tabIndex] setState: NSControlStateValueOn];
        }
    }
}

- (void)					webView: (WebView *) sender
	didStartProvisionalLoadForFrame: (WebFrame *) frame {
    // When opening a new URL in the main frame, record it as part of the history for this page
    NSURL* url = [[[frame provisionalDataSource] request] URL];
    url = [url copy];
    LogHistory(@"HISTORY: Index Page: (didStartProvisionalLoadForFrame) requestURL %@", [url absoluteString]);
    [[self history] switchToPage];
    [[self history] requestURL:url];

    // NSLog(@"IFIndexPage -didStartProvisionalLoadForFrame: Recording history action URL %@ with Title %@", [url absoluteString], [self titleForFrame: frame]);

    // Highlight the indexCell to something appropriate for the new URL
    [self highlightAppropriateIndexCellForURL:url];
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

#pragma mark - The page bar

- (NSArray*) toolbarCells {
	if (indexCells == nil) return [NSArray array];
	return indexCells;
}

@end
