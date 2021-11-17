/*
 *  ifmetabase.c
 *  ZoomCocoa
 *
 *  Created by Andrew Hunter on 14/03/2005
 *  Copyright 2005 Andrew Hunter. All rights reserved.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "ifmetabase.h"
#include "ifmetabase-internal.h"

/* Functions - general metabase manipulation */

static void FreeValue(IFValue value) {
	int x;
	
	for (x=0; x<value->childCount; x++) {
		FreeValue(value->children[x]);
	}
	
	if (value->children != NULL) free(value->children);
	if (value->value != NULL) free(value->value);
	if (value->key != NULL) free(value->key);
	
	free(value);
}

static IFValue CopyValue(IFValue value) {
	int x;
	IFValue result;
	
	if (value == NULL) return NULL;
	
	result = malloc(sizeof(struct IFValue));
	
	result->key = NULL;
	result->value = NULL;
	result->childCount = value->childCount;
	result->children = malloc(sizeof(IFValue)*value->childCount);
	result->parent = NULL;
	
	if (value->key != NULL) {
		result->key = malloc(sizeof(char)*(strlen(value->key)+1));
		strcpy(result->key, value->key);
	}
	
	if (value->value != NULL) {
		result->value = malloc(sizeof(IFChar)*(IFMB_StrLen(value->value)+1));
		IFMB_StrCpy(result->value, value->value);
	}
	
	for (x=0; x<value->childCount; x++) {
		result->children[x] = CopyValue(value->children[x]);
		result->children[x]->parent = result;
	}
	
	return result;
}

static void FreeStory(IFStory story) {
	FreeValue(story->root);
	IFMB_FreeId(story->id);
	free(story);
}

/* Constructs a new, empty metabase */
IFMetabase IFMB_Create() {
	IFMetabase result = malloc(sizeof(struct IFMetabase));
	
	result->numStories = 0;
	result->numIndexEntries = 0;
	result->stories = NULL;
	result->index = NULL;
	
	return result;
}

/* Frees up all the memory associated with a metabase */
void IFMB_Free(IFMetabase meta) {
	int x;
	
	for (x=0; x<meta->numStories; x++) {
		if (meta->stories[x] != NULL) FreeStory(meta->stories[x]);
	}
	
	if (meta->index != NULL) free(meta->index);
	if (meta->stories != NULL) free(meta->stories);
	free(meta);
}

/* Functions - IFIDs */

/* Retrieves the hexidecimal value of c */
static int hex(char c) {
	/* Various possible values for a hex number */
	if (c >= '0' && c <= '9') return c - '0';
	if (c >= 'A' && c <= 'F') return c - 'A' + 10;
	if (c >= 'a' && c <= 'f') return c - 'a' + 10;
	
	/* Not a hex value */
	return -1;
}

/* Retrieves the numeric value of a character */
static int num(char c) {
	if (c >= '0' && c <= '9') return c - '0';
	
	/* Not a numeric value */
	return -1;
}

/* Reads a positive number from val, putting the length in len */
static int number(const char* val, int* len) {
	int number = 0;
	int x;
	
	for (x=0; val[x] != 0; x++) {
		int digitVal;
		
		digitVal = num(val[x]);
		if (digitVal < 0) break;
		
		number *= 10;
		number += digitVal;
	}
	
	*len = x;
	if (x == 0) return -1;
	
	return number;
}

/* Reads a positive hexadecimal from val, putting the length in len */
static unsigned int hexnumber(const char* val, int* len) {
	unsigned int number = 0;
	int x;
	
	for (x=0; val[x] != 0; x++) {
		int digitVal;
		
		digitVal = hex(val[x]);
		if (digitVal < 0) break;
		
		number *= 16;
		number += digitVal;
	}
	
	*len = x;
	if (x == 0) return 0xffffffff;
	
	return number;
}

/* Returns if c is whitespace or not */
static int whitespace(char c) {
	return c == ' ' || c == '\t' || c == '\n' || c == '\r';
}

/* Allocates a generic ID based on a specific string */
static IFID IFMB_GenericId(const char* idString) {
	IFID result;
	
	result = malloc(sizeof(struct IFID));
	result->type = ID_GENERIC;
	
	result->data.generic.idString = malloc((strlen(idString)+1)*sizeof(char));
	strcpy(result->data.generic.idString, idString);
	
	return result;	
}

/* Takes an ID string and produces a corresponding IFID structure, or NULL if the string is invalid */
IFID IFMB_IdFromString(const char* idString) {
	/* 
	 * IFIDs have the following possible forms: 
	 *
	 * 1974A053-7DB0-4103-93A1-767C1382C0B7 (a uuid - GLULX/ZCODE, possibly others later?)
	 * UUID://1974A053-7DB0-4103-93A1-767C1382C0B7// (a uuid - GLULX/ZCODE, possibly others later?)
	 * ZCODE-11-271781 (zcode, release + serial)
	 * ZCODE-11------- (zcode, release no serial)
	 * ZCODE-11-278162-8267 (zcode, release + serial + checksum)
	 * GLULX-12359abc-263a6bf1 (glulx, memsize + checksum)
	 * GLULX-11-287367-27382917 (glulx, release + serial + checksum)
	 * TADS-78372173827931 (TADS, MD5 sum - treated identically to a MD5 sum)
	 * HUGO-78372173827931 (HUGO, MD5 sum - treated identically to a MD5 sum)
	 * 67687abe6717cef (MD5 sum)
	 */
	
	int x;
	size_t idLen;
	char lowerPrefix[10]="";
	int systemLen;
	int pos;
	unsigned char md5[16];
	IFID md5Id;
	char system[16];
	
	/* NULL string indicates a NULL ID */
	if (idString == NULL) return NULL;
	
	/* Skip any initial whitespace */
	while (whitespace(*idString)) idString++;
	
	/* Convert the start of the string to lowercase */
	for (x=0; x<10 && idString[x] != 0; x++) {
		lowerPrefix[x] = tolower(idString[x]);
	}
	
	/* Record the length of the string */
	idLen = strlen(idString);
	
	/* Try to parse a UUID */
	if ((idLen >= 39 && lowerPrefix[0] == 'u' && lowerPrefix[1] == 'u' && lowerPrefix[2] == 'i' && lowerPrefix[3] == 'd' && idString[4] == ':' && idString[5] == '/' && idString[6] == '/')
		|| (idLen == 36 && lowerPrefix[8] == '-')) {
		/* String begins with UUID://, characters 7 onwards make up the UUID itself, we're fairly casual about the parsing */
		unsigned char uuid[16];			/* The that we've retrieved */
		int uuidPos = 0;				/* The nybble that we're currently reading */
		int chrNum;
		int uuidStart = 7;
		
		if (idLen == 36) uuidStart = 0;
		
		/* Clear the UUID */
		for (chrNum=0; chrNum<16; chrNum++) uuid[chrNum] = 0;
		
		/* Iterate through the IFID string */
		for (chrNum=uuidStart; uuidPos < 32 && chrNum < idLen; chrNum++) {
			char uuidChar;
			int hexValue;
			
			uuidChar = idString[chrNum];
			
			/* '-' is permitted as a divided: for the purposes of parsing, we allow many or none of these, which allows us to parse some invalid UUIDs */
			if (uuidChar == '-') continue;
			
			/* Get and check the hexidecimal value of this character (not a valid IFID if this is not a hex value) */
			hexValue = hex(uuidChar);
			if (hexValue < -1) return NULL;
			
			/* Or it into the uuid value */
			uuid[uuidPos>>1] |= hexValue<<(4*(1-(uuidPos&1)));
			uuidPos++;
		}
		
		/* If we haven't got 32 nybbles, then this is not a UUID */
		if (uuidPos != 32) return NULL;
		
		/* Remaining characters must be '/' or whitespace only */
		for (; chrNum < idLen; chrNum++) {
			if (!whitespace(idString[chrNum]) && idString[chrNum] != '/') return NULL;
		}
		
		/* This is a UUID: return a suitable ID structure */
		return IFMB_UUID(uuid);
	}
	
	/* Try to parse a ZCODE IFID */
	if (idLen >= 14 && lowerPrefix[0] == 'z' && lowerPrefix[1] == 'c' && lowerPrefix[2] == 'o' && lowerPrefix[3] == 'd' && lowerPrefix[4] == 'e' && idString[5] == '-') {
		/* String begins with ZCODE- should be followed by a */
		int release = -1;
		char serial[6];
		unsigned int checksum = -1;
		int x, len, pos;
		
		/* Clear the serial number */
		for (x=0; x<6; x++) serial[x] = 0;
		
		/* Get the release number */
		release = number(idString + 6, &len);
		if (release < 0) return NULL;
		
		pos = 6+len;
		if (idString[pos] != '-') return NULL;
		pos++;
		
		/* Next 6 characters are the serial # */
		for (x=0; x<6; x++) {
			serial[x] = idString[pos++];
		}
		
		/* The checksum is optional (though highly recommended) */
		if (idString[pos] == '-') {
			pos++;
			
			checksum = hexnumber(idString + pos, &len);
			if (len == 0) return NULL;
			if (checksum > 0xffff) return NULL;
			
			pos += len;
		}
		
		/* The rest of the string should be just whitespace (if anything) */
		for (; pos < idLen; pos++) {
			if (!whitespace(idString[pos])) return NULL;
		}
		
		/* Return a Z-Code story ID */
		return IFMB_ZcodeId(release, serial, checksum);
	}
	
	/* GLULX IFIDs are much like zcode IDs, except the checksum is 32-bit */
	if (idLen >= 14 && lowerPrefix[0] == 'g' && lowerPrefix[1] == 'l' && lowerPrefix[2] == 'u' && lowerPrefix[3] == 'l' && lowerPrefix[4] == 'x' && idString[5] == '-') {
		/* String begins with ZCODE- should be followed by a */
		int release = -1;
		char serial[6];
		unsigned int checksum = -1;
		int x, len, pos;
		int numeric;
		int hexadecimal;
		
		/* Clear the serial number */
		for (x=0; x<6; x++) serial[x] = 0;
		
		/* Next few characters are either the release number, or a hexadecimal indication of initial memory map size */
		/* It is supposed that release numbers won't ever approach 8 characters in length */
		numeric = 1;
		hexadecimal = 1;
		for (x=6; idString[x] != '-' && idString[x] != 0; x++) {
			if (idString[x] < '0' || idString[x] > '9') numeric = 0;
			else if ((idString[x] < 'a' || idString[x] > 'f')  && (idString[x] < 'A' || idString[x] > 'F')) hexadecimal = 0;
		}
		
		if (x >= 14) {
			/* Format is GLULX-memsize-checksum */
			unsigned int memsize = -1;
			
			/* Starts with memory size */
			memsize = hexnumber(idString + 6, &len);
			if (len == 0) return NULL;
			
			/* This is followed by a checksum */
			pos = 6 + len;
			if (idString[pos] != '-') return NULL;
			
			pos++;
			checksum = hexnumber(idString + pos, &len);
			if (len == 0) return NULL;
			
			pos += len;
			
			/* The rest of the string should be just whitespace (if anything) */
			for (; pos < idLen; pos++) {
				if (!whitespace(idString[pos])) return NULL;
			}
			
			return IFMB_GlulxIdNotInform(memsize, checksum);
		} else {
			/* Format is GLULX-release-serial-checksum */

			/* Get the release number */
			release = number(idString + 6, &len);
			if (release < 0) return NULL;
			
			pos = 6+len;
			if (idString[pos] != '-') return NULL;
			pos++;
			
			/* Next 6 characters are the serial # */
			for (x=0; x<6; x++) {
				serial[x] = idString[pos++];
			}
			
			/* The checksum is mandatory for GLULX games */
			if (idString[pos] != '-') return NULL;
			
			pos++;
			
			checksum = hexnumber(idString + pos, &len);
			if (len == 0) return NULL;
			
			pos += len;
			
			/* The rest of the string should be just whitespace (if anything) */
			for (; pos < idLen; pos++) {
				if (!whitespace(idString[pos])) return NULL;
			}
			
			/* Return a GLULX story ID */
			return IFMB_GlulxId(release, serial, checksum);
		}
	}
	
	/* MD5sum identifiers are treated identically */
	pos = 0;
	
	/* Work out how long the system specifier is */
	systemLen = 0;
	for (; systemLen < 8 && idString[systemLen] != 0 && idString[systemLen] != '-'; systemLen++) {
		system[systemLen] = idString[systemLen];
	}
	system[systemLen] = 0;
	if (idString[systemLen] != '-') systemLen = 0;
	pos += systemLen;
	
	/* Rest of the string should be an MD5 specifier (32 hexadecimal characters). If not, treat this as a generic ID */
	for (x=0; x<16; x++) md5[x] = 0;
	
	x = 0;
	for (; idString[pos] != 0 && !whitespace(idString[pos]); pos++) {
		int hexValue;
		
		hexValue = hex(idString[pos]);
		if (hexValue < 0) return IFMB_GenericId(idString);
		
		if (x >= 32) break;
		md5[x>>1] |= hexValue<<(4*(1-(x&1)));

		x++;
	}
	
	if (x < 32) return IFMB_GenericId(idString);
	
	for (; idString[pos] != 0; pos++) {
		if (!whitespace(idString[pos])) return IFMB_GenericId(idString);
	}
	
	/* Is a TADS/generic MD5 string */
	md5Id = IFMB_Md5Id(md5, systemLen>0?system:NULL);
	return md5Id;
}

static char* Append(char* string, char* toAppend) {
	string = realloc(string, sizeof(char)*(strlen(string)+strlen(toAppend)+1));
	strcat(string, toAppend);
	
	return string;
}

/* Takes an IFID and returns a string representation (the caller must free this) */
char* IFMB_IdToString(IFID id) {
	char buffer[128];
	char* result = malloc(sizeof(char));
	unsigned char* code;
	int x;
	
	result[0] = 0;
	
	switch (id->type) {
		case ID_GENERIC:
			result = Append(result, id->data.generic.idString);
			break;
		
		case ID_UUID:
			result = Append(result, "UUID://");
			
			code = id->data.uuid;
			snprintf(buffer, 128, "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
					 code[0], code[1], code[2], code[3], code[4], code[5], code[6], code[7], 
					 code[8], code[9], code[10], code[11], code[12], code[13], code[14], code[15]);
			result = Append(result, buffer);
			
			result = Append(result, "//");
			break;
		
		case ID_ZCODE:
			if (id->data.zcode.checksum >= 0) {
				snprintf(buffer, 128, "ZCODE-%i-%.6s-%04X", id->data.zcode.release, id->data.zcode.serial, id->data.zcode.checksum);
			} else {
				snprintf(buffer, 128, "ZCODE-%i-%.6s", id->data.zcode.release, id->data.zcode.serial);
			}
			
			result = Append(result, buffer);
			break;
			
		case ID_GLULX:
			snprintf(buffer, 128, "GLULX-%i-%.6s-%08X", id->data.glulx.release, id->data.glulx.serial, id->data.glulx.checksum);
			result = Append(result, buffer);
			break;
			
		case ID_GLULXNOTINFORM:
			snprintf(buffer, 128, "GLULX-%08X-%08X", id->data.glulxNotInform.memsize, id->data.glulxNotInform.checksum);
			result = Append(result, buffer);
			break;
			
		case ID_MD5:
			if (id->data.md5.systemId != NULL) {
				snprintf(buffer, 128, "%s-", id->data.md5.systemId);
				result = Append(result, buffer);
			}
			for (x=0; x<16; x++) {
				snprintf(buffer, 128, "%02X", id->data.md5.md5[x]);
				result = Append(result, buffer);
			}
			break;
			
		case ID_COMPOUND:
		case ID_NULL:
			result = Append(result, "NULL");
			break;
		
		default:
			result = Append(result, "-UNKNOWN-");
	}
	
	return result;
}

/* Returns an IFID based on the 16-byte UUID passed as an argument */
IFID IFMB_UUID(const unsigned char* uuid) {
	IFID result;
	
	result = malloc(sizeof(struct IFID));
	result->type = ID_UUID;
	
	memcpy(result->data.uuid, uuid, 16);
	
	return result;
}

/* Returns an IFID based on a Z-Code legacy identifier */
IFID IFMB_ZcodeId(int release, const char* serial, int checksum) {
	IFID result;
	
	result = malloc(sizeof(struct IFID));
	result->type = ID_ZCODE;
	
	result->data.zcode.release = release;
	memcpy(result->data.zcode.serial, serial, 6);
	result->data.zcode.checksum = checksum;
	
	return result;
}

/* Returns an IFID based on a glulx identifier from an Inform-created game */
IFID IFMB_GlulxId(int release, const char* serial, unsigned int checksum) {
	IFID result;
	
	result = malloc(sizeof(struct IFID));
	result->type = ID_GLULX;
	
	result->data.glulx.release = release;
	memcpy(result->data.glulx.serial, serial, 6);
	result->data.glulx.checksum = checksum;
	
	return result;
}

/* Returns an IFID based on a generic glulx identifier */
IFID IFMB_GlulxIdNotInform(unsigned int memsize, unsigned int checksum) {
	IFID result;
	
	result = malloc(sizeof(struct IFID));
	result->type = ID_GLULXNOTINFORM;
	
	result->data.glulxNotInform.memsize = memsize;
	result->data.glulxNotInform.checksum = checksum;
	
	return result;
}

/* Returns an IFID based on a MD5 identifier */
IFID IFMB_Md5Id(const unsigned char* md5, const char* systemId) {
	IFID result;
	
	result = malloc(sizeof(struct IFID));
	result->type = ID_MD5;
	result->data.md5.systemId = NULL;
	if (systemId) {
		result->data.md5.systemId = malloc(sizeof(char)*(strlen(systemId)+1));
		strcpy(result->data.md5.systemId, systemId);
	}
	
	memcpy(result->data.md5.md5, md5, 16);
	
	return result;
}

/* Merges a set of IFIDs into a single ID */
static int countIds(IFID compoundId) {
	/* Count the number of IDs in the flattened version of compoundId */
	if (compoundId->type == ID_NULL) {
		return 0;
	} else if (compoundId->type == ID_COMPOUND) {
		int x, count;
		
		count = 0;
		for (x=0; x<compoundId->data.compound.count; x++) {
			count += countIds(compoundId->data.compound.ids[x]);
		}
		
		return count;
	} else {
		return 1;
	}
}

static IFID* flattenIds(IFID compoundId, IFID* start) {
	/* Flatten out the IDs in the compound ID into start (copies the IDs) */
	if (compoundId->type == ID_NULL) {
		return start;
	} else if (compoundId->type == ID_COMPOUND) {
		int x;
		IFID* pos = start;
		
		for (x=0; x<compoundId->data.compound.count; x++) {
			pos = flattenIds(compoundId->data.compound.ids[x], pos);
		}
		
		return pos;
	} else {
		*start = IFMB_CopyId(compoundId);
		return start+1;
	}
}

IFID IFMB_CompoundId(int count, IFID* identifiers) {
	IFID result;
	int x, numIds;
	IFID* lastId;
	
	result = malloc(sizeof(struct IFID));
	result->type = ID_COMPOUND;
	
	numIds = 0;
	for (x=0; x < count; x++) {
		numIds += countIds(identifiers[x]);
	}

	result->data.compound.count = numIds;
	result->data.compound.ids = malloc(sizeof(IFID)*numIds);
	result->data.compound.idsNotNull = NULL;
	
	lastId = result->data.compound.ids;
	for (x=0; x < count; x++) {
		lastId = flattenIds(identifiers[x], lastId);
	}
	
	return result;
}


/* Retrieves the IDs that make up a compound ID: number is returned in count. Returns NULL if the ID is not compound */
IFID* IFMB_SplitId(IFID id, int* count) {
	*count = 1;
	if (id->type != ID_COMPOUND) return NULL;
	
	if (id->data.compound.idsNotNull == NULL) {
		int start, end, x;
		
		/* idsNotNull contains the IDs in this compound ID with the ID_NULL ones moved to the end */
		id->data.compound.idsNotNull = malloc(sizeof(IFID)*id->data.compound.count);
		
		start = 0;
		end = id->data.compound.count-1;
		
		for (x=0; x<id->data.compound.count; x++) {
			IFID thisID = id->data.compound.ids[x];
			
			if (thisID->type == ID_NULL) {
				id->data.compound.idsNotNull[end--] = thisID;
			} else {
				id->data.compound.idsNotNull[start++] = thisID;
			}
		}
	}
	
	for ((*count)=0; *count < id->data.compound.count && id->data.compound.idsNotNull[*count]->type != ID_NULL;)
		 (*count)++;
	
	return id->data.compound.idsNotNull;
}

/* Compares two IDs */
int IFMB_CompareIds(IFID a, IFID b) {
	int x;
	char* useIdent;
	IFID identId;
	
	/* Compare ID types */
	if (a->type > b->type) return 1;
	if (a->type < b->type) return -1;
	
	/* Compare based on what the ID is */
	switch (a->type /* == b->type */) {
		case ID_GENERIC:
			return strcmp(a->data.generic.idString, b->data.generic.idString);
		
		case ID_UUID:
			for (x=0; x<16; x++) {
				if (a->data.uuid[x] > b->data.uuid[x]) return 1;
				if (a->data.uuid[x] < b->data.uuid[x]) return -1;
			}
			break;
			
		case ID_MD5:
			for (x=0; x<16; x++) {
				if (a->data.md5.md5[x] > b->data.md5.md5[x]) return 1;
				if (a->data.md5.md5[x] < b->data.md5.md5[x]) return -1;
			}
			
			/* Hack: older versions of this generated MD5 IDs without a system identifier: this will add one back in */
			useIdent = NULL;
			identId = NULL;
			if (a->data.md5.systemId == NULL) {
				identId = a;
				useIdent = b->data.md5.systemId;
			}
			if (b->data.md5.systemId == NULL) {
				identId = b;
				useIdent = a->data.md5.systemId;
			}
				
			if (useIdent) {
				identId->data.md5.systemId = malloc(sizeof(char)*(strlen(useIdent)+1));
				strcpy(identId->data.md5.systemId, useIdent);
			}
			break;
			
		case ID_ZCODE:
			if (a->data.zcode.release > b->data.zcode.release) return 1;
			if (a->data.zcode.release < b->data.zcode.release) return -1;
				
			for (x=0; x<6; x++) {
				if (a->data.zcode.serial[x] > b->data.zcode.serial[x]) return 1;
				if (a->data.zcode.serial[x] < b->data.zcode.serial[x]) return -1;
			}

			if (a->data.zcode.checksum >= 0 && b->data.zcode.checksum >= 0) {
				if (a->data.zcode.checksum > b->data.zcode.checksum) return 1;
				if (a->data.zcode.checksum < b->data.zcode.checksum) return -1;
			}
				
			break;
			
		case ID_GLULX:
			if (a->data.glulx.checksum > b->data.glulx.checksum) return 1;
			if (a->data.glulx.checksum < b->data.glulx.checksum) return -1;
				
			if (a->data.glulx.release > b->data.glulx.release) return 1;
			if (a->data.glulx.release < b->data.glulx.release) return -1;
						
			for (x=0; x<6; x++) {
				if (a->data.glulx.serial[x] > b->data.glulx.serial[x]) return 1;
				if (a->data.glulx.serial[x] < b->data.glulx.serial[x]) return -1;
			}
			break;
			
		case ID_GLULXNOTINFORM:
			if (a->data.glulxNotInform.memsize > b->data.glulxNotInform.memsize) return 1;
			if (a->data.glulxNotInform.memsize < b->data.glulxNotInform.memsize) return -1;
			
			if (a->data.glulxNotInform.checksum > b->data.glulxNotInform.checksum) return 1;
			if (a->data.glulxNotInform.checksum < b->data.glulxNotInform.checksum) return -1;
			break;
			
		case ID_COMPOUND:
			if (a->data.compound.count > b->data.compound.count) return 1;
			if (a->data.compound.count < b->data.compound.count) return -1;
			
			for (x=0; x<a->data.compound.count; x++) {
				int comparison;
				
				comparison = IFMB_CompareIds(a->data.compound.ids[x], b->data.compound.ids[x]);
				if (comparison != 0) return comparison;
			}
			break;
			
		default:
			fprintf(stderr, "ifmetabase - warning: IFMB_CompareIds was passed an ID it does not understand (%i)\n", a->type);
	}
	
	/* No further distinguishing marks: return 0 */
	return 0;
}

/* Frees an ID */
void IFMB_FreeId(IFID ident) {
	if (ident->type == ID_COMPOUND) {
		int x;
		
		for (x=0; x<ident->data.compound.count; x++) {
			IFMB_FreeId(ident->data.compound.ids[x]);
		}
		
		free(ident->data.compound.ids);
		
		if (ident->data.compound.idsNotNull) free(ident->data.compound.idsNotNull);
	} else if (ident->type == ID_GENERIC) {
		free(ident->data.generic.idString);
	} else if (ident->type == ID_MD5) {
		if (ident->data.md5.systemId != NULL) {
			free(ident->data.md5.systemId);
		}
	}
	
	free(ident);
}

/* Copies an ID */
IFID IFMB_CopyId(IFID ident) {
	IFID result = malloc(sizeof(struct IFID));
	
	*result = *ident;
	
	if (ident->type == ID_COMPOUND) {
		int x;
		
		result->data.compound.ids = malloc(sizeof(IFID)*ident->data.compound.count);
		result->data.compound.idsNotNull = NULL;
		
		for (x=0; x<ident->data.compound.count; x++) {
			result->data.compound.ids[x] = IFMB_CopyId(ident->data.compound.ids[x]);
		}
	} else if (ident->type == ID_GENERIC) {
		result->data.generic.idString = malloc(sizeof(char)*(strlen(ident->data.generic.idString)+1));
		strcpy(result->data.generic.idString, ident->data.generic.idString);
	} else if (ident->type == ID_MD5) {
		if (ident->data.md5.systemId != NULL) {
			size_t len = strlen(ident->data.md5.systemId);
			result->data.md5.systemId = malloc(sizeof(char)*(len+1));
			strcpy(result->data.md5.systemId, ident->data.md5.systemId);
		}
	}
	
	return result;
}

/* Functions - stories */

/* Perform a binary search in the given metabase for a story with an ID 'close to' the specified identifier - returns the number of the index entry */
static int NearestIndexNumber(IFMetabase meta, IFID ident) {
	int top, bottom, compare;
	
	bottom = 0;
	top = meta->numIndexEntries-1;
	
	while (top > bottom) {
		int middle;
		
		middle = (top+bottom)>>1;
		
		compare = IFMB_CompareIds(ident, meta->index[middle].id);
		
		if (compare == 0) return middle;
		if (compare <= -1) bottom = middle + 1;
		if (compare >= 1) top = middle - 1;
	}
	
	/* Return the first value that is less than the specified ID */
	top++;
	if (top >= meta->numIndexEntries) top = meta->numIndexEntries - 1;
	if (top >= 0) {
		compare = IFMB_CompareIds(ident, meta->index[top].id);
		
		while (compare > 0 && top >= 0) {
			top--;
			if (top >= 0) compare = IFMB_CompareIds(ident, meta->index[top].id);
		}
	}
	
#ifdef INDEXCHECK
	if (top >= 0 && top < meta->numIndexEntries) {
		compare = IFMB_CompareIds(ident, meta->index[top].id);		
		if (compare > 0) {
			printf("BAD FIND! %i\n", compare);
			abort();
		}
	}
	
	if (top+1 < meta->numIndexEntries) {
		compare = IFMB_CompareIds(ident, meta->index[top+1].id);		
		if (compare != 1) {
			printf("BAD FIND! %i\n", compare);
			abort();
		}
	}
	
	for (bottom=1; bottom<meta->numIndexEntries; bottom++) {
		compare = IFMB_CompareIds(meta->index[bottom-1].id, meta->index[bottom].id);
		
		if (compare != 1) {
			printf("CORRUPTED! %i\n", compare);
			abort();
		}
	}
#endif
	
	return top;
}

/* Searches for an existing story with the specified identifier, returns NULL if none is found */
static IFStory ExistingStoryWithId(IFMetabase meta, IFID ident) {
	if (ident->type == ID_COMPOUND) {
		/* For a compound ID, find the first story that matches any of the contained IDs */
		int x;
		
		for (x=0; x<ident->data.compound.count; x++) {
			IFStory story;
			
			story = ExistingStoryWithId(meta, ident->data.compound.ids[x]);
			if (story != NULL) return story;
		}
		
		/* Otherwise, return NULL */
		return NULL;
	} else {
		/* For all others, just search for the ID */
		int index;
		
		index = NearestIndexNumber(meta, ident);
		if (index < 0 || index >= meta->numIndexEntries) return NULL;
		
		if (IFMB_CompareIds(ident, meta->index[index].id) == 0) 
			return meta->stories[meta->index[index].storyNumber];
		else
			return NULL;
	}
}

/* Indexes the specified story number using the specified identifier */
/* If a compound ID, any IDs that could not be indexed (due to them already existing in the metabase) are set to ID_NULL as a side-effect */
static int IndexStory(IFMetabase meta, int storyNum, IFID ident) {
	if (ident->type == ID_NULL) {
		return 0;
	} else if (ident->type == ID_COMPOUND) {
		/* Compound IDs are indexed according to their contents */
		int x;
		int indexed;
		
		indexed = 0;
		for (x=0; x<ident->data.compound.count; x++) {
			int indexedEntry;
			
			indexedEntry = IndexStory(meta, storyNum, ident->data.compound.ids[x]);
			
			if (indexedEntry) {
				indexed = 1;
			} else {
				/* Got a story ID that does not identify a new story - set it to NULL */
				ident->data.compound.ids[x]->type = ID_NULL;
				
				if (ident->data.compound.idsNotNull) {
					free(ident->data.compound.idsNotNull);
					ident->data.compound.idsNotNull = NULL;
				}
			}
		}
		
		return indexed;
	} else {
		int index;

		/* Find the index entry after which to place this story */
		index = NearestIndexNumber(meta, ident);
		
		/* Nothing to do if there's already an entry with this ID */
		if (index >= 0 && IFMB_CompareIds(ident, meta->index[index].id) == 0) return 0;
		
		index++;
		
		/* Expand the index array */
		meta->numIndexEntries++;
		meta->index = realloc(meta->index, sizeof(IFIndexEntry)*meta->numIndexEntries);
		
		if (index < meta->numIndexEntries-1)
			memmove(meta->index + index + 1, meta->index + index, sizeof(IFIndexEntry)*(meta->numIndexEntries-1-index));
		
		/* Add the new entry */
		meta->index[index].id = ident;
		meta->index[index].storyNumber = storyNum;

#ifdef INDEXCHECK
		index = NearestIndexNumber(meta, ident);
		if (index < 0 || IFMB_CompareIds(ident, meta->index[index].id) != 0) abort();
#endif
		
		return 1;
	}
}

/* Retrieves the story in the metabase with the given ID (the story is created if it does not already exist) */
IFStory IFMB_GetStoryWithId(IFMetabase meta, IFID ident) {
	IFStory story;

	/* Return the existing story if there's already an entry for this ID in the metabase */
	story = ExistingStoryWithId(meta, ident);
	if (story != NULL) return story;
	
	/* Otherwise, create a new story entry */
	story = malloc(sizeof(struct IFStory));
	story->metabase = meta;
	story->id = IFMB_CopyId(ident);
	story->number = meta->numStories;
	
	story->root = malloc(sizeof(struct IFValue));
	story->root->key = NULL;
	story->root->value = NULL;
	story->root->childCount = 0;
	story->root->children = NULL;
	story->root->parent = NULL;
	
	/* Add this story to the index */
	meta->numStories++;
	meta->stories = realloc(meta->stories, sizeof(IFStory)*meta->numStories);
	meta->stories[meta->numStories-1] = story;
	
	IndexStory(meta, meta->numStories-1, story->id);
	
	return story;
}

/* Retrieves the ID associated with a given story object */
IFID IFMB_IdForStory(IFStory story) {
	return story->id;
}

/* Removes the story with the specified number from the index */
static void UnindexStory(IFMetabase meta, int storyNum, IFID ident) {
	if (ident->type == ID_NULL) {
		/* NULL stories are never indexed */
		return;
	} else if (ident->type == ID_COMPOUND) {
		int x;
		
		/* Compound stories are indexed by component - unindex those */
		for (x=0; x<ident->data.compound.count; x++) {
			UnindexStory(meta, storyNum, ident->data.compound.ids[x]);
		}
	} else {
		int index;
		
		/* Find this entry in the index */
		index = NearestIndexNumber(meta, ident);
		if (index < 0) return;
		if (index >= 0 && IFMB_CompareIds(ident, meta->index[index].id) != 0) return;
		
		/* Remove this entry from the index */
		memmove(meta->index + index, meta->index + index + 1, sizeof(IFIndexEntry)*(meta->numIndexEntries - index - 1));
		meta->numIndexEntries--;
		
#ifdef INDEXCHECK
		index = NearestIndexNumber(meta, ident);
		if (index >= 0 && IFMB_CompareIds(ident, meta->index[index].id) == 0) abort();
#endif
	}
}

/* Removes a story with the given ID from the metabase */
void IFMB_RemoveStoryWithId(IFMetabase meta, IFID ident) {
	/* Get the story with this ID */
	IFStory story = ExistingStoryWithId(meta, ident);
	if (story == NULL) return;
	
	/* Remove this story from the indexes */
	UnindexStory(meta, story->number, story->id);
	
	/* Remove the story from the metabase list of stories (a stub always remains - a bit memory inefficient, but required for our index) */
	meta->stories[story->number] = NULL;

	/* Destroy the story itself */
	FreeStory(story);
}

/* Copies a story, optionally from another metabase, optionally to a new ID. id can be NULL to create the copy with the same ID as the original */
void IFMB_CopyStory(IFMetabase meta, IFStory story, IFID id) {
	IFStory oldStory;
	IFStory newStory;
	
	if (meta == NULL) meta = story->metabase;
	if (story == NULL) return;							/* Error! */
	if (story->id == NULL) return;
	if (id == NULL && IFMB_GetStoryWithId(meta, story->id) == story) return;
	if (id == NULL) id = story->id;
	
	/* Remove any stories that have the supplied ID */
	oldStory = ExistingStoryWithId(meta, id);
	while (oldStory != NULL) {
		/* If oldStory is the same as the current story, reindex it with the new ID */
		if (oldStory == story) {
			UnindexStory(meta, oldStory->number, oldStory->id);
			
			IFMB_FreeId(oldStory->id);
			oldStory->id = IFMB_CopyId(id);
			
			IndexStory(meta, oldStory->number, oldStory->id);
			
			return;
		}
		
		/* Otherwise, remove oldStory from the metabase */
		IFMB_RemoveStoryWithId(meta, oldStory->id);
		
		/* Get any other stories that match this ID */
		oldStory = ExistingStoryWithId(meta, id);
	}
	
	/* Get the story that we're going to write the values for the old story to */
	newStory = IFMB_GetStoryWithId(meta, id);
	
	/* Copy the values */
	FreeValue(newStory->root);
	newStory->root = CopyValue(story->root);
}

/* Returns non-zero if the metabase contains a story with a given ID */
int IFMB_ContainsStoryWithId(IFMetabase meta, IFID ident) {
	return ExistingStoryWithId(meta, ident)!=NULL;
}

/* Finds the index of a value with the specified key */
static int IndexForKey(IFValue parent, const char* key) {
	int top, bottom, compare;
	
	/* Binary search for the key */
	top = parent->childCount;
	bottom = 0;
	
	while (top > bottom) {
		int middle;
		int compare;
		
		middle = (top+bottom)>>1;
		
		compare = strcmp(key, parent->children[middle]->key);
		
		if (compare == 0) {
			/* Have found the value: if there is more than one with the same key, then return the very last one */
			while (middle+1 < parent->childCount && strcmp(key, parent->children[middle+1]->key) == 0)
				middle++;
			
			return middle;
		}
		
		if (compare < 0) bottom = middle + 1;
		if (compare > 0) top = middle - 1;
	}
	
	/* Find the first value that's less than the key */
	if (top >= 0 && top < parent->childCount) {
		compare = strcmp(key, parent->children[top]->key);
		
		while (top >= 0 && compare > 0) {
			top--;
			
			if (top >= 0) compare = strcmp(key, parent->children[top]->key);
		}
	}
	
	if (top >= parent->childCount) top--;
	
	return top;
}

/* Finds a value using the specified path, from the specified value, optionally creating a new entry */
static IFValue FindValue(IFValue root, const char* path, int createEntry) {
	char* key;
	int x, dividerPos;
	IFValue childValue;
	int index;
	int found;
	
	/* Base case: no path */
	if (path == NULL || path[0] == 0) return root;
	
	/* Get the key for this stage of the path */
	for (x=0; path[x] != '.' && path[x] != '@' && path[x] != 0; x++);
	dividerPos = x;
	
	key = malloc(sizeof(char)*dividerPos+1);
	for (x=0; x<dividerPos; x++) key[x] = tolower(path[x]);
	key[x] = 0;
	
	/* Set childValue to the value for this part of the key */
	index = IndexForKey(root, key);
	
	found = 1;
	if (index < 0 || strcmp(key, root->children[index]->key) != 0) found = 0;
	
	/* Return NULL if the key is not found and we're not creating a new entry */
	if (!found && createEntry == 0) {
		free(key);
		return NULL;
	}
	
	if (!found || (createEntry == 2 && path[dividerPos] == 0)) {
		/* If createEntry is true, and the entry is not found (or this is the last entry and createEntry is 2), create a new entry */
		childValue = malloc(sizeof(struct IFValue));
		
		childValue->key = malloc(sizeof(char)*(strlen(key)+1));
		strcpy(childValue->key, key);
		childValue->value = NULL;
		childValue->childCount = 0;
		childValue->children = NULL;
		childValue->parent = root;
		
		/* Add it to the list of entries for this node */
		root->childCount++;
		root->children = realloc(root->children, sizeof(IFValue)*root->childCount);
		
		index++;
		memmove(root->children + index + 1, root->children + index,  sizeof(IFValue)*(root->childCount - 1 - index));
		
		root->children[index] = childValue;
	} else {
		childValue = root->children[index];
	}
	
	/* Continue to the next branch */
	if (path[dividerPos] == '.') dividerPos++;
	
	free(key);
	return FindValue(childValue, path + dividerPos, createEntry);
}

/* Returns a UTF-16 string for a given parameter in a story, or NULL if none was found */
/* Copy this value away if you intend to retain it: it may be destroyed on the next IFMB_ call */
IFChar* IFMB_GetValue(IFStory story, const char* valueKey) {
	IFValue value;
	
	value = FindValue(story->root, valueKey, 0);
	
	if (value != NULL) {
		return value->value;
	} else {
		return NULL;
	}
}

/* Sets the UTF-16 string for a given parameter in the story (NULL to unset the parameter) */
void IFMB_SetValue(IFStory story, const char* valueKey, IFChar* utf16value) {
	IFValue value;
	
	value = FindValue(story->root, valueKey, 1);
	
	if (value->value != NULL) free(value->value);
	
	if (utf16value == NULL) {
		value->value = NULL;
	} else {
		value->value = malloc(sizeof(IFChar)*(IFMB_StrLen(utf16value)+1));
		IFMB_StrCpy(value->value, utf16value);
	}
}

/* Adds a duplicate value key. This duplicate key is the one that is accessed by the Set/Get value operators: iteration functions can be used to access the other values */
/* Use this before calling IFMB_SetValue to set multiple values for the same key */
void IFMB_AddValue(IFStory story, const char* valueKey) {
	FindValue(story->root, valueKey, 2);
}

/* Functions - iterating */

/* Gets an iterator covering all the stories in the given metabase */
IFStoryIterator IFMB_GetStoryIterator(IFMetabase meta) {
	IFStoryIterator result = malloc(sizeof(struct IFStoryIterator));
	
	result->metabase = meta;
	result->count = -1;
	
	return result;
}

/* Gets an iterator covering all the values set in a story */
IFValueIterator IFMB_GetValueIterator(IFStory story) {
	IFValueIterator result;
	
	result = malloc(sizeof(struct IFValueIterator));
	
	result->root = story->root;
	result->count = -1;
	
	result->key = NULL;
	result->path = malloc(sizeof(char));
	result->path[0] = 0;
	
	result->pathBuf = NULL;
	
	return result;
}

/* Gets the next story defined in the metabase (or NULL if there are no more) */
IFStory IFMB_NextStory(IFStoryIterator iter) {
	iter->count++;
	
	while (iter->count < iter->metabase->numStories && iter->metabase->stories[iter->count] == NULL) {
		iter->count++;
	}
	
	if (iter->count >= iter->metabase->numStories) return NULL;
	
	return iter->metabase->stories[iter->count];
}

/* Moves to the next (or first) value: returns 0 if finished */
int IFMB_NextValue(IFValueIterator iter) {
	iter->count++;
	
	if (iter->count < iter->root->childCount) {
		if (iter->key != NULL && strcmp(iter->root->children[iter->count]->key, iter->key) != 0) {
			/* Return 0 if we've finished matching all the values with a given key */
			return 0;
		} else {
			/* There are still more values in the iterator */
			return 1; 
		}
	} else {
		/* We've finished all of the values in this iterator */
		return 0;
	}
}

/* Retrieves the key from a value iterator */
char* IFMB_KeyFromIterator(IFValueIterator iter) {
	char* key;
	
	key = iter->root->children[iter->count]->key;
	
	/* Just return the key if this is the root iterator */
	if (iter->path[0] == 0) return key;
	
	/* Otherwise build the full path to this key */
	iter->pathBuf = realloc(iter->pathBuf, sizeof(char)*(strlen(key)+strlen(iter->path)+2));

	strcpy(iter->pathBuf, iter->path);
	if (key[0] != '@') strcat(iter->pathBuf, ".");
	strcat(iter->pathBuf, key);
	
	return iter->pathBuf;
}

/* Retrieves the last part of the key from a value iterator */
char* IFMB_SubkeyFromIterator(IFValueIterator iter) {
	return iter->root->children[iter->count]->key;
}

/* Retrieves the string value from a value iterator */
IFChar* IFMB_ValueFromIterator(IFValueIterator iter) {
	return iter->root->children[iter->count]->value;
}

/* Retrieves an iterator for the nodes underneath a given value (or NULL if there are none) */
IFValueIterator IFMB_ChildrenFromIterator(IFValueIterator iter) {
	IFValueIterator result;
	IFValue newRoot;
	
	/* Get the new root of this iterator */
	newRoot = iter->root->children[iter->count];
	if (newRoot->childCount <= 0) return NULL;
	
	/* Construct a new value iterator for the children of this iterator */
	result = malloc(sizeof(struct IFValueIterator));
	
	result->root = newRoot;
	result->count = -1;
	
	result->key = NULL;
	result->path = malloc(sizeof(char));
	result->path[0] = 0;
	
	result->pathBuf = NULL;
	
	return result;	
}

/* Gets an iterator for all the values sharing a key */
IFValueIterator IFMB_GetValueIteratorForKey(IFStory story, const char* valueKey) {
	char* path;
	char* key;
	int keyPos, x, valueKeyLen;
	
	IFValue root;
	int keyIndex;
	
	IFValueIterator result;
	
	if (valueKey == NULL || valueKey[0] == 0) {
		/* No key: this is the root iterator */
		return IFMB_GetValueIterator(story);
	}
	
	/* Find the location of the last divider character */
	keyPos = 0;
	
	for (x=0; valueKey[x] != 0; x++) {
		if (valueKey[x] == '.') {
			keyPos = x;
		}
		
		if (x>0 && valueKey[x] == '@') {
			keyPos = x-1;
		}
	}
	valueKeyLen = x;
	
	/* Split up the key into the path (which describes the location we iterate across) and the key (which describes which values we find) */
	path = malloc(sizeof(char)*(keyPos+1));
	key = malloc(sizeof(char)*(valueKeyLen-keyPos));
	
	for (x=0; x<keyPos; x++) {
		path[x] = valueKey[x];
	}
	path[x] = 0;
	
	for (x=keyPos+1; valueKey[x] != 0; x++) {
		key[x-(keyPos+1)] = valueKey[x];
	}
	key[x-(keyPos+1)] = 0;
	
	/* Locate the root value */
	root = FindValue(story->root, path, 0);
	
	if (root == NULL) {
		free(path);
		free(key);
		return NULL;
	}
	
	/* Find the index for the key value */
	keyIndex = IndexForKey(root, key);
	
	if (keyIndex < 0 || keyIndex >= root->childCount || strcmp(root->children[keyIndex]->key, key) != 0) {
		free(path);
		free(key);
		return NULL;
	}
	
	/* Move to the value before the first one with this key */
	while (keyIndex >= 0 && strcmp(root->children[keyIndex]->key, key) == 0) {
		keyIndex--;
	}
	
	/* Create the iterator */
	result = malloc(sizeof(struct IFValueIterator));
	
	result->root = root;
	result->count = keyIndex;
	
	result->key = key;
	result->path = path;
	result->pathBuf = NULL;
	
	return result;
}

/* Deletes the value pointed to by this iterator (and any subvalues) */
void IFMB_DeleteIteratorValue(IFValueIterator iter) {
	IFValue root;
	IFValue oldValue;
	
	/* Remember the value that we're going to delete */
	root = iter->root;
	oldValue = root->children[iter->count];
	
	/* Remove it from the list of values */
	memmove(root->children + iter->count, root->children + iter->count + 1, root->childCount - iter->count - 1);
	root->childCount--;
	
	FreeValue(oldValue);
	
	/* Move the iterator backwards, so the next value is correct */
	iter->count--;
}

/* Sets the value for an iterator */
void IFMB_SetIteratorValue(IFValueIterator iter, IFChar* utf16value) {
	/* Free the old value for the key pointed to by the iterator */
	if (iter->root->children[iter->count]->value != NULL) {
		free(iter->root->children[iter->count]->value);
		iter->root->children[iter->count]->value = NULL;
	}
	
	/* Set the new value */
	if (utf16value != NULL) {
		iter->root->children[iter->count]->value = malloc(sizeof(IFChar)*(IFMB_StrLen(utf16value)+1));
		IFMB_StrCpy(iter->root->children[iter->count]->value, utf16value);
	}
}

/* Frees the two types of iterator */
void IFMB_FreeStoryIterator(IFStoryIterator iter) {
	free(iter);
}

void IFMB_FreeValueIterator(IFValueIterator iter) {
	if (iter->key) free(iter->key);
	if (iter->path) free(iter->path);
	if (iter->pathBuf) free(iter->pathBuf);
	
	free(iter);
}
	
/* Functions - basic UTF-16 string manipulation */

int IFMB_StrLen(const IFChar* a) {
	int x;
	
	for (x=0; a[x] != 0; x++);
	
	return x;
}

int IFMB_StrCmp(const IFChar* a, const IFChar* b) {
	int x;
	
	for (x=0; ; x++) {
		if (a[x] > b[x]) return 1;
		if (a[x] < b[x]) return -1;
		
		if (a[x] == 0) break;
	}
	
	return 0;
}

void IFMB_StrCpy(IFChar* a, const IFChar* b) {
	int x;
	
	for (x=0; b[x] != 0; x++) a[x] = b[x];
	a[x] = 0;
}
