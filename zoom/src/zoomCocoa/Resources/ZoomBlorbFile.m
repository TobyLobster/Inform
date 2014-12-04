//
//  ZoomBlorbFile.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Jul 30 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomBlorbFile.h"

@implementation ZoomBlorbFile

static unsigned int Int4(const unsigned char* bytes) {
	return (bytes[0]<<24)|(bytes[1]<<16)|(bytes[2]<<8)|(bytes[3]<<0);
}

// = Testing files =

+ (BOOL) dataIsBlorbFile: (NSData*) data {
	NSObject<ZFile>* fl = [[ZDataFile alloc] initWithData: data];
	
	BOOL res = [self zfileIsBlorb: fl];
	
	[fl close];
    [fl autorelease];
	
	return res;
}

+ (BOOL) fileContentsIsBlorb: (NSString*) filename {
	NSObject<ZFile>* fl = [[ZHandleFile alloc] initWithFileHandle: [NSFileHandle fileHandleForReadingAtPath: filename]];
	
	BOOL res = [self zfileIsBlorb: fl];
	[fl close];
    [fl autorelease];
	
	return res;
}

+ (BOOL) zfileIsBlorb: (NSObject<ZFile>*) zfile {
	// Possibly should write a faster means of doing this
	ZoomBlorbFile* fl = [[[self class] alloc] initWithZFile: zfile];
	
	if (fl == nil) return NO;
	
	BOOL res;
	
	if ([fl->formID isEqualToString: @"IFRS"]) 
		res = YES;
	else
		res = NO;
	
	if (![fl parseResourceIndex]) res = NO;
	
	[fl release];
	
	return res;
}

// = Initialisation =

- (id) initWithZFile: (NSObject<ZFile>*) f {
	self = [super init];
	
	if (self) {
		if (f == nil) {
			[self release];
			return nil;
		}
		
		file = [f retain];
		
		// Attempt to read the file
		[file seekTo: 0];
		NSData* header = [file readBlock: 12];
		
		if (header == nil) {
			[self release];
			return nil;
		}
		
		if ([header length] != 12) {
			[self release];
			return nil;
		}
		
		// File must begin with 'FORM'
		if (memcmp([header bytes], "FORM", 4) != 0) {
			[self release];
			return nil;
		}
		
		// OK, we can get the form ID
        char * form = (char*)[header bytes];
        formID = [[NSString stringWithFormat:@"%c%c%c%c", form[8], form[9], form[10], form[11]] retain];
		
		// and the theoretical file length
		const unsigned char* lBytes = [header bytes] + 4;
		formLength = (lBytes[0]<<24)|(lBytes[1]<<16)|(lBytes[2]<<8)|(lBytes[3]<<0);
		
		if (formLength + 8 > (unsigned)[file fileSize]) {
			[self release];
			return nil;
		}
		
		// Now we can parse through the blocks
		iffBlocks = [[NSMutableArray alloc] init];
		typesToBlocks = [[NSMutableDictionary alloc] init];
		locationsToBlocks = [[NSMutableDictionary alloc] init];
		
		unsigned int pos = 12;
		while (pos < formLength) {
			// Read the block
			[file seekTo: pos];
			NSData* blockHeader = [file readBlock: 8];
			
			if (blockHeader == nil || [blockHeader length] != 8) {
				[self release];
				return nil;
			}
			
			// Decode it
            char * blockChars = (char*)[blockHeader bytes];
			NSString* blockID = [NSString stringWithFormat:@"%c%c%c%c", blockChars[0], blockChars[1], blockChars[2], blockChars[3]];
			lBytes = [blockHeader bytes]+4;
			unsigned int blockLength = (lBytes[0]<<24)|(lBytes[1]<<16)|(lBytes[2]<<8)|(lBytes[3]<<0);
			
			// Create the block data
			NSDictionary* block = [NSDictionary dictionaryWithObjectsAndKeys:
				blockID, @"id",
				[NSNumber numberWithUnsignedInt: blockLength], @"length",
				[NSNumber numberWithUnsignedInt: pos+8], @"offset",
				nil];
			
			// Store it
			[iffBlocks addObject: block];
			
			NSMutableArray* typeBlocks = [typesToBlocks objectForKey: blockID];
			if (typeBlocks == nil) {
				typeBlocks = [NSMutableArray array];
				[typesToBlocks setObject: typeBlocks
								  forKey: blockID];
			}
			[typeBlocks addObject: block];
			
			[locationsToBlocks setObject: block
								  forKey: [NSNumber numberWithUnsignedInt: pos]];
			
			// Next position
			pos += 8 + blockLength;
			if ((pos&1)) pos++;
		}
	}
	
	return self;
}

- (id) initWithData: (NSData*) blorbFile {
	return [self initWithZFile: [[[ZDataFile alloc] initWithData: blorbFile] autorelease]];
}

- (id) initWithContentsOfFile: (NSString*) filename {
	return [self initWithZFile: [[[ZHandleFile alloc] initWithFileHandle:
		[NSFileHandle fileHandleForReadingAtPath: filename]] autorelease]];
}

- (void) dealloc {
	if (file) {
		[file close];
		[file release];
	}
	
	if (formID) [formID release];
	
	if (iffBlocks) [iffBlocks release];
	if (typesToBlocks) [typesToBlocks release];
	if (locationsToBlocks) [locationsToBlocks release];
	
	if (resourceIndex)  [resourceIndex release];
	if (resolution)		[resolution release];
	if (adaptiveImages) [adaptiveImages release];
	if (activePalette)  [activePalette release];
	
	[super dealloc];
}

// = Generic IFF data =

- (NSArray*) chunksWithType: (NSString*) chunkType {
	return [typesToBlocks objectForKey: chunkType];
}

- (NSData*) dataForChunk: (id) chunk {
	if (![chunk isKindOfClass: [NSDictionary class]]) return nil;
	if (!file) return nil;
	if (![[chunk objectForKey: @"offset"] isKindOfClass: [NSNumber class]]) return nil;
	if (![[chunk objectForKey: @"length"] isKindOfClass: [NSNumber class]]) return nil;
	
	NSDictionary* cD = chunk;
	
	[file seekTo: [[cD objectForKey: @"offset"] unsignedIntValue]];
	
	return [file readBlock: [[cD objectForKey: @"length"] unsignedIntValue]];
}

- (NSData*) dataForChunkWithType: (NSString*) chunkType {
	return [self dataForChunk: [[self chunksWithType: chunkType] objectAtIndex: 0]];
}

// = The resource index =

- (BOOL) parseResourceIndex {
	if (resourceIndex) {
		[resourceIndex release];
		resourceIndex = nil;
	}

	// Get the index chunk
	NSData* resourceChunk = [self dataForChunkWithType: @"RIdx"];
	if (resourceChunk == nil) {
		return NO;
	}
	const unsigned char* data = [resourceChunk bytes];
		
	// Create the index
	resourceIndex = [[NSMutableDictionary alloc] init];
	
	// Process the chunk
	int pos;
	for (pos = 4; pos+12 <= [resourceChunk length]; pos += 12) {
		// Read the chunk
        NSString* usage = [NSString stringWithFormat:@"%c%c%c%c", data[pos], data[pos+1], data[pos+2], data[pos+3]];
		NSNumber* num   = [NSNumber numberWithUnsignedInt: (data[pos+4]<<24)|(data[pos+5]<<16)|(data[pos+6]<<8)|(data[pos+7])];
		NSNumber* start = [NSNumber numberWithUnsignedInt: (data[pos+8]<<24)|(data[pos+9]<<16)|(data[pos+10]<<8)|(data[pos+11])];
		
		// Store it in the index
		NSMutableDictionary* usageDict = [resourceIndex objectForKey: usage];
		if (usageDict == nil) {
			usageDict = [NSMutableDictionary dictionary];
			[resourceIndex setObject: usageDict
							  forKey: usage];
		}
		
		[usageDict setObject: start
					  forKey: num];
		
		// Check against the data we've already parsed for this file
		if ([locationsToBlocks objectForKey: start] == nil) {
			NSLog(@"ZoomBlorbFile: Warning: '%@' resource %@ not found (at %@)", usage, num, start);
		}
	}
	
	// Process the adaptive palette chunk (if present)
	adaptive = NO;
	NSData* aPal = [self dataForChunkWithType: @"APal"];
	
	if (aPal != nil) {
		adaptive = YES;
		
		const unsigned char* pal = [aPal bytes];
		adaptiveImages = [[NSMutableSet alloc] init];
		
		for (pos=0; pos+4<=[aPal length]; pos+=4) {
			NSNumber* num = [NSNumber numberWithUnsignedInt: Int4(pal + pos)];
			[adaptiveImages addObject: num];
		}
	}
	
	return YES;
}

- (void) parseResolutionChunk {
	if (resolution != nil) return;
	
	NSData* resData = [self dataForChunkWithType: @"Reso"];
	if (resData == nil) return;
	if ([resData length] < 24) return;
	
	const unsigned char* data = [resData bytes];
	
	// Decode the window heights
	stdSize.width  = Int4(data + 0);
	stdSize.height = Int4(data + 4);
	minSize.width  = Int4(data + 8);
	minSize.height = Int4(data + 12);
	maxSize.width  = Int4(data + 16);
	maxSize.height = Int4(data + 20);
	
	// Decode image resource information
	resolution = [[NSMutableDictionary alloc] init];
	int x;
	
	for (x=24; x<[resData length]; x += 28) {
		NSNumber* imageNum = [NSNumber numberWithUnsignedInt: Int4(data + x)];

		unsigned int num, denom;
		double ratio;
		
		num = Int4(data + x + 4); denom = Int4(data + x + 8);
		if (denom == 0) ratio = 0; else ratio = ((double)num)/((double)denom);
		NSNumber* stdRatio = [NSNumber numberWithDouble: ratio];
		
		num = Int4(data + x + 12); denom = Int4(data + x + 16);
		if (denom == 0) ratio = 0; else ratio = ((double)num)/((double)denom);
		NSNumber* minRatio = [NSNumber numberWithDouble: ratio];
		
		num = Int4(data + x + 20); denom = Int4(data + x + 24);
		if (denom == 0) ratio = 0; else ratio = ((double)num)/((double)denom);
		NSNumber* maxRatio = [NSNumber numberWithDouble: ratio];
		
		NSDictionary* entry = [NSDictionary dictionaryWithObjectsAndKeys:
			stdRatio, @"stdRatio", minRatio, @"minRatio", maxRatio, @"maxRatio", nil];

		[resolution setObject: entry
					   forKey: imageNum];
	}
}

- (BOOL) containsImageWithNumber: (int) num {
	if (!resourceIndex) {
		if (![self parseResourceIndex]) return NO;
	}
	if (!resourceIndex) return NO;
	
	return 
		[locationsToBlocks objectForKey: 
			[[resourceIndex objectForKey: @"Pict"] objectForKey: 
				[NSNumber numberWithUnsignedInt: num]]] != nil;
}

// = Typed data =

- (NSData*) gameHeader {
	return [self dataForChunkWithType: @"IFhd"];
}

- (NSData*) imageDataWithNumber: (int) num {
	// Get the index	
	if (!resourceIndex) {
		if (![self parseResourceIndex]) return NO;
	}
	if (!resourceIndex) return NO;
	
	// Get the resource
	return [self dataForChunk: 
		[locationsToBlocks objectForKey: 
			[[resourceIndex objectForKey: @"Pict"] objectForKey: 
				[NSNumber numberWithUnsignedInt: num]]]];
}

- (NSData*) soundDataWithNumber: (int) num {
	// Get the index	
	if (!resourceIndex) {
		if (![self parseResourceIndex]) return NO;
	}
	if (!resourceIndex) return NO;
	
	// Get the resource
	return [self dataForChunk: 
		[locationsToBlocks objectForKey: 
			[[resourceIndex objectForKey: @"Snd "] objectForKey: 
				[NSNumber numberWithUnsignedInt: num]]]];
}

// = Fiddling with PNG palettes =

- (NSData*) paletteForPng: (NSData*) png {
	// (Appends the CRC to the palette, too)
	const unsigned char* data = [png bytes];
	unsigned int length = [png length];
	
	unsigned int pos = 8;
	
	while (pos+8 < length) {
		unsigned int blockLength = Int4(data + pos);
        const unsigned char * typeChars = data + pos + 4;
        NSString* type = [NSString stringWithFormat:@"%c%c%c%c", typeChars[0], typeChars[1], typeChars[2], typeChars[3]];
		
		if ([type isEqualToString: @"PLTE"]) {
			return [png subdataWithRange: NSMakeRange(pos+8, blockLength+4)];
		}
		
		pos += blockLength + 12;
	}
	
	return nil;
}

- (NSData*) adaptPng: (NSData*) png
		 withPalette: (NSData*) newPalette {
	if (newPalette == nil) return png;
	
	NSMutableData* newPng = [[png mutableCopy] autorelease];

	const unsigned char* data = [newPng bytes];
	unsigned int length = [newPng length];
	
	unsigned int pos = 8;
	
	while (pos+8 < length) {
		unsigned int blockLength = Int4(data + pos);
        const unsigned char * typeChars = data + pos + 4;
        NSString* type = [NSString stringWithFormat:@"%c%c%c%c", typeChars[0], typeChars[1], typeChars[2], typeChars[3]];
		
		if ([type isEqualToString: @"PLTE"]) {
			unsigned char lenBlock[4];
			unsigned int newLen = [newPalette length];
			
			newLen -= 4;
			lenBlock[0] = (unsigned char)(newLen>>24); lenBlock[1] = (unsigned char)(newLen>>16);
			lenBlock[2] = (unsigned char)(newLen>>8); lenBlock[3] = (unsigned char)(newLen>>0);
			[newPng replaceBytesInRange: NSMakeRange(pos, 4)
							  withBytes: lenBlock];
			
			[newPng replaceBytesInRange: NSMakeRange(pos+8, blockLength+4)
							  withBytes: [newPalette bytes]
								 length: newLen + 4];
			break;
		}
		
		pos += blockLength + 12;
	}
	
	return newPng;
}

// = Caching images =

- (void) setActivePalette: (NSData*) palette {
	if (adaptive && palette != nil) {
		if (![activePalette isEqualToData: palette]) {
			NSLog(@"Palette shift");
			
			[activePalette release];
			activePalette = [palette retain];
			
			[self removeAdaptiveImagesFromCache];
		}
	}
}

static const int cacheLowerLimit = 32;
static const int cacheUpperLimit = 64;

- (NSImage*) cachedImageWithNumber: (int) num {
	NSDictionary* entry = [cache objectForKey: [NSNumber numberWithUnsignedInt: num]];
	[self setActivePalette: [entry objectForKey: @"palette"]];
	return [entry objectForKey: @"image"];
}

- (NSData*) cachedPaletteForImage: (int) num {
	return [[cache objectForKey: [NSNumber numberWithUnsignedInt: num]] objectForKey: @"palette"];
}

- (void) usedImageInCache: (int) num {
	NSMutableDictionary* entry = [cache objectForKey: [NSNumber numberWithUnsignedInt: num]];
	
	[entry setObject: [NSNumber numberWithUnsignedInt: maxCacheNum++]
			  forKey: @"usageNumber"];
}

- (void) cacheImage: (NSImage*) img
		withPalette: (NSData*) palette
		   adaptive: (BOOL) isAdaptive
			 number: (int) num {
	if (cache == nil) {
		cache = [[NSMutableDictionary alloc] init];
	}
	
	// Add to the cache
	[cache setObject: [NSMutableDictionary dictionaryWithObjectsAndKeys:
		img, @"image",
		[NSNumber numberWithBool: isAdaptive], @"adaptive",
		[NSNumber numberWithUnsignedInt: maxCacheNum++], @"usageNumber",
		[NSNumber numberWithUnsignedInt: num], @"number",
		palette, @"palette",
		nil]
			  forKey: [NSNumber numberWithUnsignedInt: num]];
	
	// Remove lowest-priority images if the cache gets too full
	if ([cache count] >= cacheUpperLimit) {
		NSLog(@"ImageCache: hit %i images (removing oldest entries)", [cache count]);
		
		NSEnumerator* keyEnum = [cache keyEnumerator];
		NSMutableArray* oldestEntries = [NSMutableArray array];
		NSNumber* key;
		
		while (key = [keyEnum nextObject]) {
			// Find the place to put this particular entry
			// Yeah, could binary search here. *Probably* not worth it
			NSMutableDictionary* entry = [cache objectForKey: key];
			unsigned int thisUsage = [[entry objectForKey: @"usageNumber"] unsignedIntValue];
			
			int x;
			for (x=0; x<[oldestEntries count]; x++) {
				NSDictionary* thisEntry = [oldestEntries objectAtIndex: x];
				unsigned int usage = [[thisEntry objectForKey: @"usageNumber"] unsignedIntValue];
				
				if (usage > thisUsage) break;
			}
			
			[oldestEntries insertObject: entry
								atIndex: x];
		}
		
		// Remove objects from the cache until there are cacheLowerLimit left
		int x;
		int numToRemove = [oldestEntries count] - cacheLowerLimit;
		
		NSLog(@"%i entries to remove", numToRemove);

		for (x=0; x<numToRemove; x++) {
			NSDictionary* entry = [oldestEntries objectAtIndex: x];
			
			[cache removeObjectForKey: [entry objectForKey: @"num"]];
		}
	}
}

- (void) removeAdaptiveImagesFromCache {
	NSEnumerator* keyEnum = [cache keyEnumerator];
	NSNumber* key;
	
	NSMutableArray* keysToRemove = [NSMutableArray array];
	
	while (key = [keyEnum nextObject]) {
		NSDictionary* entry = [cache objectForKey: key];
		
		if ([[entry objectForKey: @"adaptive"] boolValue]) {
			// This is an adaptive entry: cache for later removal
			// (Have to cache to avoid mucking up the key enumerator)
			[keysToRemove addObject: key];
		}
	}
	
	NSLog(@"Removing %i adaptive entries from the cache", [keysToRemove count]);
	
	keyEnum = [keysToRemove objectEnumerator];
	while (key = [keyEnum nextObject]) {
		[cache removeObjectForKey: key];
	}
}

// = Decoded data =

- (NSSize) sizeForImageWithNumber: (int) num
					forPixmapSize: (NSSize) pixmapSize {
	// Decode the resolution chunk if necessary
	[self parseResolutionChunk];
	
	// Get the image
	NSSize result;

	NSDictionary* imageBlock = [locationsToBlocks objectForKey: 
		[[resourceIndex objectForKey: @"Pict"] objectForKey: 
			[NSNumber numberWithUnsignedInt: num]]];
	
	if (imageBlock == nil) return NSMakeSize(0,0);
	
	NSString* type = [imageBlock objectForKey: @"id"];
	
	if ([type isEqualToString: @"Rect"]) {
		// Nonstandard extension: rectangle
		NSData* rData = [self dataForChunk: imageBlock];
		const unsigned char* data = [rData bytes];
		
		if ([rData length] >= 8) {
			result.width = Int4(data);
			result.height = Int4(data + 4);
		} else {
			result.width = result.height = 0;
		}
	} else {
		NSImage* img = [self imageWithNumber: num];
		if (img == nil) return NSMakeSize(0,0);
		result = [img size];
	}
	
	// Get the resolution data
	NSDictionary* resData = [resolution objectForKey: [NSNumber numberWithUnsignedInt: num]];
	if (resData == nil) return result;
	
	// Work out the scaling factor
	double erf1, erf2, erf;
	
	erf1 = pixmapSize.width / stdSize.width;
	erf2 = pixmapSize.height / stdSize.height;
	
	if (erf1 < erf2)
		erf = erf1;
	else
		erf = erf2;
	
	double minRatio = [[resData objectForKey: @"minRatio"] doubleValue];
	double maxRatio = [[resData objectForKey: @"maxRatio"] doubleValue];
	double stdRatio = [[resData objectForKey: @"stdRatio"] doubleValue];
	
	double factor = 0;
	
	factor = erf * stdRatio;
	if (minRatio > 0 && factor < minRatio) 
		factor = minRatio;
	else if (maxRatio > 0 && factor > maxRatio)
		factor = maxRatio;
	
	if (factor <= 0)
		factor = 1.0;
	
	// Calculate the final result
	
	result.width *= factor;
	result.height *= factor;
	
	return result;
}

- (NSImage*) imageWithNumber: (int) num {
	NSDictionary* imageBlock = [locationsToBlocks objectForKey: 
		[[resourceIndex objectForKey: @"Pict"] objectForKey: 
			[NSNumber numberWithUnsignedInt: num]]];
	
	if (imageBlock == nil) return nil;
	
	NSString* type = [imageBlock objectForKey: @"id"];
	NSImage* res = nil;
	
	// Retrieve the image from the cache if possible
	res = [[[self cachedImageWithNumber: num] retain] autorelease];
	if (res != nil) {
		[self usedImageInCache: num];
		return res;
	}
	
	// Load the image from resources if not
	BOOL wasAdaptive = NO;
	
	if ([type isEqualToString: @"Rect"]) {
		// Nonstandard extension: rectangle
		NSData* rData = [self dataForChunk: imageBlock];
		const unsigned char* data = [rData bytes];
		unsigned int width, height;
		
		if ([rData length] == 8) {
			width = Int4(data);
			height = Int4(data + 4);
		} else {
			width = height = 0;
		}
		
		NSLog(@"Warning: drawing Rect image");
		res = [[[NSImage alloc] initWithSize: NSMakeSize(width, height)] autorelease];
	} else if ([type isEqualToString: @"PNG "]) {
		// PNG file
		NSData* pngData = [self dataForChunk: imageBlock];
		
		if (adaptive) {
			if ([adaptiveImages containsObject: [NSNumber numberWithUnsignedInt: num]]) {
				pngData = [self adaptPng: pngData
							 withPalette: activePalette];
				wasAdaptive = YES;
			} else {
				[self setActivePalette: [self paletteForPng: pngData]];
				wasAdaptive = NO;
			}
		}
		
		res = [[[NSImage alloc] initWithData: pngData] autorelease];
	} else if ([type isEqualToString: @"JPEG"]) {
		// JPEG file (no patent worries here, really)
		res = [[[NSImage alloc] initWithData: [self dataForChunk: imageBlock]] autorelease];
	} else {
		// Could be anything
		NSLog(@"WARNING: Unknown image chunk type: %@", type);
		res = [[[NSImage alloc] initWithData: [self dataForChunk: imageBlock]] autorelease];
	}
	
	// Cache the image
	[self cacheImage: res
		 withPalette: activePalette
			adaptive: wasAdaptive
			  number: num];
	
	NSLog(@"Cache miss");
	
	// Return the result
	return res;
}

@end
