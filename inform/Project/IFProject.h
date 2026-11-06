//
//  IFProject.h
//  Inform
//
//  Created by Andrew Hunter on Wed Aug 27 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "IFProjectTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class IFCompiler;
@class IFCompilerSettings;
@class IFInBuild;
@class IFSkein;
@class IFSkeinItem;

@interface IFProject : NSDocument<NSTextStorageDelegate>

#pragma mark - Properties
// The files and settings associated with the project
@property (atomic, readonly, copy, nullable)    NSDictionary<NSString*, NSTextStorage*> * sourceFiles;   // nil until a file is read
@property (atomic, readonly, strong)            IFCompilerSettings *  settings;
@property (atomic, readonly, strong)            IFCompiler *          compiler;
@property (atomic)                              NSRange               initialSelectionRange;
@property (atomic)                              IFFileType            projectFileType;
@property (atomic, readonly, copy, nullable)    NSString *            mainSourceFile;         // nil if there's no story file
@property (atomic, readonly, copy, nullable)    NSString *            mainSourcePathName;     // Full pathname
@property (atomic, readonly, strong, nullable)  NSArray<NSDictionary<NSString*, id>*> * testCases;   // nil until a project is read

// 'Subsidiary' files
@property (atomic, readonly, strong, nullable)  IFSkein *             currentSkein;
@property (atomic, readonly, strong)            NSMutableArray<IFSkein*> * skeins;

#pragma mark - File Handling
- (nullable NSTextStorage*) storageForFile: (nullable NSString*) sourceFile;

#pragma mark - Useful URLs
// These are nil for a project with no file URL, such as one that has never been saved.
// The report URLs are also nil if this isn't an extension project.
@property (atomic, readonly, copy, nullable) NSURL *buildDirectoryURL;
@property (atomic, readonly, copy, nullable) NSURL *materialsDirectoryURL;
@property (atomic, readonly, copy, nullable) NSURL *mainSourceFileURL;
@property (atomic, readonly, copy, nullable) NSURL *buildOutputFileURL;
@property (atomic, readonly, copy, nullable) NSURL *settingsFileURL;
@property (atomic, readonly, copy, nullable) NSURL *indexDirectoryURL;
@property (atomic, readonly, copy, nullable) NSURL *currentReportURL;
@property (atomic, readonly, copy, nullable) NSURL *extensionReportURL;
@property (atomic, readonly, copy, nullable) NSURL *baseReportURL;
@property (atomic, readonly, copy, nullable) NSURL *combinedReportURL;

- (nullable NSString*) pathForSourceFile: (nullable NSString*) file;

#pragma mark - Materials folder
- (void) createMaterials;
- (void) openMaterials;

#pragma mark - Loading, saving and clean up
- (void) reloadIndexDirectory;
- (void) reloadDirectory;
- (void) reloadSourceDirectory;
- (void) importIntoSkeinWithWindow: (NSWindow*) window;

- (void) saveIFictionWithWindow:(NSWindow*) window;
- (void) saveDocumentWithoutUserInteraction;
- (void) saveCompilerOutputWithWindow:(NSWindow*) window;

#pragma mark - Extension projects
@property (atomic, readonly) BOOL isExtensionProject;
- (void) selectSkein: (int) index;
/// Saves an extension project, then asks where to save a copy of its extension
- (void) exportExtension: (NSWindow*) window;

@property (NS_NONATOMIC_IOSONLY, readonly) bool useNewExtensions;

#pragma mark - InTest support
/// update the array of test cases
-(void) refreshTestCases;
/// Get the source text for a test case
-(void) extractSourceTaskForExtensionTestCase: (nullable NSString*) testCase;
/// Extension project compilation problems need redirecting back to extension.i7x source, not story.ni
-(NSArray*) redirectLinksToExtensionSourceCode: (NSArray*) link;

/// The commands to test a test case with; nil if intest fails
-(nullable NSArray<NSString*>*) testCommandsForExtensionTestCase: (NSString*) testCase;
- (BOOL) generateReportForTestCase: (NSString*) testCase
                         errorCode: (NSString*) errorCode
                       skeinNodeId: (unsigned long) skeinNodeId
                        skeinNodes: (int) skeinNodes
                         outputURL: (NSURL*) outputURL;
-(BOOL) generateCombinedReportForBaseInputURL: (NSURL*) baseInputURL
                                     numTests: (int) numTests
                                    outputURL: (NSURL*) outputURL;

#pragma mark - InBuild support
@property (atomic) IFInBuild* inBuild;

- (int) executeInBuildForExtension: (NSURL*) extensionURL
                            action: (NSString*) action
                  withConfirmation: (bool) confirmed;
-(bool) testExtension: (NSString*) extension
              command: (NSString*) command
             testcase: (NSString*) testcase;

#pragma mark - Skein support
@property (NS_NONATOMIC_IOSONLY, readonly, strong, nullable) IFSkeinItem *nodeToReport;
/// A skein of the commands in a recording (a .rec or .txt file), as Import Into Skein makes one;
/// nil if the file doesn't look like a recording. Declared here for the unit tests.
- (nullable IFSkein*) skeinFromRecording: (NSString*) path;

#pragma mark - Compiler support
/// The compiler, ready to launch; nil if it can't be prepared
- (nullable IFCompiler*) prepareCompilerForRelease: (BOOL) release
                               forTesting: (BOOL) releaseForTesting
                              refreshOnly: (BOOL) onlyRefresh
                                 testCase: (nullable NSString*) testCase;

@end

NS_ASSUME_NONNULL_END
