//
//  IFProjectFile.h
//  Inform
//
//  Created by Andrew Hunter on Fri Sep 12 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

// Confusingly, a FileWrapper, as a project 'file' is really a bundle

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class IFSkein;
@class IFProject;
@class IFCompilerSettings;

@interface IFProjectFile : NSObject

// Each of these is nil if the project doesn't have it
@property (atomic, strong, nullable)            IFCompilerSettings *    settings;
@property (atomic, readonly, strong, nullable)  NSFileWrapper *         sourceDirectory;
@property (atomic, readonly, copy, nullable)    NSTextStorage *         loadNotes;
@property (atomic, readonly, copy, nullable)    NSMutableArray *        loadWatchpoints;
@property (atomic, readonly, copy, nullable)    NSMutableArray *        loadBreakpoints;
@property (atomic, readonly, copy, nullable)    NSString *              loadUUID;
@property (atomic, copy, nullable)              NSString *              filename;
@property (atomic, readonly)                    BOOL                    write;

#pragma mark - New project creation

- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithEmptyProject NS_DESIGNATED_INITIALIZER;
/// nil if the file wrapper isn't a folder
- (nullable instancetype) initWithFileWrapper: (NSFileWrapper*) fileWrapper NS_DESIGNATED_INITIALIZER;

- (void) addSourceFile: (NSString*) filename
          withContents: (NSData*)   contents;

// Read
-(void) loadIntoSkeins: (NSMutableArray<IFSkein*> *) skeins
               project: (IFProject*) project
    isExtensionProject: (BOOL) isExtensionProject;

// Write
-(void) replaceSourceDirectoryWrapper:(nullable NSFileWrapper*) newWrapper;
-(void) replaceIndexDirectoryWrapper: (nullable NSFileWrapper*) newWrapper;
-(void) replaceWrapper: (nullable NSFileWrapper*) newWrapper;
-(void) writeNotes:(nullable NSData*) noteData;
-(void) writeSkeins: (NSArray<IFSkein*>*) skeins isExtensionProject: (BOOL) isExtensionProject;
-(void) writeWatchpoints:(NSArray *) watchExpressions;
-(void) writeBreakpoints:(NSArray *) breakpoints;

// Clean
- (void) cleanOutUnnecessaryFiles: (BOOL) alsoCleanIndex NS_SWIFT_NAME(cleanOutUnnecessaryFiles(alsoCleanIndex:));

@end

NS_ASSUME_NONNULL_END
