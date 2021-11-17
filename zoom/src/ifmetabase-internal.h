/*
 *  ifmetabase-internal.h
 *  ZoomCocoa
 *
 *  Created by Andrew Hunter on 16/03/2006.
 *  Copyright 2006 Andrew Hunter. All rights reserved.
 *
 */

/*
 * Internal structure definitions for the metabase
 */

#ifndef __IFMETABASE_INTERNAL_H
#define __IFMETABASE_INTERNAL_H

#include "ifmetabase.h"

/* IFMetabase index entry structure */

typedef struct IFIndexEntry IFIndexEntry;

struct IFIndexEntry {
	IFID id;
	int storyNumber;
};

/* IFStory value structure */

typedef struct IFValue* IFValue;

struct IFValue {
	char* key;
	IFChar* value;
	
	int childCount;
	IFValue* children;
	
	IFValue parent;
};

/* The IFMetabase structure */

struct IFMetabase {
	int numStories;
	IFStory* stories;
	
	int numIndexEntries;
	IFIndexEntry* index;
};

/* The IFStory structure */

struct IFStory {
	IFMetabase metabase;
	
	int number;
	IFID id;
	
	IFValue root;
};

/* IFID structure */

struct IFID {
	enum IFID_type {
		ID_NULL,
		
		ID_UUID,
		ID_ZCODE,
		ID_GLULX,
		ID_GLULXNOTINFORM,
		ID_MD5,
		ID_GENERIC,
		ID_COMPOUND
	} type;
	
	union IFID_data {
		unsigned char uuid[16];
		
		struct IFID_md5 {
			unsigned char* systemId;
			unsigned char md5[16];			
		} md5;
		
		struct IFID_zcode {
			int release;
			char serial[6];
			int checksum;
		} zcode;
		
		struct IFID_glulx {
			int release;
			char serial[6];
			unsigned int checksum;
		} glulx;
		
		struct IFID_glulxNotInform {
			unsigned int memsize;
			unsigned int checksum;
		} glulxNotInform;
		
		struct IFID_generic {
			char* idString;
		} generic;
		
		struct IFID_compound {
			int count;
			IFID* ids;
			
			IFID* idsNotNull;
		} compound;
	} data;
};

/* Iterators */

struct IFStoryIterator {
	IFMetabase metabase;
	int count;
};

struct IFValueIterator {
	IFValue root;
	int count;
	
	char* key;
	char* path;
	char* pathBuf;
};

#endif
