//
//  ZoomDownload.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 30/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>


///
/// Class that handles the download and unarchiving of files, such as plugin updates
///
@interface ZoomDownload : NSObject {
	NSURL* url;													// Where to download from
	id delegate;												// The download delegate
	NSData* md5;												// The expected MD5 for the downloaded file
	
	NSURLConnection* connection;								// The connection that the download will be loaded via
	NSFileHandle* downloadFile;									// A file handle containing the file that we're downloading
	NSString* tmpFile;											// The file that the download is going to
	NSString* tmpDirectory;										// The directoruy that the download was unarchived to
	NSString* suggestedFilename;								// The filename suggested for this download in the response
	long long expectedLength;									// The expected length of the download
	long long downloadedSoFar;									// The amount downloaded so far
	
	NSTask* task;												// The main unarchiving task
	NSMutableArray* subtasks;									// The set of subtasks that are currently running
}

// Initialisation
- (id) initWithUrl: (NSURL*) url;								// Prepares to download the specified URL
- (void) setDelegate: (id) delegate;							// Sets the delegate for this class
+ (void) removeTemporaryDirectory;								// Removes the temporary directory used for downloads (ie, when terminating)
- (void) setExpectedMD5: (NSData*) md5;							// Sets the expected MD5 for the downloaded file

// Starting the download
- (void) startDownload;											// Starts the download running

// Getting the download directory
- (NSURL*) url;													// The url for this download
- (NSString*) downloadDirectory;								// The temporary directory where the download was placed (deleted when this object is dealloced)
- (NSString*) suggestedFilename;								// The filename suggested for this download in the response

@end

///
/// Delegate methods for the download class
///
@interface NSObject(ZoomDownloadDelegate)

- (void) downloadStarting: (ZoomDownload*) download;			// A download is starting
- (void) downloadComplete: (ZoomDownload*) download;			// The download has completed
- (void) downloadFailed: (ZoomDownload*) download				// The download failed for some reason
				 reason: (NSString*) reason;

- (void) downloadConnecting: (ZoomDownload*) download;			// The download is connecting
- (void) downloading: (ZoomDownload*) download;					// The download is reading data
- (void) download: (ZoomDownload*) download						// Value between 0 and 1 indicating how far the download has progressed
		completed: (float) complete;
- (void) downloadUnarchiving: (ZoomDownload*) download;			// Indicates that a .zip or .tar file is being decompressed

@end
