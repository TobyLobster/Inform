//
//  IFWelcomeWindow.m
//  Inform
//
//  Created by Andrew Hunter on 05/10/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//  Rewritten by Toby Nelson, 2014.
//

#import "IFWelcomeWindow.h"

#import <WebKit/WebKit.h>
#import "IFAppDelegate.h"
#import "IFRecentFileCellInfo.h"
#import "IFRecentFileCell.h"

#import "IFMaintenanceTask.h"
#import "IFUtility.h"
#import "IFExtensionsManager.h"
#import "IFPreferences.h"

@implementation IFWelcomeWindow {
    /// Progress indicator that shows when a background process is running
    IBOutlet NSProgressIndicator*   backgroundProgress;

    /// News web view
    WKWebView*                      newsWebView;
    IBOutlet NSView*                newsWebParent;
    WKWebViewConfiguration *        newsWebConfiguration;

    /// Recent document scroll view
    IBOutlet NSScrollView*          recentDocumentsScrollView;
    /// Recent document Table View
    IBOutlet NSTableView*           recentDocumentsTableView;
    /// Create document scroll view
    IBOutlet NSScrollView*          createDocumentsScrollView;
    /// Create document Table View
    IBOutlet NSTableView*           createDocumentsTableView;
    /// Sample document scroll view
    IBOutlet NSScrollView*          sampleDocumentsScrollView;
    /// Sample document Table View
    IBOutlet NSTableView*           sampleDocumentsTableView;
    /// Parent
    IBOutlet NSView*                parentView;
    /// Show a web page (for advice)
    IBOutlet WebView*               webView;
    /// Show the middle section
    IBOutlet NSView*                middleView;
    /// Top banner image, as a button
    IBOutlet NSButton*              imageButton;

    /// Array of recent file info
    NSMutableArray*                 recentInfoArray;
    /// Array of create file info
    NSMutableArray*                 createInfoArray;
    /// Array of sample file info
    NSMutableArray*                 sampleInfoArray;
    /// Array of news info
    NSMutableArray*                 newsArray;

    WKNavigation *                  newsNav;
}

static const int maxItemsInRecentMenu = 8;

/// Shared welcome window
static IFWelcomeWindow* sharedWindow = nil;

#pragma mark - Initialisation

+ (IFWelcomeWindow*) sharedWelcomeWindow {
	if (sharedWindow == nil) {
		sharedWindow = [[IFWelcomeWindow alloc] initWithWindowNibName: @"Launcher"];
	}

	return sharedWindow;
}

+ (void) hideWelcomeWindow {
    if( sharedWindow != nil ) {
        [[[IFWelcomeWindow sharedWelcomeWindow] window] close];
    }
}

+ (void) showWelcomeWindow {
    IFWelcomeWindow * welcome = [IFWelcomeWindow sharedWelcomeWindow];

    [welcome showWelcomeWindow];
}

-(void) showWelcomeWindow {
    [self refreshRecentItems];

    // Hide web view
    [self hideWebView];

    // Show window
    [self showWindow: self];
    [[self window] orderFront: self];

    //NSLog(@"FRAME = %@", recentDocumentsTableView.frame);
    //NSLog(@"bounds = %@", recentDocumentsTableView.bounds);

    if (@available(macOS 11.0, *)) {
        recentDocumentsTableView.style = NSTableViewStylePlain;
        createDocumentsTableView.style = NSTableViewStylePlain;
        sampleDocumentsTableView.style = NSTableViewStylePlain;
    }
    // By default the enclosing scrollview has a bezelled border, but we set
    // it to no border here after the tableview style has been set to plain.
    recentDocumentsTableView.enclosingScrollView.borderType = NSNoBorder;
    createDocumentsTableView.enclosingScrollView.borderType = NSNoBorder;
    sampleDocumentsTableView.enclosingScrollView.borderType = NSNoBorder;


    // create news web view (if not already created)
    if (self->newsWebConfiguration == nil) {
        self->newsWebConfiguration = [[WKWebViewConfiguration alloc] init];
        // Set the navigation delegate
        IFAppDelegate* appDelegate = (IFAppDelegate*)[NSApp delegate];
        [self->newsWebConfiguration setURLSchemeHandler: appDelegate.newsManager.newsSchemeHandler
                              forURLScheme: @"inform"];
        self->newsWebView = [[WKWebView alloc] initWithFrame: self->newsWebParent.bounds
                                               configuration: self->newsWebConfiguration];
    }

    // Set the navigation delegate
    self->newsWebView.navigationDelegate = self;

    // Give the news web view a transparent background
    [self->newsWebView setValue:@(NO) forKey:@"drawsBackground"];

    // Add web view to parent
    [self->newsWebParent addSubview: self->newsWebView];

    // Refresh news if needed
    [self checkIfNewsRefreshIsNeeded];
}

- (void) hideWebView {
    [webView setHidden: YES];
    [middleView setHidden: NO];
}

- (void) showWebView {
    [webView setHidden: NO];
    [middleView setHidden: YES];
}

- (void) checkIfNewsRefreshIsNeeded {
    // Get the news from the news manager
    // when done, call the completion handler
    IFAppDelegate* appDelegate = (IFAppDelegate*)[NSApp delegate];

    [[appDelegate newsManager] getNewsWithCompletionHandler: ^(NSString* latestNews, NSURLResponse* response, NSError* error) {
        // When finished, refreshNews on main thread
        [self performSelectorOnMainThread:@selector(refreshNews:) withObject:latestNews waitUntilDone:NO];
    }];
}

- (NSString *) encodeForHTML:(NSString*) myStr {
    return [[[[[myStr stringByReplacingOccurrencesOfString: @"&" withString: @"&amp;"]
     stringByReplacingOccurrencesOfString: @"\"" withString: @"&quot;"]
     stringByReplacingOccurrencesOfString: @"'" withString: @"&#39;"]
     stringByReplacingOccurrencesOfString: @">" withString: @"&gt;"]
     stringByReplacingOccurrencesOfString: @"<" withString: @"&lt;"];
}

- (void) refreshNews: (NSString*) latestNews {
    if (newsWebView == nil) {
        // Early out if no web view to change
        return;
    }

    // Load template file
    NSError* error;
    NSString *news = [NSString stringWithContentsOfURL: [NSURL URLWithString: @"inform:/NewsTemplate.html"]
                                              encoding: NSUTF8StringEncoding
                                                 error: &error];
    if (news != nil) {
        NSDateIntervalFormatter* outputFormatter = [[NSDateIntervalFormatter alloc] init];
        outputFormatter.dateStyle = NSDateIntervalFormatterMediumStyle;
        outputFormatter.timeStyle = NSDateIntervalFormatterNoStyle;

        // parse data
        NSISO8601DateFormatter* format = [[NSISO8601DateFormatter alloc] init];
        [format setFormatOptions: NSISO8601DateFormatWithFullDate];

        NSMutableArray *data = [[latestNews componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterSet]] mutableCopy];
        NSString* str = @"";
        for (int i = 0; i < [data count]; i++)
        {
            // Parse line
            NSString *line = [data objectAtIndex: i];
            NSArray* lineParts = [line componentsSeparatedByString:@"\t"];
            if ([lineParts count] >= 3) {
                NSDate* startDate = [format dateFromString: lineParts[0]];
                NSDate* endDate = [format dateFromString: lineParts[1]];
                NSString* headline = [self encodeForHTML:lineParts[2]];
                NSString* link = @"";

                if ([lineParts count] >= 4) {
                    link = lineParts[3];
                }

                if (endDate == nil) {
                    endDate = [startDate copy];
                }

                // Use the output formatter to generate the string.
                NSString* dateStr = [outputFormatter stringFromDate:startDate toDate:endDate];
                if ((dateStr != nil) && (headline != nil)) {
                    //        <tr><td>17th June 2022</td><td><a href="http://www.inform7.com">News Item 1</a></td></tr>
                    str = [str stringByAppendingFormat:@"<tr><td>%@</td><td><a href=\"%@\">%@</a></td></tr>\n", dateStr, link, headline];
                }
            }
        }

        // replace <!-- CONTENT HERE -->
        news = [news stringByReplacingOccurrencesOfString:@"<!-- CONTENT HERE -->" withString:str];
        //NSLog(@"%@", news);

        newsNav = [newsWebView loadHTMLString: news
                                      baseURL: [NSURL URLWithString: @"inform:/"]];
    } else {
        NSLog(@"%@", error);
    }
}

- (void) refreshRecentItems {
    NSImage* icon;
    recentInfoArray = [[NSMutableArray alloc] init];
    
    NSInteger index = 0;
    for( NSURL* url in [[NSDocumentController sharedDocumentController] recentDocumentURLs] ) {
        if (![url getResourceValue:&icon forKey:NSURLEffectiveIconKey error: NULL]) {
            icon = [[NSWorkspace sharedWorkspace] iconForFile: [url path]];
        }
        
        IFRecentFileCellInfo* info = [[IFRecentFileCellInfo alloc] initWithTitle: [url lastPathComponent]
                                                                            image: icon
                                                                              url: url
                                                                             type: IFRecentFile];
        [recentInfoArray addObject: info];
        index++;
        
        if( index >= maxItemsInRecentMenu ) {
            break;
        }
    }
    
    // Item for "Open..."
    icon = [NSImage imageNamed: NSImageNameFolder];
    IFRecentFileCellInfo* info = [[IFRecentFileCellInfo alloc] initWithTitle: [IFUtility localizedString: @"Open..."]
                                                                        image: icon
                                                                          url: nil
                                                                         type: IFRecentOpen];
    [recentInfoArray addObject: info];
    [recentDocumentsTableView reloadData];
}

- (instancetype) initWithWindowNibName: (NSString*) nib {
	self = [super initWithWindowNibName: nib];
	
	if (self) {
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(startedMaintaining:)
													 name: IFMaintenanceTasksStarted
												   object: nil];
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(finishedMaintaining:)
													 name: IFCensusFinishedNotification
												   object: nil];
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(finishedMaintaining:)
													 name: IFCensusFinishedButDontUpdateExtensionsWebPageNotification
												   object: nil];

        // --- Items that refer to recent documents ---
        recentInfoArray = nil;
        [self refreshRecentItems];
        
        // --- Items that create documents ---
        createInfoArray = [[NSMutableArray alloc] init];
        
        NSImage* icon = [NSImage imageNamed: @"informfile"];
        IFRecentFileCellInfo* info = [[IFRecentFileCellInfo alloc] initWithTitle: [IFUtility localizedString: @"Create Project..."]
                                                                            image: icon
                                                                              url: nil
                                                                             type: IFRecentCreateProject];
        [createInfoArray addObject: info];

        icon = [NSImage imageNamed: @"i7xfile"];
        info = [[IFRecentFileCellInfo alloc] initWithTitle: [IFUtility localizedString: @"Create Extension..."]
                                                      image: icon
                                                        url: nil
                                                       type: IFRecentCreateExtension];
        [createInfoArray addObject: info];
        
        icon = [NSImage imageNamed: NSImageNameFolder];
        info = [[IFRecentFileCellInfo alloc] initWithTitle: [IFUtility localizedString: @"Save Documentation as eBooks"]
                                                      image: icon
                                                        url: nil
                                                       type: IFRecentSaveEPubs];
        [createInfoArray addObject: info];

        // --- Items that copy sample documents ---
        NSArray* sampleArray = @[@"Copy Onyx",                  @"Onyx.inform",
                                 @"Copy Disenchantment Bay",    @"Disenchantment Bay.inform"];

        sampleInfoArray = [[NSMutableArray alloc] init];
        icon = [NSImage imageNamed: @"informfile"];

        NSString* pathStart = [[NSBundle mainBundle] resourcePath];
        pathStart = [pathStart stringByAppendingPathComponent: @"App"];
        pathStart = [pathStart stringByAppendingPathComponent: @"Samples"];

        for( int index = 0; index < [sampleArray count]; index += 2 ) {
            NSString* path = [pathStart stringByAppendingPathComponent: sampleArray[index + 1]];
            info = [[IFRecentFileCellInfo alloc] initWithTitle: [IFUtility localizedString: sampleArray[index]]
                                                          image: icon
                                                            url: [NSURL fileURLWithPath: path
                                                                            isDirectory: YES]
                                                           type: IFRecentCopySample];
            [sampleInfoArray addObject: info];
        }

        // Link to IFDB
        icon = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericDocumentIcon)];
        info = [[IFRecentFileCellInfo alloc] initWithTitle: [IFUtility localizedString: @"Link to IFDB"]
                                                      image: icon
                                                        url: [NSURL URLWithString:@"http://ifdb.tads.org/search?sortby=new&newSortBy.x=0&newSortBy.y=0&searchfor=tag%3A+i7+source+available"]
                                                       type: IFRecentWebsiteLink];
        [sampleInfoArray addObject: info];
	}

	return self;
}

- (void) windowDidLoad {
	// Center the window on whichever screen it will appear on
	NSRect winFrame = [[self window] frame];
	
	NSScreen* winScreen = [[self window] screen];
	NSRect screenFrame = [winScreen frame];
	
	winFrame.origin.x = (screenFrame.size.width - winFrame.size.width)/2 + screenFrame.origin.x;
	winFrame.origin.y = (screenFrame.size.height - winFrame.size.height)/2 + screenFrame.origin.y;
	
	[[self window] setFrame: winFrame
					display: NO];
	
	// This window shouldn't 'float' above the other windows like most panels
	[[self window] setLevel: NSNormalWindowLevel];

    // Don't darken the image when clicked, show the alternate image
    [[imageButton cell] setHighlightsBy: NSContentsCellMask];
}

#pragma mark - Actions

- (void) startedMaintaining: (NSNotification*) not {
	[backgroundProgress startAnimation: self];
}

- (void) finishedMaintaining: (NSNotification*) not {
	[backgroundProgress stopAnimation: self];
}

- (IBAction) clickImage:(id) sender {
    [self hideWebView];
}

-(IBAction)clickedWebLink:(id)sender {
    //NSLog(@"Found tag %d", [sender tag]);
    NSArray* linkArray = @[@"http://www.inform7.com",
                           @"http://ifdb.tads.org/search?sortby=ratu&newSortBy.x=0&newSortBy.y=0&searchfor=system%3AInform+7",
                           @"http://www.intfiction.org/forum",
                           @"https://github.com/ganelson/inform",
                           @"http://ifwiki.org/index.php/Main_Page",
                           @"http://planet-if.com/",
                           @"http://ifcomp.org"];
    NSArray* adviceLinkArray = @[@"inform:/AdviceNewToInform.html",
                                 @"inform:/AdviceUpgrading.html",
                                 @"inform:/AdviceKeyboardShortcuts.html",
                                 @"inform:/AdviceMaterialsFolder.html",
                                 @"inform:/AdviceCredits.html"];

    NSString* urlString = nil;
    NSInteger index = [(NSView *)sender tag];
    if((index >= 0) && ( index < [linkArray count])) {
        urlString = linkArray[index];
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString: urlString]];
    } else {
        index -= [linkArray count];
        // Is it a link for advice?
        if((index >= 0) && ( index < [adviceLinkArray count])) {
            urlString = adviceLinkArray[index];
            [[webView mainFrame] loadRequest: [[NSURLRequest alloc] initWithURL: [NSURL URLWithString:urlString]]];
            [self showWebView];
        }
    }
}

#pragma mark - NSTableViewDataSource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if( tableView == recentDocumentsTableView ) {
        return [recentInfoArray count];
    }
    if( tableView == createDocumentsTableView ) {
        return [createInfoArray count];
    }
    if( tableView == sampleDocumentsTableView ) {
        return [sampleInfoArray count];
    }
    
    return 0;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if( tableView == recentDocumentsTableView ) {
        return recentInfoArray[row];
    }
    if( tableView == createDocumentsTableView ) {
        return createInfoArray[row];
    }
    if( tableView == sampleDocumentsTableView ) {
        return sampleInfoArray[row];
    }
    return nil;
}

- (void)tableView:(NSTableView *)tableView
  willDisplayCell:(id)cell
   forTableColumn:(NSTableColumn *)tableColumn
              row:(NSInteger)row
{
    IFRecentFileCellInfo* info = nil;
    if( tableView == recentDocumentsTableView ) {
        info = recentInfoArray[row];
    } else if( tableView == createDocumentsTableView ) {
        info = createInfoArray[row];
    } else if( tableView == sampleDocumentsTableView ) {
        info = sampleInfoArray[row];
    }
    IFRecentFileCell* cCell = (IFRecentFileCell *) cell;
    cCell.image    = info.image;
    cCell.title    = info.title;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    if( [aNotification object] == recentDocumentsTableView ) {
        NSInteger row = [recentDocumentsTableView selectedRow];

        if( row >= 0 ) {
            [recentDocumentsTableView deselectAll: self];

            IFRecentFileCellInfo* info = recentInfoArray[row];
            if( info.type == IFRecentOpen ) {
                [NSApp sendAction: @selector(openDocument:)
                               to: nil
                             from: self];
            } else if ( info.type == IFRecentFile ) {
                NSDocumentController* docControl = [NSDocumentController sharedDocumentController];
                [docControl openDocumentWithContentsOfURL: info.url
                                                  display: YES
                                        completionHandler: ^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
                    //Do nothing
                }];
            }            
        }
    } else if( [aNotification object] == createDocumentsTableView ) {
        NSInteger row = [createDocumentsTableView selectedRow];
        
        if( row >= 0 ) {
            [createDocumentsTableView deselectAll: self];
            
            IFRecentFileCellInfo* info = createInfoArray[row];
            if( info.type == IFRecentCreateProject ) {
                // Create new project
                [NSApp sendAction: @selector(newProject:)
                               to: nil
                             from: self];
            } else if( info.type == IFRecentCreateExtension ) {
                // Create new extension
                [NSApp sendAction: @selector(newExtension:)
                               to: nil
                             from: self];
                [[self class] hideWelcomeWindow];
            } else if( info.type == IFRecentSaveEPubs ) {
                // Save epubs
                [NSApp sendAction: @selector(exportToEPub:)
                               to: nil
                             from: self];
            }
        }
    } else if( [aNotification object] == sampleDocumentsTableView ) {
        NSInteger row = [sampleDocumentsTableView selectedRow];
        
        if( row >= 0 ) {
            [sampleDocumentsTableView deselectAll: self];
            
            IFRecentFileCellInfo* info = sampleInfoArray[row];
            if( info.type == IFRecentCopySample ) {
                NSURL* source = info.url;

                NSOpenPanel * chooseDirectoryPanel = [NSOpenPanel openPanel];
                [chooseDirectoryPanel setCanChooseFiles:NO];
                [chooseDirectoryPanel setCanChooseDirectories:YES];
                [chooseDirectoryPanel setCanCreateDirectories:YES];
                [chooseDirectoryPanel setAllowsMultipleSelection:NO];
                [chooseDirectoryPanel setTitle: [IFUtility localizedString:@"Choose a directory to save into"]];
                [chooseDirectoryPanel setPrompt: [IFUtility localizedString:@"Choose Directory"]];

                [chooseDirectoryPanel beginSheetModalForWindow: [sharedWindow window]
                                             completionHandler: ^(NSInteger result)
                 {
                     if (result == NSModalResponseOK) {
                         NSURL* destination = [chooseDirectoryPanel URL];

                         // Append last path component of source onto destination
                         destination = [destination URLByAppendingPathComponent: [source lastPathComponent]];
                         [(IFAppDelegate*)[NSApp delegate] doCopyProject: source
                                                                      to: destination];
                     }
                 }];
            } else if( info.type == IFRecentWebsiteLink ) {
                [[NSWorkspace sharedWorkspace] openURL: info.url];
            }
        }
    }
}

#pragma mark - News policy delegate

-                   (void)webView:(WKWebView *)webView
  decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                  decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    if (navigationAction.navigationType == WKNavigationTypeLinkActivated) {
        NSURL* url = [navigationAction.request URL];

        // Open extenal links in separate default browser app
        if (([[url scheme] isEqualTo: @"http"]) || ([[url scheme] isEqualTo: @"https"])) {
            decisionHandler(WKNavigationActionPolicyCancel);
            [[NSWorkspace sharedWorkspace] openURL:url];
            return;
        }
    }

    // default action
    decisionHandler(WKNavigationActionPolicyAllow);
}

@end
