//
//  IFJSProject.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 29/08/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFProjectPane.h"

//
// Class designed to provide a JavaScript interface to a project window.
//
// This should make it possible to create buttons that, for example, paste code into the source window.
//
@interface IFJSProject : NSObject {
	IFProjectPane* pane;
}

// Initialisation
- (id) initWithPane: (IFProjectPane*) pane;	// Initialise this object: we'll control the given pane. Note that this is *NOT* retained to avoid a retain loop (the pane retains the web view, which retains us...)

// JavaScript operations on the pane
- (void) selectView: (NSString*) view;					// Selects a specific view (valid names are source, documentation, skein, etc)
- (void) pasteCode: (NSString*) code;					// Pastes some code into the source view at the current insertion point
- (void) createNewProject: (NSString*) title
                    story: (NSString*) code;			// Creates a new project with some code in the source view
- (void) runStory: (NSString*) game;					// Compiles/Runs the current story
- (void) replayStory: (NSString*) game;					// Replays the current story: use addCommand below to create the list of commands to replay if you don't want to replay whatever was last
- (void) addCommand: (NSString*) command;				// Adds a command as a child of the last command on the skein. 'Last' command is updated to be this command instead of the one the player last replayed to
- (void) clearCommands;									// Clears the list of commands added using addCommand, so we replay to the last player-entered command again (they remain in the skein, however)

@end
