//
//  IFProjectFile.h
//  Inform
//
//  Created by Andrew Hunter on Fri Sep 12 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

// Confusingly, a FileWrapper, as a project 'file' is really a bundle

#import <Foundation/Foundation.h>

@class IFSkein;
@class IFProject;
@class IFCompilerSettings;

@interface IFProjectFile : NSObject

@property (atomic, strong)            IFCompilerSettings *    settings;
@property (atomic, readonly, strong)  NSFileWrapper *         sourceDirectory;
@property (atomic, readonly, strong)  NSFileWrapper *         syntaxDirectory;
@property (atomic, readonly, copy)    NSTextStorage *         loadNotes;
@property (atomic, readonly, copy)    NSMutableArray *        loadWatchpoints;
@property (atomic, readonly, copy)    NSMutableArray *        loadBreakpoints;
@property (atomic, readonly, copy)    NSString *              loadUUID;
@property (atomic, copy)              NSString *              filename;
@property (atomic, readonly)          BOOL                    write;

#pragma mark - New project creation

- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithEmptyProject NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithFileWrapper: (NSFileWrapper*) fileWrapper NS_DESIGNATED_INITIALIZER;

- (void) addSourceFile: (NSString*) filename;
- (void) addSourceFile: (NSString*) filename
          withContents: (NSData*)   contents;
- (void) clearIndex;

// Read
-(void) loadIntoSkeins: (NSMutableArray *) skeins
               project: (IFProject*) project
    isExtensionProject: (BOOL) isExtensionProject;

// Write
-(void) setPreferredFilename:(NSString*) name;
-(void) replaceSourceDirectoryWrapper:(NSFileWrapper*) newWrapper;
-(void) replaceIndexDirectoryWrapper: (NSFileWrapper*) newWrapper;
-(void) replaceWrapper: (NSFileWrapper*) newWrapper;
-(void) writeNotes:(NSData*) noteData;
-(void) writeSkeins: (NSArray<IFSkein*>*) skeins isExtensionProject: (BOOL) isExtensionProject;
-(void) writeWatchpoints:(NSArray *) watchExpressions;
-(void) writeBreakpoints:(NSArray *) breakpoints;

// Clean
- (void) cleanOutUnnecessaryFiles: (BOOL) alsoCleanIndex NS_SWIFT_NAME(cleanOutUnnecessaryFiles(alsoCleanIndex:));


- (void) DEBUGverifyWrapper;
@property (NS_NONATOMIC_IOSONLY, readonly, strong) NSFileWrapper *buildWrapper;

@end
