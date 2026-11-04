//
//  IFNewProjectProtocol.h
//  Inform
//
//  Created by Andrew Hunter on Sat Sep 13 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class IFProjectFile;

@protocol IFNewProjectSetupView;

///
/// Objects implementing this protocol specify a type of project that can be created via the
/// new project dialog.
///
@protocol IFNewProjectProtocol <NSObject>

/// nil, or a project type-specific view that can be used to customise the new project. Should be reallocated every time this is called.
@property (NS_NONATOMIC_IOSONLY, readonly, strong) id<IFNewProjectSetupView> configView;

/// Request to setup a file from the given \c IFProjectSetupView (which will have been previously created by configView)
- (void) setupFile: (IFProjectFile*) file
          fromView: (NSObject<IFNewProjectSetupView>*) view
         withStory: (NSString*) story
  withExtensionURL: (NSURL*) extensionURL;

-(void) setInitialFocus: (NSWindow*) window;
@property (NS_NONATOMIC_IOSONLY, readonly) NSRange initialSelectionRange;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *typeName;

// Objects implementing the IFProjectType protocol may also implement these functions.
@optional
/// Return a string to display an 'are you sure' type message
@property (atomic, readonly, copy) NSString *confirmationMessage;
/// Return a string to indicate an error with the way things are set up
@property (atomic, readonly, copy) NSString *errorMessage;
/// If showFinalPage is NO, this is the filename to create
@property (atomic, readonly, copy) NSString *saveFilename;
/// If present, the file type to open this project as
@property (atomic, readonly, copy) NSString *openAsType;

/// If present, creates and opens the document associated with this view
- (BOOL) createAndOpenDocument: (NSURL*) fileURL;

@end

@protocol IFNewProjectSetupView <NSObject>

/// The view that's displayed for this projects custom settings
@property (NS_NONATOMIC_IOSONLY, readonly, strong) NSView *view;

@end

