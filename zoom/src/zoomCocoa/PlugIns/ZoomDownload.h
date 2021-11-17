//
//  ZoomDownload.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 30/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol ZoomDownloadDelegate;

///
/// Class that handles the download and unarchiving of files, such as plugin updates
///
@interface ZoomDownload : NSObject {
	/// Where to download from
	NSURL* url;
	/// The download delegate
	__weak id<ZoomDownloadDelegate> delegate;
	/// The expected MD5 for the downloaded file
	NSData* md5;
	
	/// A file handle containing the file that we're downloading
	NSFileHandle* downloadFile;
	/// The file that the download is going to
	NSString* tmpFile;
	/// The directoruy that the download was unarchived to
	NSString* tmpDirectory;
	/// The filename suggested for this download in the response
	NSString* suggestedFilename;
	/// The expected length of the download
	long long expectedLength;
	/// The amount downloaded so far
	long long downloadedSoFar;
	
	/// The main unarchiving task
	NSTask* task;
	/// The set of subtasks that are currently running
	NSMutableArray<NSTask*>* subtasks;
}

// Initialisation
//! Prepares to download the specified URL
- (id) initWithURL: (NSURL*) url;
//! The download delegate
@property (weak) id<ZoomDownloadDelegate> delegate;
//! Removes the temporary directory used for downloads (ie, when terminating)
+ (void) removeTemporaryDirectory;
//! Sets the expected MD5 for the downloaded file
- (void) setExpectedMD5: (NSData*) md5;

@property (copy) NSData *expectedMD5;

// Starting the download
//! Starts the download running
- (void) startDownload;

// Getting the download directory
//! The url for this download
@property (readonly, strong) NSURL *url;
//! The temporary directory where the download was placed (deleted when this object is dealloced)
@property (readonly, copy) NSString *downloadDirectory;
//! The filename suggested for this download in the response
@property (readonly, copy) NSString *suggestedFilename;

@end

/// Delegate methods for the download class
@protocol ZoomDownloadDelegate <NSObject>
@optional

//! A download is starting
- (void) downloadStarting: (ZoomDownload*) download;
//! The download has completed
- (void) downloadComplete: (ZoomDownload*) download;
//! The download failed for some reason
- (void) downloadFailed: (ZoomDownload*) download
				 reason: (NSString*) reason;

//! The download is connecting
- (void) downloadConnecting: (ZoomDownload*) download;
//! The download is reading data
- (void) downloading: (ZoomDownload*) download;
//! Value between 0 and 1 indicating how far the download has progressed
- (void) download: (ZoomDownload*) download
		completed: (float) complete;
//! Indicates that a .zip or .tar file is being decompressed
- (void) downloadUnarchiving: (ZoomDownload*) download;

@end
