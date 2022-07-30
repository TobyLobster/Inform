//
//  IFProject.h
//  Inform
//
//  Created by Andrew Hunter on Wed Aug 27 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "IFProjectTypes.h"

@class IFCompiler;
@class IFCompilerSettings;
@class IFProjectFile;
@class IFIndexFile;
@class IFInTest;
@class IFSyntaxTypes;
@class IFProjectMaterialsPresenter;
@class IFSkein;
@class IFSkeinItem;

@interface IFProject : NSDocument<NSTextStorageDelegate>

@property (atomic, strong) NSFileWrapper *documentFileWrapper;

#pragma mark - Properties
// The files and settings associated with the project
@property (atomic, readonly, strong)  IFProjectFile *       projectFile;
@property (atomic, readonly, copy)    NSDictionary *        sourceFiles;
@property (atomic, readonly, strong)  IFCompilerSettings *  settings;
@property (atomic, readonly, strong)  IFCompiler *          compiler;
@property (atomic, readonly)          BOOL                  editingExtension;
@property (atomic)                    NSRange               initialSelectionRange;
@property (atomic)                    IFFileType            projectFileType;
@property (atomic, readonly)          BOOL                  singleFile;
@property (atomic, readonly, copy)    NSString *            mainSourceFile;
@property (atomic, readonly, copy)    NSString *            mainSourcePathName;     // Full pathname
@property (atomic, readonly, strong)  NSArray *             testCases;

// 'Subsidiary' files
@property (atomic, readonly, copy)    NSTextStorage *       notes;
@property (atomic, readonly, strong)  IFIndexFile *         indexFile;
@property (atomic, readonly, strong)  IFSkein *             currentSkein;
@property (atomic, readonly, strong)  NSMutableArray *      skeins;

#pragma mark - File Handling
- (NSTextStorage*) storageForFile: (NSString*) sourceFile;
- (BOOL) addFile: (NSString*) newFile;
- (BOOL) removeFile: (NSString*) oldFile;
- (BOOL) renameFile: (NSString*) oldFile 
		withNewName: (NSString*) newFile;

#pragma mark - Useful URLs
@property (atomic, readonly, copy) NSURL *buildDirectoryURL;
@property (atomic, readonly, copy) NSURL *materialsDirectoryURL;
@property (atomic, readonly, copy) NSURL *mainSourceFileURL;
@property (atomic, readonly, copy) NSURL *buildOutputFileURL;
@property (atomic, readonly, copy) NSURL *buildIndexFileURL;
@property (atomic, readonly, copy) NSURL *settingsFileURL;
@property (atomic, readonly, copy) NSURL *indexDirectoryURL;
@property (atomic, readonly, copy) NSURL *currentSkeinURL;
@property (atomic, readonly, copy) NSURL *currentReportURL;
@property (atomic, readonly, copy) NSURL *normalProblemsURL;
@property (atomic, readonly, copy) NSURL *baseReportURL;
@property (atomic, readonly, copy) NSURL *combinedReportURL;

- (NSString*) pathForSourceFile: (NSString*) file;
@property (atomic, readonly, copy) NSString *projectOutputPathName;

#pragma mark - Materials folder
- (void) createMaterials;
- (void) openMaterials;

#pragma mark - Loading, saving and clean up
- (void) reloadIndexFile;
- (void) reloadIndexDirectory;
- (void) reloadDirectory;
- (void) reloadSourceDirectory;
- (void) importIntoSkeinWithWindow: (NSWindow*) window;

- (void) saveIFictionWithWindow:(NSWindow*) window;
- (void) saveDocumentWithoutUserInteraction;
- (void) saveCompilerOutputWithWindow:(NSWindow*) window;

/// Removes compiler-generated files that are less useful to keep around
- (void) cleanOutUnnecessaryFiles: (BOOL) alsoCleanIndex NS_SWIFT_NAME(cleanOutUnnecessaryFiles(alsoCleanIndex:));

- (void) unregisterProjectTextStorage;

#pragma mark - Extension projects
@property (atomic, readonly) BOOL isExtensionProject;
-(BOOL) copyProjectExtensionSourceToMaterialsExtensions;
- (void) selectSkein: (int) index;

#pragma mark - InTest support
@property (atomic) IFInTest* inTest;
/// update the array of test cases
-(void) refreshTestCases;
/// Get the source text for a test case
-(void) extractSourceTaskForExtensionTestCase: (NSString*) testCase;
/// Extension project compilation problems need redirecting back to extension.i7x source, not story.ni
-(NSArray*) redirectLinksToExtensionSourceCode: (NSArray*) link;

-(NSArray*) testCommandsForExtensionTestCase: (NSString*) testCase;
- (BOOL) generateReportForTestCase: (NSString*) testCase
                         errorCode: (NSString*) errorCode
                          skeinURL: (NSURL*) skeinURL
                       skeinNodeId: (unsigned long) skeinNodeId
                        skeinNodes: (int) skeinNodes
                         outputURL: (NSURL*) outputURL;
-(BOOL) generateCombinedReportForBaseInputURL: (NSURL*) baseInputURL
                                     numTests: (int) numTests
                                    outputURL: (NSURL*) outputURL;

#pragma mark - Skein support
-(IFSkeinItem*) nodeToReport;

#pragma mark - Compiler support
- (IFCompiler*) prepareCompilerForRelease: (BOOL) release
                               forTesting: (BOOL) releaseForTesting
                              refreshOnly: (BOOL) onlyRefresh
                                 testCase: (NSString*) testCase;

- (void) DEBUGverifyWrapper;
- (NSFileWrapper*) buildWrapper;

@end
