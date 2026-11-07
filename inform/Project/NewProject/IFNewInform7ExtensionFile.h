//
//  IFNewInform7Extension.h
//  Inform
//
//  Created by Andrew Hunter on 18/11/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFNewProjectProtocol.h"

NS_ASSUME_NONNULL_BEGIN


@class IFProject;
@class IFPreferences;
@class IFNewInform7ExtensionView;

///
/// Project type that makes it possible to create new Natural Inform extensions directories
///
@interface IFNewInform7ExtensionFile : NSObject<IFNewProjectProtocol>

- (instancetype) init NS_UNAVAILABLE;
/// A new extension for the project given, whose author's name comes from the shared preferences
- (instancetype) initWithProject: (IFProject*) theProject;
/// A new extension for the project given, whose author's name comes from the preferences given
- (instancetype) initWithProject: (IFProject*) theProject
                     preferences: (IFPreferences*) preferences NS_DESIGNATED_INITIALIZER;

/// Writes the new extension to the file given, with its title and author from the options view, making any folders
/// it needs, and sets initialSelectionRange to the start of its empty line. NO if it can't be written.
- (BOOL) writeExtension: (NSURL*) fileURL;

@end

/// (This class name sounds suspiciously likes a free sample from one of those spams...)
@interface IFNewInform7ExtensionView : NSObject<IFNewProjectSetupView>

- (instancetype) init NS_UNAVAILABLE;
/// Options whose author's name comes from the preferences given
- (instancetype) initWithPreferences: (IFPreferences*) preferences NS_DESIGNATED_INITIALIZER;

- (void) setupControls;
@property (atomic, readonly, copy) NSString *authorName;
@property (atomic, readonly, copy) NSString *extensionName;
- (void) setInitialFocus: (NSWindow*) window;

@end

NS_ASSUME_NONNULL_END
