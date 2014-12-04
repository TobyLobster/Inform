//
//  ZoomPlugInInfo.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 29/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ZoomPlugIns/ZoomDownload.h>

typedef enum ZoomPlugInStatus {
	ZoomPlugInInstalled,									// Installed plugin
	ZoomPlugInDisabled,										// Installed plugin that has been disabled
	ZoomPlugInUpdated,										// Installed plugin, update to be installed
	ZoomPlugInDownloaded,									// Downloaded plugin available to install
	ZoomPluginUpdateAvailable,								// Update available to download
	ZoomPlugInNew,											// Not yet installed, available to download
	ZoomPlugInDownloadFailed,								// Marked as having an update, but it failed to download
	ZoomPlugInInstallFailed,								// Downloaded, but the installation failed for some reason
	ZoomPlugInDownloading,									// Currently downloading
	ZoomPlugInNotKnown,										// Unknown status
} ZoomPlugInStatus;

///
/// Class representing information about a known plugin
///
@interface ZoomPlugInInfo : NSObject<NSCopying> {
	NSString* image;										// The filename of an image for this plugin
	NSString* name;											// The name of the plugin
	NSString* author;										// The author of the plugin
	NSString* interpreterAuthor;							// The author of the interpreter
	NSString* version;										// The version number of the plugin
	NSString* interpreterVersion;							// The version number of the interpreter contained in the plugin
	NSURL* location;										// The location of this plugin
	NSData* md5;											// The MD5 for the plugin archive
	NSURL* updateUrl;										// The URL that should be consulted for updates to this plugin
	ZoomPlugInStatus status;								// The status for this plugin
	
	ZoomPlugInInfo* updated;								// The updated information for this plugin, if check for updates has found one
	ZoomDownload* updateDownload;							// The active download for the update
}

// Initialisation
- (id) initWithBundleFilename: (NSString*) bundle;			// Initialise with an existing plugin bundle
- (id) initFromPList: (NSDictionary*) plist;				// Initialise with the contents of a particular plist dictionary

// Retrieving the information
- (NSString*) name;											// The name of this plugin
- (NSString*) author;										// The author of the plugin bundle
- (NSString*) version;										// The version of the plugin bundle
- (NSString*) interpreterAuthor;							// The author of the interpreter in the plugin
- (NSString*) interpreterVersion;							// The version of the interpreter in the plugin
- (NSString*) imagePath;									// The path to an image that represents this plugin
- (NSURL*) location;										// Where this plugin is located
- (NSURL*) updateUrl;										// The URL for updates to this plugin
- (ZoomPlugInStatus) status;								// The status for this plugin
- (NSData*) md5;											// The MD5 for the archive containing the plugin
- (void) setStatus: (ZoomPlugInStatus) status;				// Updates the status for this plugin

- (ZoomPlugInInfo*) updateInfo;								// The plugin info for any known updates to this plugin
- (void) setUpdateInfo: (ZoomPlugInInfo*) info;				// Sets the update plugin info

- (ZoomDownload*) download;									// The download for the update for this plugin
- (void) setDownload: (ZoomDownload*) download;

@end
