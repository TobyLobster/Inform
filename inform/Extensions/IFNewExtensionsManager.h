//
//  IFNewExtensionsManager.h
//  Inform
//
//  Created by Toby Nelson on 21/04/2023.
//

#import <Cocoa/Cocoa.h>

@class IFProject;

NS_ASSUME_NONNULL_BEGIN

///
/// Class used to manage extensions
///
/// This class can be used as a delegate for NSSave/Open panel delegates to only allow valid extensions
/// to be selected.
///
NS_SWIFT_UI_ACTOR
@interface IFNewExtensionsManager : NSObject

/// Shared managers
@property (class, atomic, readonly, strong) IFNewExtensionsManager *sharedNewExtensionsManager;

// Setting up
- (instancetype) init NS_DESIGNATED_INITIALIZER;

/// Copies (or unzips) an extension into the project's temporary extensions folder. \c nil if that fails.
- (nullable NSURL*) copyWithUnzip: (NSURL *) sourceURL toProjectTemporary: (IFProject *) project extensionName: (NSString*) name;
/// Copies (or unzips) an extension into the given folder, and returns where it is. \c nil if that fails.
- (nullable NSURL*) copyWithUnzip: (NSURL *) sourceURL to: (NSURL *) destinationURL extensionName: (NSString*) name;
/// Removes the project's temporary extensions folder, with the copies made there to be installed
- (void) removeTemporaryFolderOfProject: (IFProject *) project NS_SWIFT_NAME(removeTemporaryFolder(of:));

@end

NS_ASSUME_NONNULL_END
