/*
 *  A Z-Machine
 *  Copyright (C) 2000 Andrew Hunter
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */

/*
 * Implementation of a metadata parser for the IF Metadata format (version 0.9)
 *
 * Implementation with expat increases complexity a lot over an implementation
 * using (say) a DOM library, but these are usually less portable and implemented
 * for languages like (blech) C++. This will work on anything that expat can be
 * compiled for, which is pretty much anything.
 */

#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdio.h>

#include <expat.h>

#include "ifmetadata.h"

#ifndef XMLCALL
/* Not always defined? */
# define XMLCALL
#endif

/* == Parser function declarations == */
static XMLCALL void startElement(void *userData,
								 const XML_Char *name,
								 const XML_Char **atts);
static XMLCALL void endElement  (void *userData,
								 const XML_Char *name);
static XMLCALL void charData    (void *userData,
								 const XML_Char *s,
								 int len);

/* == Parser state == */
typedef struct IFMDState IFMDState;

struct IFMDState {
	XML_Parser parser;
	
	IFMetadata*   data;
	IFMDStory*    story;
	IFMDIdent*    ident;
    IFMDAuxiliary* aux;
	
	int level;
	XML_Char** tagStack;
	XML_Char** tagText;
};

/* == Useful utility functions == */

/*
 * We provide a bunch of 'X' functions to provide minimal wide character support
 * for the case where wchar.h is not available. Note that current versions of
 * expat do not support widechar support without wchar.h, so you may consider this
 * superflous. This does simplify the code somewhat - ie, it should compile
 * regardless of the type of XML_Char.
 *
 * Upper/lowercase support is therefore ASCII only, and comparasons need to be
 * exact (ie not following the Unicode rules). This is presently OK, regardless
 * of the use of Unicode, as no current game format requires the use of Unicode
 * comparason rules.
 */

static int Xstrncpy(XML_Char* a, const XML_Char* b, int len) {
	int x;
	
	for (x=0; b[x] != 0 && x<len; x++) {
		a[x] = b[x];
	}
	
	a[x] = 0;
	
	return x;
}

static int XCstrcmp(const XML_Char* a, const char* b) {
	int x;
	
	for (x=0; a[x] != 0 && b[x] != 0; x++) {
		if (a[x] < (unsigned char)b[x]) return -1;
		if (a[x] > (unsigned char)b[x]) return 1;
	}
	
	if (a[x] < (unsigned char)b[x]) return -1;
	if (a[x] > (unsigned char)b[x]) return 1;
	
	return 0;
}

static int Xstrlen(const XML_Char* a) {
	int x;
	
	if (a == NULL) return 0;

	for (x=0; a[x] != 0; x++);
	
	return x;
}

static XML_Char XchompConvert(XML_Char c) {
	if (c == '\n' || c == '\t' || c == '\r') return ' ';
	if (c == 1) return '\n'; /* Hack */
	return c;
}

static XML_Char* Xchomp(const XML_Char* a) {
	/*
	 * 'Strips' the string provided
	 * '\n' and '\t' are replaced with ' '
	 * Sequences of spaces are replaced with a single space
	 * Spaces are removed from the beginning and end of the string
	 *
	 * The returned string should be released with free(), and is always as long as or shorter than a.
	 */
	
	XML_Char* result = malloc(sizeof(XML_Char)*(Xstrlen(a)+1));
	int ignoreSpaces = 1;
	int x;
	int pos = 0;
	
	if (a == NULL) {
		result[0] = 0;
		return result;
	}
	
	/* Perform the chomping */
	for (x=0; a[x] != 0; x++) {
		XML_Char c = XchompConvert(a[x]);
		
		if (c == ' ' && ignoreSpaces) continue;
		if (c == ' ' || c == '\n') ignoreSpaces = 1; else ignoreSpaces = 0;
		
		result[pos++] = c;
	}
	
	/* Strip spaces at the end of the string */
	while (pos > 0 && result[pos-1] == ' ') pos--;
	
	result[pos] = 0;
	
	return result;
}

static XML_Char* Xlower(XML_Char* s) {
	/* Converts the 's' string to lower case (for ASCII values thereof). s is converted in place */
	int x;
	
	for (x=0; s[x] !=0; x++) {
		if (s[x] >= 'A' && s[x] <= 'Z') s[x] = tolower(s[x]);
	}
	
	return s;
}

static char* Xascii(const XML_Char* s) {
	/* Converts 's' to simple ASCII. The return value must be freed */
	char* res;
	int x;
	int len = Xstrlen(s);
	
	res = malloc(sizeof(char)*(len+1));
	
	for (x=0; x<len; x++) {
		if (s[x] >= 32 && s[x] < 127)
			res[x] = s[x];
		else
			res[x] = '?';
	}
	
	res[x] = 0;
	
	return res;
}

/* Table pinched from the Unicode book */
static const unsigned char bytesFromUTF8[256] = {
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
	2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, 3,3,3,3,3,3,3,3,4,4,4,4,5,5,5,5};

static IFMDChar* Xmdchar(const XML_Char* s) {
	/* Converts s to IFMDChars. Result needs to be freed */
	int x, pos;
	int len = Xstrlen(s);
	IFMDChar* res;
	
	res = malloc(sizeof(IFMDChar)*(len+1));
	pos = 0;
	
	for (x=0; x<len; x++) {
		int chr = (unsigned char)s[x];
		
		if (chr < 127) {
			res[pos++] = chr;
		} else {
			/* UTF-8 decode */
			int bytes = bytesFromUTF8[chr];
			int chrs[6];
			int y;
			int errorFlag;
			
			if (x+bytes >= len) break;
			
			/* Read+check the characters that make up this char */
			errorFlag = 0;
			for (y=0; y<=bytes; y++) {
				chrs[y] = (unsigned char)s[x+y];
				
				if (chrs[y] < 127) errorFlag = 1;
			}
			if (errorFlag) continue; /* Ignore this character (error) */
			
			/* Get the UCS-4 character */
			switch (bytes) {
				case 1: chr = ((chrs[0]&~0xc0)<<6)|(chrs[1]&~0x80); break;
				case 2: chr = ((chrs[0]&~0xe0)<<12)|((chrs[1]&~0x80)<<6)|(chrs[2]&~0x80); break;
				case 3: chr = ((chrs[0]&~0xf0)<<18)|((chrs[1]&~0x80)<<12)|((chrs[2]&~0x80)<<6)|(chrs[3]&~0x80); break;
				case 4: chr = ((chrs[0]&~0xf8)<<24)|((chrs[1]&~0x80)<<18)|((chrs[2]&~0x80)<<12)|((chrs[3]&~0x80)<<6)|(chrs[4]&~0x80); break;
				case 5: chr = ((chrs[0]&~0xfc)<<28)|((chrs[1]&~0x80)<<24)|((chrs[2]&~0x80)<<18)|((chrs[3]&~0x80)<<12)|((chrs[4]&~0x80)<<6)|(chrs[5]&~0x80); break;
			}
			
			x += bytes;
			
			res[pos++] = chr;
		}
	}
	
	res[pos] = 0;
	
	return res;
}

static IFMDChar* Xcopy(IFMDChar* stringIn) {
	int x;
	IFMDChar* stringOut;
	int len;
	
	if (stringIn == NULL) return NULL;
	for (len=0; stringIn[len]!=0; len++);
	if (len == 0) return NULL;
	
	stringOut = malloc(sizeof(IFMDChar)*(len+1)); 
	for (x=0; x<len; x++) {
		stringOut[x] = stringIn[x];
	}
	stringOut[x] = 0;
	
	return stringOut;
}

/* State functions */
static void pushTag(IFMDState* s, const XML_Char* tag) {
	int len = Xstrlen(tag);
	int x;
	
	s->level++;
	
	s->tagStack = realloc(s->tagStack, sizeof(XML_Char*)*(s->level));
	s->tagStack[s->level-1] = malloc(sizeof(XML_Char)*(len+1));
	s->tagText = realloc(s->tagText, sizeof(XML_Char*)*(s->level));
	s->tagText[s->level-1] = NULL;

	Xstrncpy(s->tagStack[s->level-1], tag, len);
	
	for (x=0; x<len; x++) {
		if (s->tagStack[s->level-1][x] < 127) {
			s->tagStack[s->level-1][x] = tolower(s->tagStack[s->level-1][x]);
		}
	}
}

static void popTag(IFMDState* s) {
	if (s->level <= 0) {
		return;
	}
	
	s->level--;
	free(s->tagStack[s->level]);
	if (s->tagText[s->level]) free(s->tagText[s->level]);
}

static XML_Char* parentTag(IFMDState* s) {
	if (s->level < 2) return NULL;
	return s->tagStack[s->level-2];
}

static XML_Char* currentTag(IFMDState* s) {
	if (s->level < 1) return NULL;
	return s->tagStack[s->level-1];
}

static void addError(IFMDState* s, enum IFMDErrorType errorType, const char* data) {
	s->data->numberOfErrors++;
	s->data->error = realloc(s->data->error, s->data->numberOfErrors*sizeof(IFMDError));
    
	s->data->error[s->data->numberOfErrors-1].severity   = IFMDErrorFatal;
	s->data->error[s->data->numberOfErrors-1].type       = errorType;
    s->data->error[s->data->numberOfErrors-1].lineNumber = XML_GetCurrentLineNumber(s->parser);
    
    if (data) {
        s->data->error[s->data->numberOfErrors-1].moreText   = malloc(strlen(data)+1);
        strcpy(s->data->error[s->data->numberOfErrors-1].moreText, data);
    } else {
        s->data->error[s->data->numberOfErrors-1].moreText = NULL;
    }
	
	if (s->story)
		s->story->error = 1;
	
	/* printf("Error: %i (%s) (@%i)\n", errorType, data, XML_GetCurrentLineNumber(s->parser)); */
}

/* Sorting functions */
static int indexCompare(const void* a, const void* b) {
	const IFMDIndexEntry* ai = a;
	const IFMDIndexEntry* bi = b;
	
	return IFID_Compare(ai->ident, bi->ident);
}

/* == The main functions == */
IFMetadata* IFMD_Parse(const IFMDByte* data, size_t length) {
	XML_Parser theParser;
	IFMetadata* res = malloc(sizeof(IFMetadata));
	IFMDState*  currentState = malloc(sizeof(IFMDState));
	
	enum XML_Status status;
	
	int story, ident, entry;
	
	/* Create the result structure */
	res->error = NULL;
	res->stories = NULL;
	res->index = NULL;
	res->numberOfStories  = 0;
	res->numberOfErrors = 0;
	res->numberOfIndexEntries = 0;
		
	/* Create the state */
	currentState->data  = res;
	currentState->story = NULL;
	currentState->ident = NULL;
    currentState->aux   = NULL;
	currentState->level = 0;
	currentState->tagStack = NULL;
	currentState->tagText  = NULL;
	
	/* Begin parsing */
	theParser = XML_ParserCreate(NULL);
	currentState->parser = theParser;
	XML_SetElementHandler(theParser, startElement, endElement);
	XML_SetCharacterDataHandler(theParser, charData);
	XML_SetUserData(theParser, currentState);
	
	/* Go! */
	status = XML_Parse(theParser, (const char*)data, (int)length, 1);
	
	if (status != XML_STATUS_OK) {
		enum XML_Error error = XML_GetErrorCode(theParser);
		const XML_LChar* erm = XML_ErrorString(error);
		
		addError(currentState, IFMDErrorXMLError, erm);
	}
	
	/* Index */
	for (story = 0; story < res->numberOfStories; story++) {
		if (!res->stories[story]->error) {
			for (ident = 0; ident < res->stories[story]->numberOfIdents; ident++) {
				IFMDIndexEntry newEntry;
				
				newEntry.ident = res->stories[story]->idents[ident];
				newEntry.story = res->stories[story];
				
				res->numberOfIndexEntries++;
				res->index = realloc(res->index, sizeof(IFMDIndexEntry)*res->numberOfIndexEntries);
				res->index[res->numberOfIndexEntries-1] = newEntry;
			}
		}
	}
	
	/* Sort the entries for easy searching */
	qsort(res->index, res->numberOfIndexEntries, sizeof(IFMDIndexEntry), indexCompare);
	
	for (entry=0; entry<res->numberOfIndexEntries-1; entry++) {
		int cmp = IFID_Compare(res->index[entry].ident, res->index[entry+1].ident);
		
		if (cmp > 0) addError(currentState, IFMDErrorProgrammerIsASpoon, "Index not sorted");
		if (cmp == 0) {
			/* Duplicate entry */
			if (res->index[entry].story != res->index[entry+1].story) {
				char msg[512];
				char name1[256], name2[256];
				IFMDChar* title;
				
				title = res->index[entry].story->data.title;
				res->index[entry].story->error = 1;
				
				if (title) {
					IFStrnCpyC(name1, title, 256);
				} else {
					snprintf(name1, 256, "(untitled)");
				}
				
				title = res->index[entry+1].story->data.title;
				
				if (title) {
					IFStrnCpyC(name2, title, 256);
				} else {
					snprintf(name2, 256, "(untitled)");
				}
				
				snprintf(msg, 512, "Duplicate story entry (%s (%x)/%s (%x))", name1, res->index[entry].ident->data.zcode.checksum, name2,  res->index[entry+1].ident->data.zcode.checksum);
				msg[511] = 0;
				
				addError(currentState, IFMDErrorStoriesShareIDs, msg);
			} else {
				char msg[512];
				char name[512];
				IFMDChar* title;
				
				title = res->index[entry].story->data.title;
				if (!title) title = res->index[entry].story->data.title;
				
				if (title) {
					IFStrnCpyC(name, title, 512);
				} else {
					snprintf(name, 512, "(untitled)");
				}
				
				snprintf(msg, 512, "Duplicate identification entry (%s)", name);
				msg[511] = 0;
				
				addError(currentState, IFMDErrorDuplicateID, msg);
			}
			
			/* Remove following entry */
			res->numberOfIndexEntries--;
			memmove(res->index+entry+1,
					res->index+entry+2,
					sizeof(IFMDIndexEntry)*(res->numberOfIndexEntries-entry));
			
			/* Keep trying at this entry */
			entry--;
		}
	}
		
	/* Finish up */
	XML_ParserFree(theParser);
	
	while (currentState->level > 0) popTag(currentState);
	if (currentState->tagStack) free(currentState->tagStack);
	free(currentState);
	
	/* All done */
	return res;
}

void IFMD_Free(IFMetadata* oldData) {
	int x;
	
	/* Index */
	free(oldData->index);
	
	/* Stories */
	for (x=0; x<oldData->numberOfStories; x++) {
		IFStory_Free(oldData->stories[x]);
		free(oldData->stories[x]);
	}
	
	free(oldData->stories);
	
	/* Errors */
	for (x=0; x<oldData->numberOfErrors; x++) {
		if (oldData->error[x].moreText) free(oldData->error[x].moreText);
	}
	free(oldData->error);
	
	/* Finally, the data itself */
	free(oldData);
}

IFMDStory* IFMD_Find(IFMetadata* data, const IFMDIdent* id) {
	int top, bottom;
	
	bottom = 0;
	top = data->numberOfIndexEntries-1;
	
	while (bottom < top) {
		int middle = (bottom + top)>>1;
		int cmp = IFID_Compare(data->index[middle].ident, id);
		
		if (cmp == 0) return data->index[middle].story;
		else if (cmp < 0) bottom = middle+1;
		else if (cmp > 0) top    = middle-1;
	}
	
	if (bottom == top && IFID_Compare(id, data->index[bottom].ident) == 0) {
		return data->index[bottom].story;
	}
	
	return NULL;
}

/* == Parser functions == */

struct IFMDUUID IFMD_ReadUUID(const char* uuidString) {
    /* UUIDs have the format xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx */
    
    /*
     * ... but this is slightly more generic, only paying attention to the hexadecimal bits until we reach the end of the 
     * string or we get enough bytes to make a UUID.
     */
    struct IFMDUUID res={0};            /* The result */
    int x;
    
    int hexValue;                   /* Hex characters read to date */
    int hexCount;                   /* Number of hex characters read to date */
    int uuidPos;                    /* Position in the uuid where we are at present */
    
    /* Zero the bytes in res */
    for (x=0; x<16; x++) res.uuid[x] = 0;
    
    /* Read hexadecimal values from the string */
    hexValue = 0;
    hexCount = 0;
    uuidPos = 0;
    
    for (x=0; uuidString[x] != 0 && x < 40; x++) {
        unsigned char thisChar;
        int thisVal = -1;
        
        /* Read the next character */        
        thisChar = (unsigned char)uuidString[x];
        
        /* If this is a hex character, then add it to the accumulated value so far */
        if (thisChar >= '0' && thisChar <= '9') {
            thisVal = thisChar - '0';
        } else if (thisChar >= 'a' && thisChar <= 'f') {
            thisVal = thisChar - 'a' + 10;
        } else if (thisChar >= 'A' && thisChar <= 'F') {
            thisVal = thisChar - 'A' + 10;
        }
        
        /* Add to the accumulated value */
        if (thisVal >= 0) {
            hexValue <<= 4;
            hexValue |= thisVal;
            
            hexCount++;
            
            if (hexCount >= 2) {
                /* We have a byte */
                if (uuidPos < 16) {
                    res.uuid[uuidPos] = hexValue;
                }
                
                uuidPos++;

                /* Reset for the next byte */
                hexValue = 0;
                hexCount = 0;
            }
        }
    }
    
    if (uuidPos != 16) {
        /* Not a valid UUID */
        for (x=0; x<16; x++) res.uuid[x] = 0;
    }
    
    /* Return the result */
    return res;
}

static XMLCALL void startElement(void *userData,
								 const XML_Char *name,
								 const XML_Char **atts) {
	IFMDState* state = userData;
	XML_Char* parent, *current;
	
	pushTag(state, name);
	
	parent = parentTag(state);
	current = currentTag(state);
	
	if (current == NULL) {
		/* Programmer is a spoon */
		addError(state, IFMDErrorProgrammerIsASpoon, "No current tag");
		return;
	}
	
	if (parent == NULL) {
		/* ifindex only */
		if (XCstrcmp(current, "ifindex") != 0) {
			/* Not IF metadata */
			addError(state, IFMDErrorNotIFIndex, NULL);
		}
	} else if (XCstrcmp(parent, "ifindex") == 0) {
		/* <story> only */
		if (XCstrcmp(current, "story") == 0) {
			/* IF story */
			IFMDStory newStory;
			
			newStory.numberOfIdents = 0;
			newStory.idents = NULL;
			newStory.error = 0;
			
			newStory.data.title = NULL;
			newStory.data.headline = NULL;
			newStory.data.author = NULL;
			newStory.data.genre = NULL;
			newStory.data.year = 0;
			newStory.data.group = NULL;
			newStory.data.zarfian = IFMD_Unrated;
			newStory.data.teaser = NULL;
			newStory.data.comment = NULL;
			newStory.data.rating = -1.0;
			
            newStory.data.coverpicture = 0;
            newStory.data.description = NULL;
            newStory.data.auxiliary = NULL;
            
			state->data->numberOfStories++;
			state->data->stories = realloc(state->data->stories, sizeof(IFMDStory*)*state->data->numberOfStories);
			state->data->stories[state->data->numberOfStories-1] = IFStory_Alloc();
			*(state->data->stories[state->data->numberOfStories-1]) = newStory;
			
			state->story = state->data->stories[state->data->numberOfStories-1];
		} else {
			/* Unrecognised tag */
			addError(state, IFMDErrorUnknownTag, NULL);
		}
	} else if (XCstrcmp(parent, "story") == 0) {
		/* Metadata or <identification> tags */
		if (XCstrcmp(current, "identification") == 0 || XCstrcmp(current, "id") == 0) {
			/* Story ID data */
			IFMDIdent* newID = IFID_Alloc();
			int x;
			
			if (state->story == NULL) return;
			
			newID->format = IFFormat_Unknown;
			newID->dataFormat = IFFormat_Unknown;
			newID->usesMd5 = 0;
			for (x=0; x<16; x++) newID->md5Sum[x] = 0;
			
			state->story->numberOfIdents++;
			state->story->idents = realloc(state->story->idents, sizeof(IFMDIdent*)*state->story->numberOfIdents);
			state->story->idents[state->story->numberOfIdents-1] = newID;
			
			state->ident = state->story->idents[state->story->numberOfIdents-1];
		} else if (XCstrcmp(current, "title") == 0) {
		} else if (XCstrcmp(current, "headline") == 0) {
		} else if (XCstrcmp(current, "author") == 0) {
		} else if (XCstrcmp(current, "genre") == 0) {
		} else if (XCstrcmp(current, "year") == 0) {
		} else if (XCstrcmp(current, "group") == 0) {
		} else if (XCstrcmp(current, "zarfian") == 0) {
		} else if (XCstrcmp(current, "teaser") == 0) {
		} else if (XCstrcmp(current, "comment") == 0) {
		} else if (XCstrcmp(current, "rating") == 0) {
        } else if (XCstrcmp(current, "description") == 0) {
        } else if (XCstrcmp(current, "coverpicture") == 0) {
        } else if (XCstrcmp(current, "auxiliary") == 0) {
            /* Begin a new auxiliary section */
            state->aux = malloc(sizeof(IFMDAuxiliary));
            
            state->aux->leafname = NULL;
            state->aux->description = NULL;
            state->aux->next = state->story->data.auxiliary;

            state->story->data.auxiliary = state->aux;
		} else {
			/* Unrecognised tag */
            printf("Bad tag: %s\n", Xascii(current));
			addError(state, IFMDErrorUnknownTag, "Unrecognised tag");
		}
	} else if (XCstrcmp(parent, "identification") == 0 || XCstrcmp(parent, "id") == 0) {
		/* ID tags */
		if (XCstrcmp(current, "format") == 0) {
			/* Format of the story */
		} else if (XCstrcmp(current, "md5") == 0) {
			/* MD5 data */
		} else if (XCstrcmp(current, "zcode") == 0) {
			/* ZCode data */
			if (state->ident && state->ident->dataFormat != IFFormat_UUID) {
				int x;
				
				state->ident->data.zcode.checksum = 0x10000; /* == No checksum */
				state->ident->data.zcode.release  = 0;				
				for (x=0; x<6; x++) state->ident->data.zcode.serial[x] = 0;
			}
		} else if (XCstrcmp(current, "glulx") == 0) {
			/* Glulx data */
		} else if (XCstrcmp(current, "uuid") == 0) {
			/* UUID data */
		} else {
			/* Unrecognised ID tag */
			addError(state, IFMDErrorUnknownTag, "Unrecognised tag");
		}
	} else if (XCstrcmp(parent, "zcode") == 0) {
		/* ZCode data */
		if (XCstrcmp(current, "serial") == 0) {
		} else if (XCstrcmp(current, "release") == 0) {
		} else if (XCstrcmp(current, "checksum") == 0) {
		} else {
			/* Unrecognised tag */
			addError(state, IFMDErrorUnknownTag, "Unrecognised tag");
		}
	} else if (XCstrcmp(parent, "glulx") == 0) {
		/* Glulx data */
		if (XCstrcmp(current, "serial") == 0) {
		} else if (XCstrcmp(current, "release") == 0) {
		} else {
			/* Unrecognised tag */
			addError(state, IFMDErrorUnknownTag, "Unrecognised tag");
		}
    } else if (XCstrcmp(parent, "uuid") == 0) {
        /* UUID data */
	} else {
		/* Unknown data */
	}
}

static XMLCALL void endElement(void *userData,
							   const XML_Char *name) {
	IFMDState* state = userData;
	XML_Char* current;
	XML_Char* parent;
	XML_Char* currentText;
	
	current = currentTag(state);
	parent  = parentTag(state);

	if (current == NULL) {
		/* Programmer is a spoon */
		addError(state, IFMDErrorProgrammerIsASpoon, "No current tag");
		return;
	}
	
	currentText = state->tagText[state->level-1];
	
	if (parent) {
		/* Process these tags */
		if (state->ident != NULL) {
			/* Dealing with a game identification section */
			
			if (XCstrcmp(parent, "identification") == 0 || XCstrcmp(parent, "id") == 0) {
				/* General identification */
				if (XCstrcmp(current, "md5") == 0) {
					/* MD5 key <identification><md5> */
					char key[32];
					int pos = 0;
					int x;
					int len = Xstrlen(currentText);
					
					IFMDByte checksum[16];
					
					/* Read the text of the key */
					for (x=0; x<len; x++) {
						int cT = currentText[x];
						
						if ((cT >= 'a' && cT <= 'f') ||
							(cT >= 'A' && cT <= 'F') ||
							(cT >= '0' && cT <= '9')) {
							key[pos++] = cT;
							
							if (pos >= 32) break;
						}
					}
					
					/* Key is a 128-bit number - we convert into bytes */
					for (x=0; x<16; x++) checksum[x] = 0;
					
					for (x=(pos-1); x >= 0; x--) {
						/* x = the nibble we're dealing with */
						/* key[x] = the hexadecimal char we're dealing with */
						int hex = key[x];
						int val = 0;
						int byte = x>>1;
						
						if (hex >= 'a' && hex <= 'f') val = 10 + (hex-'a');
						else if (hex >= 'A' && hex <= 'F') val = 10 + (hex-'A');
						else if (hex >= '0' && hex <= '9') val = hex-'0';
						
						if ((x&1) != 0) {
							/* First nibble */
							checksum[byte] |= val;
						} else {
							/* Second nibble */
							checksum[byte] |= val<<4;
						}
					}
					
					/* Store the result */
					state->ident->usesMd5 = 1;
					memcpy(state->ident->md5Sum, checksum, sizeof(IFMDByte)*16);
				} else if (XCstrcmp(current, "format") == 0) {
					/* File format specifier <identification><format> */
					XML_Char* format = Xlower(Xchomp(currentText));
					
                    if (XCstrcmp(format, "uuid") == 0) {
                        state->ident->format = IFFormat_UUID;
					} else if (XCstrcmp(format, "zcode") == 0) {
						state->ident->format = IFFormat_ZCode;
					} else if (XCstrcmp(format, "glulx") == 0) {
						state->ident->format = IFFormat_Glulx;
					} else if (XCstrcmp(format, "tads") == 0) {
						state->ident->format = IFFormat_TADS;
					} else if (XCstrcmp(format, "hugo") == 0) {
						state->ident->format = IFFormat_HUGO;
					} else if (XCstrcmp(format, "alan") == 0) {
						state->ident->format = IFFormat_Alan;
					} else if (XCstrcmp(format, "adrift") == 0) {
						state->ident->format = IFFormat_Adrift;
					} else if (XCstrcmp(format, "level9") == 0) {
						state->ident->format = IFFormat_Level9;
					} else if (XCstrcmp(format, "agt") == 0) {
						state->ident->format = IFFormat_AGT;
					} else if (XCstrcmp(format, "magscrolls") == 0) {
						state->ident->format = IFFormat_MagScrolls;
					} else if (XCstrcmp(format, "advsys") == 0) {
						state->ident->format = IFFormat_AdvSys;
					} else {
						/* Unrecognised format */
						addError(state, IFMDErrorUnknownFormat, "Unknown game format");
					}
					
					free(format);
				}
            } else if (XCstrcmp(parent, "uuid") == 0) {
                /* UUID idenfication section */
				XML_Char* text = Xlower(Xchomp(currentText));

                state->ident->dataFormat = IFFormat_UUID;
                
                if (XCstrcmp(current, "uuid") == 0) {
                    state->ident->data.uuid = IFMD_ReadUUID(Xascii(text));
                }
			} else if (XCstrcmp(parent, "zcode") == 0) {
				/* zcode identification section */
				XML_Char* text = Xlower(Xchomp(currentText));
				
                if (state->ident->dataFormat != IFFormat_UUID) {
                    state->ident->dataFormat = IFFormat_ZCode;
                    
                    if (XCstrcmp(current, "serial") == 0) {
                        int x;
                        
                        for (x=0; x<6 && text[x] != 0; x++) {
                            state->ident->data.zcode.serial[x] = text[x];
                        }
                    } else if (XCstrcmp(current, "release") == 0) {
                        char* release = Xascii(text);
                        
                        state->ident->data.zcode.release = atoi(release);
                        
                        free(release);
                    } else if (XCstrcmp(current, "checksum") == 0) {
                        char* checksum = Xascii(text);
                        int x, val;
                        
                        val = 0;
                        for (x=0; x<4 && checksum[x] != 0; x++) {
                            int hex = 0;
                            
                            val <<= 4;
                            
                            if (checksum[x] >= '0' && checksum[x] <= '9') hex = checksum[x]-'0';
                            else if (checksum[x] >= 'A' && checksum[x] <= 'F') hex = checksum[x]-'A'+10;
                            else if (checksum[x] >= 'a' && checksum[x] <= 'f') hex = checksum[x]-'a'+10;
                            else break;
                            
                            val |= hex;
                        }
                        
                        state->ident->data.zcode.checksum = val;
                        
                        free(checksum);
                    }
                }
				
				free(text);
			} else if (XCstrcmp(parent, "glulx") == 0) {
				/* glulx identification section */
				XML_Char* text = Xlower(Xchomp(currentText));
				
                if (state->ident->dataFormat != IFFormat_UUID) {
                    state->ident->dataFormat = IFFormat_Glulx;
                    
                    if (XCstrcmp(current, "serial") == 0) {
                        int x;
                        
                        for (x=0; x<6 && text[x] != 0; x++) {
                            state->ident->data.glulx.serial[x] = text[x];
                        }
                    } else if (XCstrcmp(current, "release") == 0) {
                        char* release = Xascii(text);
                        
                        state->ident->data.glulx.release = atoi(release);
                        
                        free(release);
                    }
                }
				
				free(text);
			}
		} else if (state->story != NULL) {
			/* Dealing with a story section */
			if (XCstrcmp(parent, "story") == 0) {
				/* Probably metadata */
				XML_Char* text = Xchomp(currentText);
				
				if (XCstrcmp(current, "title") == 0) {
					state->story->data.title = Xmdchar(text);
				} else if (XCstrcmp(current, "headline") == 0) {
					state->story->data.headline = Xmdchar(text);
				} else if (XCstrcmp(current, "author") == 0) {
					state->story->data.author = Xmdchar(text);
				} else if (XCstrcmp(current, "genre") == 0) {
					state->story->data.genre = Xmdchar(text);
				} else if (XCstrcmp(current, "year") == 0) {
					char* year = Xascii(text);
					
					state->story->data.year = atoi(year);
					
					free(year);
				} else if (XCstrcmp(current, "group") == 0) {
					state->story->data.group = Xmdchar(text);
				} else if (XCstrcmp(current, "zarfian") == 0) {
					Xlower(text);
					
					if (XCstrcmp(text, "merciful") == 0) {
						state->story->data.zarfian = IFMD_Merciful;
					} else if (XCstrcmp(text, "polite") == 0) {
						state->story->data.zarfian = IFMD_Polite;
					} else if (XCstrcmp(text, "tough") == 0) {
						state->story->data.zarfian = IFMD_Tough;
					} else if (XCstrcmp(text, "nasty") == 0) {
						state->story->data.zarfian = IFMD_Nasty;
					} else if (XCstrcmp(text, "cruel") == 0) {
						state->story->data.zarfian = IFMD_Cruel;
					}
				} else if (XCstrcmp(current, "teaser") == 0) {
					state->story->data.teaser = Xmdchar(text);
				} else if (XCstrcmp(current, "comment") == 0) {
					state->story->data.comment = Xmdchar(text);
				} else if (XCstrcmp(current, "rating") == 0) {
					char* rating = Xascii(text);
					
					state->story->data.rating = atof(rating);
					
					free(rating);
                } else if (XCstrcmp(current, "description") == 0) {
                    state->story->data.description = Xmdchar(text);
                } else if (XCstrcmp(current, "coverpicture") == 0) {
                    char* coverpicture = Xascii(text);
                    
                    state->story->data.coverpicture = atoi(coverpicture);
                } else if (XCstrcmp(current, "auxiliary") == 0) {
                }
				
				free(text);
			} else if (XCstrcmp(parent, "auxiliary") == 0) {
                /* Auxiliary metadata */
				XML_Char* text = Xchomp(currentText);

                if (XCstrcmp(current, "leafname")) {
                    state->aux->leafname = Xmdchar(text);
                } else if (XCstrcmp(current, "description")) {
                    state->aux->description = Xmdchar(text);
                }
            }
		}
	}
	
	if (parent && (XCstrcmp(parent, "teaser") == 0 || XCstrcmp(parent, "comment") == 0 || XCstrcmp(parent, "description") == 0) &&
		XCstrcmp(current, "br") == 0) {
		/* <br> is allowed: this is a bit of a hack */
		XML_Char newLine[2] = { 1, 0 };
				
		popTag(state);
		charData(state, newLine, 1);
		return;
	}
	
	if (XCstrcmp(current, "identification") == 0 || XCstrcmp(current, "id") == 0) {
		/* Verify the identification for errors */
		if (state->ident != NULL &&
            state->ident->dataFormat != IFFormat_Unknown &&
            state->ident->dataFormat != IFFormat_UUID &&
			state->ident->dataFormat != state->ident->format) {
			/* Specified one format with <format>, but gave data for another */
			addError(state, IFMDErrorMismatchedFormats, "Specified one format with <format>, but gave data for another");
		}
				
		/* Clear it */
		state->ident = NULL;
	} else if (XCstrcmp(current, "story") == 0) {
		state->story = NULL;
	}
	
	popTag(state);
}

static XMLCALL void charData(void *userData,
							 const XML_Char *s,
							 int len) {
	IFMDState* state = userData;
	int oldLen = Xstrlen(state->tagText[state->level-1]);
			
	/* Store this text */
	state->tagText[state->level-1] = realloc(state->tagText[state->level-1], 
											 sizeof(XML_Char)*(oldLen+len+1));
	Xstrncpy(state->tagText[state->level-1] + oldLen,
			 s, len);
}

/* == Story/ID functions == */
int IFID_Compare(const IFMDIdent* a, const IFMDIdent* b) {
	int x;
	
	/* Format comparison */
	if (a->format > b->format) return 1;
	if (a->format < b->format) return -1;
	
	if (a->dataFormat > b->dataFormat) return 1;
	if (a->dataFormat < b->dataFormat) return -1;
	
	/* Format-specific comparison */
	switch (a->dataFormat) { /* (Must be the same as b->dataFormat) */
        case IFFormat_UUID:
            for (x=0; x<16; x++) {
                if (a->data.uuid.uuid[x] > b->data.uuid.uuid[x]) return 1;
                if (a->data.uuid.uuid[x] < b->data.uuid.uuid[x]) return -1;
            }
            
            return 0;
        
		case IFFormat_ZCode:
			/* ZCode comparison is considered decisive: skip any future tests */
			
			/* Serial number */
			for (x=0; x<6; x++) {
				if (a->data.zcode.serial[x] > b->data.zcode.serial[x]) return 1;
				if (a->data.zcode.serial[x] < b->data.zcode.serial[x]) return -1;
			}
			
			/* Release */
			if (a->data.zcode.release > b->data.zcode.release) return 1;
			if (a->data.zcode.release < b->data.zcode.release) return -1;
				
			/* Checksum */
			if (a->data.zcode.checksum < 0x10000 && b->data.zcode.checksum < 0x10000) {
				if (a->data.zcode.checksum > b->data.zcode.checksum) return 1;
				if (a->data.zcode.checksum < b->data.zcode.checksum) return -1;
			}

			/* They're the same */
			return 0;
			
		case IFFormat_Glulx:
			/* Do nothing (Glulx comparison is not considered decisive) */
			break;
			
		default:
			/* Unknown format */
			break;
	}
	
	/* MD5 comparison (if possible) */
	if (a->usesMd5 && !b->usesMd5) return 1;
	if (!a->usesMd5 && b->usesMd5) return -1;
	
	if (a->usesMd5 && b->usesMd5) {
		for (x=0; x<16; x++) {
			unsigned char md5a, md5b;
			
			md5a = a->md5Sum[x];
			md5b = b->md5Sum[x];
			
			if (md5a > md5b) return 1;
			if (md5a < md5b) return -1;
		}
	}
	
	/* Surely these are the same game! */
	return 0;
}

void IFID_Free(IFMDIdent* oldId) {
	/* Note: only frees the data associated with the ident (ie, not the oldId pointer itself) */
	
	/* Nothing to do yet */
}

void IFStory_Free(IFMDStory* oldStory) {
	/* Note: only frees the data associated with the story (ie, not the oldStory pointer itself) */
	int x;
	
	for (x=0; x<oldStory->numberOfIdents; x++) {
		IFID_Free(oldStory->idents[x]);
		free(oldStory->idents[x]);
	}
	
	if (oldStory->data.title)    free(oldStory->data.title);
	if (oldStory->data.headline) free(oldStory->data.headline);
	if (oldStory->data.author)   free(oldStory->data.author);
	if (oldStory->data.genre)    free(oldStory->data.genre);
	if (oldStory->data.group)    free(oldStory->data.group);
	if (oldStory->data.teaser)   free(oldStory->data.teaser);
	if (oldStory->data.comment)  free(oldStory->data.comment);
    
    if (oldStory->data.description) free(oldStory->data.description);

    while (oldStory->data.auxiliary) {
        IFMDAuxiliary* oldAux = oldStory->data.auxiliary;
        
        if (oldAux->leafname)    free(oldAux->leafname);
        if (oldAux->description) free(oldAux->description);
        
        oldStory->data.auxiliary = oldAux->next;
        free(oldAux);
    }
	
	free(oldStory->idents);
}

/* Formatting strings */
int IFStrLen(const IFMDChar* string) {
	int len;
	
	for (len=0;string[len]!=0;len++);
	
	return len;
}

char* IFStrnCpyC(char* dst, const IFMDChar* src, size_t sz) {
	int pos;
	
	for (pos=0; src[pos]!=0 && pos<(sz-1); pos++) {
		if (src[pos] < 127) dst[pos] = src[pos]; else dst[pos] = '?';
	}
	
	dst[pos] = 0;
	
	return dst;
}

static unsigned short int* GetUTF16(const IFMDChar* src, int* len) {
	int pos, dpos;
	int alloc;
	unsigned short int* res;
	
	res = NULL;
	alloc = 0;
	dpos = 0;
	
#define UTStore(x) if (dpos >= alloc) { alloc += 256; res = realloc(res, sizeof(short int)*alloc); } res[dpos++] = x;
	
	for (pos=0; src[pos]!=0; pos++) {
		if (src[pos] <= 0xffff) {
			UTStore(src[pos]);
		} else if (src[pos] <= 0x10ffff) {
			UTStore(0xd800 + (src[pos]>>10));
			UTStore(0xdc00 + (src[pos]&0x3ff));
		} else {
			/* Skip this character */
		}
	}
    UTStore(0);
	
	if (len) *len = dpos-1;

    return res;
}

#ifdef HAVE_WCHAR_H
wchar_t* IFStrnCpyW(wchar_t* dst, const IFMDChar* src, size_t sz) {
	unsigned short int* utf16 = GetUTF16(src, NULL);
	int x;
	
	for (x=0; utf16[x]!=0 && x<(sz-1); x++) {
		dst[x] = utf16[x];
	}
	
	dst[x] = 0;
	
	free(utf16);
	
	return dst;
}
#endif

#ifdef HAVE_COREFOUNDATION
CFStringRef IFStrCpyCF(const IFMDChar* src) {
	int len;
	unsigned short int* utf16 = GetUTF16(src, &len);
	CFStringRef string;
	
	string = CFStringCreateWithCharactersNoCopy(kCFAllocatorDefault, utf16, len, kCFAllocatorMalloc);
	
	return string;
}

IFMDChar* IFMakeStrCF(const CFStringRef src) {
	/* UTF-16 to UTF-32 */
	IFMDChar* res;
	
	CFDataRef extData = CFStringCreateExternalRepresentation(NULL, src, kCFStringEncodingUTF32LE, '?');
	CFIndex len = CFDataGetLength(extData);
	res = malloc(len + 4); /* + 4 for terminating NULL */
	CFDataGetBytes(extData, CFRangeMake(0, len), (UInt8 *)res);
	CFRelease(extData);
	
	/* null terminator */
	res[len/4] = 0;
	
	
	/* Return results */
	return res;
}
#endif

/* = Allocation functions = */

IFMetadata* IFMD_Alloc(void) {
	IFMetadata* md;
	
	md = malloc(sizeof(IFMetadata));
	
	md->numberOfStories = md->numberOfErrors = md->numberOfIndexEntries = 0;
	md->stories = NULL;
	md->error   = NULL;
	md->index   = NULL;
	
	return md;
}

IFMDStory* IFStory_Alloc(void) {
	IFMDStory* st;
	
	st = malloc(sizeof(IFMDStory));
	
	st->numberOfIdents = 0;
	st->idents = NULL;
	st->error = 0;
	
	st->data.title = NULL;
	st->data.headline = NULL;
	st->data.author = NULL;
	st->data.genre = NULL;
	st->data.year = 0;
	st->data.group = NULL;
	st->data.zarfian = IFMD_Unrated;
	st->data.teaser = NULL;
	st->data.comment = NULL;
	st->data.rating = -1.0;
    
    st->data.description = NULL;
    st->data.coverpicture = -1;
    st->data.auxiliary = NULL;
	
	return st;
}

IFMDIdent* IFID_Alloc(void) {
	IFMDIdent* id;
	
	id = malloc(sizeof(IFMDIdent));
	
	id->format = IFFormat_Unknown;
	id->dataFormat = IFFormat_Unknown;
	id->usesMd5 = 0;
	
	return id;
}

/* = Copying = */
void IFIdent_Copy(IFMDIdent* dst, const IFMDIdent* src) {
	*dst = *src;
}

void IFStory_Copy(IFMDStory* dst, const IFMDStory* src) {
	IFStory_Free(dst);

	/* Idents, etc */
	dst->error = src->error;
	dst->numberOfIdents = src->numberOfIdents;
	
	if (src->numberOfIdents > 0) {
		int x;
		
		dst->idents = malloc(sizeof(IFMDIdent*)*src->numberOfIdents);
		
		for (x=0; x<src->numberOfIdents; x++) {
			dst->idents[x] = IFID_Alloc();
			IFIdent_Copy(dst->idents[x], src->idents[x]);
		}
	} else {
		dst->idents = NULL;
	}
	
	/* Data */
	dst->data.title = Xcopy(src->data.title);
	dst->data.headline = Xcopy(src->data.headline);
	dst->data.author = Xcopy(src->data.author);
	dst->data.genre = Xcopy(src->data.genre);
	dst->data.group = Xcopy(src->data.group);
	dst->data.teaser = Xcopy(src->data.teaser);
	dst->data.comment = Xcopy(src->data.comment);
	
	dst->data.year = src->data.year;
	dst->data.zarfian = src->data.zarfian;
	dst->data.rating = src->data.rating;
    
    dst->data.coverpicture = src->data.coverpicture;
    dst->data.description = Xcopy(src->data.description);
    dst->data.auxiliary = NULL; /* FIXME */
}

/* = Modification functions = */

void IFMD_AddStory(IFMetadata* data, IFMDStory* storyToAdd) {
	int x;
	IFMDStory* newEntry;
	
	/* Try to find the old story if it exists */
	
	/* Add story to the list */
	data->numberOfStories++;
	data->stories = realloc(data->stories, sizeof(IFMDStory*)*data->numberOfStories);
	
	data->stories[data->numberOfStories-1] = IFStory_Alloc();
	IFStory_Copy(data->stories[data->numberOfStories-1], storyToAdd);
	
	newEntry = data->stories[data->numberOfStories-1];
	
	/* Add story to the index, remove any idents that appear twice */
#define BINARY_SEARCH
	for (x=0; x<storyToAdd->numberOfIdents; x++) {
#ifndef BINARY_SEARCH
		int res, cmp;
		IFMDIdent* id = storyToAdd->idents[x];
		
		cmp = -1;
		for (res=0; res<data->numberOfIndexEntries; res++) {
			cmp = IFID_Compare(data->index[res].ident, id);
			if (cmp != -1) break;
		}
#else
		int top, bottom, res, cmp;
		IFMDIdent* id = storyToAdd->idents[x];
		
		bottom = 0;
		top = data->numberOfIndexEntries-1;
		res = 0;
		cmp = -1;
		
		while (bottom < top) {
			int middle = (bottom + top)>>1;
			cmp = IFID_Compare(data->index[middle].ident, id);
			
			if (cmp == 0) { res = middle; break; }
			else if (cmp < 0) bottom = middle+1;
			else if (cmp > 0) top    = middle-1;
		}
		
		/* Maneuver to the right place to add new entries */
		if (cmp != 0) res = bottom;
		if (res < 0) res++;
		if (res >= data->numberOfIndexEntries)
			res--;
		
		if (res >= 0)
			cmp = IFID_Compare(data->index[res].ident, id);
		else
			cmp = -1;
		
		/* Move down */
		while (cmp > 0 && res > 0) {
			res--;
			cmp = IFID_Compare(data->index[res].ident, id);
		}
		
		/* Move up */
		while (cmp < 0 && res < data->numberOfIndexEntries-1) {
			res++;
			cmp = IFID_Compare(data->index[res].ident, id);
		}
		
		/* Fall off the end if need be */
		if (cmp < 0 && res == data->numberOfIndexEntries-1) {
			res++;
		}
#endif
		
		/* Res should now be equal to the first place where cmp = 1 */
		
		if (res != -1 && cmp == 0) {
			if (data->index[res].story != newEntry) {
				int storyId, y;
				IFMDStory* thisStory = data->index[res].story;
				
				/* Delete this ident from the index */
				data->numberOfIndexEntries--;
				memmove(data->index+res,
						data->index+res+1,
						sizeof(*data->index)*(data->numberOfIndexEntries-res));
				
				/* Delete this ident from its story */
				storyId = -1;
				
				for (y=0; y<thisStory->numberOfIdents; y++) {
					if (IFID_Compare(thisStory->idents[y], id) == 0) { storyId = y; break; }
				}
				
				if (storyId >= 0) {
					IFID_Free(thisStory->idents[y]);
					free(thisStory->idents[y]);
					
					thisStory->numberOfIdents--;
					memmove(thisStory->idents+storyId,
							thisStory->idents+storyId+1,
							sizeof(IFMDIdent*)*(thisStory->numberOfIdents-storyId));
					
					if (thisStory->numberOfIdents == 0) {
						/* Used to do this: */
						/* thisStory->error = 1; */ /* Won't be saved/indexed any more */
						/* Was simple, and slightly problematic for what I want to do */
						/* Ergo, must delete this story from the list */
						int storyNum = -1;
						int z;
						
						/* thisStory must be in data->stories */
						for (z=0; z<data->numberOfStories; z++) {
							if (data->stories[z] == thisStory) {
								storyNum = z; break;
							}
						}
						
						if (storyNum < 0 || storyNum >= data->numberOfStories) {
							/* Subtly handle this error condition */
							abort(); /* BLEAAARRRGH */
						}
						
						if (newEntry == thisStory) {
							/* Programmer is a spoon */
							abort();
						}
						
						/* Rearrange the stories */
						data->numberOfStories--;
						memmove(data->stories+storyNum,
								data->stories+storyNum+1,
								sizeof(IFMDStory*)*(data->numberOfStories-storyNum));
						
						/* Delete this story */
						IFStory_Free(thisStory);
						free(thisStory);
					}
				}
			}
		}
		
		/* Res should now be equal to the first place where cmp = 1 */
		data->numberOfIndexEntries++;
		data->index = realloc(data->index, sizeof(IFMDIndexEntry)*data->numberOfIndexEntries);
		memmove(data->index+res + 1, data->index+res, sizeof(IFMDIndexEntry)*(data->numberOfIndexEntries-res-1));
		
		data->index[res].story = newEntry;
		data->index[res].ident = newEntry->idents[x];
	}
	
	return;
}

void IFMD_DeleteStory(IFMetadata* data, IFMDIdent* id) {
    /* Find the entry to delete */
    int x;
    int freeID;
    int top, bottom, res, cmp;
    IFMDStory* story;
    
    bottom = 0;
    top = data->numberOfIndexEntries-1;
    res = 0;
    cmp = -1;
    
    while (bottom < top) {
        int middle = (bottom + top)>>1;
        cmp = IFID_Compare(data->index[middle].ident, id);
        
        if (cmp == 0) { res = middle; break; }
        else if (cmp < 0) bottom = middle+1;
        else if (cmp > 0) top    = middle-1;
    }
    
    /* If cmp is 0, then we haven't found anythiung interesting */
    if (cmp != 0) return;
    
    /* Delete this ID from the list of IDs supported by the story*/
    story = data->index[res].story;
    
    freeID = 0;
    for (x=0; x<story->numberOfIdents; x++) {
        if (IFID_Compare(story->idents[x], id) == 0) {
            /* Delete this ident (might cause id to be freed as well!) */
            if (story->idents[x] != id)
                IFID_Free(story->idents[x]);
            else
                freeID = 1;
            
            story->numberOfIdents--;
            memmove(story->idents + x, story->idents + x + 1, sizeof(IFMDIdent*)*(story->numberOfIdents-x));
            
            x--;
        }
    }
    
    if (freeID) {
        /* One of the IDs we would have freed is the ID that was passed as a parameter */
        IFID_Free(id);
    }
    
    /* Delete the story itself if necessary */
    if (story->numberOfIdents <= 0) {
        for (x=0; x<data->numberOfStories; x++) {
            if (data->stories[x] == story) {
                data->numberOfStories--;
                memmove(data->stories + x, data->stories + x + 1, sizeof(IFMDStory*)*(data->numberOfStories-x));
                
                x--;
            }
        }
        
        IFStory_Free(story);
    }
    
    /* Delete res from the index */
    data->numberOfIndexEntries--;
    memmove(data->index + res, data->index + res + 1, sizeof(IFMDIndexEntry)*(data->numberOfIndexEntries-res));
}

/* Saving metadata */
static unsigned char* makeutf8xml(IFMDChar* string, int allowNewlines) {
	unsigned char* res = NULL;
	int len = 0;
	int pos = 0;
	int x;
	
#define add(c) if (len <= pos) { len += 256; res = realloc(res, sizeof(unsigned char)*len); } res[pos++] = c
	
	for (x=0; string[x] != 0; x++) {
		IFMDChar chr = string[x];

		switch (chr) {
			case '<':
				add('&'); add('l'); add('t'); add(';');
				break;
			case '>':
				add('&'); add('g'); add('t'); add(';');
				break;
			case '&':
				add('&'); add('a'); add('m'); add('p'); add(';');
				break;
			case '\'':
				add('&'); add('a'); add('p'); add('o'); add('s'); add(';');
				break;
			case '\"':
				add('&'); add('q'); add('u'); add('o'); add('t'); add(';');
				break;
			case '\n':
				if (allowNewlines) {
					add('<'); add('b'); add('r'); add('/'); add('>');
				}
				break;
				
			default:
                if (chr < 0x20) {
                    /* These are for the most part invalid */
                    /* 
                       Actually, according to the XML spec, they are fine, but expat complains and pain often 
                       results. This *will* prevent certain broken game files from indexing properly, and will
                       generally result in duplicate entries in these cases.
                    */
				} else if (chr < 0x80) {
					add(chr);
				} else if (chr < 0x800) {
					add(0xc0 | (chr>>6));
					add(0x80 | (chr&0x3f));
				} else if (chr < 0x10000) {
					add(0xe0 | (chr>>12));
					add(0x80 | ((chr>>6)&0x3f));
					add(0x80 | (chr&0x3f));
				} else if (chr < 0x200000) {
					add(0xf0 | (chr>>18));
					add(0x80 | ((chr>>12)&0x3f));
					add(0x80 | ((chr>>6)&0x3f));
					add(0x80 | (chr&0x3f));
				} else {
					/* These characters can't be represented by unicode anyway */
				}
		}
	}
	
	add(0);
	return res;
}

int IFMD_Save(IFMetadata* data, 
			  int(*writeFunction)(const char* bytes, int length, void* userData), 
			  void* userData) {
	/*
	 * We save in UTF-8 format. UTF-16 may be more efficient if characters outside ASCII are in 
	 * common use
	 */
	int story;
	unsigned char* utf8;

#define ws(s) if (writeFunction((const char*)s, (int)strlen((const char*)s), userData) != 0) return 1;
#define wutf(s) utf8 = makeutf8xml(s, 0); ws(utf8); free(utf8);
#define wutfblock(s) utf8 = makeutf8xml(s, 1); ws(utf8); free(utf8);
	
	/* Header */
	ws("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
	ws("<ifindex version=\"0.9\">\n");
	ws(" <!-- Metadata output generated automatically by ifmetadata.c by Andrew Hunter -->\n");
	
	/* For each story */
	for (story=0; story<data->numberOfStories; story++) {
		int ident;
		IFMDStory* thisStory = data->stories[story];
		
		if (thisStory->error) continue; /* No erroneous stories */
		if (thisStory->numberOfIdents == 0) continue; /* No nonexistent stories */
		
		ws("\n <story>\n");
		
		/* Write the idents */
		for (ident=0; ident<thisStory->numberOfIdents; ident++) {
			IFMDIdent* thisIdent = thisStory->idents[ident];
			
			ws("  <id>\n");

			/* Data format */
			ws("   <format>");
			switch (thisIdent->format) {
				case IFFormat_ZCode: ws("zcode"); break;
				case IFFormat_Glulx: ws("glulx"); break;
				
				case IFFormat_TADS: ws("tads"); break;
				case IFFormat_HUGO: ws("hugo"); break;
				case IFFormat_Alan: ws("alan"); break;
				case IFFormat_Adrift: ws("adrift"); break;
				case IFFormat_Level9: ws("level9"); break;
				case IFFormat_AGT: ws("agt"); break;
				case IFFormat_MagScrolls: ws("magscrolls"); break;
				case IFFormat_AdvSys: ws("advsys"); break;
				default: ws("unknown"); break;
			}
			ws("</format>\n");
			
			/* Format-specific data */
			switch (thisIdent->dataFormat) {
                case IFFormat_UUID:
                {
                    char buf[40];
                    int x;
                    
                    ws("    <uuid>\n");
                    ws("      <uuid>");
                    
                    int bufPos = 0;
                    for (x=0; x<16; x++) {
                        char thisByte[4];
                        
                        snprintf(thisByte, 4, "%02x", thisIdent->data.uuid.uuid[x]);
                        
                        buf[bufPos++] = thisByte[0];
                        buf[bufPos++] = thisByte[1];
                        
                        if (x == 3 || x == 5 || x == 7 || x == 9) {
                            buf[bufPos++] = '-';
                        }
                    }
                    
                    buf[bufPos++] = 0;
                    
                    ws(buf);
                    
                    ws("</uuid>\n");
                    ws("    </uuid>\n");
                    break;
                }
                
				case IFFormat_ZCode:
				{
					char buf[16];
                    IFMDChar cbuf[16];
                    int x;
					
					ws("   <zcode>\n");
					
					ws("    <serial>");
					snprintf(buf, 16, "%.6s", thisIdent->data.zcode.serial);
                    for (x=0; x<16; x++) cbuf[x] = buf[x];
					//ws(buf);
                    wutf(cbuf);
					ws("</serial>\n");
					
					ws("    <release>");
					snprintf(buf, 16, "%i", thisIdent->data.zcode.release);
					ws(buf);
					ws("</release>\n");
					
					if (thisIdent->data.zcode.checksum < 0x10000) {
						ws("    <checksum>");
						snprintf(buf, 16, "%04x", thisIdent->data.zcode.checksum);
						ws(buf);
						ws("</checksum>\n");
					}
					
					ws("   </zcode>\n");
					break;
				}
					
				default:
					ws("    <!-- Format-specific data not current supported for this format -->\n");
					break;
			}
			
			/* MD5 */
			if (thisIdent->usesMd5) {
				int x;
				
				ws("   <md5>");
				for (x=0; x<16; x++) {
					char s[4];
					
					snprintf(s, 4, "%02x", (unsigned char) thisIdent->md5Sum[x]);
				}
				ws("   </md5>\n");
			}
			
			ws("  </id>\n");
		}
		
		/* Write the metadata */
		if (thisStory->data.title && thisStory->data.title[0] != 0) {
			ws("  <title>");
			wutf(thisStory->data.title);
			ws("</title>\n");
		}

		if (thisStory->data.headline && thisStory->data.headline[0] != 0) {
			ws("  <headline>");
			wutf(thisStory->data.headline);
			ws("</headline>\n");
		}
		
		if (thisStory->data.author && thisStory->data.author[0] != 0) {
			ws("  <author>");
			wutf(thisStory->data.author);
			ws("</author>\n");
		}
		
		if (thisStory->data.genre && thisStory->data.genre[0] != 0) {
			ws("  <genre>");
			wutf(thisStory->data.genre);
			ws("</genre>\n");
		}

		if (thisStory->data.year != 0) {
			char buf[16];
			
			snprintf(buf, 16, "%i", thisStory->data.year);
			
			ws("  <year>");
			ws(buf);
			ws("</year>\n");
		}

		if (thisStory->data.group && thisStory->data.group[0] != 0) {
			ws("  <group>");
			wutf(thisStory->data.group);
			ws("</group>\n");
		}

		if (thisStory->data.zarfian != IFMD_Unrated) {
			switch (thisStory->data.zarfian) {
				case IFMD_Merciful: ws("  <zarfian>merciful</zarfian>\n"); break;
				case IFMD_Polite: ws("  <zarfian>polite</zarfian>\n"); break;
				case IFMD_Tough: ws("  <zarfian>tough</zarfian>\n"); break;
				case IFMD_Nasty: ws("  <zarfian>nasty</zarfian>\n"); break;
				case IFMD_Cruel: ws("  <zarfian>cruel</zarfian>\n"); break;
				default: break;
			}
		}

		if (thisStory->data.teaser && thisStory->data.teaser[0] != 0) {
			ws("  <teaser>\n   ");
			wutfblock(thisStory->data.teaser);
			ws("\n  </teaser>\n");
		}

		if (thisStory->data.comment && thisStory->data.comment[0] != 0) {
			ws("  <comment>\n   ");
			wutfblock(thisStory->data.comment);
			ws("\n  </comment>\n");
		}
		
		if (thisStory->data.rating >= 0) {
			char buf[16];
			
			snprintf(buf, 16, "%.2f", thisStory->data.rating);
			
			ws("  <rating>");
			ws(buf);
			ws("</rating>\n");
		}
        
        /* Inform 7 fields */
        
        if (thisStory->data.coverpicture >= 0) {
			char buf[16];
			
			snprintf(buf, 16, "%i", thisStory->data.coverpicture);
			
			ws("  <coverpicture>");
			ws(buf);
			ws("</coverpicture>\n");
        }
        if (thisStory->data.description != NULL) {
			ws("  <description>\n");
			wutfblock(thisStory->data.description);
			ws("\n  </description>\n");
        }
        
        if (thisStory->data.auxiliary != NULL) {
            IFMDAuxiliary* aux = thisStory->data.auxiliary;
            
            while (aux != NULL) {
                ws("  <auxiliary>\n");
                
                if (aux->leafname) {
                    ws("   <leafname>");
                    wutf(aux->leafname);
                    ws("</leafname>\n");
                }
                
                if (aux->description) {
                    ws("   <description>");
                    wutf(aux->description);
                    ws("</description>\n");
                }
                
                ws("  </auxiliary>\n");
                
                aux = aux->next;
            }
        }
		
		ws(" </story>\n");
	}
	
	/* Finish up */
	ws("</ifindex>\n");
	
	return 0;
}

#ifdef IFMD_ALLOW_TESTING
/* ==== TESTING ==== */

/*
 * Sometimes, it seems a game's description can disappear when it's transferred from one
 * iFiction repository to another. These functions are designed to test the addition and
 * removal of items to a repository.
 *
 * I haven't yet seen this for an 'established' game: IE, I think it's a problem to do
 * with adding a new game to a repository.
 */
static int indexCheck(IFMetadata* data) {
	int x;
	int result = 1;
	int missing = 0;
	int wrongStory = 0;
	int outOfOrder = 0;
	
	for (x=0; x<data->numberOfIndexEntries; x++) {
		IFMDStory* story = IFMD_Find(data,  data->index[x].ident);
		
		if (story == NULL) {
			missing++;
			result = 0;
		} else if (story != data->index[x].story) {
			wrongStory++;
			result = 0;
		}
		
		if (x > 0) {
			int cmp;
			cmp = IFID_Compare(data->index[x-1].ident, data->index[x].ident);
			if (cmp != -1) {
				printf(" OO: %i/%i", cmp, x);
				outOfOrder++;
				result = 0;
			}
		}
	}
	
	if (result == 0) {
		printf(" FAIL: %i/%i/%i (%i) ", missing, wrongStory, outOfOrder, data->numberOfIndexEntries);
	}

	return result;
}

static int storyCheck(IFMetadata* data) {
	int x;
	int result = 1;
	int missing = 0;
	int wrongStory = 0;
	int count = 0;
	
	for (x=0; x<data->numberOfStories; x++) {
		int y;
		
		for (y=0; y<data->stories[x]->numberOfIdents; y++) {
			IFMDStory* story = IFMD_Find(data, data->stories[x]->idents[y]);
			
			count++;
			
			if (story == NULL) {
				missing++;
				result = 0;
			} else if (story != data->stories[x]) {
				wrongStory++;
				result = 0;
			}
		}
	}
	
	if (result == 0) {
		printf(" FAIL: %i/%i (%i) ", missing, wrongStory, count);
	}
	
	return result;
}

void IFMD_testrepository(IFMetadata* data) {
	IFMetadata* newData;
	int x;
	int iter;
	
	printf("= IFMetadata testing started\n");
	printf("== Repository has %i entries, and was parsed with %i errors\n", data->numberOfStories, data->numberOfErrors);
	printf("== Index contains %i entries\n", data->numberOfIndexEntries);
	printf("==\n");
	
	// Test one: check index entries are in order and check that we can find them OK
	printf("== TEST ONE: existing index test - %s\n", indexCheck(data)?"Passed":"Failed");
	
	// Test two: make sure that index entries are available for all idents stored in stories
	printf("== TEST TWO: complete index test - %s\n", storyCheck(data)?"Passed":"Failed");
	
	// Test three: create a new metadata set, add all the stories from this one to it, several times
	// (additional passes determine the failure pattern in
	printf("== TEST THREE: new data test:\n");
	
	newData = IFMD_Alloc();
	
	for (iter = 0; iter<4; iter++) {
		for (x=0; x<data->numberOfStories; x++) {
			IFMD_AddStory(newData, data->stories[x]);
			indexCheck(newData);
		}
		
		printf("=== %i - %s/%s\n", iter, indexCheck(newData)?"Passed":"Failed", storyCheck(newData)?"Passed":"Failed");
	}
	printf("\n");
	
	IFMD_Free(newData);
	
	printf("= IFMetadata testing complete\n");
}
#endif
