//
//  IFProjectFile.h
//  Inform
//
//  Created by Andrew Hunter on Fri Sep 12 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

// Confusingly, a FileWrapper, as a project 'file' is really a bundle

#import <Foundation/Foundation.h>
#import "IFCompilerSettings.h"

@class ZoomSkein;

@interface IFProjectFile : NSObject {
    NSFileWrapper* bundleDirectory;
    NSFileWrapper* sourceDirectory;
    NSFileWrapper* buildDirectory;
}

// = New project creation =
- (id) initWithEmptyProject;
- (id) initWithFileWrapper: (NSFileWrapper*) fileWrapper;

- (void) addSourceFile: (NSString*) filename;
- (void) addSourceFile: (NSString*) filename
          withContents: (NSData*)   contents;
- (void) clearIndex;

- (IFCompilerSettings*) settings;
- (void) setSettings: (IFCompilerSettings*) settings;


- (NSFileWrapper*) sourceDirectory;
- (NSFileWrapper*) syntaxDirectory;

// Read
- (NSTextStorage *) loadNotes;
- (void) loadIntoSkein:(ZoomSkein *) skein;
- (NSMutableArray*) loadWatchpoints;
- (NSMutableArray*) loadBreakpoints;
- (NSString*) loadUUID;

// Write
-(void) setPreferredFilename:(NSString*) name;
-(void) replaceSourceDirectoryWrapper:(NSFileWrapper*) newWrapper;
-(void) replaceIndexDirectoryWrapper: (NSFileWrapper*) newWrapper;
-(void) writeNotes:(NSData*) noteData;
-(void) writeSkein:(NSString*) xmlData;
-(void) writeWatchpoints:(NSArray *) watchExpressions;
-(void) writeBreakpoints:(NSArray *) breakpoints;

// Clean
- (void) cleanOutUnnecessaryFiles: (BOOL) alsoCleanIndex;

-(NSString*) filename;
-(void) setFilename: (NSString*) newFilename;
-(BOOL) write;

@end
