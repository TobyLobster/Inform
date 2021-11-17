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

@protocol ZoomGlkSaveRefDelegate;

///
/// GlkFileRef object that can be used to create a .glksave package
///
@class ZoomSkein;
@interface ZoomGlkSaveRef : NSObject<GlkFileRef> {
	//! The plugin specifying what is creating this fileref
	ZoomPlugIn* plugin;
	//! The path for this fileref
	NSString* path;
	
	//! The preview lines to save for this object
	NSArray<NSString*>* preview;
	//! The skein to save for this object (or the skein loaded for this object)
	ZoomSkein* skein;
	
	//! The delegate for this object
	id<ZoomGlkSaveRefDelegate> delegate;
	//! The autoflush flag
	BOOL autoflush;
}

// Initialisation
//! Initialises a saveref that saves files from the specified plugin object to the specified path
- (id) initWithPlugIn: (ZoomPlugIn*) plugin
				 path: (NSString*) path;

// Extra properties
//! Sets the delegate for this object (the delegate is retained)
@property (strong) id<ZoomGlkSaveRefDelegate> delegate;

//! An array of strings that can be used for the preview for this file
- (void) setPreview: (NSArray<NSString*>*) preview;
//! Sets the skein that will be saved with this reference
//! Retrieves a skein previously set with setSkein, or the skein most recently loaded for this file
@property (retain) ZoomSkein *skein;

@end

///
/// ZoomGlkSaveRef delegate methods
///
@protocol ZoomGlkSaveRefDelegate <NSObject>
@optional

//! Call back to indicate that we're reading from a specific save file
- (void) readingFromSaveFile: (ZoomGlkSaveRef*) file;

@end
