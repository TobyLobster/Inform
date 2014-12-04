//
//  ZoomiFictionController.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jan 22 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#import "ZoomiFButton.h"
#import "ZoomStory.h"
#import "ZoomCollapsableView.h"
#import "ZoomSavePreviewView.h"
#import "ZoomCollapsingSplitView.h"
#import "ZoomResourceDrop.h"
#import "ZoomStoryTableView.h"
#import "ZoomMetadata.h"
#import "ZoomFlipView.h"
#import "ZoomDownloadView.h"
#import "ZoomDownload.h"
#import "ZoomJSError.h"
#import "ZoomSignPost.h"

@interface ZoomiFictionController : NSWindowController {
	IBOutlet ZoomiFButton* addButton;
	IBOutlet ZoomiFButton* newgameButton;
	IBOutlet ZoomiFButton* continueButton;	
	// IBOutlet ZoomiFButton* drawerButton;
	IBOutlet ZoomiFButton* infoButton;
	
	//IBOutlet ZoomCollapsableView* collapseView;
	
	IBOutlet ZoomFlipView* flipView;
	IBOutlet NSView* topPanelView;
	IBOutlet NSView* filterView;
	IBOutlet NSView* infoView;
	IBOutlet NSView* saveGameView;
	IBOutlet NSMatrix* flipButtonMatrix;
	
	IBOutlet NSView* mainView;
	IBOutlet NSView* browserView;
	
	IBOutlet WebView* ifdbView;
	IBOutlet NSTextField* currentUrl;
	IBOutlet NSButton* playButton;
	IBOutlet NSButton* forwardButton;
	IBOutlet NSButton* backButton;
	IBOutlet NSButton* homeButton;
	NSWindow* downloadWindow;
	ZoomDownloadView* downloadView;
	
	IBOutlet NSWindow* picturePreview;
	IBOutlet NSImageView* picturePreviewView;
	
	IBOutlet NSProgressIndicator* progressIndicator;
	int indicatorCount;
	
	IBOutlet NSTextView* gameDetailView;
	IBOutlet NSImageView* gameImageView;
	
	IBOutlet ZoomCollapsingSplitView* splitView;
	
	float splitViewPercentage;
	BOOL splitViewCollapsed;
	
	IBOutlet ZoomStoryTableView* mainTableView;
	IBOutlet NSTableView* filterTable1;
	IBOutlet NSTableView* filterTable2;
	
	IBOutlet NSTextField* searchField;
	
	IBOutlet NSMenu* storyMenu;
	IBOutlet NSMenu* saveMenu;
	
	BOOL showDrawer;
	
	BOOL needsUpdating;
	
	BOOL queuedUpdate;
	BOOL isFiltered;
	BOOL saveGamesAvailable;
	
	// Save game previews
	IBOutlet ZoomSavePreviewView* previewView;
	
	// Resource drop zone
	ZoomResourceDrop* resourceDrop;
	
	// Data source information
	NSMutableArray* filterSet1;
	NSMutableArray* filterSet2;
	
	NSMutableArray* storyList;
	NSString*       sortColumn;
	
	// The browser
	BOOL usedBrowser;							// YES if the browser has been used
	BOOL browserOn;								// YES if the browser is being displayed
	BOOL smallBrowser;							// YES if we've turned on small fonts in the browser
	
	ZoomDownload* activeDownload;				// The currently active download
	NSTimer* downloadFadeTimer;					// The fade in/out timer for the download window
	NSDate* downloadFadeStart;					// The time the current fade operation started
	double initialDownloadOpacity;				// The opacity when the last fade operation started
	
	ZoomStoryID* signpostId;					// Story to open after the download has completed
	NSString* installPlugin;					// The name of the plugin to install
	ZoomSignPost* activeSignpost;				// The active signpost file
	BOOL downloadUpdateList;					// YES if we're trying to download an update list
	BOOL downloadPlugin;						// YES if we're trying to download a .zoomplugin file
	
	ZoomJSError* lastError;						// The last error to occur
}

+ (ZoomiFictionController*) sharediFictionController;

- (IBAction) addButtonPressed: (id) sender;
- (IBAction) startNewGame: (id) sender;
- (IBAction) restoreAutosave: (id) sender;
- (IBAction) searchFieldChanged: (id) sender;
- (IBAction) changeFilter1: (id) sender;
- (IBAction) changeFilter2: (id) sender;
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
- (NSArray*) mergeiFictionFromMetabase: (ZoomMetadata*) newData;

- (void) addFiles: (NSArray *)filenames;

- (void) setupSplitView;
- (void) collapseSplitView;

- (void) openSignPost: (NSData*) signpostFile
		forceDownload: (BOOL) download;

@end
