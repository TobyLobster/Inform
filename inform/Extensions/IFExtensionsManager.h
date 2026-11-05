//
//  IFExtensionsManager.h
//  Inform
//
//  Created by Andrew Hunter on 06/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFProgress.h"
#import "IFProject.h"
#import "IFExtensionInfo.h"
#import "IFExtensionDownload.h"

NS_ASSUME_NONNULL_BEGIN

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

///
/// Class used to manage extensions
///
/// This class can be used as a delegate for NSSave/Open panel delegates to only allow valid extensions
/// to be selected.
///
@interface IFExtensionsManager : NSObject<NSOpenSavePanelDelegate>

@property (atomic) BOOL rebuildAvailableExtensionsCache;
@property (atomic) BOOL rebuildExtensionDictionaryCache;
@property (atomic) BOOL cacheChanged;

/// Shared managers
@property (class, atomic, readonly, strong) IFExtensionsManager *sharedNaturalInformExtensionsManager;

// Setting up
- (instancetype) init NS_DESIGNATED_INITIALIZER;

- (void) dirtyCache;

// Retrieving the list of installed extensions
/// Array of available extension information
- (NSArray<IFExtensionInfo*>*) availableExtensionsWithCompilerVersion: (NSString*) compilerVersion;

/// Array of available authors
- (NSArray<NSString*>*) availableAuthorsWithCompilerVersion: (NSString*) compilerVersion;
/// Array of available extensions for a given author
- (NSArray<IFExtensionInfo*>*) availableExtensionsByAuthor: (NSString*) author
                                       withCompilerVersion: (NSString*) compilerVersion;

// ... and the list of files within a given extension (full paths)
/// Complete list of files in the given extension
- (NSArray<NSString*>*) filesInExtensionWithName: (NSString*) name;

/// From a file potentially containing a natural inform extension, works out the author, title, version information.
/// Each piece given a place to go is set, to \c nil if it isn't found (the version is \c nil if there isn't one).
- (IFExtensionResult) infoForNaturalInformExtension: (NSString*) file
                                             author: (NSString* _Nullable __strong* _Nullable) authorOut
                                              title: (NSString* _Nullable __strong* _Nullable) titleOut
                                            version: (NSString* _Nullable __strong* _Nullable) versionOut;

/// Copies a file from the given path into the installed extensions, perhaps replacing an existing extension
- (IFExtensionResult) installLegacyExtension: (NSString*) extensionPath
                             finalPath: (NSString* _Nullable __strong* _Nullable) finalPathOut
                                 title: (NSString* _Nullable __strong* _Nullable) titleOut
                                author: (NSString* _Nullable __strong* _Nullable) authorOut
                               version: (NSString* _Nullable __strong* _Nullable) versionOut
                    showWarningPrompts: (BOOL) showWarningPrompts
                                notify: (BOOL) notify;

-(void) startLegacyCensus:(NSNumber*) notify;

#pragma mark - Download and Install

-(void) addError: (NSString*) message;
- (BOOL) downloadAndInstallExtension: (NSURL*) url
                              window: (nullable NSWindow*) aWindow
                      notifyDelegate: (nullable NSObject*) notifyDelegate
                        javascriptId: (nullable NSString*) javascriptId;
- (void) downloadAndInstallFinished: (IFExtensionDownload*) download;
-(void) reportDownloadResults: (IFExtensionDownload*) download;

#pragma mark -
-(void) unit_test;

@end

NS_ASSUME_NONNULL_END
