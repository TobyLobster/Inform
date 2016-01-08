//
//  IFExtensionsManager.h
//  Inform
//
//  Created by Andrew Hunter on 06/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFProgress.h"

extern NSString* IFExtensionsUpdatedNotification;				// Sent when the extensions are updated
extern NSString* IFCensusFinishedNotification;
extern NSString* IFCensusFinishedButDontUpdateExtensionsWebPageNotification;

// *******************************************************************************************
@interface IFExtensionInfo : NSObject

@property (atomic, strong) NSString* displayName;
@property (atomic, strong) NSString* filepath;
@property (atomic, strong) NSString* author;
@property (atomic, strong) NSString* version;
@property (atomic, strong) NSString* md5Hash;
@property (atomic)         BOOL      isBuiltIn;

-(instancetype) init NS_UNAVAILABLE NS_DESIGNATED_INITIALIZER;

-(instancetype) initWithDisplayName: (NSString*) displayName
                 filepath: (NSString*) filepath
                   author: (NSString*) author
                  version: (NSString*) version
                  md5Hash: (NSString*) md5Hash
                isBuiltIn: (BOOL) isBuiltIn NS_DESIGNATED_INITIALIZER;

// Remove leading "The " and trailing proviso (in brackets) from a display name to get title used for extension filename
+(NSString*) canonicalTitle:(NSString*) displayName;
@property (atomic, readonly, copy) NSString *safeVersion;
-(BOOL) isEqual: (id) other;

@end

// *******************************************************************************************
typedef enum IFExtensionDownloadState {
    IFExtensionDownloadNotStarted,
    IFExtensionDownloadInProgress,
    IFExtensionDownloadFailed,
    IFExtensionInstallFailed,
    IFExtensionDownloadAndInstallSucceeded,
} IFExtensionDownloadState;

@interface IFExtensionDownload : NSObject

@property (atomic) IFExtensionDownloadState state;
@property (atomic, strong) NSURLConnection* connection;
@property (atomic, strong) NSMutableData*   receivedData;
@property (atomic) long long                expectedLength;
@property (atomic, strong) NSWindow*        window;
@property (atomic, strong) NSString*        javascriptId;
@property (atomic, strong) NSObject*        notifyDelegate;
@property (atomic, strong) NSString*        title;
@property (atomic, strong) NSString*        author;
@property (atomic, strong) NSString*        version;
@property (atomic, strong) NSURL*           url;

// Download and install
- (instancetype) init NS_UNAVAILABLE NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithURL: (NSURL*) url
                      window: (NSWindow*) aWindow
              notifyDelegate: (NSObject*) notifyDelegate
                javascriptId: (NSString*) javascriptId NS_DESIGNATED_INITIALIZER;

@property (atomic, readonly) BOOL startDownloadAndInstall;
@property (atomic, readonly, copy) NSString *safeVersion;

@end


// *******************************************************************************************
//
// Class used to manage extensions
//
// This class can be used as a delegate for NSSave/Open panel delegates to only allow valid extensions
// to be selected.
//
@interface IFExtensionsManager : NSObject<NSTableViewDataSource, NSOpenSavePanelDelegate>

@property (atomic) BOOL rebuildAvailableExtensionsCache;
@property (atomic) BOOL rebuildExtensionDictionaryCache;
@property (atomic) BOOL cacheChanged;

// Shared managers
+ (IFExtensionsManager*) sharedNaturalInformExtensionsManager;

// Setting up
- (instancetype) init NS_DESIGNATED_INITIALIZER;

- (void) dirtyCache;

// Retrieving the list of installed extensions
@property (atomic, readonly, copy) NSArray *availableExtensions;										// Array of available extension information
@property (atomic, readonly, copy) NSArray *availableAuthors;                                          // Array of available authors
- (NSArray*) availableExtensionsByAuthor:(NSString*) author;            // Array of available extensions for a given author

- (BOOL) isFileInstalled:(NSString*) fullPath;

// ... and the list of files within a given extension (full paths)
- (NSArray*) filesInExtensionWithName: (NSString*) name;				// Complete list of files in the given extension
- (NSArray*) sourceFilesInExtensionWithName: (NSString*) name;			// Complete list of source files in the given extension

// From a file potentially containing a natural inform extension, works out the author, title, version information
- (BOOL) infoForNaturalInformExtension: (NSString*) file
                                author: (NSString*__strong*) authorOut
                                 title: (NSString*__strong*) titleOut
                               version: (NSString*__strong*) versionOut;

// Copies a file from the given path into the installed extensions, perhaps replacing an existing extension
- (BOOL) installExtension: (NSString*) extensionPath
                finalPath: (NSString*__strong*) finalPathOut
                    title: (NSString*__strong*) titleOut
                   author: (NSString*__strong*) authorOut
                  version: (NSString*__strong*) versionOut
       showWarningPrompts: (BOOL) showWarningPrompts
                   notify: (BOOL) notify;
-(void) startCensus:(NSNumber*) notify;
- (void) updateExtensions;

// = Download and Install =
-(void) addError: (NSString*) message;
- (BOOL) downloadAndInstallExtension: (NSURL*) url
                              window: (NSWindow*) aWindow
                      notifyDelegate: (NSObject*) notifyDelegate
                        javascriptId: (NSString*) javascriptId;
- (void) downloadAndInstallFinished: (IFExtensionDownload*) download;

@end
