//
//  ZoomGlkPlugIn.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 24/11/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <ZoomPlugIns/ZoomPlugIn.h>
#import <ZoomPlugIns/ZoomGlkWindowController.h>
#import <ZoomPlugIns/ZoomGlkDocument.h>

///
/// Base class for plugins that provide a Glk-based interpreter.
///
@interface ZoomGlkPlugIn : ZoomPlugIn {
	//! Constructed on demand
	ZoomGlkDocument* document;
	
	//! Path to the client application
	NSString* clientPath;
	//! Place to put save files
	NSURL* preferredSaveDir;
}

// Configuring the client
//! Selects which GlkClient executable to run
- (void) setClientPath: (NSString*) clientPath;
//! If non-nil, sets the logo to display for this game
- (NSImage*) logo;

@property (copy) NSString *clientPath;

@property (copy) NSURL *preferredSaveDirectoryURL;

@end
