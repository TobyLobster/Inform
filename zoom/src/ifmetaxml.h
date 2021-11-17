/*
 *  ifmetaxml.h
 *  ZoomCocoa
 *
 *  Created by Andrew Hunter on 04/04/2006.
 *  Copyright 2006 Andrew Hunter. All rights reserved.
 *
 */

#ifndef __IFMETAXML_H
#define __IFMETAXML_H

/*
 * Importer for iFiction XML files.
 */

#include <stdlib.h>
#include <ZoomPlugIns/ifmetabase.h>

/* Possible error codes */
typedef enum IFXmlError {
	IFXmlNotIfiction,
	IFXmlNoVersionSupplied,
	IFXmlVersionIsTooRecent,
	
	IFXmlMismatchedTags,
	IFXmlUnrecognisedTag,
	
	IFXmlBadId,
	IFXmlBadZcodeSection,
	IFXmlStoryWithNoId,
} IFXmlError;

/* Load the records contained in the specified string into the specified metabase */
extern void IF_ReadIfiction(IFMetabase meta, const unsigned char* xml, size_t size);

/* Save the records contained in the specified metabase using the specified function */
extern void IF_WriteIfiction(IFMetabase meta, int(*writeFunction)(const char* bytes, int length, void* userData), void* userData);

/* Returns a default string for an error message */
extern char* IF_StringForError(IFXmlError errorCode);

#endif
