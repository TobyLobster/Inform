//
//  ZoomiFictionController.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jan 22 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#import <ZoomPlugIns/ZoomStory.h>
@class CollapsableView;
@class SavePreviewView;
@class FadeView;
#import "ZoomCollapsingSplitView.h"
#import <ZoomPlugIns/ZoomResourceDrop.h>
#import "ZoomStoryTableView.h"
#import <ZoomPlugIns/ZoomMetadata.h>
#import "ZoomFlipView.h"
@class DownloadView;
#import <ZoomPlugIns/ZoomDownload.h>
#import "ZoomJSError.h"

@interface ZoomiFictionController : NSWindowController <NSTextStorageDelegate, ZoomDownloadDelegate, NSTableViewDataSource, NSOpenSavePanelDelegate, NSControlTextEditingDelegate, NSMenuItemValidation, NSTabViewDelegate>

@property (class, readonly, strong) ZoomiFictionController *sharediFictionController NS_SWIFT_NAME(shared);

@property (weak) IBOutlet WKWebView* ifdbView;
@property (weak) IBOutlet NSTextField* currentUrl;
@property (weak) IBOutlet NSProgressIndicator* progressIndicator;

/// The currently active download
@property (strong) ZoomDownload* activeDownload;

/// Story to open after the download has completed
@property (strong) ZoomStoryID* signpostID;

/// The last error to occur
@property (strong) ZoomJSError* lastError;

/// \c YES if we're trying to download an update list
@property BOOL downloadUpdateList;
/// \c YES if we're trying to download a .zoomplugin file
@property BOOL downloadPlugin;

- (IBAction) addButtonPressed: (id) sender;
- (IBAction) startNewGame: (id) sender;
- (IBAction) restoreAutosave: (id) sender;
- (IBAction) searchFieldChanged: (id) sender;
- (IBAction) changeFilter1: (id) sender;
- (IBAction) changeFilter2: (id) sender;
- (IBAction) delete: (id) sender;
- (IBAction) deleteSavegame: (id) sender;

- (IBAction) flipToFilter: (id) sender;
- (IBAction) flipToInfo: (id) sender;
- (IBAction) flipToSaves: (id) sender;

- (IBAction) showIfDb: (id) sender;
- (IBAction) showLocalGames: (id) sender;
- (IBAction) goBack: (id) sender;
- (IBAction) goForward: (id) sender;
- (IBAction) goHome: (id) sender;
- (IBAction) playIfdbGame: (id) sender;

- (ZoomStory*) storyForID: (ZoomStoryID*) ident;
- (void) configureFromMainTableSelection;
- (void) reloadTableData;

- (void) mergeiFictionFromFile: (NSString*) filename;
- (BOOL) mergeiFictionFromURL: (NSURL*) filename error: (NSError**) outError;
- (NSArray<ZoomStory*>*) mergeiFictionFromMetabase: (ZoomMetadata*) newData;

- (void) addFiles: (NSArray<NSString*> *)filenames DEPRECATED_MSG_ATTRIBUTE("use -addURLs: instead");
- (void) addURLs: (NSArray<NSURL*> *)filenames;

- (void) setupSplitView;
- (void) collapseSplitView;

- (void) openSignPost: (NSData*) signpostFile
		forceDownload: (BOOL) download;

#pragma mark - WebKit helper functions

- (BOOL) canPlayFileAtURL: (NSURL*) filename;
- (void) updateBackForwardButtons;
- (void) hideDownloadWindow: (NSTimeInterval) duration;

@end
