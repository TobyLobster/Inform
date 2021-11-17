//
//  glk_files.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 16/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "GlkMemoryFileRef.h"

#include "glk.h"
#import "cocoaglk.h"
#import "glk_client.h"

static frefid_t cocoaglk_firstfref = NULL;
static NSMutableDictionary<NSNumber*,NSArray<NSString*>*>* cocoaglk_usagetypes = nil;
static NSMutableDictionary<NSString*,id<GlkFileRef>>* cocoaglk_fileref_bindings = nil;

#pragma mark - Prompt object

@interface GlkFilePrompt : NSObject<GlkFilePrompt> {
	id<GlkFileRef> ref;
	BOOL cancelled;
}

@property (retain, setter=promptedFileRef:) id<GlkFileRef> fileRef;
@property (readonly) BOOL cancelled;

@end

@implementation GlkFilePrompt
@synthesize fileRef = ref;

- (id) init {
	self = [super init];
	
	if (self) {
		ref = nil;
		cancelled = NO;
	}
	
	return self;
}

- (void) dealloc {
	[ref release];
	
	[super dealloc];
}

@synthesize cancelled;

- (void) promptCancelled {
	cancelled = YES;
}

@end

#pragma mark - Utility functions

static NSString* cocoaglk_key_for_usage(glui32 usage) {
	switch (usage) {
		case fileusage_Data:				return GlkFileUsageData;
		case fileusage_SavedGame:			return GlkFileUsageSavedGame;
		case fileusage_InputRecord:			return GlkFileUsageInputRecord;
		case fileusage_Transcript:			return GlkFileUsageTranscript;
		case fileusage_cocoaglk_GameData:	return GlkFileUsageGameData;
		case fileusage_cocoaglk_GameFile:	return GlkFileUsageGameFile;
		
		default:
			return [NSString stringWithFormat: @"Usage-%08x", usage];
	}
}

void cocoaglk_set_types_for_usage(glui32 usage, NSArray* extensions) {
	if (!cocoaglk_usagetypes) cocoaglk_usagetypes = [[NSMutableDictionary alloc] init];
	
	// Remember the usages locally
	[cocoaglk_usagetypes setObject: [[[NSArray alloc] initWithArray: extensions
														  copyItems: YES] autorelease]
							forKey: [NSNumber numberWithUnsignedInt: usage&fileusage_TypeMask]];
	
	// Also remember them in the main client
	[cocoaglk_session setFileTypes: extensions
						  forUsage: cocoaglk_key_for_usage(usage&fileusage_TypeMask)];
}

NSArray* cocoaglk_types_for_usage(glui32 usage) {
	// Retrieves a list of valid file types for a given usage
	NSArray* result = [cocoaglk_usagetypes objectForKey: [NSNumber numberWithUnsignedInt: usage&fileusage_TypeMask]];
	
	// Use the user-supplied values if they're available
	if (result) return result;
	
	// Try getting the value from the session
	result = [cocoaglk_session fileTypesForUsage: cocoaglk_key_for_usage(usage&fileusage_TypeMask)];
	
	if (result) {
		// Cache the value locally for future reference
		if (!cocoaglk_usagetypes) cocoaglk_usagetypes = [[NSMutableDictionary alloc] init];
		[cocoaglk_usagetypes setObject: [[[NSArray alloc] initWithArray: result
															  copyItems: YES] autorelease]
								forKey: [NSNumber numberWithUnsignedInt: usage&fileusage_TypeMask]];
		return result;
	}
	
	// Otherwise, use the defaults (which are convienient if you're writing a GLULX interpreter, but probably stupid otherwise)
	switch (usage&fileusage_TypeMask) {
		case fileusage_Data: return @[@"dat"];
		case fileusage_SavedGame: return @[@"sav"];
		case fileusage_InputRecord: return @[@"txt", @"rec"];
		case fileusage_Transcript: return @[@"txt"];

		case fileusage_cocoaglk_GameData: return @[@"blb"];
		case fileusage_cocoaglk_GameFile: return @[@"blb", @"ulx", @"glb", @"gblorb"];
			
		default: return nil;
	}
}

BOOL cocoaglk_frefid_sane(frefid_t ref) {
	// Check if ref is a 'valid' frefid
	if (ref == NULL) return NO;
	if (ref->key != GlkFileRefKey) return NO;
	
	// Programmer is a spoon type problems
	if (ref->last && ref == cocoaglk_firstfref) {
		NSLog(@"Oops: fref has a previous fref but is marked as the first");
		return NO;
	}
	
	if (!ref->last && ref != cocoaglk_firstfref) {
		NSLog(@"Oops: fref has no previous fref but is not the first");
		return NO;
	}
	
	return YES;
}

#pragma mark - Doing things with frefs

/// This creates a reference to a temporary file. It is always a new file
/// (one which does not yet exist). The file (once created) will be somewhere
/// out of the player's way. [[This is why no name is specified; the player
///	will never need to know it.]]
frefid_t glk_fileref_create_temp(glui32 usage, glui32 rock) {
	id<GlkFileRef> ref = [cocoaglk_session tempFileRef];
	if (!ref) return NULL;
	
	frefid_t res = malloc(sizeof(struct glk_fileref_struct));
	
	res->key = GlkFileRefKey;
	res->rock = rock;
	res->fileref = [ref retain];
	res->usage = usage;
	
	res->next = cocoaglk_firstfref;
	res->last = NULL;
	if (cocoaglk_firstfref) cocoaglk_firstfref->last = res;
	cocoaglk_firstfref = res;
	
	if (cocoaglk_register) {
		res->giRock = cocoaglk_register(res, gidisp_Class_Fileref);
	}

#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_fileref_create_temp(%u, %u) = %p", usage, rock, res);
#endif
		
	return res;
}

//
// This creates a reference to a file with a specific name. The file will
// be in a fixed location relevant to your program, and visible to the
// player. [[This usually means "in the same directory as your program."]]
//
frefid_t glk_fileref_create_by_name(glui32 usage, char *name,
									glui32 rock) {
	NSString* filename = [[[NSString alloc] initWithBytes: name
												   length: strlen(name)
												 encoding: NSISOLatin1StringEncoding] autorelease];
	id<GlkFileRef> ref = [cocoaglk_fileref_bindings objectForKey: filename];
	if (!ref) ref = [cocoaglk_session fileRefWithName: filename];
	if (!ref) return NULL;
	
	frefid_t res = malloc(sizeof(struct glk_fileref_struct));
	
	res->key = GlkFileRefKey;
	res->rock = rock;
	res->fileref = [ref retain];
	res->usage = usage;
	
	// Transcripts and input records must be autoflushed
	if ((usage&fileusage_TypeMask) == fileusage_Transcript
		|| (usage&fileusage_TypeMask) == fileusage_InputRecord) {
		[ref setAutoflush: YES];
	}
	
	res->next = cocoaglk_firstfref;
	res->last = NULL;
	if (cocoaglk_firstfref) cocoaglk_firstfref->last = res;
	cocoaglk_firstfref = res;
	
	if (cocoaglk_register) {
		res->giRock = cocoaglk_register(res, gidisp_Class_Fileref);
	}
	
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_fileref_create_by_name(%u, \"%s\", %u) = %p", usage, name, rock, res);
#endif
	
	return res;
}

//
// This creates a reference to a file by asking the player to locate
// it. The library may simply prompt the player to type a name, or may use
// a platform-native file navigation tool. (The prompt, if any, is inferred
// from the usage argument.)
//
frefid_t glk_fileref_create_by_prompt(glui32 usage, glui32 fmode,
									  glui32 rock) {
	// Flush the buffer so the display is up to date
	cocoaglk_flushbuffer("Creating a file by prompt");
	
	// Work out if we're reading or writing
	BOOL forWriting = NO;
	
	if (fmode == filemode_Write || fmode == filemode_WriteAppend) {
		forWriting = YES;
	} else {
		// filemode_ReadWrite is kind of an ambiguous case, but we go for a 'reading' style (ie, the file must exist)
		forWriting = NO;
	}
	
	// Create the prompt object
	GlkFilePrompt* prompt = [[GlkFilePrompt alloc] init];
	
	// Request that the prompt be run
	[cocoaglk_session promptForFilesForUsage: cocoaglk_key_for_usage(usage&fileusage_TypeMask)
								  forWriting: forWriting
									 handler: prompt];
	
	// Run until we get a result
	while (![prompt cancelled] && ![prompt fileRef]) {
		[[NSRunLoop currentRunLoop] acceptInputForMode: NSDefaultRunLoopMode
											beforeDate: [NSDate distantFuture]];
	}
	
	id<GlkFileRef> ref = [[prompt fileRef] retain];
	
	// Release the prompt
	[prompt release];
	
	if (!ref) {
#if COCOAGLK_TRACE
		NSLog(@"TRACE: glk_fileref_create_by_prompt(%u, %u, %u) = NULL", usage, fmode, rock);
#endif
		
		return NULL;				// We got nada
	}

	// Transcripts and input records must be autoflushed
	if ((usage&fileusage_TypeMask) == fileusage_Transcript
		|| (usage&fileusage_TypeMask) == fileusage_InputRecord) {
		[ref setAutoflush: YES];
	}
	
	// Create the fref
	frefid_t res = malloc(sizeof(struct glk_fileref_struct));
	
	res->key = GlkFileRefKey;
	res->rock = rock;
	res->fileref = ref;
	res->usage = usage;
	
	res->next = cocoaglk_firstfref;
	res->last = NULL;
	if (cocoaglk_firstfref) cocoaglk_firstfref->last = res;
	cocoaglk_firstfref = res;
	
	if (cocoaglk_register) {
		res->giRock = cocoaglk_register(res, gidisp_Class_Fileref);
	}

#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_fileref_create_by_prompt(%u, %u, %u) = %p", usage, fmode, rock, res);
#endif
	
	// We're done
	return res;
}

///
// This copies an existing file reference, but changes the usage. (The
// original fileref is not modified.)
//
// The use of this function can be tricky. If you change the type of the
// fileref (fileusage_Data, fileusage_SavedGame, etc), the new reference may
// or may not point to the same actual disk file. [[This generally depends
//	on whether the platform uses suffixes to indicate file type.]] If you
// do this, and open both file references for writing, the results are
// unpredictable. It is safest to change the type of a fileref only if it
// refers to a nonexistent file.
//
frefid_t glk_fileref_create_from_fileref(glui32 usage, frefid_t fref,
										 glui32 rock) {
	if (!cocoaglk_frefid_sane(fref)) {
		cocoaglk_error("glk_fileref_create_from_fileref called with an invalid frefid");
		return NULL;
	}
	
	frefid_t res = malloc(sizeof(struct glk_fileref_struct));
	
	res->key = GlkFileRefKey;
	res->rock = rock;
	res->fileref = [fref->fileref retain];
	res->usage = usage;
	
	res->next = cocoaglk_firstfref;
	res->last = NULL;
	if (cocoaglk_firstfref) cocoaglk_firstfref->last = res;
	cocoaglk_firstfref = res;
	
	if (cocoaglk_register) {
		res->giRock = cocoaglk_register(res, gidisp_Class_Fileref);
	}
	
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_fileref_create_from_fileref(%u, %p, %u) = %p", usage, fref, rock, res);
#endif
	
	return res;
}

//
// Destroys a fileref which you have created. This does *not* affect
// the disk file; it just reclaims the resources allocated by the
// glk_fileref_create... function.
// 
// It is legal to destroy a fileref after opening a file with it (while the
// file is still open.) The fileref is only used for the opening operation,
// not for accessing the file stream.
//
//		(Though in our case, destroying a temp fref usually results in the 
//		temp file being deleted. This is OK, though, because it just means
//		the temp file becomes anonymous)
//
void glk_fileref_destroy(frefid_t fref) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_fileref_destroy(%p)", fref);
#endif

	if (!cocoaglk_frefid_sane(fref)) {
		cocoaglk_error("glk_fileref_destroy called with an invalid frefid");
		return;
	}

	// Unregister the filereg
	if (cocoaglk_unregister) {
		cocoaglk_unregister(fref, gidisp_Class_Fileref, fref->giRock);
	}
	
	// Finish it off
	if (fref->last) fref->last->next = fref->next;
	if (fref->next) fref->next->last = fref->last;	
	if (fref == cocoaglk_firstfref) cocoaglk_firstfref = fref->next;
	
	fref->last = NULL;
	fref->next = NULL;

	fref->key = 0;
	[fref->fileref release];
	
	free(fref);
}

//
// This iterates through all the existing filerefs. See section 1.6.2,
// "Iterating Through Opaque Objects".
//
frefid_t glk_fileref_iterate(frefid_t fref, glui32 *rockptr) {
	frefid_t res = NULL;
	
	if (fref == NULL) {
		res = cocoaglk_firstfref;
	} else {
		if (!cocoaglk_frefid_sane(fref)) {
			cocoaglk_error("glk_fileref_iterate called with an invalid frefid");
			return NULL;
		}
		
		res = fref->next;
	}
	
	if (res && !cocoaglk_frefid_sane(res)) {
		cocoaglk_error("glk_fileref_iterate moved to an invalid frefid");
		return NULL;
	}
	
	if (res && rockptr) *rockptr = res->rock;
	
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_fileref_iterate(%p, %p=%u) = %p", fref, rockptr, rockptr?*rockptr:0, res);
#endif
	
	return res;
}

//
// This retrieves the fileref's rock value. See section 1.6.1, "Rocks".
//
glui32 glk_fileref_get_rock(frefid_t fref) {
	if (!cocoaglk_frefid_sane(fref)) {
		cocoaglk_error("glk_fileref_get_rock called with an invalid frefid");
		return 0;
	}

#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_fileref_get_rock(%p) = %u", fref, fref->rock);
#endif
		
	return fref->rock;
}

// 
// This deletes the file referred to by fref. It does not destroy the
// fileref itself.
//
void glk_fileref_delete_file(frefid_t fref) {
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_fileref_delete_file(%p)", fref);
#endif

	if (!cocoaglk_frefid_sane(fref)) {
		cocoaglk_error("glk_fileref_delete_file called with an invalid frefid");
		return;
	}
	
	[fref->fileref deleteFile];
}

//
// This returns TRUE (1) if the fileref refers to an existing file, and FALSE
// (0) if not.
//
glui32 glk_fileref_does_file_exist(frefid_t fref) {
	if (!cocoaglk_frefid_sane(fref)) {
		cocoaglk_error("glk_fileref_does_file_exist called with an invalid frefid");
		return 0;
	}
	
	glui32 res = 0;
	
	if ([fref->fileref fileExists]) {
		res = 1;
	} else {
		res = 0;
	}
	
#if COCOAGLK_TRACE
	NSLog(@"TRACE: glk_fileref_does_file_exist(%p) = %u", fref, res);
#endif
	
	return res;
}

//
// Unbinds a known filename
//
void cocoaglk_unbind_file(const char* filename) {
	// Sanity check
	if (filename == NULL) {
		cocoaglk_error("NULL filename passed to cocoaglk_unbind_file");
		return;
	}
	
	// Unbind this file
	NSString* name = [NSString stringWithUTF8String: filename];
	
	if (cocoaglk_fileref_bindings == nil || [cocoaglk_fileref_bindings objectForKey: name] == nil) {
		cocoaglk_warning("cocoaglk_unbind_file called with a filename that is already unbound");
		return;
	}
	
	[cocoaglk_fileref_bindings removeObjectForKey: name];
}

//
// Binds a filename to a specified block of memory (it will become a read-only memory file)
//
void cocoaglk_bind_memory_to_named_file(const unsigned char* memory, int length, const char* filename) {
	// Sanity check
	if (filename == NULL) {
		cocoaglk_error("NULL filename passed to cocoaglk_bind_memory_to_named_file");
		return;
	}
	
	if (memory == NULL) {
		cocoaglk_error("NULL memory block passed to cocoaglk_bind_memory_to_named_file");
		return;		
	}
	
	if (length < 0) {
		cocoaglk_error("Negative length passed to cocoaglk_bind_memory_to_named_file");
		return;		
	}
	
	if (cocoaglk_fileref_bindings == nil) cocoaglk_fileref_bindings = [[NSMutableDictionary alloc] init];
	
	// Bind this file
	NSString* name = [NSString stringWithUTF8String: filename];
	
	NSData* data = [NSData dataWithBytesNoCopy: (unsigned char*)memory
										length: length];
	GlkMemoryFileRef* fileref = [[[GlkMemoryFileRef alloc] initWithData: data] autorelease];
	[cocoaglk_fileref_bindings setObject: fileref
								  forKey: name];
}

#import <GlkView/GlkFileRef.h>

frefid_t cocoaglk_open_file(NSURL *path, glui32 textmode,
							glui32 rock)
{
	// Create the fref
	frefid_t res = malloc(sizeof(struct glk_fileref_struct));
	
	res->key = GlkFileRefKey;
	res->rock = rock;
	res->fileref = [[GlkFileRef alloc] initWithPath:path];
	res->usage = textmode == TRUE ? fileusage_TextMode : fileusage_BinaryMode;
	
	res->next = cocoaglk_firstfref;
	res->last = NULL;
	if (cocoaglk_firstfref) cocoaglk_firstfref->last = res;
	cocoaglk_firstfref = res;
	
	if (cocoaglk_register) {
		res->giRock = cocoaglk_register(res, gidisp_Class_Fileref);
	}

#if COCOAGLK_TRACE
	NSLog(@"TRACE: cocoaglk_open_file(%@, %u, %u) = %p", path, textmode, rock, res);
#endif
	
	// We're done
	return res;

}
