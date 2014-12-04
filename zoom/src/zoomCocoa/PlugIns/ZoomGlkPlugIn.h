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
	ZoomGlkDocument* document;										// Constructed on demand
	
	NSString* clientPath;											// Path to the client application
	NSString* preferredSaveDir;										// Place to put save files
}

// Configuring the client
- (void) setClientPath: (NSString*) clientPath;						// Selects which GlkClient executable to run
- (NSImage*) logo;													// If non-nil, sets the logo to display for this game

@end
