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
@interface IFExtensionInfo : NSObject {
    NSString* _displayName;
    NSString* _filepath;
    NSString* _author;
    NSString* _version;
    NSString* _md5Hash;
    BOOL      _isBuiltIn;
}

@property (strong) NSString* displayName;
@property (strong) NSString* filepath;
@property (strong) NSString* author;
@property (strong) NSString* version;
@property (strong) NSString* md5Hash;
@property BOOL isBuiltIn;

-(id) initWithDisplayName: (NSString*) displayName
                 filepath: (NSString*) filepath
                   author: (NSString*) author
                  version: (NSString*) version
                  md5Hash: (NSString*) md5Hash
                isBuiltIn: (BOOL) isBuiltIn;

// Remove leading "The " and trailing proviso (in brackets) from a display name to get title used for extension filename
+(NSString*) canonicalTitle:(NSString*) displayName;
-(NSString*) safeVersion;
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

@interface IFExtensionDownload : NSObject {
    IFExtensionDownloadState _state;
    NSURL*                   _url;
    NSURLConnection*         _connection;
    NSMutableData*           _receivedData;
    long long                _expectedLength;
    NSWindow*                _window;
    NSObject*                _notifyDelegate;
    NSString*                _javascriptId;
    NSString*                _title;
    NSString*                _author;
    NSString*                _version;
}

@property IFExtensionDownloadState  state;
@property (strong) NSURLConnection* connection;
@property (strong) NSMutableData*   receivedData;
@property long long                 expectedLength;
@property (strong) NSWindow*        window;
@property (strong) NSString*        javascriptId;
@property (strong) NSObject*        notifyDelegate;
@property (strong) NSString*        title;
@property (strong) NSString*        author;
@property (strong) NSString*        version;
@property (strong) NSURL*           url;

// Download and install
-(id) initWithURL: (NSURL*) url
           window: (NSWindow*) aWindow
   notifyDelegate: (NSObject*) notifyDelegate
     javascriptId: (NSString*) javascriptId;

- (BOOL) startDownloadAndInstall;
- (NSString*) safeVersion;

@end


// *******************************************************************************************
//
// Class used to manage extensions
//
// This class can be used as a delegate for NSSave/Open panel delegates to only allow valid extensions
// to be selected.
//
@interface IFExtensionsManager : NSObject<NSTableViewDataSource, NSOpenSavePanelDelegate> {
	// Collection directories to look
	NSMutableArray* extensionCollectionDirectories;		// Standard set of extension directories

	// Cache data
	NSDictionary* cacheExtensionDictionary;				// Caches the extension dictionary until we next clear the cache
	NSArray*      cacheAvailableExtensions;             // Caches the available extensions array until we next clear the cache
    int           userLibraryCount;                     // Number of extension dictionaries that are 'installed' to ~/Library/Inform rather than internal to the Inform app bundle resources (i.e. one)

    // Update extensions
	BOOL          updatingExtensions;					// Set to YES if an update is pending

    BOOL _rebuildAvailableExtensionsCache;
    BOOL _rebuildExtensionDictionaryCache;
    BOOL _cacheChanged;

    // Download and install
    NSMutableArray* downloads;                          // Mutable array of current downloads
    int numberOfBatchedExtensions;                      // How many things we are downloading and installing
    int numberOfErrors;                                 // Number of failed download / installs
    NSMutableString* errorString;                       // Multiple error messages are accumulated into this string
    IFProgress* dlProgress;                             // Progress
}

@property BOOL rebuildAvailableExtensionsCache;
@property BOOL rebuildExtensionDictionaryCache;
@property BOOL cacheChanged;

// Shared managers
+ (IFExtensionsManager*) sharedNaturalInformExtensionsManager;

// Setting up
- (id) init;

- (void) dirtyCache;

// Retrieving the list of installed extensions
- (NSArray*) availableExtensions;										// Array of available extension information
- (NSArray*) availableAuthors;                                          // Array of available authors
- (NSArray*) availableExtensionsByAuthor:(NSString*) author;            // Array of available extensions for a given author

- (BOOL) isFileInstalled:(NSString*) fullPath;

// ... and the list of files within a given extension (full paths)
- (NSArray*) filesInExtensionWithName: (NSString*) name;				// Complete list of files in the given extension
- (NSArray*) sourceFilesInExtensionWithName: (NSString*) name;			// Complete list of source files in the given extension

// From a file potentially containing a natural inform extension, works out the author, title, version information
- (BOOL) infoForNaturalInformExtension: (NSString*) file
                                author: (NSString**) authorOut
                                 title: (NSString**) titleOut
                               version: (NSString**) versionOut;

// Copies a file from the given path into the installed extensions, prehaps replacing an existing extension
- (BOOL) installExtension: (NSString*) extensionPath
                finalPath: (NSString**) finalPathOut
                    title: (NSString**) titleOut
                   author: (NSString**) authorOut
                  version: (NSString**) versionOut
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
