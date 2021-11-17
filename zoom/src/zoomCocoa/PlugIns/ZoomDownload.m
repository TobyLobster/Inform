//
//  ZoomDownload.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 30/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "ZoomDownload.h"

#include <CommonCrypto/CommonDigest.h>

@interface ZoomDownload () <NSURLSessionDataDelegate, NSURLSessionDelegate>

@end

@implementation ZoomDownload {
	NSURLSession *session;
	/// The connection that the download will be loaded via
	NSURLSessionDataTask *dataTask;
}

#pragma mark - Initialisation

static NSString* downloadDirectory;
static int lastDownloadId = 0;

+ (void) initialize {
	// Pick a directory to store downloads in
	NSString* tempDir = NSTemporaryDirectory();
	if (tempDir == nil || [@"" isEqualToString: tempDir] || [@"/" isEqualToString: tempDir] || [tempDir characterAtIndex: 0] != '/') return;
	
	int pid = (int)getpid();
	
	downloadDirectory = [tempDir stringByAppendingPathComponent: [NSString stringWithFormat: @"Zoom-Downloads-%i", pid]];
}

+ (void) removeTemporaryDirectory {
	BOOL exists;
	BOOL isDir;
	
	if (downloadDirectory == nil) return;
	
	exists = [[NSFileManager defaultManager] fileExistsAtPath: downloadDirectory
												  isDirectory: &isDir];
	if (exists) {
		NSLog(@"Removing %@", downloadDirectory);
		[[NSFileManager defaultManager] removeItemAtPath: downloadDirectory
												   error: NULL];
	}
}

- (id) initWithURL: (NSURL*) newUrl {
	self = [super init];
	
	if (self) {
		if (newUrl == nil) {
			return nil;
		}
		
		url = [newUrl copy];
		NSURLSessionConfiguration *config = [NSURLSessionConfiguration.ephemeralSessionConfiguration copy];
		config.networkServiceType = NSURLNetworkServiceTypeBackground;
		session = [NSURLSession sessionWithConfiguration: config
												delegate: self
										   delegateQueue: nil];
	}
	
	return self;
}

- (void) dealloc {
	// Finished with notifications
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	// Delete the temporary file
	if ([[NSFileManager defaultManager] fileExistsAtPath: tmpFile]) {
		NSLog(@"Removing: %@", tmpFile);
		[[NSFileManager defaultManager] removeItemAtPath: tmpFile
												   error: NULL];
	}
	
	// Delete the temporary directory
	BOOL isDir=NO;
	if (tmpDirectory 
		&& [[NSFileManager defaultManager] fileExistsAtPath: tmpDirectory
												isDirectory: &isDir]) {
		if (isDir) {
			NSLog(@"Removing: %@", tmpDirectory);
			[[NSFileManager defaultManager] removeItemAtPath: tmpDirectory
													   error: NULL];
		}
	}
	
	// Kill any tasks
	if (task && [task isRunning]) {
		[task interrupt];
		[task terminate];
	}
	if (subtasks) {
		for (NSTask* sub in subtasks) {
			if ([sub isRunning]) {
				[sub interrupt];
				[sub terminate];
			}
		}
	}
}

@synthesize delegate;
@synthesize expectedMD5=md5;

#pragma mark - Starting the download

- (void) startDownload {
	// Do nothing if this download is already running
	if (dataTask != nil) return;
	
	// Let the delegate know
	if (delegate && [delegate respondsToSelector: @selector(downloadStarting:)]) {
		[delegate downloadStarting: self];
	}
	
	NSLog(@"Downloading: %@", url);
	
	// Create a connection to download the specified URL
	NSURLRequest* request = [NSURLRequest requestWithURL: url
											 cachePolicy: NSURLRequestReloadIgnoringCacheData
										 timeoutInterval: 30];
	dataTask = [session dataTaskWithRequest: request];
	dataTask.taskDescription = [NSString stringWithFormat:@"Zoom: Downloading %@", url.lastPathComponent];
}

- (void) createDownloadDirectory {
	if (!downloadDirectory) return;
	
	BOOL exists;
	BOOL isDir;
	
	exists = [[NSFileManager defaultManager] fileExistsAtPath: downloadDirectory
												  isDirectory: &isDir];
	if (!exists) {
		[[NSFileManager defaultManager] createDirectoryAtPath: downloadDirectory
												   withIntermediateDirectories: NO
												   attributes: nil
														error:NULL];
	} else if (!isDir) {
		downloadDirectory = [downloadDirectory stringByAppendingString: @"-1"];
		[self createDownloadDirectory];
	}
}

#pragma mark - Status events

- (void) finished {
	// Kill any tasks
	if (task && [task isRunning]) {
		[task interrupt];
		[task terminate];
	}
	if (subtasks) {
		for (NSTask* sub in subtasks) {
			if ([sub isRunning]) {
				[sub interrupt];
				[sub terminate];
			}
		}
	}

	[dataTask cancel];
	dataTask = nil;
	tmpFile = nil;
	downloadFile = nil;
	task = nil;
	subtasks = nil;
}

- (void) failed: (NSString*) reason {
	[self finished];

	if (delegate && [delegate respondsToSelector: @selector(downloadFailed:reason:)]) {
		[delegate downloadFailed: self
						  reason: reason];
	}
}

- (void) succeeded {
	dataTask = nil;

	task = nil;
	subtasks = nil;

	// Let the download delegate know that the download has finished
	if (delegate && [delegate respondsToSelector: @selector(downloadComplete:)]) {
		[delegate downloadComplete: self];
	}
}

#pragma mark - The unarchiver

- (NSString*) directoryForUnarchiving {
	if (tmpDirectory != nil) return tmpDirectory;
	if (!downloadDirectory) return nil;
	
	NSString* directory = [downloadDirectory stringByAppendingPathComponent: [NSString stringWithFormat: @"unarchived-%i", lastDownloadId]];
	
	// Pick a directory name that doesn't already exist
	while ([[NSFileManager defaultManager] fileExistsAtPath: directory]) {
		lastDownloadId++;
		directory = [downloadDirectory stringByAppendingPathComponent: [NSString stringWithFormat: @"unarchived-%i", lastDownloadId]];
	}
	
	// Create the directory
	if ([[NSFileManager defaultManager] createDirectoryAtPath: directory
								  withIntermediateDirectories: NO
												   attributes: nil
														error: NULL]) {
		return tmpDirectory = [directory copy];
	} else {
		return nil;
	}
}

- (NSTask*) unarchiveFile: (NSString*) filename
			  toDirectory: (NSString*) directory {
	// Some ifarchive mirrors give us .tar.Z.tar and .tar.gz.tar type files: replace those
	if ([[filename lowercaseString] hasSuffix: @".tar.z.tar"]) {
		filename = [filename substringToIndex: [filename length] - [@".tar.z.tar" length]];
		filename = [filename stringByAppendingString: @".tar.z"];
	}
	if ([[filename lowercaseString] hasSuffix: @".tar.gz.tar"]) {
		filename = [filename substringToIndex: [filename length] - [@".tar.gz.tar" length]];
		filename = [filename stringByAppendingString: @".tar.gz"];
	}
	
	// Creates an NSTask that will unarchive the specified filename (which must be supplied as stdin) to the specified directory
	NSString* pathExtension = [[filename pathExtension] lowercaseString];
	NSString* withoutExtension = [filename stringByDeletingPathExtension];
	BOOL needNextStage = NO;
	NSTask* result = [[NSTask alloc] init];
	
	[result setLaunchPath: @"/usr/bin/env"];
	
	if ([pathExtension isEqualToString: @"zip"]) {
		// Unarchive as a .zip file
		[result setArguments: @[@"ditto",
								@"-x",
								@"-k",
								@"-",
								directory]];
	} else if ([pathExtension isEqualToString: @"tar"]) {
		// Is a something.tar file
		[result setArguments: @[@"tar",
								@"-xC",
								directory]];
	} else if ([pathExtension isEqualToString: @"gz"]
			   || [pathExtension isEqualToString: @"bz2"]
			   || [pathExtension isEqualToString: @"z"]) {
		// Is a something.gz file: need to do a two-stage task
		NSTask* nextStage = [self unarchiveFile: withoutExtension
									toDirectory: directory];
		
		// Pick the unarchiver to use
		NSString* unarchiver = @"gunzip";
		if ([pathExtension isEqualToString: @"gz"])		unarchiver = @"gunzip";
		if ([pathExtension isEqualToString: @"bz2"])	unarchiver = @"bunzip2";
		if ([pathExtension isEqualToString: @"z"])		unarchiver = @"uncompress";
		
		// Create the unarchiver
		[result setArguments: @[unarchiver]];
		
		// Create the pipes to connect the next task to the unarchiver
		NSPipe* pipe = [NSPipe pipe];
		
		[nextStage setStandardInput: pipe];
		[result setStandardOutput: pipe];
		
		// Add the next stage to the list of subtasks
		if (subtasks == nil) subtasks = [[NSMutableArray alloc] init];
		[subtasks addObject: nextStage];
	} else if ([pathExtension isEqualToString: @"tgz"]) {
		return [self unarchiveFile: [[withoutExtension stringByAppendingPathExtension: @"tar"] stringByAppendingPathExtension: @"gz"]
					   toDirectory: directory];
	} else if ([pathExtension isEqualToString: @"tbz"] || [pathExtension isEqualToString: @"tbz2"]) {
		return [self unarchiveFile: [[withoutExtension stringByAppendingPathExtension: @"tar"] stringByAppendingPathExtension: @"bz2"]
					   toDirectory: directory];
	} else {
		// Default is just to copy the file
		NSString* destFile = [directory stringByAppendingPathComponent: [filename lastPathComponent]];
		if (suggestedFilename && [[suggestedFilename lastPathComponent] length] > 0) destFile = [directory stringByAppendingPathComponent: [suggestedFilename lastPathComponent]];
		[[NSFileManager defaultManager] createFileAtPath: destFile
												contents: [NSData data]
											  attributes: nil];

		[result setArguments: @[@"cat", @"-"]];
		[result setStandardOutput: [NSFileHandle fileHandleForWritingAtPath: destFile]];
	}
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(taskDidTerminate:)
												 name: NSTaskDidTerminateNotification
											   object: result];
	return result;
}

- (void) unarchiveFile {
	if (![self directoryForUnarchiving]) {
		[self failed: @"Couldn't create directory for unarchiving"];
	}
	
	// Create the unarchiving task
	task = nil;
	task = [self unarchiveFile: tmpFile
					toDirectory: [self directoryForUnarchiving]];
	
	if (task == nil) {
		// Oops: couldn't create the task
		[self failed: @"Could not decompress the downloaded file."];
		return;
	}
	if (![[NSFileManager defaultManager] fileExistsAtPath: tmpFile]) {
		// Oops, the download file doesn't exist
		[self failed: @"The downloaded file was deleted before it could be unarchived."];
		return;
	}
	
	// Set the input file handle for the main task
	NSLog(@"Unarchiving %@ to %@", tmpFile, tmpDirectory);
	[task setStandardInput: [NSFileHandle fileHandleForReadingAtPath: tmpFile]];
	
	// Notify the delegate that we're starting to unarchive the 
	if (delegate && [delegate respondsToSelector: @selector(download:completed:)]) {
		[delegate download: self
				 completed: -1];
	}
	if (delegate && [delegate respondsToSelector: @selector(downloadUnarchiving:)]) {
		[delegate downloadUnarchiving: self];
	}
	
	// Start the tasks
	if (subtasks != nil) {
		for (NSTask* sub in subtasks) {
			[sub launch];
		}
	}
	[task launch];
}

#pragma mark - NSURLConnection delegate

- (NSString*) fullExtensionFor: (NSString*) filename {
	NSString* extension = [filename pathExtension];
	NSString* withoutExtension = [filename stringByDeletingPathExtension];
	
	if (extension == nil || [extension length] <= 0) return nil;
	
	NSString* extraExtension = [self fullExtensionFor: withoutExtension];
	if (extraExtension != nil) {
		return [extraExtension stringByAppendingPathExtension: extension];
	} else {
		return extension;
	}
}

- (void)URLSession:(NSURLSession *)session
		  dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
	NSInteger status = 200;
	if ([response isKindOfClass: [NSHTTPURLResponse class]]) {
		status = [(NSHTTPURLResponse*)response statusCode];
	}
	
	if (status >= 400) {
		// Failure: give up
		NSLog(@"Error: %li", (long)status);
		
		switch (status)
		{
			case 403:
				[self failed: @"The server forbade access to the file"];
				break;
				
			case 404:
				[self failed: @"The file was not found on the server"];
				break;
				
			case 410:
				[self failed: @"The file is no longer available on the server"];
				break;
				
			case 500:
				[self failed: @"The server is suffering from a fault"];
				break;
				
			case 503:
				[self failed: @"The server is currently unavailable"];
				
			default:
				[self failed: [NSString stringWithFormat: @"Server reported code %li", (long)status]];
		}
		completionHandler(NSURLSessionResponseCancel);
		return;
	}
	
	expectedLength = [response expectedContentLength];
	downloadedSoFar = 0;
	
	// Create the download directory if it doesn't exist
	[self createDownloadDirectory];
	if (!downloadDirectory || ![[NSFileManager defaultManager] fileExistsAtPath: downloadDirectory]) {
		[self failed: [NSString stringWithFormat: @"Couldn't create download directory"]];
	}
	
	// Create the download file
	tmpFile = [downloadDirectory stringByAppendingPathComponent: [NSString stringWithFormat: @"download-%i", lastDownloadId++]];
	tmpFile = [tmpFile stringByAppendingPathExtension: [self fullExtensionFor: [response suggestedFilename]]];
	
	suggestedFilename = [[response suggestedFilename] copy];
	
	if ([[suggestedFilename pathExtension] isEqualToString: @"txt"]) {
		// Some servers produce .zblorb.txt files, etc.
		if ([[[suggestedFilename stringByDeletingPathExtension] pathExtension] length] > 0) {
			suggestedFilename = [suggestedFilename stringByDeletingPathExtension];
		}
	}
	
	if (downloadFile) {
		[downloadFile closeFile];
		downloadFile = nil;
	}
	NSLog(@"Downloading to %@", tmpFile);
	[[NSFileManager defaultManager] createFileAtPath: tmpFile
											contents: [NSData data]
										  attributes: nil];
	downloadFile = [NSFileHandle fileHandleForWritingAtPath: tmpFile];
	
	if (downloadFile == nil) {
		// Failed to create the download file
		NSLog(@"...Could not create file");
		
		[self failed: @"Unable to save the download to disk"];
		completionHandler(NSURLSessionResponseCancel);
		return;
	}
	
	if (delegate && [delegate respondsToSelector: @selector(downloading:)]) {
		[delegate downloading: self];
	}
	completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session
		  dataTask:(NSURLSessionDataTask *)dataTask
	didReceiveData:(NSData *)data {
	// Write to the download file
	if (downloadFile) {
		[downloadFile writeData: data];
	}
	
	// Let the delegate know of the progress
	downloadedSoFar += [data length];
	
	if (expectedLength != 0) {
		float proportion = ((double)downloadedSoFar)/((double)expectedLength);
		
		if (delegate && [delegate respondsToSelector: @selector(download:completed:)]) {
			[delegate download: self
					 completed: proportion];
		}
	}
}

-    (void)URLSession:(NSURLSession *)session
				 task:(NSURLSessionTask *)task
 didCompleteWithError:(nullable NSError *)error {
	if (error) {
		// Delete the downloaded file
		if (downloadFile) {
			[downloadFile closeFile];
			downloadFile = nil;
			
			[[NSFileManager defaultManager] removeItemAtPath: tmpFile
													   error: nil];
		}
		
		tmpFile = nil;
		
		NSLog(@"Download failed with error: %@", error);
		
		// Inform the delegate, and give up
		[self failed: [NSString stringWithFormat: @"Connection failed: %@", [error localizedDescription]]];

		return;
	}
	if (downloadFile) {
		// Finish writing the file
		[downloadFile closeFile];
		downloadFile = nil;
		
		// If we have an MD5, then verify that the file matches it
		if (md5) {
			CC_MD5_CTX state;
			CC_MD5_Init(&state);
			
			NSFileHandle* readDownload = [NSFileHandle fileHandleForReadingAtPath: tmpFile];
			if (readDownload == nil) {
				[self failed: @"The downloaded file was deleted before it could be processed"];
				return;
			}
			
			// Read in the file and update the MD5 sum
			@autoreleasepool {
				NSData* readBytes;
				while ((readBytes = [readDownload readDataOfLength: 65536]) && [readBytes length] > 0) {
					CC_MD5_Update(&state, [readBytes bytes], (CC_LONG)[readBytes length]);
				}
			}
			
			// Finish up and get the MD5 digest
			unsigned char digest[CC_MD5_DIGEST_LENGTH];
			CC_MD5_Final(digest, &state);
			
			NSData* digestData = [NSData dataWithBytes: digest
												length: CC_MD5_DIGEST_LENGTH];
			NSLog(@"MD5 digest is %@", digestData);
			
			if (![digestData isEqual: md5]) {
				NSLog(@"Could not verify download");
				[self failed: @"The downloaded file has an invalid checksum"];
				return;
			}
		}
		
		// Create the download directory
		NSString* directory = [self directoryForUnarchiving];
		if (directory == nil) {
			// Couldn't create the directory
			[self failed: @"Could not create a directory to decompress the downloaded file"];
			return;
		}
		
		// Unarchive the file if it's a zip or a tar file, or move it to the download directory
		[self unarchiveFile];
	}
}

#pragma mark - NSTask delegate

- (void) taskDidTerminate: (NSNotification*) not {
	// Do nothing if no task is running
	if (task == nil) return;
	
	// Check if all of the tasks have finished
	BOOL finished = YES;
	BOOL succeeded = YES;
	
	if (subtasks) {
		for (NSTask* sub in subtasks) {
			if ([sub isRunning]) {
				finished = NO;
			} else if ([sub terminationStatus] != 0) {
				succeeded = NO;
			}
		}
	}
	if ([task isRunning]) {
		finished = NO;
	} else if ([task terminationStatus] != 0) {
		succeeded = NO;
	}
	
	if (!succeeded) {
		// Oops, failed
		NSLog(@"Failed to unarchive %@", tmpFile);
		[self failed: @"The downloaded file failed to decompress"];
		return;
	} else if (finished) {
		// Download has successfully completed
		NSLog(@"Unarchiving task succeeded");
		[self succeeded];
	}
}

#pragma mark - Getting the download directory
@synthesize url;
@synthesize downloadDirectory=tmpDirectory;
@synthesize suggestedFilename;

@end
