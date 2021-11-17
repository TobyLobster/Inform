//
//  GlkSessionProtocol.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 17/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#ifndef __GLKVIEW_GLKSESSIONPROTOCOL_H__
#define __GLKVIEW_GLKSESSIONPROTOCOL_H__

//
// Communications with an individual client session
//

#import <Foundation/Foundation.h>
#import <GlkView/GlkViewDefinitions.h>
#import <GlkView/GlkBuffer.h>
#import <GlkView/GlkStreamProtocol.h>
#import <GlkView/GlkEventProtocol.h>
#import <GlkView/GlkEventListenerProtocol.h>
#import <GlkView/GlkFileRefProtocol.h>
#import <GlkView/GlkFilePromptProtocol.h>
#import <GlkView/GlkImageSourceProtocol.h>

#include <sys/types.h>

NS_ASSUME_NONNULL_BEGIN

// Strings for the predefined glk file types
#define GlkFileUsageData		(@"GlkFileUsageData"		)
#define GlkFileUsageSavedGame	(@"GlkFileUsageSavedGame"	)
#define GlkFileUsageInputRecord	(@"GlkFileUsageInputRecord"	)
#define GlkFileUsageTranscript	(@"GlkFileUsageTranscript"	)
#define GlkFileUsageGameData	(@"GlkFileUsageGameData"	)
#define GlkFileUsageGameFile	(@"GlkFileUsageGameFile"	)

/// Structure representing a size in pixels or characters
typedef struct GlkSize {
	int width;
	int height;
} GlkSize;

/// Communications with an individual client session
@protocol GlkSession <NSObject>

// Housekeeping
- (void) clientHasStarted: (pid_t) processId;
- (void) clientHasFinished;
 
/// Receiving data from the buffer
- (void) performOperationsFromBuffer: (in bycopy GlkBuffer*) buffer;

// Windows
- (GlkSize) sizeForWindowIdentifier: (unsigned) windowId;

// Streams
- (nullable byref id<GlkStream>) streamForWindowIdentifier: (unsigned) windowId;
/// Stream created before the task was initialised (used, for example, for specifying which file was double-clicked on)
- (byref id<GlkStream>) inputStream;
/// Stream created before the task was initialised (used, for example, for specifying which file was double-clicked on)
- (nullable byref id<GlkStream>) streamForKey: (in bycopy NSString*) key;

// Styles
- (glui32) measureStyle: (glui32) styl
				   hint: (glui32) hint
			   inWindow: (glui32) windowId;

// Events
/// Cancel line events for the specified window (and get the input so far)
- (bycopy NSString*) cancelLineEventsForWindowIdentifier: (unsigned) windowIdentifier;

/// Request for the next event on the queue
- (nullable bycopy id<GlkEvent>) nextEvent;
/// Listener can be nil to indicate that no listener is required
- (void) setEventListener: (nullable in byref id<GlkEventListener>) listener;
/// Called to indicating that we're starting a glk_select call
- (void) willSelect;

/// Gets the sync count value (this is used to determine if information cached on the server is still relevant)
@property (nonatomic, readonly) NSInteger synchronisationCount;

// Errors and warnings
/// Shows an error message
- (void) showError: (in bycopy NSString*) error;
/// Shows a warning message
- (void) showWarning: (in bycopy NSString*) warning;
/// Shows a log message
- (void) logMessage: (in bycopy NSString*) message;
/// Shows a log message with a priority
- (void) logMessage: (in bycopy NSString*) message
	   withPriority: (int) priority;

// Filerefs
/// Returns \c NULL if the name is invalid (or if we're not supporting named files for some reason)
- (nullable id<GlkFileRef>) fileRefWithName: (in bycopy NSString*) name;
/// Temp files are automagically deleted when the session goes away
- (nullable id<GlkFileRef>) tempFileRef;

/// Returns the list of the preferred filetypes for the specified usage
- (nullable bycopy NSArray<NSString*>*) fileTypesForUsage: (in bycopy NSString*) usage;
/// Specifies the extensions that are valid for a particular type of file
- (void) setFileTypes: (in bycopy NSArray<NSString*>*) extensions
			 forUsage: (in bycopy NSString*) usage;
/// Will return quickly, then the handler will be told the results later
- (void) promptForFilesForUsage: (in bycopy NSString*) usage
					 forWriting: (BOOL) writing
						handler: (in byref id<GlkFilePrompt>) handler;
/// Will return quickly, then the handler will be told the results later
- (void) promptForFilesOfType: (in bycopy NSArray<NSString*>*) filetypes
				   forWriting: (BOOL) writing
					  handler: (in byref id<GlkFilePrompt>) handler;

// Images
/// Sets where we get our image data from
- (void) setImageSource: (in byref id<GlkImageSource>) newSource;
/// Retrieves the size of an image
- (NSSize) sizeForImageResource: (glui32) imageId;
/// Retrieves the active image source
- (out byref id<GlkImageSource>) imageSource;

/// The active image source.
@property (readwrite, retain, nonatomic) id<GlkImageSource> imageSource;
@end

NS_ASSUME_NONNULL_END

#endif
