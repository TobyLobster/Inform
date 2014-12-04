//
//  ZoomSignPost.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 28/10/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>


///
/// Class that deals with understanding IFDB signpost files.
///
@interface ZoomSignPost : NSObject {
	// The signpost data
	NSMutableArray* ifids;
	NSString* interpreterDisplayName;
	NSString* interpreterURL;
	NSString* interpreterVersion;
	NSString* pluginVersion;
	NSString* downloadURL;
	NSString* errorMessage;
	
	// Parsing state
	BOOL reparseAsPlist;
	BOOL parseError;
	NSMutableArray* pathStack;
	NSMutableArray* cDataStack;
}

// = Initialising =

- (id) initWithData: (NSData*) data;							// Parses the specified signpost data
- (BOOL) parseData: (NSData*) data;								// Replaces the data stored in this signpost with the specified data

// = Getting signpost data =

- (NSArray*) ifids;												// The IDs associated with this signpost
- (NSString*) interpreterDisplayName;							// The display name of the interpreter (the interpreter system name)
- (NSURL*) interpreterURL;										// The URL of the interpreter update page
- (NSString*) interpreterVersion;								// The requested interpreter version
- (NSString*) pluginVersion;									// The requested plugin version
- (NSURL*) downloadURL;											// The download URL for the game
- (NSString*) errorMessage;										// The error contained in this signpost (or nil)

- (NSData*) data;												// Returns a serialized NSData object for this signpost (can be passed back to initWithData: to reload the signpost later)

@end
