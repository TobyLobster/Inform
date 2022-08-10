//
//  IFExtensionsManager.h
//  Inform
//
//  Created by Andrew Hunter on 06/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFProgress.h"
#import "IFSemVer.h"

extern NSNotificationName const IFExtensionsUpdatedNotification;				// Sent when the extensions are updated
extern NSNotificationName const IFCensusFinishedNotification;
extern NSNotificationName const IFCensusFinishedButDontUpdateExtensionsWebPageNotification;

typedef NS_ENUM(int, IFExtensionResult) {
    IFExtensionNotFound,
    IFExtensionNotValid,
    IFExtensionAlreadyExists,
    IFExtensionCantWriteDestination,
    IFExtensionSuccess,
};

#pragma mark -

@interface IFExtensionInfo : NSObject

@property (atomic, copy)   NSString* displayName;
@property (atomic, copy)   NSString* filepath;
@property (atomic, copy)   NSString* author;
@property (atomic, copy)   NSString* version;
@property (atomic, copy)   NSString* md5Hash;
@property (atomic)         BOOL      isBuiltIn;

-(instancetype) init NS_UNAVAILABLE;

-(instancetype) initWithDisplayName: (NSString*) displayName
                 filepath: (NSString*) filepath
                   author: (NSString*) author
                  version: (NSString*) version
                  md5Hash: (NSString*) md5Hash
                isBuiltIn: (BOOL) isBuiltIn NS_DESIGNATED_INITIALIZER;

/// Remove leading "The ", "An ", or "A ", and trailing proviso (in brackets) from a display name to get title used for extension filename
+(NSString*) canonicalTitle:(NSString*) displayName;
@property (atomic, readonly, copy) NSString *safeVersion;
@property (atomic, readonly, copy) IFSemVer *semver;
-(BOOL) isEqual: (id) other;

@end

#pragma mark -

typedef NS_ENUM(int, IFExtensionDownloadState) {
    IFExtensionDownloadNotStarted,
    IFExtensionDownloadInProgress,
    IFExtensionDownloadFailed,
    IFExtensionInstallFailed,
    IFExtensionDownloadAndInstallSucceeded,
};

@interface IFExtensionDownload : NSObject

@property (atomic) IFExtensionDownloadState state;
@property (atomic, strong) NSURLSessionDataTask* connection;
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
- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithURL: (NSURL*) url
                      window: (NSWindow*) aWindow
              notifyDelegate: (NSObject*) notifyDelegate
                javascriptId: (NSString*) javascriptId NS_DESIGNATED_INITIALIZER;

@property (atomic, readonly) BOOL startDownloadAndInstall;
@property (atomic, readonly, copy) NSString *safeVersion;

@end


#pragma mark -

///
/// Class used to manage extensions
///
/// This class can be used as a delegate for NSSave/Open panel delegates to only allow valid extensions
/// to be selected.
///
@interface IFExtensionsManager : NSObject<NSTableViewDataSource, NSOpenSavePanelDelegate>

@property (atomic) BOOL rebuildAvailableExtensionsCache;
@property (atomic) BOOL rebuildExtensionDictionaryCache;
@property (atomic) BOOL cacheChanged;

/// Shared managers
+ (IFExtensionsManager*) sharedNaturalInformExtensionsManager;
@property (class, atomic, readonly, strong) IFExtensionsManager *sharedNaturalInformExtensionsManager;

// Setting up
- (instancetype) init NS_DESIGNATED_INITIALIZER;

- (void) dirtyCache;

// Retrieving the list of installed extensions
/// Array of available extension information
@property (atomic, readonly, copy) NSArray<IFExtensionInfo*> *availableExtensions;
/// Array of available authors
@property (atomic, readonly, copy) NSArray<NSString*> *availableAuthors;
/// Array of available extensions for a given author
- (NSArray<IFExtensionInfo*>*) availableExtensionsByAuthor:(NSString*) author;

- (BOOL) isFileInstalled:(NSString*) fullPath;

// ... and the list of files within a given extension (full paths)
/// Complete list of files in the given extension
- (NSArray*) filesInExtensionWithName: (NSString*) name;
/// Complete list of source files in the given extension
- (NSArray*) sourceFilesInExtensionWithName: (NSString*) name;

/// From a file potentially containing a natural inform extension, works out the author, title, version information
- (IFExtensionResult) infoForNaturalInformExtension: (NSString*) file
                                             author: (NSString*__strong*) authorOut
                                              title: (NSString*__strong*) titleOut
                                            version: (NSString*__strong*) versionOut;

/// Copies a file from the given path into the installed extensions, perhaps replacing an existing extension
- (IFExtensionResult) installExtension: (NSString*) extensionPath
                             finalPath: (NSString*__strong*) finalPathOut
                                 title: (NSString*__strong*) titleOut
                                author: (NSString*__strong*) authorOut
                               version: (NSString*__strong*) versionOut
                    showWarningPrompts: (BOOL) showWarningPrompts
                                notify: (BOOL) notify;

-(void) startCensus:(NSNumber*) notify;
- (void) updateExtensions;

#pragma mark - Download and Install

-(void) addError: (NSString*) message;
- (BOOL) downloadAndInstallExtension: (NSURL*) url
                              window: (NSWindow*) aWindow
                      notifyDelegate: (NSObject*) notifyDelegate
                        javascriptId: (NSString*) javascriptId;
- (void) downloadAndInstallFinished: (IFExtensionDownload*) download;

#pragma mark -
-(void) unit_test;

@end

