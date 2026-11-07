//
//  IFNewProjectProtocol.h
//  Inform
//
//  Created by Andrew Hunter on Sat Sep 13 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class IFProjectFile;

@protocol IFNewProjectSetupView;

///
/// Objects implementing this protocol specify a type of project that can be created via the
/// new project dialog.
///
@protocol IFNewProjectProtocol <NSObject>

/// nil, or a project type-specific view that can be used to customise the new project. Should be reallocated every time this is called.
@property (NS_NONATOMIC_IOSONLY, readonly, strong, nullable) id<IFNewProjectSetupView> configView;

/// Request to setup a file from the given \c IFProjectSetupView (which will have been previously created by configView)
- (void) setupFile: (IFProjectFile*) file
          fromView: (nullable NSObject<IFNewProjectSetupView>*) view
         withStory: (nullable NSString*) story
  withExtensionURL: (nullable NSURL*) extensionURL;

-(void) setInitialFocus: (NSWindow*) window;
@property (NS_NONATOMIC_IOSONLY, readonly) NSRange initialSelectionRange;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *typeName;

// Objects implementing the IFProjectType protocol may also implement these functions.
@optional
/// Return a string to display an 'are you sure' type message (nil if there's nothing to confirm)
@property (atomic, readonly, copy, nullable) NSString *confirmationMessage;
/// Return a string to indicate an error with the way things are set up (nil if there's no error)
@property (atomic, readonly, copy, nullable) NSString *errorMessage;
/// If showFinalPage is NO, this is the filename to create (nil if it can't be worked out)
@property (atomic, readonly, copy, nullable) NSString *saveFilename;

/// If present, creates and opens the document associated with this view
- (BOOL) createAndOpenDocument: (NSURL*) fileURL;

@end

@protocol IFNewProjectSetupView <NSObject>

/// The view that's displayed for this projects custom settings
@property (NS_NONATOMIC_IOSONLY, readonly, strong) NSView *view;

@end

NS_ASSUME_NONNULL_END
