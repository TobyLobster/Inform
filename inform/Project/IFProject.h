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
- (NSURL*) buildDirectoryURL;
- (NSURL*) materialsDirectoryURL;
- (NSURL*) mainSourceFileURL;
- (NSURL*) buildOutputFileURL;
- (NSURL*) buildIndexFileURL;
- (NSURL*) settingsFileURL;
- (NSURL*) indexDirectoryURL;
- (NSURL*) currentSkeinURL;
- (NSURL*) currentReportURL;
- (NSURL*) normalProblemsURL;
- (NSURL*) baseReportURL;
- (NSURL*) combinedReportURL;

- (NSString*) pathForSourceFile: (NSString*) file;
- (NSString*) projectOutputPathName;

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
- (void) cleanOutUnnecessaryFiles: (BOOL) alsoCleanIndex;

- (void) unregisterProjectTextStorage;


#pragma mark - Debugging
- (BOOL) canDebug;

// Watchpoints
- (void) addWatchExpression: (NSString*) expression;
- (void) replaceWatchExpressionAtIndex: (unsigned) index
						withExpression: (NSString*) expression;
- (NSString*) watchExpressionAtIndex: (unsigned) index;
@property (atomic, readonly) unsigned int watchExpressionCount;
- (void) removeWatchExpressionAtIndex: (unsigned) index;

// Breakpoints
- (void) addBreakpointAtLine: (int) line
					  inFile: (NSString*) filename;
- (void) replaceBreakpointAtIndex: (unsigned) index
			 withBreakpointAtLine: (int) line
						   inFile: (NSString*) filename;
- (int) lineForBreakpointAtIndex: (unsigned) index;
- (NSString*) fileForBreakpointAtIndex: (unsigned) index;
- (unsigned int) breakpointCount;
- (void) removeBreakpointAtIndex: (unsigned) index;
- (void) removeBreakpointAtLine: (int) line
						 inFile: (NSString*) file;

#pragma mark - Extension projects
-(BOOL) isExtensionProject;
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
