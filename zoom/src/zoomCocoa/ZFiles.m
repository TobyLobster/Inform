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
    NSObject<ZFile>* theFile;
};

// = Files =
ZFile* open_file_from_object(NSObject<ZFile>* file) {
    if (file == nil)
        return NULL;

    ZFile* res = malloc(sizeof(ZFile));

    res->theFile = [file retain];

    return res;
}

ZFile* open_file(char* filename) {
    // This shouldn't normally be called in this version of Zoom
    NSLog(@"Warning: open_file with filename '%s' called", filename);

    // Open the file
    NSFileHandle* handle = [NSFileHandle fileHandleForReadingAtPath: [NSString stringWithCString: filename]];

    if (handle == nil) {
        return NULL;
    }

    // Create a file object
    ZFile* f = malloc(sizeof(ZFile));

    f->theFile = [[ZHandleFile alloc] initWithFileHandle: handle];

    return f;
}

ZFile* open_file_write(char* filename) {
    // This shouldn't normally be called in this version of Zoom
    NSLog(@"Warning: open_file_write with filename called");

    // Open the file
    NSFileHandle* handle = [NSFileHandle fileHandleForWritingAtPath: [NSString stringWithCString: filename]];

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
    return (ZByte)[file->theFile readByte];
}

ZUWord read_word(ZFile* file) {
    return (ZByte)[file->theFile readWord];
}

ZUWord read_rword(ZFile* file) {
    NSLog(@"read_rword: Function not implemented: %s %i", __FILE__, __LINE__);
    
    return 0;
}

ZByte* read_page(ZFile* file, int page_no) {
    NSLog(@"read_page: Function not implemented: %s %i", __FILE__, __LINE__);
    
    return NULL;
}

ZByte* read_block(ZFile* file, int start_pos, int end_pos) {
    NSAutoreleasePool* p = [[NSAutoreleasePool alloc] init];
    static NSData* result = nil;

    [file->theFile seekTo: start_pos];
    result = [file->theFile readBlock: end_pos - start_pos];

    ZByte* res2 = malloc([result length]);
    memcpy(res2, [result bytes], [result length]);
    
    [p release];
    return res2;
}

void   read_block2(ZByte* block, ZFile* file, int start_pos, int end_pos) {
    NSAutoreleasePool* p = [[NSAutoreleasePool alloc] init];
    NSData* result = nil;

    [file->theFile seekTo: start_pos];
    result = [file->theFile readBlock: end_pos - start_pos];

    memcpy(block, [result bytes], [result length]);
    [p release];
}

void   write_block(ZFile* file, ZByte* block, int length) { 
    [file->theFile writeBlock: [NSData dataWithBytes: block length: length]];
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

ZDWord get_file_size(char* filename) { 
	return [[[[NSFileManager defaultManager] fileAttributesAtPath: [NSString stringWithCString: filename]
													 traverseLink: YES] objectForKey: NSFileSize]
		intValue];
    return 0;
}

ZDWord get_size_of_file(ZFile* file) {
    return [file->theFile fileSize];
}

int end_of_file(ZFile* file) {
	return [file->theFile endOfFile];
}
