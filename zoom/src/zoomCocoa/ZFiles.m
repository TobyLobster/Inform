//
//  ZFiles.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomZMachine.h"
#import "ZoomServer.h"

#include "file.h"
#include "display.h"

struct ZFile {
    id<ZFile> theFile;
};

#pragma mark - Files
ZFile* open_file_from_object(id<ZFile> file) {
    if (file == nil)
        return NULL;

    ZFile* res = malloc(sizeof(ZFile));

    res->theFile = [file retain];

    return res;
}

ZFile* open_file(const char* filename) {
    // This shouldn't normally be called in this version of Zoom
    NSLog(@"Warning: open_file with filename called");

    // Open the file
    NSFileHandle* handle = [NSFileHandle fileHandleForReadingFromURL: [NSURL fileURLWithFileSystemRepresentation: filename isDirectory: NO relativeToURL: nil] error: NULL];

    if (handle == nil) {
        return NULL;
    }

    // Create a file object
    ZFile* f = malloc(sizeof(ZFile));

    f->theFile = [[ZHandleFile alloc] initWithFileHandle: handle];

    return f;
}

ZFile* open_file_write(const char* filename) {
    // This shouldn't normally be called in this version of Zoom
    NSLog(@"Warning: open_file_write with filename called");

    // Open the file
    NSFileHandle* handle = [NSFileHandle fileHandleForWritingToURL: [NSURL fileURLWithFileSystemRepresentation: filename isDirectory: NO relativeToURL: nil] error: NULL];

    if (handle == nil) {
        return NULL;
    }

    // Create a file object
    ZFile* f = malloc(sizeof(ZFile));

    f->theFile = [[ZHandleFile alloc] initWithFileHandle: handle];

    return f;
}

void close_file(ZFile* file) {
    [file->theFile close];
    [file->theFile release];
    free(file);
}

ZByte read_byte(ZFile* file) {
    return [file->theFile readByte];
}

ZUWord read_word(ZFile* file) {
    return [file->theFile readWord];
}

ZDWord read_dword(ZFile* file) {
    return [file->theFile readDWord];
}

ZUWord read_rword(ZFile* file) {
    @autoreleasepool {
#if 0
        return __builtin_bswap16([file->theFile readWord]);
#else
        return [file->theFile readByte]|([file->theFile readByte]<<8);
#endif
    }
}

ZByte* read_page(ZFile* file, int page_no) {
    return read_block(file, 4096*page_no, 4096*page_no+4096);
}

ZByte* read_block(ZFile* file, int start_pos, int end_pos) {
    @autoreleasepool {
    NSData* result = nil;

    [file->theFile seekTo: start_pos];
    result = [file->theFile readBlock: end_pos - start_pos];

    ZByte* res2 = malloc([result length]);
    memcpy(res2, [result bytes], [result length]);
    
    return res2;
    }
}

void   read_block2(ZByte* block, ZFile* file, int start_pos, int end_pos) {
    @autoreleasepool {
    NSData* result = nil;

    [file->theFile seekTo: start_pos];
    result = [file->theFile readBlock: end_pos - start_pos];

    memcpy(block, [result bytes], [result length]);
    }
}

void   write_block(ZFile* file, const ZByte* block, int length) {
    @autoreleasepool {
    [file->theFile writeBlock: [NSData dataWithBytes: block length: length]];
    }
}

void write_byte(ZFile* file, ZByte byte) {
    [file->theFile writeByte: byte];
}

void write_word(ZFile* file, ZWord word) { 
    [file->theFile writeWord: word];
}

void write_dword(ZFile* file, ZDWord word) { 
    [file->theFile writeDWord: word];
}

ZDWord get_file_size(const char* filename) { 
	return [[[[NSFileManager defaultManager] attributesOfItemAtPath: [[[NSFileManager defaultManager] stringWithFileSystemRepresentation:filename length:strlen(filename)] stringByResolvingSymlinksInPath]
															  error: NULL] objectForKey: NSFileSize]
		intValue];
    return 0;
}

ZDWord get_size_of_file(ZFile* file) {
    return (ZDWord)[file->theFile fileSize];
}

int end_of_file(ZFile* file) {
	return [file->theFile endOfFile];
}
