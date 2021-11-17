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
#import "IFImageCache.h"
#import "IFUtility.h"
#import "IFExtensionsManager.h"
#import "IFPreferences.h"

@implementation IFWelcomeWindow {
    IBOutlet NSProgressIndicator*   backgroundProgress;         // Progress indicator that shows when a background process is running
    IBOutlet NSScrollView*          recentDocumentsScrollView;  // Recent document scroll view
    IBOutlet NSTableView*           recentDocumentsTableView;   // Recent document Table View
    IBOutlet NSScrollView*          createDocumentsScrollView;  // Create document scroll view
    IBOutlet NSTableView*           createDocumentsTableView;   // Create document Table View
    IBOutlet NSScrollView*          sampleDocumentsScrollView;  // Sample document scroll view
    IBOutlet NSTableView*           sampleDocumentsTableView;   // Sample document Table View
    IBOutlet NSView*                parentView;                 // Parent
    IBOutlet WebView*               webView;                    // Show a web page (for advice)
    IBOutlet NSView*                middleView;                 // Show the middle section
    IBOutlet NSButton*              imageButton;                // Top banner image, as a button

    NSMutableArray*                 recentInfoArray;            // Array of recent file info
    NSMutableArray*                 createInfoArray;            // Array of create file info
    NSMutableArray*                 sampleInfoArray;            // Array of sample file info
}

static const int maxItemsInRecentMenu = 8;

// Shared welcome window
static IFWelcomeWindow* sharedWindow = nil;

// = Initialisation =

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
    // Get latest list of recent items
    IFWelcomeWindow * welcome = [IFWelcomeWindow sharedWelcomeWindow];
    [welcome refreshRecentItems];

    // Hide web view
    [welcome hideWebView];

    // Show window
    [welcome showWindow: self];
    [[welcome window] orderFront: self];
}

- (void) hideWebView {
    [webView setHidden: YES];
    [middleView setHidden: NO];
}

- (void) showWebView {
    [webView setHidden: NO];
    [middleView setHidden: YES];
}

- (void) refreshRecentItems {
    NSImage* icon;
    recentInfoArray = [[NSMutableArray alloc] init];
    
    int index = 0;
    for( NSURL* url in [[NSDocumentController sharedDocumentController] recentDocumentURLs] ) {
        icon = [[NSWorkspace sharedWorkspace] iconForFile: [url path]];
        
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
        info = [[IFRecentFileCellInfo alloc] initWithTitle: [IFUtility localizedString: @"Save Documentation for iBooks"]
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

// = Actions =

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
                           @"http://www.intfiction.org/forum/viewforum.php?f=7",
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

// == NSTableViewDataSource methods ==

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
                NSError* error = nil;
                [docControl openDocumentWithContentsOfURL: info.url
                                                  display: YES
                                                    error: &error];
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
                     if (result == NSOKButton) {
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

@end
