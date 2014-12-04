//
//  ZoomGlkSaveRef.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 15/07/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ZoomPlugIns/ZoomPlugIn.h>
#import <GlkView/GlkFileRefProtocol.h>

///
/// GlkFileRef object that can be used to create a .glksave package
///
@class ZoomSkein;
@interface ZoomGlkSaveRef : NSObject<GlkFileRef> {
	ZoomPlugIn* plugin;										// The plugin specifying what is creating this fileref
	NSString* path;											// The path for this fileref
	
	NSArray* preview;										// The preview lines to save for this object
	ZoomSkein* skein;										// The skein to save for this object (or the skein loaded for this object)
	
	id delegate;											// The delegate for this object
	BOOL autoflush;											// The autoflush flag
}

// Initialisation
- (id) initWithPlugIn: (ZoomPlugIn*) plugin					// Initialises a saveref that saves files from the specified plugin object to the specified path
				 path: (NSString*) path;

// Extra properties
- (void) setDelegate: (id) delegate;						// Sets the delegate for this object (the delegate is retained)

- (void) setPreview: (NSArray*) preview;					// An array of strings that can be used for the preview for this file
- (void) setSkein: (ZoomSkein*) skein;						// Sets the skein that will be saved with this reference
- (ZoomSkein*) skein;										// Retrieves a skein previously set with setSkein, or the skein most recently loaded for this file

@end

///
/// ZoomGlkSaveRef delegate methods
///

@interface NSObject(ZoomGlkSaveRefDelegate)

- (void) readingFromSaveFile: (ZoomGlkSaveRef*) file;		// Call back to indicate that we're reading from a specific save file

@end
