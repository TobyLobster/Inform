/*
 *  ifmetabase.h
 *  ZoomCocoa
 *
 *  Created by Andrew Hunter on 14/03/2005
 *  Copyright 2005 Andrew Hunter. All rights reserved.
 */

#ifndef __IFMETABASE_H
#define __IFMETABASE_H

/*
 * The metabase is a set of functions designed for creating and manipulating metadata in the
 * 'iFiction' format. It deals with the metadata in an abstract sense: this library does not
 * define the external format of the data.
 *
 * A note on 'compound' IDs: these are intended for a story that has multiple possible IDs.
 * The searching routines will return a story that contains any one of the IDs. So if you
 * have a story with ID ZCODE-01-010101 and you search for a compound ID with 
 * (ZCODE-02-020202, ZCODE-01-010101) you will get that story. BUT if no story exists with
 * either ID yet, you will get a new story that has both IDs. Searching for either ID will
 * produce the same story.
 *
 * Compound IDs are searched for in left-to-right order, so when using them, put the most
 * relevant identifier first. (Eg, if using an MD5 identifier on a ZCode story, put it
 * last, after the Zcode identifier). This ensures that the metabase always makes some
 * sort of sense: doing this the other way round means that it's possible an entry won't
 * be found for the zcode identifier, but will for the md5 one.
 *
 * These functions are not thread-safe, but should be re-entrant. That is, you can use
 * this in multi-threaded applications provided that you use locks with individual 
 * metabases.
 */

/* Data structures */

typedef unsigned short IFChar;						/*!< A UTF-16 character */

typedef struct IFMetabase* IFMetabase;				/*!< A metabase */
typedef struct IFID* IFID;							/*!< A story identifier */
typedef struct IFStory* IFStory;					/*!< A story entry in the metabase */

typedef struct IFStoryIterator* IFStoryIterator;	/*!< An iterator that covers all stories */
typedef struct IFValueIterator* IFValueIterator;	/*!< An iterator that covers the values set for a story */

/* Functions - general metabase manipulation */

/*! Constructs a new, empty metabase */
extern IFMetabase IFMB_Create(void);

/*! Frees up all the memory associated with a metabase */
extern void IFMB_Free(IFMetabase meta);

/* Functions - IFIDs */

/*! Takes an ID string and produces a corresponding IFID structure, or NULL if the string is invalid */
extern IFID IFMB_IdFromString(const char* idString);

/*! Takes an IFID and returns a string representation (the caller must free this) */
extern char* IFMB_IdToString(IFID id);

/*! Returns an IFID based on the 16-byte UUID passed as an argument */
extern IFID IFMB_UUID(const unsigned char* uuid);

/*! Returns an IFID based on a Z-Code legacy identifier */
extern IFID IFMB_ZcodeId(int release, const char* serial, int checksum);

/*! Returns an IFID based on a glulx identifier from an Inform-created game */
extern IFID IFMB_GlulxId(int release, const char* serial, unsigned int checksum);

/*! Returns an IFID based on a generic glulx identifier */
extern IFID IFMB_GlulxIdNotInform(unsigned int memsize, unsigned int checksum);

/*! Returns an IFID based on a MD5 identifier */
extern IFID IFMB_Md5Id(const unsigned char* md5, const char* systemId);

/*! Merges a set of IFIDs into a single ID */
extern IFID IFMB_CompoundId(int count, IFID* identifiers);

/*! Retrieves the IDs that make up a compound ID: number is returned in count. Returns \c NULL if the ID is not compound */
extern IFID* IFMB_SplitId(IFID id, int* count);

/*! Compares two IDs */
extern int IFMB_CompareIds(IFID a, IFID b);

/*! Frees an ID */
extern void IFMB_FreeId(IFID ident);

/*! Copies an ID */
extern IFID IFMB_CopyId(IFID ident);

/* Functions - stories */

/*! Retrieves the story in the metabase with the given ID */
extern IFStory IFMB_GetStoryWithId(IFMetabase meta, IFID ident);

/*! Retrieves the ID associated with a given story object */
extern IFID IFMB_IdForStory(IFStory story);

/*! Removes a story with the given ID from the metabase */
extern void IFMB_RemoveStoryWithId(IFMetabase meta, IFID ident);

/*! Copies a story, optionally from another metabase, optionally to a new ID. id can be \c NULL to create the copy with the same ID as the original */
extern void IFMB_CopyStory(IFMetabase meta, IFStory story, IFID id);

/*! Returns non-zero if the metabase contains a story with a given ID */
extern int IFMB_ContainsStoryWithId(IFMetabase meta, IFID ident);

/*! Returns a UTF-16 string for a given parameter in a story, or \c NULL if none was found
 
 Copy this value away if you intend to retain it: it may be destroyed on the next IFMB_ call */
extern IFChar* IFMB_GetValue(IFStory story, const char* valueKey);

/*! Sets the UTF-16 string for a given parameter in the story (\c NULL to unset the parameter) */
extern void IFMB_SetValue(IFStory story, const char* valueKey, IFChar* utf16value);

/*! Adds a duplicate value key. This duplicate key is the one that is accessed by the Set/Get value operators: iteration functions can be used to access the other values
 
 Use this before calling \c IFMB_SetValue to set multiple values for the same key */
extern void IFMB_AddValue(IFStory story, const char* valueKey);

/* Functions - iterating */

/*! Gets an iterator covering all the stories in the given metabase */
extern IFStoryIterator IFMB_GetStoryIterator(IFMetabase meta);

/*! Gets an iterator covering all the values set in a story */
extern IFValueIterator IFMB_GetValueIterator(IFStory story);

/*! Gets an iterator for all the values sharing a key */
extern IFValueIterator IFMB_GetValueIteratorForKey(IFStory story, const char* valueKey);

/*! Gets the next story defined in the metabase */
extern IFStory IFMB_NextStory(IFStoryIterator iter);

/*! Moves to the next (or first) value: returns 0 if finished */
extern int IFMB_NextValue(IFValueIterator iter);

/*! Retrieves the key from a value iterator */
extern char* IFMB_KeyFromIterator(IFValueIterator iter);

/*! Retrieves the last part of the key from a value iterator */
extern char* IFMB_SubkeyFromIterator(IFValueIterator iter);

/*! Retrieves the string value from a value iterator */
extern IFChar* IFMB_ValueFromIterator(IFValueIterator iter);

/*! Deletes the value pointed to by this iterator (and any subvalues) */
extern void IFMB_DeleteIteratorValue(IFValueIterator iter);

/*! Sets the value for an iterator */
extern void IFMB_SetIteratorValue(IFValueIterator iter, IFChar* utf16value);

/*! Retrieves an iterator for the nodes underneath a given value (or \c NULL if there are none) */
extern IFValueIterator IFMB_ChildrenFromIterator(IFValueIterator iter);

/* Frees the two types of iterator */
extern void IFMB_FreeStoryIterator(IFStoryIterator iter);
extern void IFMB_FreeValueIterator(IFValueIterator iter);

/* Functions - basic UTF-16 string manipulation */

extern int IFMB_StrLen(const IFChar* a);
extern int IFMB_StrCmp(const IFChar* a, const IFChar* b);
extern void IFMB_StrCpy(IFChar* a, const IFChar* b);

#endif
