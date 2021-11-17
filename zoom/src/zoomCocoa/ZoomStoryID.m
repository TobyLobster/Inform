//
//  ZoomStoryID.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Jan 13 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomStoryID.h"
#import "ZoomBlorbFile.h"
#import "ZoomPlugIn.h"
#import "ZoomPlugInManager.h"

#include "ifmetabase.h"
#include <CommonCrypto/CommonDigest.h>

BOOL ZoomIsSpotlightIndexing = NO;
NSErrorDomain const ZoomStoryIDErrorDomain = @"uk.org.logicalshift.zoomview.storyid.errors";

@implementation ZoomStoryID {
	IFID ident;
	BOOL needsFreeing;
}

+ (ZoomStoryID*) idForFile: (NSString*) filename {
	return [self idForURL: [NSURL fileURLWithPath: filename]];
}

+ (ZoomStoryID*) idForURL: (NSURL*) filename {
	ZoomStoryID* result = nil;

	if (!ZoomIsSpotlightIndexing) {
		ZoomPlugIn* plugin = [[ZoomPlugInManager sharedPlugInManager] instanceForURL: filename];
		
		if (plugin != nil) {
			// Try asking the plugin for the type of this file
			result = [plugin idForStory];
		}
		
		if (result != nil) return result;
	}
	
	// If this is a z-code or blorb file, then try the Z-Code ID
	NSString* extension = [[filename pathExtension] lowercaseString];
	
	if ([extension isEqualToString: @"z3"]
		|| [extension isEqualToString: @"z4"]
		|| [extension isEqualToString: @"z5"]
		|| [extension isEqualToString: @"z6"]
		|| [extension isEqualToString: @"z7"]
		|| [extension isEqualToString: @"z8"]
		|| [extension isEqualToString: @"blb"]
		|| [extension isEqualToString: @"zlb"]
		|| [extension isEqualToString: @"zblorb"]) {
		result = [[ZoomStoryID alloc] initWithZCodeFileAtURL: filename error: NULL];
	}
	
	// if that fails, try using glulx parsing.
	if ((result == nil) &&
		([extension isEqualToString: @"gblorb"]
		 || [extension isEqualToString: @"glb"]
		 || [extension isEqualToString: @"blb"]
		 || [extension isEqualToString: @"blorb"]
		 || [extension isEqualToString: @"zblorb"]
		 || [extension isEqualToString: @"zlb"])) {
		result = [[ZoomStoryID alloc] initWithGlulxFileAtURL: filename error: NULL];
	}
	
	return result;
}

- (id) initWithIdString: (NSString*) idString {
	self = [super init];
	
	if (self) {
		needsFreeing = YES;
		ident = IFMB_IdFromString([idString UTF8String]);
	}
	
	return self;
}

- (instancetype)initWithZCodeStory:(NSData *)gameData {
	return [self initWithZCodeStory: gameData error: NULL];
}

- (id) initWithZCodeStory: (NSData*) gameData error: (NSError *__autoreleasing  _Nullable * _Nullable) outError {
	self = [super init];
	
	if (self) {
		const unsigned char* bytes = [gameData bytes];
		NSInteger length = [gameData length];
		
		if ([gameData length] < 64) {
			// Too little data for this to be a Z-Code file
			return nil;
		}

		if (bytes[0] == 'F' && bytes[1] == 'O' && bytes[2] == 'R' && bytes[3] == 'M') {
			// This is not a Z-Code file; it's possibly a blorb file, though
			
			// Try to interpret as a blorb file
			ZoomBlorbFile* blorbFile = [[ZoomBlorbFile alloc] initWithData: gameData
																	 error: outError];
			
			if (blorbFile == nil) {
				return nil;
			}
			
			// See if we can get the ZCOD chunk
			NSData* data = [blorbFile dataForChunkWithType: @"ZCOD"];
			if (data == nil) {
				return nil;
			}
			
			if ([data length] < 64) {
				// This file is too short to be a Z-Code file
				return nil;
			}
			
			// Change to using the blorb data instead
			bytes = [data bytes];
			length = [data length];
			blorbFile=nil;
		}
		
		// Interpret the Z-Code data into an identification
		needsFreeing = YES;
		ident = IFMB_ZcodeId((((int)bytes[0x2])<<8)|((int)bytes[0x3]),
							 bytes + 0x12,
							 (((int)bytes[0x1c])<<8)|((int)bytes[0x1d]));
		
		// Scan for the string 'UUID://' - use this as an ident for preference if it exists (and represents a valid UUID)
		int x;
		BOOL gotUUID = NO;
		
		for (x=0; x<length-48; x++) {
			if (bytes[x] == 'U' && bytes[x+1] == 'U' && bytes[x+2] == 'I' && bytes[x+3] == 'D' &&
				bytes[x+4] == ':' && bytes[x+5] == '/' && bytes[x+6] == '/') {
				// This might be a UUID section
				char uuidText[50];
				
				// Check to see if we've got a UUID
				int y;
				int digitCount = 0;
				gotUUID = YES;
				
				for (y=0; y<7; y++) uuidText[y] = bytes[x+y];
				for (y=7; y<48; y++) {
					uuidText[y] = bytes[x+y];
					
					if (bytes[x+y-1] == '/' && bytes[x+y] == '/') break;
					if (bytes[x+y] == '-' || bytes[x+y] == '/') continue;
					if ((bytes[x+y] >= '0' && bytes[x+y] <= '9') ||
						(bytes[x+y] >= 'a' && bytes[x+y] <= 'f') ||
						(bytes[x+y] >= 'A' && bytes[x+y] <= 'F')) {
						digitCount++;
						continue;
					}
					
					gotUUID = NO;
					break;
				}
				uuidText[y] = 0;
				
				if (gotUUID) {
					IFID uuidId = IFMB_IdFromString(uuidText);
					
					if (uuidId == NULL) {
						gotUUID = false;
					} else {
						IFMB_FreeId(ident);
						ident = uuidId;
						needsFreeing = YES;
					}
				}

				if (gotUUID) break;
			}
		}
		if (ident == nil) {
			return nil;
		}
	}
	
	return self;
}

- (instancetype) initWithZCodeFileAtURL: (NSURL*) zcodeFile error: (NSError**)outError {
	self = [super init];
	
	if (self) {
		const unsigned char* bytes;
		NSInteger length;
		
		NSFileHandle* fh = [NSFileHandle fileHandleForReadingFromURL: zcodeFile error: outError];
		if (!fh) {
			return nil;
		}
		NSData* data = [fh readDataToEndOfFile];
		[fh closeFile];
		
		if ([data length] < 64) {
			// This file is too short to be a Z-Code file
			if (outError) {
				*outError = [NSError errorWithDomain: ZoomStoryIDErrorDomain code: ZoomStoryIDErrorFileTooSmall userInfo: nil];
			}
			return nil;
		}
		
		bytes = [data bytes];
		length = [data length];
		
		if (bytes[0] == 'F' && bytes[1] == 'O' && bytes[2] == 'R' && bytes[3] == 'M') {
			// This is not a Z-Code file; it's possibly a blorb file, though
						
			// Try to interpret as a blorb file
			ZoomBlorbFile* blorbFile = [[ZoomBlorbFile alloc] initWithContentsOfURL: zcodeFile error: outError];
			
			if (blorbFile == nil) {
				return nil;
			}
			
			// See if we can get the ZCOD chunk
			data = [blorbFile dataForChunkWithType: @"ZCOD"];
			if (data == nil) {
				if (outError) {
					*outError = [NSError errorWithDomain: ZoomStoryIDErrorDomain code: ZoomStoryIDErrorNoZCodeChunk userInfo: nil];
				}
				return nil;
			}
			
			if ([data length] < 64) {
				// This file is too short to be a Z-Code file
				if (outError) {
					*outError = [NSError errorWithDomain: ZoomStoryIDErrorDomain code: ZoomStoryIDErrorFileTooSmall userInfo: nil];
				}
				return nil;
			}
			
			// Change to using the blorb data instead
			bytes = [data bytes];
			length = [data length];
		}
		
		if (bytes[0] > 8) {
			// This cannot be a Z-Code file
			if (outError) {
				*outError = [NSError errorWithDomain: ZoomStoryIDErrorDomain code: ZoomStoryIDErrorBadZCodeVersion userInfo: nil];
			}
			return nil;
		}
		
		// Interpret the Z-Code data into an identification
		needsFreeing = YES;
		ident = IFMB_ZcodeId((((int)bytes[0x2])<<8)|((int)bytes[0x3]),
							 bytes + 0x12,
							 (((int)bytes[0x1c])<<8)|((int)bytes[0x1d]));
		
		// Scan for the string 'UUID://' - use this as an ident for preference if it exists (and represents a valid UUID)
		int x;
		BOOL gotUUID = NO;
		
		for (x=0; x<length-48; x++) {
			if (bytes[x] == 'U' && bytes[x+1] == 'U' && bytes[x+2] == 'I' && bytes[x+3] == 'D' &&
				bytes[x+4] == ':' && bytes[x+5] == '/' && bytes[x+6] == '/') {
				// This might be a UUID section
				char uuidText[50];
				
				// Check to see if we've got a UUID
				int y;
				int digitCount = 0;
				gotUUID = YES;
				
				for (y=0; y<7; y++) uuidText[y] = bytes[x+y];
				for (y=7; y<48; y++) {
					uuidText[y] = bytes[x+y];
					
					if (bytes[x+y-1] == '/' && bytes[x+y] == '/') break;
					if (bytes[x+y] == '-' || bytes[x+y] == '/') continue;
					if ((bytes[x+y] >= '0' && bytes[x+y] <= '9') ||
						(bytes[x+y] >= 'a' && bytes[x+y] <= 'f') ||
						(bytes[x+y] >= 'A' && bytes[x+y] <= 'F')) {
						digitCount++;
						continue;
					}
					
					gotUUID = NO;
					break;
				}
				uuidText[y] = 0;
				
				if (gotUUID) {
					IFID uuidId = IFMB_IdFromString(uuidText);
					
					if (uuidId == NULL) {
						gotUUID = false;
					} else {
						IFMB_FreeId(ident);
						ident = uuidId;
						needsFreeing = YES;
					}
				}
				
				if (gotUUID) break;
			}
		}
		
		if (ident == nil) {
			if (outError) {
				*outError = [NSError errorWithDomain: ZoomStoryIDErrorDomain code: ZoomStoryIDErrorNoIdentGenerated userInfo: nil];
			}
			return nil;
		}
	}
	
	return self;
}

- (instancetype) initWithGlulxFileAtURL: (NSURL*) glulxFile error:(NSError *__autoreleasing  _Nullable * _Nullable)outError {
	self = [super init];
	
	if (self) {
		// Read the header of this file
		const unsigned char* bytes;
		
		NSFileHandle* fh = [NSFileHandle fileHandleForReadingFromURL: glulxFile error: outError];
		if (!fh) {
			return nil;
		}
		NSData* data = [fh readDataOfLength: 64];
		[fh closeFile];
		
		if ([data length] < 64) {
			// This file is too short to be a Glulx file
			if (outError) {
				*outError = [NSError errorWithDomain: ZoomStoryIDErrorDomain code: ZoomStoryIDErrorFileTooSmall userInfo: nil];
			}
			return nil;
		}
		
		bytes = [data bytes];
		
		if (bytes[0] == 'F' && bytes[1] == 'O' && bytes[2] == 'R' && bytes[3] == 'M') {
			// This is not a Z-Code file; it's possibly a blorb file, though
			
			// Try to interpret as a blorb file
			ZoomBlorbFile* blorbFile = [[ZoomBlorbFile alloc] initWithContentsOfURL: glulxFile error: outError];
			
			if (blorbFile == nil) {
				return nil;
			}
			
			// See if we can get the ZCOD chunk
			data = [blorbFile dataForChunkWithType: @"GLUL"];
			if (data == nil) {
				if (outError) {
					*outError = [NSError errorWithDomain: ZoomStoryIDErrorDomain code: ZoomStoryIDErrorNoGlulxChunk userInfo: nil];
				}
				return nil;
			}
			
			if ([data length] < 64) {
				// This file is too short to be a Z-Code file
				if (outError) {
					*outError = [NSError errorWithDomain: ZoomStoryIDErrorDomain code: ZoomStoryIDErrorFileTooSmall userInfo: nil];
				}
				return nil;
			}
			
			// Change to using the blorb data instead
			bytes = [data bytes];
		} else if (bytes[0] == 'G' && bytes[1] == 'l' && bytes[2] == 'u' && bytes[3] == 'l') {
			data = [NSData dataWithContentsOfURL: glulxFile];
			bytes = [data bytes];
			
			if ([data length] < 64) {
				if (outError) {
					*outError = [NSError errorWithDomain: ZoomStoryIDErrorDomain code: ZoomStoryIDErrorFileTooSmall userInfo: nil];
				}
				return nil;
			}
		} else {
			// Not a Glulx file
			if (outError) {
				*outError = [NSError errorWithDomain: NSCocoaErrorDomain code: NSFileReadCorruptFileError userInfo: nil];
			}
			return nil;
		}
		
		// bytes now contains the Glulx file we want the ID for
		NSInteger memsize = (bytes[16]<<24) | (bytes[17]<<16) | (bytes[18]<<8) | (bytes[19]<<0);
		if (memsize > [data length]) memsize = [data length];
		
		// Scan for a UUID
		NSInteger x;
		BOOL gotUUID = NO;
		
		for (x=0; x<memsize-48; x++) {
			if (bytes[x] == 'U' && bytes[x+1] == 'U' && bytes[x+2] == 'I' && bytes[x+3] == 'D' &&
				bytes[x+4] == ':' && bytes[x+5] == '/' && bytes[x+6] == '/') {
				// This might be a UUID section
				char uuidText[50];
				
				// Check to see if we've got a UUID
				int y;
				int digitCount = 0;
				gotUUID = YES;
				
				for (y=0; y<7; y++) uuidText[y] = bytes[x+y];
				for (y=7; y<48; y++) {
					uuidText[y] = bytes[x+y];
					
					if (bytes[x+y-1] == '/' && bytes[x+y] == '/') break;
					if (bytes[x+y] == '-' || bytes[x+y] == '/') continue;
					if ((bytes[x+y] >= '0' && bytes[x+y] <= '9') ||
						(bytes[x+y] >= 'a' && bytes[x+y] <= 'f') ||
						(bytes[x+y] >= 'A' && bytes[x+y] <= 'F')) {
						digitCount++;
						continue;
					}
					
					gotUUID = NO;
					break;
				}
				uuidText[y] = 0;
				
				if (gotUUID) {
					IFID uuidId = IFMB_IdFromString(uuidText);
					
					if (uuidId == NULL) {
						gotUUID = false;
					} else {
						ident = uuidId;
						needsFreeing = YES;
						return self;
					}
				}
				
				if (gotUUID) break;
			}
		}
		
		// Legacy mode: check if this is an Inform file
		if (bytes[36] == 'I' && bytes[37] == 'n' && bytes[38] == 'f' && bytes[39] == 'o') {
			int release = (bytes[52]<<8) | (bytes[53]);
			int checksum = (bytes[32]<<24) | (bytes[33]<<16) | (bytes[34]<<8) | (bytes[35]<<0);
			
			ident = IFMB_GlulxId(release, bytes + 54, checksum);
			needsFreeing = YES;
		} else {
			int checksum = (bytes[32]<<24) | (bytes[33]<<16) | (bytes[34]<<8) | (bytes[35]<<0);

			ident = IFMB_GlulxIdNotInform((unsigned int)memsize, checksum);
			needsFreeing = YES;
		}
		if (ident == nil) {
			if (outError) {
				*outError = [NSError errorWithDomain: ZoomStoryIDErrorDomain code: ZoomStoryIDErrorNoIdentGenerated userInfo: nil];
			}
			return nil;
		}
	}
	
	return self;
}

- (id) initWithZCodeFile: (NSString*) zcodeFile {
	return [self initWithZCodeFileAtURL: [NSURL fileURLWithPath: zcodeFile] error: NULL];
}

- (id) initWithGlulxFile: (NSString*) glulxFile {
	return [self initWithGlulxFileAtURL: [NSURL fileURLWithPath: glulxFile] error: NULL];
}

- (id) initWithData: (NSData*) genericGameData
			   type: (NSString*) type {
	self = [super init];
	
	if (self) {
		// Take MD5 of the data
		CC_MD5_CTX md5state;
		unsigned char r[CC_MD5_DIGEST_LENGTH];
		
		CC_MD5_Init(&md5state);
		CC_MD5_Update(&md5state, [genericGameData bytes], (CC_LONG)[genericGameData length]);
		CC_MD5_Final(r, &md5state);
		
		// Build the string
		NSInteger len = ([type lengthOfBytesUsingEncoding:NSUTF8StringEncoding]+32+2);
		char* result = malloc(sizeof(char)*len);
		
		snprintf(result, len, "%s-%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
				 [type UTF8String],
				 r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12], r[13], r[14], r[15]);
		
		// Allocate the identity block
		ident = IFMB_IdFromString(result);
		needsFreeing = YES;
			
		free(result);
		if (ident == nil) {
			return nil;
		}

	}
	
	return self;
}

- (id) initWithData: (NSData*) genericGameData {
	return [self initWithData: genericGameData
						 type: @"MD5"];
}

- (instancetype) initWithUUID: (NSUUID*) uuid {
	if (self = [super init]) {
		uuid_t uuidBytes;
		[uuid getUUIDBytes:uuidBytes];
		ident = IFMB_UUID(uuidBytes);
		needsFreeing = YES;
	}
	return self;
}

- (id) initWithIdent: (IFID) idt {
	self = [super init];
	
	if (idt == nil) {
		return nil;
	}
	
	if (self) {
		ident = IFMB_CopyId(idt);
		needsFreeing = YES;
	}
	
	return self;
}

- (id) initWithZcodeRelease: (int) release
					 serial: (const unsigned char*) serial
				   checksum: (int) checksum {
	self = [super init];
	
	if (self) {
		ident = IFMB_ZcodeId(release, serial, checksum);
		needsFreeing = YES;
	}
	
	return self;
}

- (void) dealloc {
	if (needsFreeing && ident != NULL) {
		IFMB_FreeId(ident);
	}
}

@synthesize ident;

#pragma mark - NSCopying
- (id) copyWithZone: (NSZone*) zone {
	ZoomStoryID* newID = [[ZoomStoryID alloc] init];
	
	newID->ident = IFMB_CopyId(ident);
	newID->needsFreeing = YES;
	
	return newID;
}

#pragma mark - NSCoding
- (void)encodeWithCoder:(NSCoder *)encoder {
	if (encoder.allowsKeyedCoding) {
		char* stringId = IFMB_IdToString(ident);
		NSString* stringIdent = [[NSString alloc] initWithBytesNoCopy:stringId length:strlen(stringId) encoding:NSUTF8StringEncoding freeWhenDone:YES];
		[encoder encodeObject:stringIdent forKey:@"IFMBStringID"];
	} else {
		// Version might change later on
		int version = 2;
		
		[encoder encodeValueOfObjCType: @encode(int) 
									at: &version];
		
		char* stringId = IFMB_IdToString(ident);
		NSString* stringIdent = [NSString stringWithUTF8String: stringId];
		[encoder encodeObject: stringIdent];
		free(stringId);
	}
}

enum IFMDFormat {
	IFFormat_Unknown = 0x0,
	
	IFFormat_ZCode,
	IFFormat_Glulx,
	
	IFFormat_TADS,
	IFFormat_HUGO,
	IFFormat_Alan,
	IFFormat_Adrift,
	IFFormat_Level9,
	IFFormat_AGT,
	IFFormat_MagScrolls,
	IFFormat_AdvSys,
	
	IFFormat_UUID,			/* 'Special' format used for games identified by a UUID */
};

typedef unsigned char IFMDByte;

- (id)initWithCoder:(NSCoder *)decoder {
	self = [super init];
	
	if (self) {
		if (decoder.allowsKeyedCoding) {
			NSString* idString = (NSString*)[decoder decodeObjectOfClass:[NSString class] forKey:@"IFMBStringID"];
			
			ident = IFMB_IdFromString([idString UTF8String]);
			needsFreeing = YES;
		} else {
			ident = NULL;
			needsFreeing = YES;
			
			// As above, but backwards
			int version;
			
			[decoder decodeValueOfObjCType: @encode(int) at: &version size: sizeof(int)];
			
			if (version == 1) {
				// General stuff (data format, MD5, etc) [old v1 format used by versions of Zoom prior to 1.0.5dev3]
				char md5sum[16];
				IFMDByte usesMd5;
				enum IFMDFormat dataFormat;
				
				[decoder decodeValueOfObjCType: @encode(enum IFMDFormat)
											at: &dataFormat
										  size: sizeof(enum IFMDFormat)];
				[decoder decodeValueOfObjCType: @encode(IFMDByte)
											at: &usesMd5
										  size: sizeof(IFMDByte)];
				if (usesMd5) {
					[decoder decodeArrayOfObjCType: @encode(IFMDByte)
											 count: 16
												at: md5sum];
				}
				
				switch (dataFormat) {
					case IFFormat_ZCode:
					{
						char serial[6];
						int release;
						int checksum;
						
						[decoder decodeArrayOfObjCType: @encode(IFMDByte)
												 count: 6
													at: serial];
						[decoder decodeValueOfObjCType: @encode(int)
													at: &release
												  size: sizeof(int)];
						[decoder decodeValueOfObjCType: @encode(int)
													at: &checksum
												  size: sizeof(int)];
						
						ident = IFMB_ZcodeId(release, serial, checksum);
						needsFreeing = YES;
						break;
					}
						
					case IFFormat_UUID:
					{
						unsigned char uuid[16];
						
						[decoder decodeArrayOfObjCType: @encode(unsigned char)
												 count: 16
													at: uuid];
						ident = IFMB_UUID(uuid);
						needsFreeing = YES;
						break;
					}
						
					default:
						/* No other formats are supported yet */
						break;
				}
			} else if (version == 2) {
				NSString* idString = (NSString*)[decoder decodeObject];
				
				ident = IFMB_IdFromString([idString UTF8String]);
				needsFreeing = YES;
			} else {
				// Only v1 and v2 decodes supported ATM
				
				NSLog(@"Tried to load a version %i ZoomStoryID (this version of Zoom supports only versions 1 and 2)", version);
				
				return nil;
			}
			if (ident == nil) {
				return nil;
			}
		}
	}
	
	return self;
}

+ (BOOL)supportsSecureCoding
{
	return YES;
}

#pragma mark - Hashing/comparing
- (NSUInteger) hash {
	return [[self description] hash];
}

- (BOOL) isEqual: (id)anObject {
	if ([anObject isKindOfClass: [ZoomStoryID class]]) {
		ZoomStoryID* compareWith = anObject;
		
		if (IFMB_CompareIds(ident, [compareWith ident]) == 0) {
			return YES;
		} else {
			return NO;
		}
	} else {
		return NO;
	}
}

- (NSString*) description {
	char* stringId = IFMB_IdToString(ident);
	NSString* identString = [[NSString alloc] initWithBytesNoCopy: stringId length: strlen(stringId) encoding: NSUTF8StringEncoding freeWhenDone: YES];
	
	if (identString == nil) {
		free(stringId);
		return @"(null)";
	}
	
	return identString;
}

- (NSString *)debugDescription {
	char* stringId = IFMB_IdToString(ident);
	NSString* identString = [[NSString alloc] initWithBytesNoCopy: stringId length: strlen(stringId) encoding: NSUTF8StringEncoding freeWhenDone: YES];
	
	if (identString == nil) {
		free(stringId);
		return @"(null)";
	}
	
	return identString;
}

#pragma mark - Port coding

- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder { 
	if ([encoder isBycopy]) return self; 
	return [super replacementObjectForPortCoder:encoder]; 
} 

@end
