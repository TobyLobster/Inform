//
//  ZoomBlorbFile.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Jul 30 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomBlorbFile.h"

NSErrorDomain const ZoomBlorbErrorDomain = @"uk.org.logicalshift.zoomview.blorb.errors";
static NSString *const ZoomBlorbID = @"id";
static NSString *const ZoomBlorbLength = @"length";
static NSString *const ZoomBlorbOffset = @"offset";

@implementation ZoomBlorbFile {
	id<ZFile> file;
	
	NSString*       formID;
	unsigned int    formLength;

	NSMutableArray<NSDictionary<NSString*,id>*>*		 iffBlocks;
	NSMutableDictionary<NSString*,NSMutableArray<NSDictionary<NSString*,id>*>*>* typesToBlocks;
	NSMutableDictionary<NSNumber*,NSDictionary<NSString*,id>*>* locationsToBlocks;
	
	NSMutableDictionary<NSString*,NSMutableDictionary<NSNumber*,NSNumber*>*>* resourceIndex;
	
	BOOL adaptive;
	NSMutableSet<NSNumber*>* adaptiveImages;
	NSData*       activePalette;
	
	NSSize stdSize;
	NSSize minSize;
	NSSize maxSize;
	NSMutableDictionary* resolution;
	
	NSMutableDictionary<NSNumber*, NSMutableDictionary<NSString*,id>*>* cache;
	unsigned int maxCacheNum;
}

static unsigned int Int4(const unsigned char* bytes) {
	return (bytes[0]<<24)|(bytes[1]<<16)|(bytes[2]<<8)|(bytes[3]<<0);
}

#pragma mark - Testing files

+ (BOOL) dataIsBlorbFile: (NSData*) data {
	id<ZFile> fl = [[ZDataFile alloc] initWithData: data];
	
	BOOL res = [self zfileIsBlorb: fl];
	
	[fl close];
	
	return res;
}

+ (BOOL) URLContentsAreBlorb: (NSURL*) filename {
	ZHandleFile *fl = [[ZHandleFile alloc] initWithFileHandle: [NSFileHandle fileHandleForReadingFromURL: filename error: NULL]];
	
	BOOL res = [self zfileIsBlorb: fl];
	[fl close];

	return res;

}

+ (BOOL) fileContentsIsBlorb: (NSString*) filename {
	return [self URLContentsAreBlorb: [NSURL fileURLWithPath: filename]];
}

+ (BOOL) zfileIsBlorb: (id<ZFile>) zfile {
	// Possibly should write a faster means of doing this
	ZoomBlorbFile* fl = [[[self class] alloc] initWithZFile: zfile
													  error: NULL];
	
	if (fl == nil) return NO;
	
	BOOL res;
	
	if ([fl->formID isEqualToString: @"IFRS"]) 
		res = YES;
	else
		res = NO;
	
	if (![fl parseResourceIndex]) res = NO;
	
	return res;
}

#pragma mark - Initialisation

- (id) initWithZFile: (id<ZFile>) f {
	return [self initWithZFile: f error: NULL];
}

- (id) initWithZFile: (id<ZFile>) f error: (NSError**) outError {
	self = [super init];
	
	if (self) {
		if (f == nil) {
			if (outError) {
				*outError = [NSError errorWithDomain: NSOSStatusErrorDomain
												code: paramErr
											userInfo: nil];
			}
			return nil;
		}
		
		file = f;
		
		// Attempt to read the file
		[file seekTo: 0];
		NSData* header = [file readBlock: 12];
		
		if (header == nil) {
			if (outError) {
				*outError = [NSError errorWithDomain: NSCocoaErrorDomain
												code: NSFileReadNoSuchFileError
											userInfo: nil];
			}
			return nil;
		}
		
		if ([header length] != 12) {
			if (outError) {
				*outError = [NSError errorWithDomain: ZoomBlorbErrorDomain
												code: ZoomBlorbErrorTooSmall
											userInfo: nil];
			}
			return nil;
		}
		
		// File must begin with 'FORM'
		if (memcmp([header bytes], "FORM", 4) != 0) {
			if (outError) {
				*outError = [NSError errorWithDomain: ZoomBlorbErrorDomain
												code: ZoomBlorbErrorNoFORMBlock
											userInfo: nil];
			}
			return nil;
		}
		
		// OK, we can get the form ID
		NSData *dataLen = [header subdataWithRange:NSMakeRange(8, 4)];

		formID = [[NSString alloc] initWithData:dataLen encoding:NSMacOSRomanStringEncoding];
		
		// and the theoretical file length
		const unsigned char* lBytes = [header bytes] + 4;
		formLength = (lBytes[0]<<24)|(lBytes[1]<<16)|(lBytes[2]<<8)|(lBytes[3]<<0);
		
		if (formLength + 8 > (unsigned)[file fileSize]) {
			if (outError) {
				*outError = [NSError errorWithDomain: ZoomBlorbErrorDomain
												code: ZoomBlorbErrorTooSmall
											userInfo: nil];
			}
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
				if (outError) {
					*outError = [NSError errorWithDomain: ZoomBlorbErrorDomain
													code: ZoomBlorbErrorTooSmall
												userInfo: nil];
				}
				return nil;
			}
			
			// Decode it
			NSData *dataLen = [blockHeader subdataWithRange:NSMakeRange(0, 4)];
			NSString* blockID = [[NSString alloc] initWithData:dataLen encoding:NSMacOSRomanStringEncoding];
			lBytes = [blockHeader bytes]+4;
			unsigned int blockLength = (lBytes[0]<<24)|(lBytes[1]<<16)|(lBytes[2]<<8)|(lBytes[3]<<0);
			
			// Create the block data
			NSDictionary* block = @{
				ZoomBlorbID: blockID,
				ZoomBlorbLength: @(blockLength),
				ZoomBlorbOffset: @(pos+8)};
			
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
								  forKey: @(pos)];
			
			// Next position
			pos += 8 + blockLength;
			if ((pos&1)) pos++;
		}
	}
	
	return self;
}

- (id) initWithData: (NSData*) blorbFile {
	return [self initWithData: blorbFile
						error: NULL];
}

- (instancetype) initWithData: (NSData*) blorbFile error: (NSError**) outError {
	return [self initWithZFile: [[ZDataFile alloc] initWithData: blorbFile]
						 error: outError];
}

- (id) initWithContentsOfFile: (NSString*) filename {
	return [self initWithContentsOfURL: [NSURL fileURLWithPath: filename]
								 error: NULL];
}

- (id) initWithContentsOfURL: (NSURL*) filename error: (NSError**) outError {
	NSFileHandle *fh = [NSFileHandle fileHandleForReadingFromURL: filename
														   error: outError];
	if (!fh) {
		return nil;
	}
	return [self initWithZFile: [[ZHandleFile alloc] initWithFileHandle: fh]
						 error: outError];
}

- (void) dealloc {
	if (file) {
		[file close];
	}
}

#pragma mark - Generic IFF data

- (NSArray*) chunksWithType: (NSString*) chunkType {
	return [typesToBlocks objectForKey: chunkType];
}

- (NSData*) dataForChunk: (NSDictionary<NSString*,id>*) chunk {
	if (![chunk isKindOfClass: [NSDictionary class]]) return nil;
	if (!file) return nil;
	if (![[chunk objectForKey: ZoomBlorbOffset] isKindOfClass: [NSNumber class]]) return nil;
	if (![[chunk objectForKey: ZoomBlorbLength] isKindOfClass: [NSNumber class]]) return nil;
	
	NSDictionary<NSString*,NSNumber*>* cD = chunk;
	
	[file seekTo: cD[ZoomBlorbOffset].unsignedIntValue];
	
	return [file readBlock: cD[ZoomBlorbLength].unsignedIntValue];
}

- (NSData*) dataForChunkWithType: (NSString*) chunkType {
	return [self dataForChunk: [[self chunksWithType: chunkType] objectAtIndex: 0]];
}

#pragma mark - The resource index

- (BOOL) parseResourceIndex {
	if (resourceIndex) {
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
		NSData *usageDat = [resourceChunk subdataWithRange:NSMakeRange(pos, 4)];
		NSString* usage = [[NSString alloc] initWithData:usageDat encoding:NSMacOSRomanStringEncoding];
		NSNumber* num = [NSNumber numberWithUnsignedInt: (data[pos+4]<<24)|(data[pos+5]<<16)|(data[pos+6]<<8)|(data[pos+7])];
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
			NSNumber* num = @(Int4(pal + pos));
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
		NSNumber* imageNum = @(Int4(data + x));

		unsigned int num, denom;
		double ratio;
		
		num = Int4(data + x + 4); denom = Int4(data + x + 8);
		if (denom == 0) ratio = 0; else ratio = ((double)num)/((double)denom);
		NSNumber* stdRatio = @(ratio);
		
		num = Int4(data + x + 12); denom = Int4(data + x + 16);
		if (denom == 0) ratio = 0; else ratio = ((double)num)/((double)denom);
		NSNumber* minRatio = @(ratio);
		
		num = Int4(data + x + 20); denom = Int4(data + x + 24);
		if (denom == 0) ratio = 0; else ratio = ((double)num)/((double)denom);
		NSNumber* maxRatio = @(ratio);
		
		NSDictionary* entry = @{
			@"stdRatio": stdRatio, @"minRatio": minRatio, @"maxRatio": maxRatio};

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
				@(num)]] != nil;
}

#pragma mark - Typed data

- (NSData*) gameHeader {
	return [self dataForChunkWithType: @"IFhd"];
}

- (NSData*) imageDataWithNumber: (int) num {
	// Get the index	
	if (!resourceIndex) {
		if (![self parseResourceIndex]) return nil;
	}
	if (!resourceIndex) return nil;
	
	// Get the resource
	return [self dataForChunk: 
		[locationsToBlocks objectForKey: 
			[[resourceIndex objectForKey: @"Pict"] objectForKey: 
				@(num)]]];
}

- (NSData*) soundDataWithNumber: (int) num {
	// Get the index	
	if (!resourceIndex) {
		if (![self parseResourceIndex]) return nil;
	}
	if (!resourceIndex) return nil;
	
	// Get the resource
	return [self dataForChunk: 
		[locationsToBlocks objectForKey: 
			[[resourceIndex objectForKey: @"Snd "] objectForKey: 
				@(num)]]];
}

#pragma mark - Fiddling with PNG palettes

- (NSData*) paletteForPng: (NSData*) png {
	// (Appends the CRC to the palette, too)
	const unsigned char* data = [png bytes];
	NSUInteger length = [png length];
	
	unsigned int pos = 8;
	
	while (pos+8 < length) {
		unsigned int blockLength = Int4(data + pos);
		const void* type = data + pos + 4;

		if (memcmp(type, "PLTE", 4) == 0) {
			return [png subdataWithRange: NSMakeRange(pos+8, blockLength+4)];
		}
		
		pos += blockLength + 12;
	}
	
	return nil;
}

- (NSData*) adaptPng: (NSData*) png
		 withPalette: (NSData*) newPalette {
	if (newPalette == nil) return png;
	
	NSMutableData* newPng = [png mutableCopy];

	const unsigned char* data = [newPng bytes];
	NSUInteger length = [newPng length];
	
	unsigned int pos = 8;
	
	while (pos+8 < length) {
		unsigned int blockLength = Int4(data + pos);
		const void* type = data + pos + 4;
		
		if (memcmp(type, "PLTE", 4) == 0) {
			unsigned char lenBlock[4];
			NSUInteger newLen = [newPalette length];
			
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

#pragma mark - Caching images

- (void) setActivePalette: (NSData*) palette {
	if (adaptive && palette != nil) {
		if (![activePalette isEqualToData: palette]) {
			NSLog(@"Palette shift");
			
			activePalette = palette;
			
			[self removeAdaptiveImagesFromCache];
		}
	}
}

static const int cacheLowerLimit = 32;
static const int cacheUpperLimit = 64;

- (NSImage*) cachedImageWithNumber: (int) num {
	NSDictionary* entry = cache[@(num)];
	[self setActivePalette: entry[@"palette"]];
	return entry[@"image"];
}

- (NSData*) cachedPaletteForImage: (int) num {
	return cache[@(num)][@"palette"];
}

- (void) usedImageInCache: (int) num {
	NSMutableDictionary* entry = [cache objectForKey: @(num)];
	
	[entry setObject: @(maxCacheNum++)
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
		@(isAdaptive), @"adaptive",
		@(maxCacheNum++), @"usageNumber",
		@(num), @"number",
		palette, @"palette",
		nil]
			  forKey: @(num)];
	
	// Remove lowest-priority images if the cache gets too full
	if ([cache count] >= cacheUpperLimit) {
		NSLog(@"ImageCache: hit %lu images (removing oldest entries)", (unsigned long)[cache count]);
		
		NSMutableArray<NSDictionary*>* oldestEntries = [NSMutableArray array];
		
		for (NSNumber* key in cache) {
			// Find the place to put this particular entry
			// Yeah, could binary search here. *Probably* not worth it
			NSMutableDictionary<NSString*,id>* entry = cache[key];
			unsigned int thisUsage = [entry[@"usageNumber"] unsignedIntValue];
			
			NSInteger x;
			for (x=0; x<[oldestEntries count]; x++) {
				NSDictionary* thisEntry = oldestEntries[x];
				unsigned int usage = [thisEntry[@"usageNumber"] unsignedIntValue];
				
				if (usage > thisUsage) break;
			}
			
			[oldestEntries insertObject: entry
								atIndex: x];
		}
		
		// Remove objects from the cache until there are cacheLowerLimit left
		NSInteger numToRemove = [oldestEntries count] - cacheLowerLimit;
		
		NSLog(@"%li entries to remove", (long)numToRemove);

		for (NSDictionary* entry in oldestEntries) {
			[cache removeObjectForKey: entry[@"num"]];
		}
	}
}

- (void) removeAdaptiveImagesFromCache {
	NSMutableArray<NSNumber*>* keysToRemove = [NSMutableArray array];
	
	for (NSNumber* key in cache) {
		NSDictionary* entry = cache[key];
		
		if ([entry[@"adaptive"] boolValue]) {
			// This is an adaptive entry: cache for later removal
			// (Have to cache to avoid mucking up the key enumerator)
			[keysToRemove addObject: key];
		}
	}
	
	NSLog(@"Removing %lu adaptive entries from the cache", (unsigned long)[keysToRemove count]);
	
	[cache removeObjectsForKeys: keysToRemove];
}

#pragma mark - Decoded data

- (NSSize) sizeForImageWithNumber: (int) num
					forPixmapSize: (NSSize) pixmapSize {
	// Decode the resolution chunk if necessary
	[self parseResolutionChunk];
	
	// Get the image
	NSSize result;

	NSDictionary* imageBlock = [locationsToBlocks objectForKey: 
		[[resourceIndex objectForKey: @"Pict"] objectForKey: 
			@(num)]];
	
	if (imageBlock == nil) return NSZeroSize;
	
	NSString* type = [imageBlock objectForKey: ZoomBlorbID];
	
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
		if (img == nil) return NSZeroSize;
		result = [img size];
	}
	
	// Get the resolution data
	NSDictionary* resData = [resolution objectForKey: @(num)];
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
			@(num)]];
	
	if (imageBlock == nil) return nil;
	
	NSString* type = [imageBlock objectForKey: ZoomBlorbID];
	NSImage* res = nil;
	
	// Retrieve the image from the cache if possible
	res = [self cachedImageWithNumber: num];
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
		res = [[NSImage alloc] initWithSize: NSMakeSize(width, height)];
	} else if ([type isEqualToString: @"PNG "]) {
		// PNG file
		NSData* pngData = [self dataForChunk: imageBlock];
		
		if (adaptive) {
			if ([adaptiveImages containsObject: @(num)]) {
				pngData = [self adaptPng: pngData
							 withPalette: activePalette];
				wasAdaptive = YES;
			} else {
				[self setActivePalette: [self paletteForPng: pngData]];
				wasAdaptive = NO;
			}
		}
		
		res = [[NSImage alloc] initWithData: pngData];
	} else if ([type isEqualToString: @"JPEG"]) {
		// JPEG file (no patent worries here, really)
		res = [[NSImage alloc] initWithData: [self dataForChunk: imageBlock]];
	} else {
		// Could be anything
		NSLog(@"WARNING: Unknown image chunk type: %@", type);
		res = [[NSImage alloc] initWithData: [self dataForChunk: imageBlock]];
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
