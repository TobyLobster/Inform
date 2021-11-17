/*
 *  ifmetaxml.c
 *  ZoomCocoa
 *
 *  Created by Andrew Hunter on 04/04/2006.
 *  Copyright 2006 Andrew Hunter. All rights reserved.
 *
 */

#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdio.h>

#include <expat.h>

#include "ifmetaxml.h"

#ifdef HAVE_COREFOUNDATION
#include <CoreFoundation/CoreFoundation.h>
#endif

/* == Reading ifiction records == */

#ifndef XMLCALL
/* Not always defined? */
# define XMLCALL
#endif

/* The XML parser function declarations */
static XMLCALL void StartElement(void *userData,
								 const XML_Char *name,
								 const XML_Char **atts);
static XMLCALL void EndElement  (void *userData,
								 const XML_Char *name);
static XMLCALL void CharData    (void *userData,
								 const XML_Char *s,
								 int len);

/* The parser state structure */
typedef struct IFXmlTag {
	IFChar* value;
	XML_Char* name;
	int failed;
	
	char* path;
	
	struct IFXmlTag* parent;
} IFXmlTag;

typedef struct IFXmlState {
	XML_Parser parser;
	IFMetabase meta;
	
	int failed;					/* Set to 1 if the parsing suffers a fatal error */
	
	int version;				/* 090 or 100, or 0 if no <ifindex> tag has been encountered */
	
	IFXmlTag* tag;				/* The current topmost tag */
	
	IFID storyId;				/* The identification chunks to attach to the current story, once we've finished building it */
	IFStory story;				/* The story that we're building */
	
	IFMetabase tempMetabase;	/* A temporary metabase that we put half-built stories into */
	IFID tempId;				/* The ID of a temporary story */
	
	int release;				/* For 0.9 zcode IDs: the release # */
	char serial[6];				/* For 0.9 zcode IDs: the serial # */
	int checksum;				/* For 0.9 zcode IDs: the checksum */
} IFXmlState;

/* Load the records contained in the specified */
void IF_ReadIfiction(IFMetabase meta, const unsigned char* xml, size_t size) {
	XML_Parser theParser;
	IFXmlState* currentState;
	
	/* Construct the parser state structure */
	currentState = malloc(sizeof(IFXmlState));
	
	currentState->meta = meta;
	currentState->failed = 0;
	currentState->version = 0;
	currentState->story = NULL;
		
	currentState->storyId = NULL;
	currentState->story = NULL;
	currentState->tag = NULL;
	
	currentState->tempMetabase = IFMB_Create();
	currentState->tempId = IFMB_GlulxIdNotInform(0, 0);
	
	/* Begin parsing */
	theParser = XML_ParserCreate(NULL);
	currentState->parser = theParser;

	XML_SetElementHandler(theParser, StartElement, EndElement);
	XML_SetCharacterDataHandler(theParser, CharData);
	XML_SetUserData(theParser, currentState);
	
	/* Ready? Go! */
	XML_Parse(theParser, (const char*)xml, (int)size, 1);
	
	/* Clear up any temp stuff we may have created */
	if (currentState->storyId) IFMB_FreeId(currentState->storyId);
	IFMB_FreeId(currentState->tempId);
	IFMB_Free(currentState->tempMetabase);
	
	free(currentState);
	
	XML_ParserFree(theParser);
}

/* Some string utility functions */

/* This isn't used if we're using CoreFoundation. */
#ifndef HAVE_COREFOUNDATION
static const unsigned char bytesFromUTF8[256] = {
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
	2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, 3,3,3,3,3,3,3,3,4,4,4,4,5,5,5,5};
#endif

/* Compare an XML string against a C string */
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

/* Converts s to IFChars. Result needs to be freed */
static int Xstrlen(const XML_Char* a) {
	int x;
	
	if (a == NULL) return 0;
	
	for (x=0; a[x] != 0; x++);
	
	return x;
}

/* Converts 's' to simple ASCII. The return value must be freed */
static char* Xascii(const IFChar* s) {
	char* res;
	int x;
	int len = IFMB_StrLen(s);
	
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

static IFChar* Xmdchar(const XML_Char* s, int len) {
#ifdef HAVE_COREFOUNDATION
	if (len < 0) len = Xstrlen(s);
	static_assert(sizeof(XML_Char) == sizeof(char), "Expected XML_Char to be the same size as a char, as is in Apple's built-in expat.");
	CFStringRef str = CFStringCreateWithBytesNoCopy(NULL, s, len, kCFStringEncodingUTF8, true, kCFAllocatorNull);
	CFDataRef utf16Data = CFStringCreateExternalRepresentation(NULL, str, kCFStringEncodingUTF16LE, '?');
	CFRelease(str);
	
	size_t dataLen = CFDataGetLength(utf16Data);
	IFChar* res = malloc(dataLen+2);
	CFDataGetBytes(utf16Data, CFRangeMake(0, dataLen), (UInt8 *)res);
	res[dataLen/2] = 0;
	
	CFRelease(utf16Data);
	
	return res;
#else
	int x, pos;
	IFChar* res;
	
	if (len < 0) len = Xstrlen(s);
	
	res = malloc(sizeof(IFChar)*(len+1));
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
#endif
}

/* Error handling/reporting */

char* IF_StringForError(IFXmlError errorCode) {
	switch (errorCode) {
		case IFXmlNotIfiction: return "IFXmlNotIfiction";
		case IFXmlNoVersionSupplied: return "IFXmlNoVersionSupplied";
		case IFXmlVersionIsTooRecent: return "IFXmlVersionIsTooRecent";
		
		case IFXmlMismatchedTags: return "IFXmlMismatchedTags";
		case IFXmlUnrecognisedTag: return "IFXmlUnrecognisedTag";
		
		case IFXmlBadId: return "IFXmlBadId";
		case IFXmlBadZcodeSection: return "IFXmlBadZcodeSection";
		case IFXmlStoryWithNoId: return "IFXmlStoryWithNoId";
	}
	
	return "IFXMLUnknownError";
}

static void Error(IFXmlState* state, IFXmlError errorType, void* errorData) {
	XML_Size line, column;
	
	line = XML_GetCurrentLineNumber(state->parser);
	column = XML_GetCurrentColumnNumber(state->parser);
	
	printf("**** Ifiction ERROR: %s <%i> (line=%lu, column=%lu)\n", IF_StringForError(errorType), errorType, line, column);
}

/* The XML parser itself */

static XMLCALL void StartElement(void *userData,
								 const XML_Char *name,
								 const XML_Char **atts) {
	IFXmlState* state;
	int x;
	IFXmlTag* tag;
	XML_Char* parent;
	
	/* Get the state */
	state = (IFXmlState*)userData;
	
	if (state->tag) {
		parent = state->tag->name;
	} else {
		parent = "";
	}
	
	/* Put this tag onto the tag stack */
	tag = malloc(sizeof(IFXmlTag));

	tag->value = malloc(sizeof(IFChar));
	tag->value[0] = 0;
	tag->name = malloc(sizeof(char)*(strlen(name)+1));
	tag->path = NULL;
	strcpy(tag->name, name);
	
	tag->parent = state->tag;
	if (tag->parent) {
		tag->failed = tag->parent->failed;
	} else {
		tag->failed = 0;
	}
	
	state->tag = tag;

	/* Do nothing else if the parse has failed fatally for some reason */
	if (state->failed) return;
	
	/* The action we take depends on the current state and the next token */
	if (state->version == 0) {
		if (XCstrcmp(name, "ifindex") != 0) {
			Error(state, IFXmlNotIfiction, NULL);
			state->failed = 1;
			return;
		}
		
		/* How the file is parsed depends on the version number that's supplied */
		for (x=0; atts[x] != NULL; x+=2) {
			if (XCstrcmp(atts[x], "version") == 0) {
				double version;
				
				version = strtod(atts[x+1], NULL);
				state->version = version * 100;
			}
		}

		if (state->version == 0) {
			Error(state, IFXmlNoVersionSupplied, NULL);
			state->failed = 1;
		} else if (state->version > 100) {
			Error(state, IFXmlVersionIsTooRecent, NULL);
			state->failed = 1;
		}
	} else if (XCstrcmp(name, "br") == 0) {
		/* 'br' tags are allowed anywhere and just add a newline to the tag value */
		if (state->tag->parent) {
			int valueLen = IFMB_StrLen(state->tag->parent->value);
			
			state->tag->parent->value = realloc(state->tag->parent->value, sizeof(IFChar)*(valueLen+2));
			
			state->tag->parent->value[valueLen] = '\n';
			state->tag->parent->value[valueLen+1] = 0;
		}
	} else if (state->version == 90) {
		
		/* == Version 0.9 identification and data format == */

		if (state->tag->failed) {
			/* Just ignore 'failed' tags */
		} else if (XCstrcmp(parent, "ifindex") == 0) {
			/* Tags under the 'ifindex' root tag */
			if (XCstrcmp(name, "story") == 0) {
				/* Start of a story */
				if (state->storyId != NULL) {
					IFMB_FreeId(state->storyId);
					state->storyId = NULL;
				}
				
				IFMB_RemoveStoryWithId(state->tempMetabase, state->tempId);
				state->story = IFMB_GetStoryWithId(state->tempMetabase, state->tempId);
			} else {
				/* Unknown tag */
				Error(state, IFXmlUnrecognisedTag, NULL);
				state->tag->failed = 1;
			}
		} else if (XCstrcmp(parent, "story") == 0) {
			/* Tags under the 'story' tag */
			if (XCstrcmp(name, "identification") == 0 || XCstrcmp(name, "id") == 0) {
				/* Start of an identification chunk */
			} else if (XCstrcmp(name, "title") == 0) {
			} else if (XCstrcmp(name, "headline") == 0) {
			} else if (XCstrcmp(name, "author") == 0) {
			} else if (XCstrcmp(name, "genre") == 0) {
			} else if (XCstrcmp(name, "year") == 0) {
			} else if (XCstrcmp(name, "group") == 0) {
			} else if (XCstrcmp(name, "zarfian") == 0) {
			} else if (XCstrcmp(name, "teaser") == 0) {
			} else if (XCstrcmp(name, "comment") == 0) {
			} else if (XCstrcmp(name, "rating") == 0) {
			} else if (XCstrcmp(name, "description") == 0) {
			} else if (XCstrcmp(name, "coverpicture") == 0) {
			} else if (XCstrcmp(name, "auxiliary") == 0) {
			} else {
				/* Unknown tag */
				Error(state, IFXmlUnrecognisedTag, NULL);
				state->tag->failed = 1;
			}
		} else if (XCstrcmp(parent, "identification") == 0 || XCstrcmp(parent, "id") == 0) {
			if (XCstrcmp(name, "zcode") == 0) {
				int x;
				
				for (x=0; x<6; x++) state->serial[x] = '-';
				state->release = -1;
				state->checksum = -1;
				
			} else if (XCstrcmp(name, "format") == 0) {
			} else if (XCstrcmp(name, "uuid") == 0) {
			} else {
				Error(state, IFXmlUnrecognisedTag, NULL);
				state->tag->failed = 1;
			}
		} else if (XCstrcmp(parent, "zcode") == 0) {
			if (XCstrcmp(name, "release") == 0) {
			} else if (XCstrcmp(name, "serial") == 0) {
			} else if (XCstrcmp(name, "checksum") == 0) {
			} else {
				Error(state, IFXmlUnrecognisedTag, NULL);
			}
		} else {
			Error(state, IFXmlUnrecognisedTag, NULL);
		}
	} else {
		
		/* == Version 1.0 identification and data format == */
		
		if (XCstrcmp(parent, "ifindex") == 0 && XCstrcmp(name, "story") == 0) {
			
			/* Start of a story tag */
			
			if (state->storyId != NULL) {
				IFMB_FreeId(state->storyId);
				state->storyId = NULL;
			}
			
			IFMB_RemoveStoryWithId(state->tempMetabase, state->tempId);
			state->story = IFMB_GetStoryWithId(state->tempMetabase, state->tempId);

		} else if (XCstrcmp(name, "identification") == 0 || XCstrcmp(name, "id") == 0) {
			/* Version 1.0 identification section (handled when closing the tag) */
		} else if (XCstrcmp(parent, "identification") == 0 || XCstrcmp(parent, "id") == 0) {
			/* Tag within a version 1.0 identification section (handled when closing the tag) */
		} else if (state->story != NULL) {
			
			char* lastPath;
			char* fullPath;
			
			/* Tag within a story */
			
			/* Concatenate the path with the path of the previous tag */
			if (state->tag->parent->path == NULL) {
				lastPath = "";
			} else {
				lastPath = state->tag->parent->path;
			}
			
			fullPath = malloc(sizeof(XML_Char)*(strlen(lastPath) + 2 + strlen(name)));
			
			if (lastPath[0] != 0) {
				strcpy(fullPath, lastPath);
				strcat(fullPath, ".");
				strcat(fullPath, name);
			} else {
				strcpy(fullPath, name);
			}
			
			state->tag->path = fullPath;
			
			/* Add a key for this path */
			IFMB_AddValue(state->story, fullPath);
			
			/* Add any attributes that were set */
			for (x=0; atts[x] != NULL; x += 2) {
				char* attributePath;
				IFChar* attributeValue;
				
				/* Get the path for this attribute */
				attributePath = malloc(strlen(fullPath)+strlen(atts[x])+2);
				strcpy(attributePath, fullPath);
				strcat(attributePath, "@");
				strcat(attributePath, atts[x]);
				
				attributeValue = Xmdchar(atts[x+1], (int)strlen(atts[x+1]));
				
				/* Set the value */
				IFMB_SetValue(state->story, attributePath, attributeValue);
				
				/* Tidy up */
				free(attributePath);
			}
		}
	}
}

static XMLCALL void EndElement(void *userData,
							   const XML_Char *name) {
	IFXmlState* state;
	IFXmlTag* tag;
	int pos, whitePos;
	XML_Char* parent;
	IFChar* value;
	
	/* Get the state */
	state = (IFXmlState*)userData;
	if (state->failed) return;
	if (state->tag == NULL) return;
	
	if (XCstrcmp(state->tag->name, name) != 0) {
		/* Mismatched tags */
		Error(state, IFXmlMismatchedTags, NULL);
		state->tag->failed = 1;
	}
	
	if (state->tag->parent) {
		parent = state->tag->parent->name;
	} else {
		parent = "";
	}
	
	/* Trim out whitespace for the current tag */
	pos = whitePos = 0;
	
	while (state->tag->value[whitePos] == ' ') whitePos++;
	while (state->tag->value[whitePos] != 0) {
		state->tag->value[pos++] = state->tag->value[whitePos];

		if (state->tag->value[whitePos] == ' ' || state->tag->value[whitePos] == '\n') {
			whitePos++;
			while (state->tag->value[whitePos] == ' ') whitePos++;
		} else {
			whitePos++;
		}
	}
	
	if (pos > 0 && state->tag->value[pos-1] == ' ') pos--;
	state->tag->value[pos] = 0;
	
	value = state->tag->value;

	/* Perform an action on this tag */
	if (!state->tag->failed) {
		if (XCstrcmp(name, "br") == 0) {
			/* br tags are supported anywhere */
		} else if (state->version == 90) {
			
			/* == Handle version 0.90 tags == */
			
			if (XCstrcmp(parent, "identification") == 0 || XCstrcmp(parent, "id") == 0) {
				/* An identification section */
				if (XCstrcmp(name, "zcode") == 0) {
					/* End of a ZCode ID */
					if (state->release < 0) {
						Error(state, IFXmlBadZcodeSection, NULL);
					} else {
						IFID newId;
						
						newId = IFMB_ZcodeId(state->release, state->serial, state->checksum);
						
						if (state->storyId == NULL) {
							state->storyId = newId;
						} else {
							IFID ids[2];
							IFID compoundId;
							
							ids[0] = newId;
							ids[1] = state->storyId;
							
							compoundId = IFMB_CompoundId(2, ids);
							
							IFMB_FreeId(newId);
							IFMB_FreeId(state->storyId);
							
							state->storyId = compoundId;
						}
					}
				}
			} else if (XCstrcmp(parent, "zcode") == 0) {
				/* zcode identification section */
				
				if (XCstrcmp(name, "serial") == 0) {
					int x;
					
					for (x=0; x<6 && value[x] != 0; x++) {
						state->serial[x] = value[x];
					}
				} else if (XCstrcmp(name, "release") == 0) {
					char* release = Xascii(value);
					
					state->release = atoi(release);
					
					free(release);
				} else if (XCstrcmp(name, "checksum") == 0) {
					char* checksum = Xascii(value);
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
					
					state->checksum = val;
					
					free(checksum);
				}
			} else if (XCstrcmp(parent, "uuid") == 0) {
				/* UUID identification section */
				if (XCstrcmp(name, "uuid") == 0) {
					unsigned char uuid[16];
					int uuidPos;
					int x;
					IFID newId;
					
					for (x=0; x<16; x++) uuid[x] = 0;
					
					/* Work out the UUID data */
					uuidPos = 0;
					for (x=0; value[x] != 0; x++) {
						int digitVal = -1;
						
						if (value[x] == '\n' || value[x] == ' ' || value[x] == '-') continue;
						
						if (value[x] >= '0' && value[x] <= '9') {
							digitVal = value[x] - '0';
						} else if (value[x] >= 'a' && value[x] <= 'f') {
							digitVal = value[x] - 'a' + 10;
						} else if (value[x] >= 'A' && value[x] <= 'F') {
							digitVal = value[x] - 'A' + 10;
						}
						
						uuid[uuidPos>>1] |= digitVal << ((1-(uuidPos&1))*4);
						uuidPos++;
						if (uuidPos >= 32) break;
					}
					
					/* Merge with the currently generated IDs */
					newId = IFMB_UUID(uuid);
					
					if (state->storyId == NULL) {
						state->storyId = newId;
					} else {
						IFID ids[2];
						IFID compoundId;
						
						ids[0] = newId;
						ids[1] = state->storyId;
						
						compoundId = IFMB_CompoundId(2, ids);
						
						IFMB_FreeId(newId);
						IFMB_FreeId(state->storyId);
						
						state->storyId = compoundId;
					}
				}
			} else if (XCstrcmp(parent, "story") == 0) {
				/* Story data (or identification, which we ignore) */
				char* key = NULL;
				
				if (XCstrcmp(name, "title") == 0) {
					key = "bibliographic.title";
				} else if (XCstrcmp(name, "headline") == 0) {
					key = "bibliographic.headline";
				} else if (XCstrcmp(name, "author") == 0) {
					key = "bibliographic.author";
				} else if (XCstrcmp(name, "genre") == 0) {
					key = "bibliographic.genre";
				} else if (XCstrcmp(name, "year") == 0) {
					key = "bibliographic.firstpublished";
				} else if (XCstrcmp(name, "group") == 0) {
					key = "bibliographic.group";
				} else if (XCstrcmp(name, "zarfian") == 0) {
					key = "bibliographic.forgiveness";
				} else if (XCstrcmp(name, "teaser") == 0) {
					key = "zoom.teaser";
				} else if (XCstrcmp(name, "comment") == 0) {
					key = "zoom.comment";
				} else if (XCstrcmp(name, "rating") == 0) {
					key = "zoom.rating";
				} else if (XCstrcmp(name, "description") == 0) {
					key = "bibliographic.description";
				} else if (XCstrcmp(name, "coverpicture") == 0) {
					key = "zcode.coverpicture";
				} else if (XCstrcmp(name, "auxiliary") == 0) {
					key = "resources.auxiliary";
				}
				
				if (key != NULL && state->story != NULL) {
					IFMB_SetValue(state->story, key, value);
				}
			} else if (XCstrcmp(parent, "ifindex") == 0) {
				
				if (XCstrcmp(name, "story") == 0) {
					/* End of story: copy it into the main metabase */
					if (state->storyId != NULL) {
						IFMB_CopyStory(state->meta, state->story, state->storyId);
						
						IFMB_FreeId(state->storyId);
						state->storyId = NULL;
					} else {
						Error(state, IFXmlStoryWithNoId, NULL);
					}
				}
			}
			
		} else {
			
			/* == Handle version 1.00 tags == */
			
			if (XCstrcmp(parent, "identification") == 0 || XCstrcmp(parent, "id") == 0) {
				
				if (XCstrcmp(name, "ifid") == 0) {
					IFID newId;
					char* idValue;
					int x;
					
					/* Construct the IFID used here */
					idValue = malloc(sizeof(char)*(IFMB_StrLen(value)+1));
					for (x=0; value[x] != 0; x++) {
						idValue[x] = value[x];
					}
					idValue[x] = 0;
					
					newId = IFMB_IdFromString(idValue);
					free(idValue);
					
					if (newId != NULL) {
						
						/* Merge with the story ID that we're building at the moment */
						
						if (state->storyId == NULL) {
							state->storyId = newId;
						} else {
							IFID ids[2];
							IFID compoundId;
							
							ids[0] = newId;
							ids[1] = state->storyId;
							
							compoundId = IFMB_CompoundId(2, ids);
							
							IFMB_FreeId(newId);
							IFMB_FreeId(state->storyId);
							
							state->storyId = compoundId;
						}

					} else {
						
						/* This ID is invalid */
						Error(state, IFXmlBadId, NULL);
						
					}
				}
				
			} else if (state->tag->path != NULL) {

				/* Set the value for the current tag */
				IFMB_SetValue(state->story, state->tag->path, value);

			} else if (XCstrcmp(name, "story") == 0) {
				
				/* Store the story we've just finished building */
				if (state->storyId != NULL) {
					IFMB_CopyStory(state->meta, state->story, state->storyId);
					
					IFMB_FreeId(state->storyId);
					state->storyId = NULL;
					state->story = NULL;
				} else {
					Error(state, IFXmlStoryWithNoId, NULL);
				}
				
			}
		}
	}
	
	/* Pop this tag from the stack */
	tag = state->tag;
	state->tag = tag->parent;
	
	if (tag->path != NULL) free(tag->path);
	free(tag->value);
	free(tag->name);
	free(tag);
}

static XMLCALL void CharData(void *userData,
							 const XML_Char *s,
							 int len) {
	IFXmlState* state;
	int valueLen, charDataLen, x;
	IFChar* charData;
	
	/* Get the state */
	state = (IFXmlState*)userData;
	if (state->failed) return;
	if (state->tag == NULL) return;
	if (state->tag->failed) return;
	
	/* Append the character data for the current tag */
	charData = Xmdchar(s, len);
	charDataLen = IFMB_StrLen(charData);
	valueLen = IFMB_StrLen(state->tag->value);
	
	state->tag->value = realloc(state->tag->value, sizeof(IFChar)*(valueLen+charDataLen+1));
	
	for (x=0; x<charDataLen; x++) {
		IFChar c = charData[x];
		
		/* All whitespace characters become spaces */
		if (c == ' ' || c == '\n' || c == '\r' || c == '\t') {
			state->tag->value[valueLen+x] = ' ';
		} else {
			state->tag->value[valueLen+x] = charData[x];
		}
	}
	
	state->tag->value[valueLen+charDataLen] = 0;
	
	/* Tidy up after ourselves */
	free(charData);
}

/* == Writing ifiction records == */

static unsigned char* MakeUtf8Xml(IFChar* string, int allowNewlines) {
	unsigned char* res = NULL;
	int len = 0;
	int pos = 0;
	int x;
	
#define add(c) if (len <= pos) { len += 256; res = realloc(res, sizeof(unsigned char)*len); } res[pos++] = c
	
	for (x=0; string[x] != 0; x++) {
		IFChar chr = string[x];
		
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
				} else if (chr <= 0xffff) {
					add(0xe0 | (chr>>12));
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

/* Stack of iterators that are being processed */
typedef struct ValueStackItem {
	IFValueIterator iterator;
	struct ValueStackItem* previous;
} ValueStackItem;

void IF_WriteIfiction(IFMetabase meta, int(*writeFunction)(const char* bytes, int length, void* userData), void* userData) {
#define w(s) { unsigned char* res = s; writeFunction(res, (int)strlen(res), userData); }
#define wu(s) { unsigned char* res; res = MakeUtf8Xml(s, 1); writeFunction(res, (int)strlen(res), userData); free(res); }
#define wun(s) { unsigned char* res; res = MakeUtf8Xml(s, 0); writeFunction(res, (int)strlen(res), userData); free(res); }
	
	IFStoryIterator stories;
	ValueStackItem* values;
	
	IFStory story;
	int x;
	
	/* Write out the header */
	w("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
	w("<ifindex version=\"1.0\" xmlns=\"http://babel.ifarchive.org/protocol/iFiction/\">\n");
	
	/* Iterate through the stories */
	stories = IFMB_GetStoryIterator(meta);
	
	while ((story = IFMB_NextStory(stories))) {
		int idCount;
		IFID singleId[1];
		IFID* storyIds;
		
		w(" <story>\n");
		
		/* Write out the IDs for the story */
		/* TODO: <format>, <bafn>, etc */
		
		/* Get the IDs that apply to this story */
		storyIds = IFMB_SplitId(IFMB_IdForStory(story), &idCount);
		if (storyIds == NULL) {
			singleId[0] = IFMB_IdForStory(story);
			storyIds = singleId;
			idCount = 1;
		}
		
		/* Write them out in identification sections */
		for (x=0; x<idCount; x++) {
			char* idString;
			
			idString = IFMB_IdToString(storyIds[x]);
			
			w("  <identification><ifid>");
			w(idString);
			w("</ifid></identification>\n");
			
			free(idString);
		}
		
		/* Iterate through the values for this story */
		values = malloc(sizeof(ValueStackItem));
		
		values->iterator = IFMB_GetValueIterator(story);
		values->previous = NULL;
		
		while (values != NULL) {
			if (IFMB_NextValue(values->iterator)) {
				IFValueIterator subValues;
				char* key;
				IFChar* value;
				
				key = IFMB_SubkeyFromIterator(values->iterator);
				value = IFMB_ValueFromIterator(values->iterator);
				subValues = IFMB_ChildrenFromIterator(values->iterator);
				
				/* Ignore attribute keys */
				if (key[0] == '@') {
					if (subValues != NULL) IFMB_FreeValueIterator(subValues);
					continue;
				}
				
				/* Ignore empty keys */
				if (value == NULL && subValues == NULL) continue;
				
				/* Open the tag for this value */
				w("  <");
				w(key);
				
				/* Write out any attributes that this tag might have */
				while (subValues != NULL && IFMB_NextValue(subValues)) {
					char* subKey;
					
					subKey = IFMB_SubkeyFromIterator(subValues);

					if (subKey[0] == '@') {
						w(" ");
						w(subKey+1);
						w("=\"");
						wun(IFMB_ValueFromIterator(subValues));
						w("\"");
					}
				}
				
				if (subValues != NULL) IFMB_FreeValueIterator(subValues);
				
				/* End of the opening tag */
				w(">\n");
				
				/* Write the value itself */
				if (value != NULL) {
					w("   ");
					wu(IFMB_ValueFromIterator(values->iterator));
					w("\n");
				}
				
				/* Get an iterator for any values underneath this one */
				subValues = IFMB_ChildrenFromIterator(values->iterator);
				
				if (subValues == NULL) {
					/* No child values */
					w("  </");
					w(IFMB_SubkeyFromIterator(values->iterator));
					w(">\n");
				} else {
					/* Push this iterator onto the stack */
					ValueStackItem* newValues;
					
					newValues = malloc(sizeof(ValueStackItem));
					
					newValues->iterator = subValues;
					newValues->previous = values;
					
					values = newValues;
				}
				
			} else {
				
				ValueStackItem* previousValues;
				
				/* Finished this iterator, move back to the last one */
				previousValues = values->previous;
				
				IFMB_FreeValueIterator(values->iterator);
				free(values);
				
				values = previousValues;
				
				/* Close the tag that we were writing */
				if (values != NULL) {
					w("  </");
					w(IFMB_SubkeyFromIterator(values->iterator));
					w(">\n");
				}
			}
		}
		
		w(" </story>\n");
	}
	
	IFMB_FreeStoryIterator(stories);
	
	/* Write out the footer */
	w("</ifindex>\n");
}
