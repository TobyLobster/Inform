//
//  IFNewExtensionsManager.h
//  Inform
//
//  Created by Toby Nelson on 21/04/2023.
//

#import <Cocoa/Cocoa.h>

@class IFProject;

///
/// Class used to manage extensions
///
/// This class can be used as a delegate for NSSave/Open panel delegates to only allow valid extensions
/// to be selected.
///
@interface IFNewExtensionsManager : NSObject

/// Shared managers
+ (IFNewExtensionsManager*) sharedNewExtensionsManager;
@property (class, atomic, readonly, strong) IFNewExtensionsManager *sharedNewExtensionsManager;

// Setting up
- (instancetype) init NS_DESIGNATED_INITIALIZER;

- (NSURL*) copyWithUnzip: (NSURL *) sourceURL toProjectTemporary: (IFProject *) project;
- (NSURL*) copyWithUnzip: (NSURL *) sourceURL to: (NSURL *) destinationURL;

@end
