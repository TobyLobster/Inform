//
//  IFWelcomeWindow.m
//  Inform
//
//  Created by Andrew Hunter on 05/10/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//  Rewritten by Toby Nelson, 2014.
//

#import "IFWelcomeWindow.h"
#import "IFAppDelegate.h"
#import "IFRecentFileCellInfo.h"
#import "IFRecentFileCell.h"

#import "IFMaintenanceTask.h"
#import "IFImageCache.h"
#import "IFUtility.h"
#import "IFExtensionsManager.h"
#import "IFPreferences.h"

@implementation IFWelcomeWindow

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
    [recentInfoArray release];
    recentInfoArray = [[NSMutableArray alloc] init];
    
    int index = 0;
    for( NSURL* url in [[NSDocumentController sharedDocumentController] recentDocumentURLs] ) {
        icon = [[NSWorkspace sharedWorkspace] iconForFile: [url path]];
        
        IFRecentFileCellInfo* info = [[[IFRecentFileCellInfo alloc] initWithTitle: [url lastPathComponent]
                                                                            image: icon
                                                                              url: url
                                                                             type: IFRecentFile] autorelease];
        [recentInfoArray addObject: info];
        index++;
        
        if( index >= maxItemsInRecentMenu ) {
            break;
        }
    }
    
    // Item for "Open..."
    icon = [NSImage imageNamed: NSImageNameFolder];
    IFRecentFileCellInfo* info = [[[IFRecentFileCellInfo alloc] initWithTitle: [IFUtility localizedString: @"Open..."]
                                                                        image: icon
                                                                          url: nil
                                                                         type: IFRecentOpen] autorelease];
    [recentInfoArray addObject: info];
    [recentDocumentsTableView reloadData];
}

- (id) initWithWindowNibName: (NSString*) nib {
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
        
        NSImage* icon = [IFImageCache loadResourceImage: @"informfile.icns"];
        IFRecentFileCellInfo* info = [[[IFRecentFileCellInfo alloc] initWithTitle: [IFUtility localizedString: @"Create Project..."]
                                                                            image: icon
                                                                              url: nil
                                                                             type: IFRecentCreateProject] autorelease];
        [createInfoArray addObject: info];

        icon = [IFImageCache loadResourceImage: @"i7xfile.icns"];
        info = [[[IFRecentFileCellInfo alloc] initWithTitle: [IFUtility localizedString: @"Create Extension..."]
                                                      image: icon
                                                        url: nil
                                                       type: IFRecentCreateExtension] autorelease];
        [createInfoArray addObject: info];
        
        icon = [NSImage imageNamed: NSImageNameFolder];
        info = [[[IFRecentFileCellInfo alloc] initWithTitle: [IFUtility localizedString: @"Save Documentation for iBooks"]
                                                      image: icon
                                                        url: nil
                                                       type: IFRecentSaveEPubs] autorelease];
        [createInfoArray addObject: info];

        // --- Items that copy sample documents ---
        NSArray* sampleArray = @[@"Copy Onyx",                  @"Onyx.inform",
                                 @"Copy Disenchantment Bay",    @"Disenchantment Bay.inform"];

        sampleInfoArray = [[NSMutableArray alloc] init];
        icon = [IFImageCache loadResourceImage: @"informfile.icns"];

        NSString* pathStart = [[NSBundle mainBundle] resourcePath];
        pathStart = [pathStart stringByAppendingPathComponent: @"App"];
        pathStart = [pathStart stringByAppendingPathComponent: @"Samples"];

        for( int index = 0; index < [sampleArray count]; index += 2 ) {
            NSString* path = [pathStart stringByAppendingPathComponent: [sampleArray objectAtIndex: index + 1]];
            info = [[[IFRecentFileCellInfo alloc] initWithTitle: [IFUtility localizedString: [sampleArray objectAtIndex: index]]
                                                          image: icon
                                                            url: [NSURL fileURLWithPath: path
                                                                            isDirectory: YES]
                                                           type: IFRecentCopySample] autorelease];
            [sampleInfoArray addObject: info];
        }

        // Link to IFDB
        icon = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericDocumentIcon)];
        info = [[[IFRecentFileCellInfo alloc] initWithTitle: [IFUtility localizedString: @"Link to IFDB"]
                                                      image: icon
                                                        url: [NSURL URLWithString:@"http://ifdb.tads.org/search?sortby=new&newSortBy.x=0&newSortBy.y=0&searchfor=tag%3A+i7+source+available"]
                                                       type: IFRecentWebsiteLink] autorelease];
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
    int index = [sender tag];
    if((index >= 0) && ( index < [linkArray count])) {
        urlString = [linkArray objectAtIndex: index];
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString: urlString]];
    } else {
        index -= [linkArray count];
        // Is it a link for advice?
        if((index >= 0) && ( index < [adviceLinkArray count])) {
            urlString = [adviceLinkArray objectAtIndex: index];
            [[webView mainFrame] loadRequest: [[[NSURLRequest alloc] initWithURL: [NSURL URLWithString:urlString]] autorelease]];
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
        return [recentInfoArray objectAtIndex: row];
    }
    if( tableView == createDocumentsTableView ) {
        return [createInfoArray objectAtIndex: row];
    }
    if( tableView == sampleDocumentsTableView ) {
        return [sampleInfoArray objectAtIndex: row];
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
        info = [recentInfoArray objectAtIndex:row];
    } else if( tableView == createDocumentsTableView ) {
        info = [createInfoArray objectAtIndex:row];
    } else if( tableView == sampleDocumentsTableView ) {
        info = [sampleInfoArray objectAtIndex:row];
    }
    IFRecentFileCell* cCell = (IFRecentFileCell *) cell;
    cCell.image    = info.image;
    cCell.title    = info.title;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    if( [aNotification object] == recentDocumentsTableView ) {
        int row = [recentDocumentsTableView selectedRow];

        if( row >= 0 ) {
            [recentDocumentsTableView deselectAll: self];

            IFRecentFileCellInfo* info = [recentInfoArray objectAtIndex: row];
            if( info.type == IFRecentOpen ) {
                [NSApp sendAction: @selector(openDocument:)
                               to: nil
                             from: self];
            } else if ( info.type == IFRecentFile ) {
                NSDocumentController* docControl = [NSDocumentController sharedDocumentController];
                
                [docControl openDocumentWithContentsOfURL: info.url
                                                  display: YES
                                        completionHandler: ^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error)
                 {
                     // TODO: Anything needed here?
                 }];
            }            
        }
    } else if( [aNotification object] == createDocumentsTableView ) {
        int row = [createDocumentsTableView selectedRow];
        
        if( row >= 0 ) {
            [createDocumentsTableView deselectAll: self];
            
            IFRecentFileCellInfo* info = [createInfoArray objectAtIndex: row];
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
        int row = [sampleDocumentsTableView selectedRow];
        
        if( row >= 0 ) {
            [sampleDocumentsTableView deselectAll: self];
            
            IFRecentFileCellInfo* info = [sampleInfoArray objectAtIndex: row];
            if( info.type == IFRecentCopySample ) {
                NSURL* source = info.url;

                NSOpenPanel * chooseDirectoryPanel = [NSOpenPanel openPanel];
                [chooseDirectoryPanel setCanChooseFiles:NO];
                [chooseDirectoryPanel setCanChooseDirectories:YES];
                [chooseDirectoryPanel setCanCreateDirectories:YES];
                [chooseDirectoryPanel setAllowsMultipleSelection:NO];
                [chooseDirectoryPanel setTitle: [IFUtility localizedString:@"Choose a directory to save into"]];
                [chooseDirectoryPanel setPrompt: [IFUtility localizedString:@"Choose Directory"]];

                [chooseDirectoryPanel beginSheetModalForWindow: nil
                                             completionHandler: ^(NSInteger result)
                 {
                     if (result == NSOKButton) {
                         NSURL* destination = [chooseDirectoryPanel URL];

                         // Append last path component of source onto destination
                         destination = [destination URLByAppendingPathComponent: [source lastPathComponent] isDirectory: YES];
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
