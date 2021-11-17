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

NS_ASSUME_NONNULL_BEGIN

@protocol ZoomPlugInManagerDelegate;

// Notifications
/// Notification that the set of plugin information has changed
extern NSNotificationName const ZoomPlugInInformationChangedNotification;

/// Class that manages the plugins installed with Zoom
@interface ZoomPlugInManager : NSObject<ZoomDownloadDelegate, NSURLSessionDataDelegate>

/// The shared plug-in manager
@property (class, readonly, retain) ZoomPlugInManager *sharedPlugInManager;
/// The plug-in installation directory
@property (class, readonly, copy) NSString *plugInsPath;

// Setting the delegate
/// The plug-in delegate
@property (weak, nullable) id<ZoomPlugInManagerDelegate> delegate;

// Dealing with existing plugins
/// Causes this class to load all of the plugins
- (void) loadPlugIns;
/// Gets the plugin for the specified file
- (nullable Class) plugInForFile: (NSString*) fileName DEPRECATED_MSG_ATTRIBUTE("Use -plugInForURL: instead");
/// Gets the plugin for the specified URL
- (nullable Class) plugInForURL: (NSURL*) fileName;
/// Gets a plug-in instance for the specified file
- (nullable __kindof ZoomPlugIn*) instanceForFile: (NSString*) filename DEPRECATED_MSG_ATTRIBUTE("Use -instanceForURL: instead");
/// Gets a plug-in instance for the specified URL
- (nullable __kindof ZoomPlugIn*) instanceForURL: (NSURL*) filename;

//// The loaded plugin bundles
- (NSArray<NSBundle*>*) pluginBundles;
/// Array of strings indicating the names of the loaded plugins
- (NSArray<NSString*>*) loadedPlugIns;
/// Returns the version of the plugin with the specified name
- (NSString*) versionForPlugIn: (NSString*) plugin;
/// Compares version numbers
- (BOOL) version: (NSString*) oldVersion
	 isNewerThan: (NSString*) newVerison;

// Installing new plugins
//// Indicates that this object has been finished with and any files should be deleted
- (void) finishedWithObject;

/// Request that all known updates and new plugins be downloaded
- (void) downloadUpdates;
/// Requests that the specified plugin be installed
- (BOOL) installPlugIn: (NSString*) pluginBundle;
/// Causes Zoom to finish updating any plugins after a restart
- (void) finishUpdatingPlugins;
/// \c YES if a restart is required
@property (readonly) BOOL restartRequired;

/// Retrieves the plist dictionary for the specified plugin bundle
- (nullable NSDictionary<NSString*,id>*) plistForBundleAtPath: (NSString*) pluginBundle;
/// Retrieves the display name of the specified plugin bundle
- (nullable NSString*) nameForBundle: (NSString*) pluginBundle;
/// Retrieves the author of the specified plugin
- (nullable NSString*) authorForBundle: (NSString*) pluginBundle;
/// Retrieves the author of the interpreter of the specified plugin
- (nullable NSString*) terpAuthorForBundle: (NSString*) pluginBundle;
/// Retrieves the version number of the specified plugin bundle
- (nullable NSString*) versionForBundle: (NSString*) pluginBundle;

// Getting information about plugins
/// Array of \c ZoomPlugInInfo objects containing the information about all the plugins known about by this object
- (NSArray<ZoomPlugInInfo*>*) informationForPlugins;
/// Performs a check for updates operation on the specified URLs
- (void) checkForUpdatesFromURLs: (NSArray<NSURL*>*) urls;
/// Performs a general check for updates operation
- (void) checkForUpdates;

- (NSArray<NSString*>*)pluginSupportedFileTypes;

@end

//!
//! Delegate methods
//!
@protocol ZoomPlugInManagerDelegate <NSObject>
@optional

//! Indicates that the plugin information has changed
- (void) pluginInformationChanged;
//! Indicates that the plug-in manager needs a restart before it can continue
- (void) needsRestart;

//! Indicates that a check for updates has started
- (void) checkingForUpdates;
//! Indicates that the check for updates has finished
- (void) finishedCheckingForUpdates;

//! Indicates that the manager is downloading updates
- (void) downloadingUpdates;
//! Indicates that a download status message should be displayed
- (void) downloadProgress: (NSString*) status
			   percentage: (CGFloat) percent;
//! Indicates that downloading has finished
- (void) finishedDownloadingUpdates;

@end

NS_ASSUME_NONNULL_END
