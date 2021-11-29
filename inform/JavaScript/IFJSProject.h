//
//  IFJSProject.h
//  Inform
//
//  Created by Andrew Hunter on 29/08/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFProjectPane.h"

///
/// Class designed to provide a JavaScript interface to a project window.
///
/// This makes it possible to create buttons that, for example, paste code into the source window.
///
@interface IFJSProject : NSObject

// Initialisation
- (instancetype) init NS_UNAVAILABLE;
/// Initialise this object: we'll control the given pane. Note that this is \b NOT retained to
/// avoid a retain loop (the pane retains the web view, which retains us...)
- (instancetype) initWithPane: (IFProjectPane*) pane NS_DESIGNATED_INITIALIZER;

#pragma mark - JavaScript operations on the pane

/// Selects a specific view (valid names are source, documentation, skein, etc)
- (void) selectView: (NSString*) view;
/// Pastes some code into the source view at the current insertion point
- (void) pasteCode: (NSString*) code;
/// Creates a new project with some code in the source view
- (void) createNewProject: (NSString*) title
                    story: (NSString*) code;

@end
