
#import "ZoomProtocol.h"

#define maxBufferCount 1024
NSString* const ZBufferNeedsFlushingNotification = @"ZBufferNeedsFlushingNotification";

#pragma mark Implementation of the various standard classes
@implementation ZHandleFile
- (id) init {
    self = [super init];

    if (self) {
        // Can't initialise without a valid file handle
        return NULL;
    }

    return self;
}

- (id) initWithFileHandle: (NSFileHandle*) hdl {
    self = [super init];

    if (self) {
        handle = hdl;
    }

    return self;
}

// Read
- (unsigned char) readByte {
    NSData* data = [handle readDataOfLength: 1];
    if (data == nil || [data length] < 1) return 0xff;

    return ((unsigned char*)[data bytes])[0];
}

- (unsigned short) readWord {
    NSData* data = [handle readDataOfLength: 2];
    if (data == nil || [data length] < 2) return 0xffff;

    const unsigned char* bytes = [data bytes];
    return (bytes[0]<<8)|bytes[1];
}

- (unsigned int) readDWord {
    NSData* data = [handle readDataOfLength: 4];
    if (data == nil || [data length] < 4) return 0xffffffff;

    const unsigned char* bytes = [data bytes];
    return (bytes[0]<<24)|(bytes[1] << 16)|(bytes[2] << 8)|bytes[3];
}

- (bycopy NSData*) readBlock: (NSInteger) length {
    NSData* data = [handle readDataOfLength: length];
    return data;
}

- (oneway void) seekTo: (off_t) p {
    [handle seekToFileOffset: p];
}

// Write
- (oneway void) writeByte: (unsigned char) byte {
    NSData* data = [NSData dataWithBytes: &byte
                                  length: 1];
    [handle writeData: data];
}

- (oneway void) writeWord: (short) word {
    unsigned char bytes[2];

    bytes[0] = (word>>8);
    bytes[1] = word&0xff;

    NSData* data = [NSData dataWithBytes: bytes
                                  length: 2];

    [handle writeData: data];
}

- (oneway void) writeDWord: (unsigned int) dword {
    unsigned char bytes[4];

    bytes[0] = (dword>>24)&0xff;
    bytes[1] = (dword>>16)&0xff;
    bytes[2] = (dword>>8)&0xff;
    bytes[3] = dword&0xff;

    NSData* data = [NSData dataWithBytes: bytes
                                  length: 4];

    [handle writeData: data];
}

- (oneway void) writeBlock: (in bycopy NSData*) block {
    [handle writeData: block];
}

- (BOOL) sufferedError {
    return NO;
}

- (bycopy NSString*) errorMessage {
    return @"";
}

- (off_t) fileSize {
    unsigned long long pos = [handle offsetInFile];

    [handle seekToEndOfFile];
    unsigned long long res = [handle offsetInFile];

    [handle seekToFileOffset: pos];

    return res;
}

- (BOOL) endOfFile {
	// Sigh, Cocoa provides no 'end of file' method. Er, glaring ommision or what?
	unsigned long long oldOffset = [handle offsetInFile];
	
	[handle seekToEndOfFile];
	unsigned long long eofOffset = [handle offsetInFile];
	
	if (oldOffset == eofOffset) return YES;
	
	[handle seekToFileOffset: oldOffset];
	return NO;
}

- (oneway void) close {
    [handle closeFile];
}

@end

@implementation ZDataFile
- (id) init {
    self = [super init];

    if (self) {
        // Can't initialise without valid data
        return NULL;
    }

    return self;
}

- (id) initWithData: (NSData*) dt {
    self = [super init];

    if (self) {
        data = dt;
        pos = 0;
    }

    return self;
}

- (unsigned char) readByte {
    if (pos >= [data length]) {
        return 0xff;
    }
    
    return ((unsigned char*)[data bytes])[pos++];
}

- (unsigned short) readWord {
    if ((pos+1) >= [data length]) {
        return 0xffff;
    }

    NSData* preBytes = [data subdataWithRange: NSMakeRange(pos, 2)];
    const unsigned char* bytes = [preBytes bytes];

    unsigned short res =  (bytes[0]<<8) | bytes[1];
    pos+=2;

    return res;
}

- (unsigned int) readDWord {
    if ((pos+3) >= [data length]) {
        return 0xffffffff;
    }

    NSData* preBytes = [data subdataWithRange: NSMakeRange(pos, 4)];
    const unsigned char* bytes = [preBytes bytes];

    unsigned int res =  ((bytes[0]<<24) | (bytes[1]<<16) |
                         (bytes[2]<<8) | (bytes[3]));
    pos+=4;

    return res;
}

- (bycopy NSData*) readBlock: (NSInteger) length {
    if (pos >= [data length]) {
        return nil;
    }

    if ((pos + length) > [data length]) {
        NSInteger diff = (pos+length) - [data length];

        length -= diff;
    }

    NSData* res =  [data subdataWithRange: NSMakeRange(pos, length)];

    pos += length;

    return res;
}

- (oneway void) seekTo: (off_t) p {
    pos = (NSInteger)p;
    if (pos > [data length]) {
        pos = [data length];
    }
}

- (oneway void) writeByte: (__unused unsigned char) byte {
    return; // Do nothing
}

- (oneway void) writeWord: (__unused short) word {
    return; // Do nothing
}

- (oneway void) writeDWord: (__unused unsigned int) dword {
    return; // Do nothing
}

- (oneway void) writeBlock: (in bycopy __unused NSData*) block {
    return; // Do nothing
}

- (BOOL) sufferedError {
    return NO;
}

- (bycopy NSString*) errorMessage {
    return @"";
}

- (off_t) fileSize {
    return [data length];
}

- (BOOL) endOfFile {
	return pos >= [data length];
}

- (oneway void) close {
    return; // Do nothing
}
@end

#pragma mark - ZStyle

@implementation ZStyle

- (id) init {
    self = [super init];
    if (self) {
        foregroundTrue = backgroundTrue = NULL;
        foregroundColour = 0;
        backgroundColour = 7;

        isFixed = isBold = isUnderline = isSymbolic = NO;
    }
    return self;
}

@synthesize foregroundColour;
@synthesize backgroundColour;
@synthesize foregroundTrue;
@synthesize backgroundTrue;
@synthesize fixed=isFixed;
@synthesize forceFixed=isForceFixed;
@synthesize bold=isBold;
@synthesize underline=isUnderline;
@synthesize symbolic=isSymbolic;
@synthesize reversed=isReversed;

- (BOOL) isFixed {
    return isFixed || isForceFixed;
}

- (id) copyWithZone: (NSZone*) zone {
    ZStyle* style = [[[self class] alloc] init];

    [style setForegroundColour: foregroundColour];
    [style setBackgroundColour: backgroundColour];
    [style setForegroundTrue: foregroundTrue];
    [style setBackgroundTrue: backgroundTrue];

    [style setReversed:   isReversed];
    [style setFixed:      isFixed];
    [style setBold:       isBold];
    [style setUnderline:  isUnderline];
    [style setSymbolic:   isSymbolic];
	[style setForceFixed: isForceFixed];

    return style;
}

- (NSString*) description {
    return [NSString stringWithFormat: @"Style - bold: %@, underline %@, fixed %@, symbolic %@",
                        isBold?@"YES":@"NO",
                        isUnderline?@"YES":@"NO",
                        isFixed?@"YES":@"NO",
                        isSymbolic?@"YES":@"NO"];
}

- (NSString*) debugDescription {
    return [NSString stringWithFormat: @"Style - bold: %@, underline %@, fixed %@, symbolic %@",
                        isBold?@"YES":@"NO",
                        isUnderline?@"YES":@"NO",
                        isFixed?@"YES":@"NO",
                        isSymbolic?@"YES":@"NO"];
}

#define FLAGSCODINGKEY @"flags"
#define TRUEFORECOLORCODINGKEY @"foregroundTrue"
#define TRUEBACKCOLORCODINGKEY @"backgroundTrue"
#define FOREGROUNDCOLORCODINGKEY @"foregroundColour"
#define BACKGROUNDCOLORCODINGKEY @"backgroundColour"

- (void) encodeWithCoder: (NSCoder*) coder {
    int flags = (isBold?1:0) | (isUnderline?2:0) | (isFixed?4:0) | (isSymbolic?8:0) | (isReversed?16:0) | (isForceFixed?32:0);
    
	if (coder.allowsKeyedCoding) {
		[coder encodeInt: flags forKey: FLAGSCODINGKEY];

		[coder encodeObject: foregroundTrue forKey: TRUEFORECOLORCODINGKEY];
		[coder encodeObject: backgroundTrue forKey: TRUEBACKCOLORCODINGKEY];
		[coder encodeInt: foregroundColour forKey: FOREGROUNDCOLORCODINGKEY];
		[coder encodeInt: backgroundColour forKey: BACKGROUNDCOLORCODINGKEY];
	} else {
		[coder encodeValueOfObjCType: @encode(int) at: &flags];
		
		[coder encodeObject: foregroundTrue];
		[coder encodeObject: backgroundTrue];
		[coder encodeValueOfObjCType: @encode(int) at: &foregroundColour];
		[coder encodeValueOfObjCType: @encode(int) at: &backgroundColour];
	}
}

- (id) initWithCoder: (NSCoder*) coder {
    self = [super init];
    if (self) {
		int flags;
		if (coder.allowsKeyedCoding) {
			flags = [coder decodeIntForKey: FLAGSCODINGKEY];
			
			foregroundTrue = [coder decodeObjectOfClass: [NSColor class] forKey: TRUEFORECOLORCODINGKEY];
			backgroundTrue = [coder decodeObjectOfClass: [NSColor class] forKey: TRUEBACKCOLORCODINGKEY];

			foregroundColour = [coder decodeIntForKey: FOREGROUNDCOLORCODINGKEY];
			backgroundColour = [coder decodeIntForKey: BACKGROUNDCOLORCODINGKEY];
		} else {
			[coder decodeValueOfObjCType: @encode(int) at: &flags size: sizeof(int)];
			
			foregroundTrue   = [coder decodeObject];
			backgroundTrue   = [coder decodeObject];
			
			[coder decodeValueOfObjCType: @encode(int) at: &foregroundColour size: sizeof(int)];
			[coder decodeValueOfObjCType: @encode(int) at: &backgroundColour size: sizeof(int)];
		}
        isBold = (flags&1)?YES:NO;
        isUnderline = (flags&2)?YES:NO;
        isFixed = (flags&4)?YES:NO;
        isSymbolic = (flags&8)?YES:NO;
        isReversed = (flags&16)?YES:NO;
		isForceFixed = (flags&32)?YES:NO;
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder
{
    if ([encoder isBycopy]) return self;
    return [super replacementObjectForPortCoder:encoder];
}

- (BOOL) isEqual: (id) object {
    if (![(NSObject*)object isKindOfClass: [self class]]) {
        return NO;
    }

    ZStyle* obj = object;

    if (obj.bold      == isBold &&
        obj.underline == isUnderline &&
        obj.fixed     == isFixed &&
        obj.symbolic  == isSymbolic &&
        obj.reversed  == isReversed &&
        [obj foregroundColour] == foregroundColour &&
        [obj backgroundColour] == backgroundColour &&
        ((foregroundTrue == nil && [obj foregroundTrue] == nil) ||
         ([[obj foregroundTrue] isEqual: foregroundTrue])) &&
        ((backgroundTrue == nil && [obj backgroundTrue] == nil) ||
         ([[obj backgroundTrue] isEqual: backgroundTrue]))) {
        return YES;
    }

    return NO;
}

@end

#pragma mark - ZBuffer

// Buffer type strings
static NSString* const ZBufferWriteString  = @"ZBWS";
static NSString* const ZBufferClearWindow  = @"ZBCW";
static NSString* const ZBufferMoveTo       = @"ZBMT";
static NSString* const ZBufferEraseLine    = @"ZBEL";
static NSString* const ZBufferSetWindow    = @"ZBSW";

static NSString* const ZBufferPlotRect     = @"ZBPR";
static NSString* const ZBufferPlotText     = @"ZBPT";
static NSString* const ZBufferPlotImage    = @"ZBPI";
static NSString* const ZBufferScrollRegion = @"ZBSR";

@implementation ZBuffer {
    NSMutableArray<NSArray*>* buffer;
    int bufferCount;
}

// Initialisation
- (id) init {
    self = [super init];
    if (self) {
        buffer = [[NSMutableArray alloc] init];
    }
    return self;
}

// NSCopying

- (id) copyWithZone: (NSZone*) zone {
    ZBuffer* buf;
    buf = [[[self class] alloc] init];

    buf->buffer = [buffer mutableCopy];

    return buf;
}

// NSCoding

- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder
{
    // Allow bycopying
    if ([encoder isBycopy]) return self;
    return [super replacementObjectForPortCoder:encoder];
}

- (void) encodeWithCoder: (NSCoder*) coder {
	if (coder.allowsKeyedCoding) {
		[coder encodeObject: buffer forKey: @"Buffer"];
	} else {
		[coder encodeObject: buffer];
	}
}

- (id) initWithCoder: (NSCoder*) coder {
    self = [super init];
    if (self) {
		if (coder.allowsKeyedCoding) {
			buffer = [coder decodeObjectOfClasses: [NSSet setWithObjects: [NSString class], [ZStyle class], [NSValue class], [NSNumber class], [NSObject class], nil] forKey: @"Buffer"];
		} else {
			buffer = [coder decodeObject];
		}
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
	return YES;
}

// Buffering

// General window routines
- (void) writeString: (NSString*)          string
           withStyle: (ZStyle*)            style
            toWindow: (id<ZWindow>) window {
    NSArray* lastTime;

    // If we can, merge this write with the preceding one
    lastTime = [buffer lastObject];
    if (lastTime) {
        if ([[lastTime objectAtIndex: 0] isEqualToString: ZBufferWriteString]) {
            ZStyle* lastStyle             = [lastTime objectAtIndex: 2];

            if (lastStyle == style ||
                [lastStyle isEqual: style]) {
                id<ZWindow> lastWindow = [lastTime objectAtIndex: 3];
                if (lastWindow == window) {
                    NSMutableString* lastString   = [lastTime objectAtIndex: 1];

                    [lastString appendString: string];
					[self addedToBuffer];
                   return;
                }
            }
        }
    }

    // Create a new write
    [buffer addObject:
        @[ZBufferWriteString,
          [NSMutableString stringWithString: string],
          style,
          window]];
	[self addedToBuffer];
}

- (void) clearWindow: (id<ZWindow>) window
           withStyle: (ZStyle*) style {
    [buffer addObject:
        @[ZBufferClearWindow,
          style,
          window]];
	[self addedToBuffer];
}

// Upper window routines
- (void) moveCursorToPoint: (NSPoint) newCursorPos
                  inWindow: (id<ZUpperWindow>) window {
    [buffer addObject:
        @[ZBufferMoveTo,
          @(newCursorPos),
          window]];
	[self addedToBuffer];
}

- (void) eraseLineInWindow: (id<ZUpperWindow>) window
                 withStyle: (ZStyle*) style {
    [buffer addObject:
        @[ZBufferEraseLine,
          style,
          window]];
	[self addedToBuffer];
}

- (void) setWindow: (id<ZUpperWindow>) window
         startLine: (int) startLine
           endLine: (int) endLine {
    [buffer addObject:
        @[ZBufferSetWindow,
          @(startLine),
          @(endLine),
          window]];
	[self addedToBuffer];
}

// Pixmap window routines
- (void) plotRect: (NSRect) rect
		withStyle: (ZStyle*) style
		 inWindow: (id<ZPixmapWindow>) window {
    [buffer addObject:
        @[ZBufferPlotRect,
          @(rect),
          style,
          window]];
	[self addedToBuffer];
}

- (void) plotText: (NSString*) text
		  atPoint: (NSPoint) point
		withStyle: (ZStyle*) style
		 inWindow: (id<ZPixmapWindow>) win {
    [buffer addObject:
        @[ZBufferPlotText,
          [text copy],
          @(point),
          style,
          win]];
	[self addedToBuffer];
}

- (void) scrollRegion: (NSRect) region
			  toPoint: (NSPoint) newPoint
			 inWindow: (id<ZPixmapWindow>) win {
	[buffer addObject:
		@[ZBufferScrollRegion,
          @(region),
          @(newPoint),
          win]];
}

- (void) plotImage: (int) number
		   atPoint: (NSPoint) point
		  inWindow: (id<ZPixmapWindow>) win {
	[buffer addObject:
	 @[ZBufferPlotImage,
	   @(number),
	   @(point),
	   win]];
}

// Unbuffering
- (BOOL) isEmpty {
    if ([buffer count] < 1)
        return YES;
    else
        return NO;
}

- (void) blat {
#ifdef DEBUG
	NSLog(@"Buffer: flushing... (%@)", buffer);
#endif
	
    for (NSArray* entry in buffer) {
        NSString* entryType = [entry objectAtIndex: 0];
#ifdef DEBUG
		NSLog(@"Buffer: %@", entryType);
#endif

        if ([entryType isEqualToString: ZBufferWriteString]) {
            NSString* str = [entry objectAtIndex: 1];
            ZStyle*   sty = [entry objectAtIndex: 2];
            id<ZWindow> win = [entry objectAtIndex: 3];

            [win writeString: str
                   withStyle: sty];
			
#ifdef DEBUG
			NSLog(@"Buffer: ZBufferWriteString(%@)", str);
#endif
        } else if ([entryType isEqualToString: ZBufferClearWindow]) {
            ZStyle* sty = [entry objectAtIndex: 1];
            id<ZWindow> win = [entry objectAtIndex: 2];

            [win clearWithStyle: sty];
			
#ifdef DEBUG
			NSLog(@"Buffer: ZBufferClearWindow");
#endif
        } else if ([entryType isEqualToString: ZBufferMoveTo]) {
            NSPoint whereTo = [[entry objectAtIndex: 1] pointValue];
            id<ZUpperWindow> win = [entry objectAtIndex: 2];

            [win setCursorPositionX: whereTo.x
                                  Y: whereTo.y];
			
#ifdef DEBUG
			NSLog(@"Buffer: ZBufferMoveTo(%g, %g)", whereTo.x, whereTo.y);
#endif
        } else if ([entryType isEqualToString: ZBufferEraseLine]) {
            ZStyle* sty = [entry objectAtIndex: 1];
            id<ZUpperWindow> win = [entry objectAtIndex: 2];

            [win eraseLineWithStyle: sty];
			
#ifdef DEBUG
			NSLog(@"Buffer: ZBufferEraseLine");
#endif
        } else if ([entryType isEqualToString: ZBufferSetWindow]) {
            int startLine = [[entry objectAtIndex: 1] intValue];
            int endLine   = [[entry objectAtIndex: 2] intValue];
            id<ZUpperWindow> win = [entry objectAtIndex: 3];

            [win startAtLine: startLine];
            [win endAtLine: endLine];
			
#ifdef DEBUG
			NSLog(@"Buffer: ZBufferSetWindow(%i, %i)", startLine, endLine);
#endif
		} else if ([entryType isEqualToString: ZBufferPlotRect]) {
			NSRect rect = [[entry objectAtIndex: 1] rectValue];
			ZStyle* style = [entry objectAtIndex: 2];
			id<ZPixmapWindow> win = [entry objectAtIndex: 3];
			
			[win plotRect: rect
				withStyle: style];
		} else if ([entryType isEqualToString: ZBufferPlotText]) {
			NSString* text = [entry objectAtIndex: 1];
			NSPoint point = [[entry objectAtIndex: 2] pointValue];
			ZStyle* style = [entry objectAtIndex: 3];
			id<ZPixmapWindow> win = [entry objectAtIndex: 4];
			
			[win plotText: text
				  atPoint: point
				withStyle: style];
		} else if ([entryType isEqualToString: ZBufferPlotImage]) {
			int number = [[entry objectAtIndex: 1] intValue];
			NSPoint point = [[entry objectAtIndex: 2] pointValue];
			id<ZPixmapWindow> win = [entry objectAtIndex: 3];
			
			[win plotImageWithNumber: number
							 atPoint: point];
		} else if ([entryType isEqualToString: ZBufferScrollRegion]) {
			NSRect region = [[entry objectAtIndex: 1] rectValue];
			NSPoint point = [[entry objectAtIndex: 2] pointValue];
			id<ZPixmapWindow> win = [entry objectAtIndex: 3];
			
			[win scrollRegion: region
					  toPoint: point];
        } else {
            NSLog(@"Unknown buffer type: %@", entryType);
        }
    }
}

// Notifications
- (void) addedToBuffer {
	bufferCount++;
	
	if (bufferCount > maxBufferCount) {
		[[NSNotificationCenter defaultCenter] postNotificationName: ZBufferNeedsFlushingNotification
															object: self];
		bufferCount = 0;
	}
}

@end

#pragma mark - File wrappers
@implementation ZPackageFile

- (instancetype) initWithURL: (NSURL*) path
				 defaultFile: (NSString*) filename
				  forWriting: (BOOL) write {
	self = [super init];
	
	if (self) {
		BOOL failed = NO;
		
		forWriting = write;
		pos = 0;
		
		defaultFile = [filename copy];
		if (defaultFile == nil) defaultFile = @"save.qut";
		
		attributes = nil;
		
		if (forWriting) {
			// Setup for writing
			writePath = [path copy];
			wrapper = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: [NSDictionary dictionary]];
			
			data = nil;
			writeData = [[NSMutableData alloc] init];
		} else {
			// Setup for reading
			writePath = nil; // No writing!
			writeData = nil;
			wrapper = [[NSFileWrapper alloc] initWithURL: path
												 options: (NSFileWrapperReadingOptions)0
												   error: NULL];
			
			if (![wrapper isDirectory]) {
				failed = YES;
			}
			
			data = [[wrapper fileWrappers] objectForKey: defaultFile];
			
			if (![data isRegularFile]) {
				failed = YES;
			}
		}
		
		if (wrapper == nil || failed) {
			// Couldn't open file
			return nil;
		}
	}
	
	return self;
}

- (id) initWithPath: (NSString*) path
		defaultFile: (NSString*) filename
		 forWriting: (BOOL) write {
	return [self initWithURL: [NSURL fileURLWithPath:path] defaultFile: filename forWriting: write];
}

@synthesize attributes;

- (unsigned char) readByte {
	if (forWriting) {
		[NSException raise: @"ZoomFileReadException" format: @"Tried to read from a file open for writing"];
		return 0;
	}
	
	if (pos >= [[data regularFileContents] length]) return 0xff;
    NSData *preBytes = [[data regularFileContents] subdataWithRange:NSMakeRange(pos++, 1)];
	
	return *((unsigned char*)preBytes.bytes);
}

- (unsigned short) readWord {
	if (forWriting) {
		[NSException raise: @"ZoomFileReadException" format: @"Tried to read from a file open for writing"];
		return 0;
	}
	NSData *rfc = [data regularFileContents];
	
	if ((pos+1) >= [rfc length]) {
        return 0xffff;
    }
	
    NSData *preBytes = [rfc subdataWithRange: NSMakeRange(pos, 2)];
    const unsigned char* bytes = preBytes.bytes;
	
    unsigned short res =  (bytes[0]<<8) | bytes[1];
    pos+=2;
	
    return res;	
}

- (unsigned int) readDWord {
	if (forWriting) {
		[NSException raise: @"ZoomFileReadException" format: @"Tried to read from a file open for writing"];
		return 0;
	}
    NSData *rfc = [data regularFileContents];

    if ((pos+3) >= [rfc length]) {
        return 0xffffffff;
    }
	
    NSData *preBytes = [rfc subdataWithRange: NSMakeRange(pos, 4)];
    const unsigned char* bytes = preBytes.bytes;
	
    unsigned int res =  ((bytes[0]<<24) | (bytes[1]<<16) |
                         (bytes[2]<<8) | (bytes[3]));
    pos+=4;
	
    return res;
}

- (bycopy NSData*) readBlock: (NSInteger) length {
	if (forWriting) {
		[NSException raise: @"ZoomFileReadException" format: @"Tried to read from a file open for writing"];
		return nil;
	}
	
    NSData* bytes = [data regularFileContents];
	
    if (pos >= [bytes length]) {
        return nil;
    }
	
    if ((pos + length) > [bytes length]) {
        NSInteger diff = (NSInteger)((pos+length) - [bytes length]);
		
        length -= diff;
    }
	
    NSData* res = [bytes subdataWithRange: NSMakeRange(pos, length)];
	
    pos += length;
	
    return res;
}

- (oneway void) seekTo: (off_t) p {
	pos = p;
}

- (oneway void) writeByte: (unsigned char) byte {
	if (!forWriting) {
		[NSException raise: @"ZoomFileWriteException" format: @"Tried to write to a file open for reading"];
		return;
	}
	
	unsigned char b = byte;
	
	[writeData appendBytes: &b
					length: 1];
}

- (oneway void) writeWord: (short) word {
	if (!forWriting) {
		[NSException raise: @"ZoomFileWriteException" format: @"Tried to write to a file open for reading"];
		return;
	}
	
	unsigned char b[2];
	
	b[0] = (word>>8)&0xff;
	b[1] = word&0xff;
	
	[writeData appendBytes: b
					length: 2];
}

- (oneway void) writeDWord: (unsigned int) dword {
	if (!forWriting) {
		[NSException raise: @"ZoomFileWriteException" format: @"Tried to write to a file open for reading"];
		return;
	}
	
	unsigned char b[4];
	
	b[0] = (dword>>24)&0xff;
	b[1] = (dword>>16)&0xff;
	b[2] = (dword>>8)&0xff;
	b[3] = dword&0xff;
	
	[writeData appendBytes: b
					length: 4];
}

- (oneway void) writeBlock: (in bycopy NSData*) block {
	if (!forWriting) {
		[NSException raise: @"ZoomFileWriteException" format: @"Tried to write to a file open for reading"];
		return;
	}
	
	[writeData appendData: block];
}

- (BOOL) sufferedError {
	return NO;
}

- (bycopy NSString*) errorMessage {
	return nil;
}

- (off_t) fileSize {
	if (forWriting) {
		[NSException raise: @"ZoomFileReadException" format: @"Tried to read from a file open for writing"];
		return 0;
	}
	
	return [[data regularFileContents] length];
}

- (BOOL) endOfFile {
	return (pos >= [[data regularFileContents] length]);
}

- (oneway void) close {
	if (forWriting) {
		// Write out the file
		if ([[wrapper fileWrappers] objectForKey: defaultFile] != nil) {
			[wrapper removeFileWrapper: [[wrapper fileWrappers] objectForKey: defaultFile]];
		}
		
		[wrapper addRegularFileWithContents: writeData
						  preferredFilename: defaultFile];
        if (attributes) {
            NSMutableDictionary *attribDict = [wrapper.fileAttributes mutableCopy];
            [attribDict addEntriesFromDictionary:attributes];
            wrapper.fileAttributes = attribDict;
        }
		
		[wrapper writeToURL: writePath
					options: (NSFileWrapperWritingAtomic | NSFileWrapperWritingWithNameUpdating)
		originalContentsURL: nil
					  error: NULL];
	}
}

- (void) addData: (NSData*) newData
	 forFilename: (NSString*) filename {
	if (!forWriting) {
		[NSException raise: @"ZoomFileWriteException" format: @"Tried to write to a file open for reading"];
		return;
	}
	
	[wrapper addRegularFileWithContents: newData
					  preferredFilename: filename];
}

- (NSData*) dataForFile: (NSString*) filename {
	if (forWriting) {
		[NSException raise: @"ZoomFileReadException" format: @"Tried to read from a file open for writing"];
		return nil;
	}
	
	return [[wrapper fileWrappers][filename] regularFileContents];
}

@end

@interface NSColorSpace (PortCoderCompat)
@end

@implementation NSColorSpace (PortCoderCompat)

- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder {
    // Always copy!
    return self;
}

@end
