//
//  ZoomPlugInManager.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 15/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ZoomPlugIns/ZoomPlugIn.h>
#import <ZoomPlugIns/ZoomPlugInInfo.h>

// Notifications
extern NSString* ZoomPlugInInformationChangedNotification;	// Notification that the set of plugin information has changed

//
// Class that manages the plugins installed with Zoom
//
@interface ZoomPlugInManager : NSObject {
	NSLock* pluginLock;										// The plugin lock
	id delegate;											// The delegate for this class
	
	NSMutableArray* pluginBundles;							// The bundles containing the loaded plugins
	NSMutableArray* pluginClasses;							// The ZoomPlugIn classes from the bundles
	NSMutableDictionary* pluginsToVersions;					// Array mapping plugin versions to names
	
	NSMutableArray* pluginInformation;						// Information about all plugins known about by this object (including those that live elsewhere)
	
	NSString* lastPlistPlugin;								// The path of the last plugin we retrieved a plist for
	NSDictionary* lastPlist;								// The plist retrieved from the lastPlistPlugin
	
	NSMutableArray* checkUrls;								// Check for updates URLs that are still waiting to be processed
	NSURLRequest* lastRequest;								// The last check for updates request that was sent
	NSURLConnection* checkConnection;						// The connection for the last request
	NSURLResponse* checkResponse;							// The response to the last check for updates request
	NSMutableData* checkData;								// The data returned for the last check for updates request
	
	BOOL restartRequired;									// Set to YES if a restart is required
	BOOL downloading;										// YES if we're downloading updates
	ZoomPlugInInfo* downloadInfo;							// The plug in that we're performing a download for
	ZoomDownload* currentDownload;							// The active download for this object
}

+ (ZoomPlugInManager*) sharedPlugInManager;					// The shared plug-in manager
+ (NSString*) plugInsPath;									// The plug-in installation directory

// Setting the delegate
- (void) setDelegate: (id) delegate;						// Sets a new plug-in delegate

// Dealing with existing plugins
- (void) loadPlugIns;										// Causes this class to load all of the plugins
- (Class) plugInForFile: (NSString*) fileName;				// Gets the plugin for the specified file
- (ZoomPlugIn*) instanceForFile: (NSString*) filename;		// Gets a plug-in instance for the specified file

- (NSArray*) pluginBundles;									// The loaded plugin bundles
- (NSArray*) loadedPlugIns;									// Array of strings indicating the names of the loaded plugins
- (NSString*) versionForPlugIn: (NSString*) plugin;			// Returns the version of the plugin with the specified name
- (BOOL) version: (NSString*) oldVersion					// Compares 
	 isNewerThan: (NSString*) newVerison;

// Installing new plugins
- (void) finishedWithObject;								// Indicates that this object has been finished with and any files should be deleted

- (void) downloadUpdates;									// Request that all known updates and new plugins be downloaded
- (BOOL) installPlugIn: (NSString*) pluginBundle;			// Requests that the specified plugin be installed
- (void) finishUpdatingPlugins;								// Causes Zoom to finish updating any plugins after a restart
- (BOOL) restartRequired;									// YES if a restart is required

- (NSDictionary*) plistForBundle: (NSString*) pluginBundle;	// Retrieves the plist dictionary for the specified plugin bundle
- (NSString*) nameForBundle: (NSString*) pluginBundle;		// Retrieves the display name of the specified plugin bundle
- (NSString*) authorForBundle: (NSString*) pluginBundle;	// Retrieves the author of the specified plugin
- (NSString*) terpAuthorForBundle: (NSString*) pluginBundle;	// Retrieves the author of the interpreter of the specified plugin
- (NSString*) versionForBundle: (NSString*) pluginBundle;	// Retrieves the version number of the specified plugin bundle

// Getting information about plugins
- (NSArray*) informationForPlugins;							// Array of ZoomPlugInInfo objects containing the information about all the plugins known about by this object
- (void) checkForUpdatesFrom: (NSArray*) urls;				// Performs a check for updates operation on the specified URLs
- (void) checkForUpdates;									// Performs a general check for updates operation

@end

//
// Delegate methods
//
@interface NSObject(ZoomPlugInManagerDelegate)

- (void) pluginInformationChanged;							// Indicates that the plugin information has changed
- (void) needsRestart;										// Indicates that the plug-in manager needs a restart before it can continue

- (void) checkingForUpdates;								// Indicates that a check for updates has started
- (void) finishedCheckingForUpdates;						// Indicates that the check for updates has finished

- (void) downloadingUpdates;								// Indicates that the manager is downloading updates
- (void) downloadProgress: (NSString*) status				// Indicates that a download status message should be displayed
			   percentage: (float) percent;
- (void) finishedDownloadingUpdates;						// Indicates that downloading has finished

@end