//
//  GlkSessionProtocol.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 17/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

//
// Communications with an individual client session
//

#import "GlkBuffer.h"
#import "GlkStreamProtocol.h"
#import "GlkEventProtocol.h"
#import "GlkEventListenerProtocol.h"
#import "GlkFileRefProtocol.h"
#import "GlkFilePromptProtocol.h"
#import "GlkImageSourceProtocol.h"

#include <sys/types.h>

// Strings for the predefined glk file types
#define GlkFileUsageData		(@"GlkFileUsageData"		)
#define GlkFileUsageSavedGame	(@"GlkFileUsageSavedGame"	)
#define GlkFileUsageInputRecord	(@"GlkFileUsageInputRecord"	)
#define GlkFileUsageTranscript	(@"GlkFileUsageTranscript"	)
#define GlkFileUsageGameData	(@"GlkFileUsageGameData"	)
#define GlkFileUsageGameFile	(@"GlkFileUsageGameFile"	)

// Structure representing a size in pixels or characters
typedef struct GlkSize GlkSize;
struct GlkSize {
	int width;
	int height;
};

@protocol GlkSession

// Housekeeping
- (void) clientHasStarted: (pid_t) processId;
- (void) clientHasFinished;
 
// Receiving data from the buffer
- (void) performOperationsFromBuffer: (in bycopy GlkBuffer*) buffer;

// Windows
- (GlkSize) sizeForWindowIdentifier: (unsigned) windowId;

// Streams
- (byref NSObject<GlkStream>*) streamForWindowIdentifier: (unsigned) windowId;
- (byref NSObject<GlkStream>*) inputStream;													// Stream created before the task was initialised (used, for example, for specifying which file was double-clicked on)
- (byref NSObject<GlkStream>*) streamForKey: (in bycopy NSString*) key;						// Stream created before the task was initialised (used, for example, for specifying which file was double-clicked on)

// Styles
- (glui32) measureStyle: (glui32) styl
				   hint: (glui32) hint
			   inWindow: (glui32) windowId;

// Events
- (bycopy NSString*) cancelLineEventsForWindowIdentifier: (unsigned) windowIdentifier;		// Cancel line events for the specified window (and get the input so far)

- (bycopy NSObject<GlkEvent>*) nextEvent;													// Request for the next event on the queue
- (void) setEventListener: (in byref NSObject<GlkEventListener>*) listener;					// Listener can be nil to indicate that no listener is required
- (void) willSelect;																		// Called to indicating that we're starting a glk_select call

- (int)  synchronisationCount;																// Gets the sync count value (this is used to determine if information cached on the server is still relevant)

// Errors and warnings
- (void) showError: (in bycopy NSString*) error;											// Shows an error message
- (void) showWarning: (in bycopy NSString*) warning;										// Shows a warning message
- (void) logMessage: (in bycopy NSString*) message;											// Shows a log message
- (void) logMessage: (in bycopy NSString*) message											// Shows a log message with a priority
	   withPriority: (int) priority;

// Filerefs
- (NSObject<GlkFileRef>*) fileRefWithName: (in bycopy NSString*) name;						// Returns NULL if the name is invalid (or if we're not supporting named files for some reason)
- (NSObject<GlkFileRef>*) tempFileRef;														// Temp files are automagically deleted when the session goes away

- (bycopy NSArray*) fileTypesForUsage: (in bycopy NSString*) usage;							// Returns the list of the preferred filetypes for the specified usage
- (void) setFileTypes: (in bycopy NSArray*) extensions										// Specifies the extensions that are valid for a particular type of file
			 forUsage: (in bycopy NSString*) usage;	
- (void) promptForFilesForUsage: (in bycopy NSString*) usage								// Will return quickly, then the handler will be told the results later
					 forWriting: (BOOL) writing
						handler: (in byref NSObject<GlkFilePrompt>*) handler;
- (void) promptForFilesOfType: (in bycopy NSArray*) filetypes								// Will return quickly, then the handler will be told the results later
				   forWriting: (BOOL) writing
					  handler: (in byref NSObject<GlkFilePrompt>*) handler;

// Images
- (void) setImageSource: (in byref id<GlkImageSource>) newSource;							// Sets where we get our image data from
- (NSSize) sizeForImageResource: (glui32) imageId;											// Retrieves the size of an image
- (out byref id<GlkImageSource>) imageSource;												// Retrieves the active image source

@end
