//
//  IFNewInform7ExtensionFile.h
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
/// Project type for the New Extension window, which makes a new extension in a project's materials folder and opens it
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

/// Fills in the author's name from the preferences, and a title to change
- (void) setupControls;
/// The author's name, as typed
@property (nonatomic, readonly, copy) NSString *authorName;
/// The extension's title, as typed
@property (nonatomic, readonly, copy) NSString *extensionName;
/// Puts the keyboard focus on the title
- (void) setInitialFocus: (NSWindow*) window;

@end

NS_ASSUME_NONNULL_END
