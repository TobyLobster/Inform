//
//  ZoomPlugInInfo.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 29/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ZoomPlugIns/ZoomDownload.h>

typedef NS_ENUM(int, ZoomPlugInStatus) {
	/// Installed plugin
	ZoomPlugInInstalled,
	/// Installed plugin that has been disabled
	ZoomPlugInDisabled,
	/// Installed plugin, update to be installed
	ZoomPlugInUpdated,
	/// Downloaded plugin available to install
	ZoomPlugInDownloaded,
	/// Update available to download
	ZoomPluginUpdateAvailable,
	/// Not yet installed, available to download
	ZoomPlugInNew,
	/// Marked as having an update, but it failed to download
	ZoomPlugInDownloadFailed,
	/// Downloaded, but the installation failed for some reason
	ZoomPlugInInstallFailed,
	/// Currently downloading
	ZoomPlugInDownloading,
	/// Unknown status
	ZoomPlugInNotKnown,
};

///
/// Class representing information about a known plugin
///
@interface ZoomPlugInInfo : NSObject<NSCopying>

// Initialisation
/// Initialise with an existing plugin bundle
- (instancetype) initWithBundleFilename: (NSString*) bundle;
/// Initialise with the contents of a particular plist dictionary
- (instancetype) initFromPList: (NSDictionary<NSString*, id>*) plist;

// Retrieving the information
/// The name of this plugin
@property (readonly, copy) NSString *name;
/// The author of the plugin bundle
@property (readonly, copy) NSString *author;
/// The version of the plugin bundle
@property (readonly, copy) NSString *version;
/// The author of the interpreter in the plugin
@property (readonly, copy) NSString *interpreterAuthor;
/// The version of the interpreter in the plugin
@property (readonly, copy) NSString *interpreterVersion;
/// The image that represents this plugin
@property (readonly, copy) NSImage *image;
/// Where this plugin is located
@property (readonly, strong) NSURL *location;
/// The URL for updates to this plugin
@property (readonly, strong) NSURL *updateUrl;
/// The status for this plugin
@property ZoomPlugInStatus status;
/// The MD5 for the archive containing the plugin
@property (readonly, copy) NSData *md5;
/// Updates the status for this plugin
- (void) setStatus: (ZoomPlugInStatus) status;

/// The plugin info for any known updates to this plugin
@property (strong) ZoomPlugInInfo *updateInfo;

/// The download for the update for this plugin
@property (strong) ZoomDownload *download;

@end
