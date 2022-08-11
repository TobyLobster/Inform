//
//  IFProject.m
//  Inform
//
//  Created by Andrew Hunter on Wed Aug 27 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "IFProject.h"
#import "IFProjectController.h"

#import "IFPreferences.h"
#import "IFSyntaxManager.h"
#import "IFExtensionsManager.h"
#import "IFNaturalIntel.h"
#import "IFUtility.h"
#import "IFProjectMaterialsPresenter.h"
#import "IFI7OutputSettings.h"
#import "IFOutputSettings.h"
#import "NSString+IFStringExtensions.h"
#import "IFCompilerSettings.h"
#import "IFCompiler.h"
#import "IFInTest.h"
#import "IFProjectFile.h"
#import "IFIndexFile.h"
#import "IFSkein.h"
#import "IFSkeinItem.h"


@implementation IFProject {
    // The data for this project
    IFProjectFile*          projectFile;
    IFCompilerSettings*     settings;

    IFCompiler*             compiler;

    NSMutableDictionary*    sourceFiles;
    NSString*               mainSource;

    NSTextStorage*          notes;
    IFIndexFile*            indexFile;

    BOOL                    editingExtension;
    BOOL                    singleFile;
    NSRange                 initialSelectionRange;

    NSMutableArray*         watchExpressions;
    NSMutableArray*         breakpoints;
    NSString*               uuid;

    NSLock*                 matcherLock;
    int                     syntaxBuildCount;

    IFProjectMaterialsPresenter* materialsAccess;

    // Temporary window pointer - only used for save dialog
    NSWindow*               tempInternalWindow;

    NSFileWrapper *         _documentFileWrapper;
}

// == Initialisation ==

- (instancetype) init {
    self = [super init];

    if (self) {
        uuid                    = nil;
        settings                = [[IFCompilerSettings alloc] init];
        projectFile             = nil;
        sourceFiles             = nil;
        mainSource              = nil;
        singleFile              = YES;
        initialSelectionRange   = NSMakeRange(0, 0);

        _currentSkein           = [[IFSkein alloc] initWithProject: self];
        _skeins                 = [[NSMutableArray alloc] init];
        compiler                = [[IFCompiler alloc] init];
        notes                   = [[NSTextStorage alloc] initWithString: @""];
        materialsAccess         = nil;
        _inTest                 = [[IFInTest alloc] init];

		watchExpressions        = [[NSMutableArray alloc] init];
		breakpoints             = [[NSMutableArray alloc] init];
    }

    return self;
}

-(void) unregisterProjectTextStorage {
    for( NSString* key in sourceFiles) {
        [IFSyntaxManager unregisterTextStorage:sourceFiles[key]];
    }
}


// == close ==
-(void) close {
	// Clean out any files that we aren't using any more, if set in the preferences
	if ([[IFPreferences sharedPreferences] cleanProjectOnClose]) {
		[self cleanOutUnnecessaryFiles: NO];
	}
    [self unregisterProjectTextStorage];

    materialsAccess = nil;

    [super close];
}

- (void) createMaterials {
    materialsAccess = [[IFProjectMaterialsPresenter alloc] initWithURL: self.fileURL];
}


// == useful file URLs ==
- (NSURL*) sourceDirectoryURL {
    return [self.fileURL URLByAppendingPathComponent: @"Source"];
}

- (NSURL*) buildDirectoryURL {
    return [self.fileURL URLByAppendingPathComponent: @"Build"];
}

- (NSURL*) buildOutputFileURL {
    return [[self.buildDirectoryURL URLByAppendingPathComponent: @"output"]
                                    URLByAppendingPathExtension: self.settings.fileExtension];
}

- (NSURL*) buildIndexFileURL {
    return [self.buildDirectoryURL URLByAppendingPathComponent: @"index.html"];
}

- (NSURL*) mainSourceFileURL {
    if( self.mainSourceFile == nil ) {
        return nil;
    }
    return [self.sourceDirectoryURL URLByAppendingPathComponent: self.mainSourceFile];
}

- (NSURL*) testSourceFileURL {
    return [self.sourceDirectoryURL URLByAppendingPathComponent: @"story.ni"];
}

- (NSURL*) indexDirectoryURL {
    return [self.fileURL URLByAppendingPathComponent: @"Index"];
}

- (NSURL*) indexHeadingsFileURL {
    return [self.indexDirectoryURL URLByAppendingPathComponent: @"Headings.xml"];
}

- (NSURL*) settingsFileURL {
    return [self.fileURL URLByAppendingPathComponent: @"Settings.plist"];
}

- (NSURL*) materialsDirectoryURL {
    // Work out the location of the materials folder
    NSString* projectName	= [self.fileURL.lastPathComponent stringByDeletingPathExtension];
    NSURL* pathURL          = [self.fileURL URLByDeletingLastPathComponent];
    pathURL                 = [pathURL URLByAppendingPathComponent: projectName];
    pathURL                 = [pathURL URLByAppendingPathExtension: @"materials"];

    return pathURL;
}

- (NSURL*) metadataURL {
    return [self.fileURL URLByAppendingPathComponent: @"Metadata.ifiction"];
}

-(NSURL*) currentSkeinURL {
    if( [self isExtensionProject] ) {
        NSUInteger index = [self.skeins indexOfObject: self.currentSkein];
        if( index == NSNotFound ) {
            return nil;
        }

        NSString* filename = [NSString stringWithFormat:@"Skein%c.skein", 'A' + (int) index];
        return [self.fileURL URLByAppendingPathComponent: filename];
    }
    return [self.fileURL URLByAppendingPathComponent: @"Skein.skein"];
}

-(NSURL*) normalProblemsURL {
    return [self.buildDirectoryURL URLByAppendingPathComponent: @"Problems.html"];
}

-(NSURL*) baseReportURL {
    if( [self isExtensionProject] ) {
        NSString* fileName = [NSString stringWithFormat:@"Inform-Report.html"];
        return [[IFUtility temporaryDirectoryURL] URLByAppendingPathComponent:fileName];
    }
    NSAssert(false, @"Asking for report when not an extension project");
    return nil;
}

-(NSURL*) currentReportURL {
    if( [self isExtensionProject] ) {
        NSUInteger index = [self.skeins indexOfObject: self.currentSkein];
        if( index == NSNotFound ) {
            return nil;
        }

        NSString* fileName = [NSString stringWithFormat:@"Inform-Report-%d.html", (int) index + 1];
        return [[IFUtility temporaryDirectoryURL] URLByAppendingPathComponent:fileName];
    }
    NSAssert(false, @"Asking for report when not an extension project");
    return nil;
}

-(NSURL*) combinedReportURL {
    if( [self isExtensionProject] ) {
        return [self.buildDirectoryURL URLByAppendingPathComponent: @"Problems.html"];
    }
    NSAssert(false, @"Asking for combined report when not an extension project");
    return nil;
}

// == useful file paths ==
- (NSString*) mainSourceFile {
    if (singleFile || editingExtension) return mainSource;

    NSFileWrapper* sourceDir = [projectFile sourceDirectory];
    NSDictionary* source     = [sourceDir fileWrappers];

    mainSource = nil;

    for( NSString* key in source ) {
        if( self.projectFileType == IFFileTypeInform7ExtensionProject ) {
            if ([[key pathExtension] isEqualTo: @"i7x"]) {
                mainSource = [key copy];
            }
        }
        else {
            if ([[key pathExtension] isEqualTo: @"inf"] ||
                [[key pathExtension] isEqualTo: @"ni"] ||
                [[key pathExtension] isEqualTo: @"i7"]) {
                mainSource = [key copy];
            }
        }
    }

    return mainSource;
}


- (NSString*) projectInputPathName {
    // Inform 7 compiler takes the project directory path
    return self.fileURL.path;
}

- (NSString*) projectOutputPathName {
    return self.buildOutputFileURL.path;
}

- (NSString*) mainSourcePathName {
    if( self.mainSourceFileURL == nil ) {
        return nil;
    }
    return self.mainSourceFileURL.path;
}

- (NSString*) singleInputPathName {
    return self.fileURL.path;
}

- (NSString*) singleBuildDirectoryPath {
    return [self.fileURL URLByDeletingLastPathComponent].path;
}

-(NSURL*) directoryURLToFindSourceFiles {
    if (editingExtension) {
        // Special case: we're editing an extension, so source files are in the root directory
        return self.fileURL;
    }
    return self.sourceDirectoryURL;

}

- (NSString*) pathForSourceFile: (NSString*) file {
    if( file == nil ) return nil;
    if ([file isAbsolutePath]) return [file stringByStandardizingPath];

    return [[self directoryURLToFindSourceFiles] URLByAppendingPathComponent: file].path;
}


// == storage ==
- (NSTextStorage*) storageWithString: (NSString*) string
                         forFilename: (NSString*) filename {
    string = [string stringByReplacingOccurrencesOfString:@"\n\r" withString:@"\n"];
    string = [string stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];

    // Create the syntax-highlighting text storage object
    NSTextStorage* res = [[NSTextStorage alloc] initWithString: string];

    [IFSyntaxManager registerTextStorage: res
                                filename: [filename lastPathComponent]
                            intelligence: [IFProjectTypes intelligenceForFilename: filename]
                             undoManager: [self undoManager]];
    return res;
}

- (NSTextStorage*) storageWithAttributedString: (NSAttributedString*) string
                                   forFilename: (NSString*) filename {
    NSTextStorage* res = [[NSTextStorage alloc] initWithAttributedString: string];

    [IFSyntaxManager registerTextStorage: res
                                filename: [filename lastPathComponent]
                            intelligence: [IFProjectTypes intelligenceForFilename: filename]
                             undoManager: [self undoManager]];
    return res;
}

+(NSStringEncoding) alternateStringEncodingFor:(NSStringEncoding) encoding {
    if( encoding == NSUTF8StringEncoding ) {
        return NSISOLatin1StringEncoding;
    }
    return NSUTF8StringEncoding;
}

- (NSTextStorage*) storageWithData: (NSData*) fileContents
                       forFilename: (NSString*) filename {
    NSString* ext = [[filename pathExtension] lowercaseString];
    BOOL loadAsRtf = [ext isEqualToString: @"rtf"] ||
    [ext isEqualToString: @"rtfd"];

    if (loadAsRtf) {
        return [self storageWithAttributedString: [[NSAttributedString alloc] initWithRTF: fileContents
                                                                       documentAttributes: nil]
                                     forFilename: filename];
    } else {
        NSStringEncoding encoding = [IFProjectTypes encodingForFilename: filename];

        // First, try loading with the default encoding
        NSString* fileString = [[NSString alloc] initWithData: fileContents
                                                     encoding: encoding];
        if (fileString == nil) {
            // Try to load with an alternative encoding...
            NSStringEncoding newEncoding = [[self class] alternateStringEncodingFor: encoding];

            NSLog(@"Warning: file '%@' cannot be interpreted as string encoding %d: trying %d",
                  filename, (int) encoding, (int) newEncoding);

            fileString = [[NSString alloc] initWithData: fileContents
                                               encoding: newEncoding];
            if (fileString == nil) {
                // We can't interpret this file in any way - report the failure.
                NSLog(@"Warning: no text available for file '%@'", filename);
                fileString = @"";
            }
        }
        
        return [self storageWithString: fileString
                           forFilename: filename];
    }
}


// == intest ==
-(NSString*) testSourcePathName {
    return self.testSourceFileURL.path;
}

-(void) refreshTestCases {
    _testCases = @[];

    // Only relevant for Inform7 extension projects
    if( _projectFileType != IFFileTypeInform7ExtensionProject ) {
        return;
    }
    if( [self mainSourcePathName] == nil ) {
        return;
    }

    _testCases = [_inTest refreshExtensionCatalogue: [self mainSourcePathName]];
}

-(void) extractSourceTaskForExtensionTestCase: (NSString*) testCase {
    // Only relevant for Inform7 extension projects
    if( _projectFileType != IFFileTypeInform7ExtensionProject ) {
        return;
    }
    if( testCase == nil ) {
        return;
    }

    [_inTest extractSourceTaskForExtensionFile: self.mainSourcePathName
                                   forTestCase: testCase
                            outputToSourceFile: self.testSourcePathName];
}

-(NSArray*) testCommandsForExtensionTestCase: (NSString*) testCase {
    NSString* commandString = [_inTest testCommandsForExtension: self.mainSourcePathName
                                                       testCase: testCase];
    commandString = [commandString stringByRemovingTrailingWhitespace];
    return [commandString componentsSeparatedByString:@"\n"];
}

-(IFSkeinItem*) nodeToReport {
    if( self.currentSkein != nil ) {
        return [self.currentSkein nodeToReport];
    }
    return nil;
}

-(NSString*) reportStateForSkein {
    if( self.currentSkein != nil ) {
        return [self.currentSkein reportStateForSkein];
    }
    return @"";
}

- (BOOL) generateReportForTestCase: (NSString*) testCase
                         errorCode: (NSString*) errorCode
                          skeinURL: (NSURL*) skeinURL
                       skeinNodeId: (unsigned long) skeinNodeId
                        skeinNodes: (int) skeinNodes
                         outputURL: (NSURL*) outputURL {
    int exitCode = [_inTest generateReportForExtension: self.mainSourcePathName
                                              testCase: testCase
                                             errorCode: errorCode
                                           problemsURL: [self normalProblemsURL]
                                              skeinURL: skeinURL
                                           skeinNodeId: skeinNodeId
                                            skeinNodes: skeinNodes
                                             outputURL: outputURL];
    if( exitCode == 0 ) {
        return YES;
    }

    NSLog(@"Intest report returned exit code %d\n", exitCode);
    return NO;
}

// Outputs an HTML report that combinines the individual reports
-(BOOL) generateCombinedReportForBaseInputURL: (NSURL*) baseInputURL
                                     numTests: (int) numTests
                                    outputURL: (NSURL*) outputURL {
    int exitCode = [_inTest generateCombinedReportForExtension: self.mainSourcePathName
                                                  baseInputURL: baseInputURL
                                                      numTests: numTests
                                                     outputURL: outputURL];
    if( exitCode == 0 ) {
        return YES;
    }

    NSLog(@"Intest combined report returned exit code %d\n", exitCode);
    return NO;
}

-(void) setSkeinTestCaseTitles {
    if( _skeins.count > 0 ) {
        int index = 0;
        for( IFSkein* skein in _skeins ) {
            if( _testCases.count > index ) {
                skein.rootItem.command = _testCases[index][@"testTitle"];
            }
            index++;
        }
    }
}

-(void) selectSkein: (int) index {
    if( index < 0 ) {
        _currentSkein = nil;
        NSDictionary* userDictionary = @{};
        [[NSNotificationCenter defaultCenter] postNotificationName: IFSkeinReplacedNotification
                                                            object: self
                                                          userInfo: userDictionary ];
        return;
    }

    // Make sure we have enough skeins
    while( _skeins.count <= index ) {
        [_skeins addObject: [[IFSkein alloc] initWithProject: self]];
    }

    // Has skein changed?
    if( _currentSkein != _skeins[index] ) {
        // Clear skein undos when setting skein
        if( _currentSkein ) [self.undoManager removeAllActionsWithTarget: _currentSkein];

        // Select the appropriate skein
        _currentSkein = _skeins[index];

        // Set the titles of each skein to the titles of each test case
        [self setSkeinTestCaseTitles];

        // Let the skein views update based on the new skein
        NSDictionary* userDictionary = @{};
        [[NSNotificationCenter defaultCenter] postNotificationName: IFSkeinReplacedNotification
                                                            object: self
                                                          userInfo: userDictionary ];
    }

    // Make sure the skein updates
    [self->_currentSkein postSkeinChangedWithAnimate: NO
                                   keepActiveVisible: NO];
}

-(void) loadSkeinsFileType:(IFFileType) fileType {
    BOOL isExtensionProject = (fileType == IFFileTypeInform7ExtensionProject);

    // Clear undo stack
    if( _currentSkein ) [[self undoManager] removeAllActionsWithTarget: _currentSkein];

    // Disable undo
    [[self undoManager] disableUndoRegistration];

    // Load skeins
    [projectFile loadIntoSkeins: _skeins
                        project: self
             isExtensionProject: isExtensionProject];

    // Enable undo
    [[self undoManager] enableUndoRegistration];

    // Select the first skein
    if( isExtensionProject ) {
        [self selectSkein: -1];
    }
    else {
        [self selectSkein: 0];
    }
}

// == reading/writing ==

-(BOOL) readProject: (NSFileWrapper*) fileWrapper
           fileType: (IFFileType) fileType
              error: (NSError *__autoreleasing*) outError {

    // Check we have a directory... Inform projects are bundle directories.
    if (!fileWrapper.isDirectory) {
        if( outError ) {
            *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                            code: NSFileReadUnknownError
                                        userInfo: nil];
        }
        return NO;
    }

    // Remove old project data
    [self unregisterProjectTextStorage];

    // Create an object to represent the bundle files
    projectFile = [[IFProjectFile alloc] initWithFileWrapper: fileWrapper];

    // Refresh the settings
    settings = [projectFile settings];
    _projectFileType = fileType;

    // Create materials folder, if necessary
    [self createMaterials];

    // Turn the source directory into NSTextStorages
    NSFileWrapper* sourceDir = [projectFile sourceDirectory];

    if (sourceDir == nil) {
        projectFile = nil;

        if( outError ) {
            *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                            code: NSFileReadUnknownError
                                        userInfo: nil];
        }
        return NO;
    }

    sourceFiles = [[NSMutableDictionary alloc] init];
    NSDictionary* source = [sourceDir fileWrappers];

    // Load all the source files
    for( NSString* key in source ) {
        if (![source[key] isRegularFile]) {
            continue;
        }

        NSData* regularFileContents = [source[key] regularFileContents];
        
        NSTextStorage* text = [self storageWithData: regularFileContents
                                        forFilename: key];

        sourceFiles[key] = text;

        NSString* pathExtension = [key pathExtension];
        if( fileType == IFFileTypeInform7ExtensionProject )
        {
            if ([pathExtension isEqualTo: @"i7x"]) {
                mainSource = [key copy];
            }
        }
        else
        {
            if ([pathExtension isEqualTo: @"inf"] ||
                [pathExtension isEqualTo: @"ni"] ||
                [pathExtension isEqualTo: @"i7"]) {
                mainSource = [key copy];
            }
        }
    }

    // Re-create the settings as required
    if (settings == nil) {
        settings = [[IFCompilerSettings alloc] init];
        
        if ([[mainSource pathExtension] isEqualTo: @"ni"] ||
            [[mainSource pathExtension] isEqualTo: @"i7"] ||
            [[mainSource pathExtension] isEqualTo: @"i7x"]) {
            [settings setLibraryToUse: @"Natural"];
            [settings setUsingNaturalInform: YES];
        }
    }

    singleFile = NO;

    // Load the notes (if present)
    notes = [projectFile loadNotes];

    // Work out which test cases we have
    [self refreshTestCases];

    // Load the skein files (if present)
    [self loadSkeinsFileType: fileType];

    // Load the watchpoints file (if present)
    watchExpressions = [projectFile loadWatchpoints];
    if (watchExpressions == nil ) {
        watchExpressions = [[NSMutableArray alloc] init];
    }

    // Load the breakpoints file (if present)
    breakpoints = [projectFile loadBreakpoints];
    if( breakpoints == nil ) {
		breakpoints = [[NSMutableArray alloc] init];
    }
    
    // Load UUID, if present
    uuid = [projectFile loadUUID];

    // Load the index file (if present)
    [self reloadIndexFile];

    [self breakpointsHaveChanged];
    return YES;
}

-(BOOL) readSourceFile: (NSFileWrapper*) fileWrapper
                 error: (NSError*__autoreleasing*) outError {
    // No project file
    projectFile = nil;
    
    [self unregisterProjectTextStorage];
    sourceFiles = nil;
    
    // Default settings
    settings = [[IFCompilerSettings alloc] init];
    
    NSString* filename = [fileWrapper filename];

    if( [IFProjectTypes informVersionForFilename: filename] ) {
		[settings setLibraryToUse: @"Natural"];
		[settings setUsingNaturalInform: YES];
    }

    // Load the single file
    NSData* data = [fileWrapper regularFileContents];

    NSString* theFile = [[NSString alloc] initWithData: data
                                              encoding: [IFProjectTypes encodingForFilename:filename]];

    NSTextStorage* text = [[NSTextStorage alloc] initWithString: theFile];

    [IFSyntaxManager registerTextStorage: text
                                    name: filename
                                    type: [IFProjectTypes highlighterTypeForFilename: filename]
                            intelligence: [IFProjectTypes intelligenceForFilename: filename]
                             undoManager: [self undoManager]];

    sourceFiles = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                   text,
                   [filename lastPathComponent], nil];

    mainSource = [[filename lastPathComponent] copy];

    singleFile = YES;
    return YES;
}

-(BOOL) readExtension: (NSFileWrapper*) fileWrapper
                error: (NSError*__autoreleasing*) outError {
    // Check we have a directory... Inform extension projects are directories.
    if (![fileWrapper isDirectory]) {
        if( outError ) {
            *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                            code: NSFileReadUnknownError
                                        userInfo: nil];
        }
        return NO;
    }

    // Opening a plain ole extension
    editingExtension = YES;
    singleFile = NO;

    projectFile = [[IFProjectFile alloc] initWithFileWrapper: fileWrapper];

    // Turn the source directory into NSTextStorages
    [self unregisterProjectTextStorage];
    mainSource = nil;

    sourceFiles = [[NSMutableDictionary alloc] init];
    NSDictionary* source = [fileWrapper fileWrappers];

    // Load all the source files
    for( NSString* key in source ) {
        NSTextStorage* text;

        if ([key characterAtIndex: 0] == '.') {
            continue;
        }
        if (![source[key] isRegularFile]) {
            continue;
        }

        NSData* regularFileContents = [source[key] regularFileContents];
        text = [self storageWithData: regularFileContents
                         forFilename: key];

        sourceFiles[key] = text;

        if ([[key pathExtension] isEqualTo: @"inf"] ||
            [[key pathExtension] isEqualTo: @"ni"] ||
            [[key pathExtension] isEqualTo: @"i7"] ||
            [[key pathExtension] isEqualTo: @""]) {
            mainSource = [key copy];
        }
    }

    // Create an 'Untitled' file if there's no mainSource
    if (!mainSource) {
        mainSource = @"Untitled";
        sourceFiles[mainSource] = [self storageWithString: @""
                                            forFilename: @"Untitled"];
    }
    return YES;
}

- (BOOL)readFromFileWrapper: (NSFileWrapper *) fileWrapper
                     ofType: (NSString *) typeName
                      error: (NSError *__autoreleasing*) outError {
    [self setDocumentFileWrapper: fileWrapper];

    IFFileType fileType = [IFProjectTypes fileTypeFromString: typeName];
    switch( fileType ) {
        // Inform project file
        case IFFileTypeInform7Project:
        case IFFileTypeInform7ExtensionProject: {
            return [self readProject: fileWrapper
                            fileType: fileType
                               error: outError];
        }

        // Inform 6 source file
        case IFFileTypeInform6SourceFile: {
            return [self readSourceFile: fileWrapper
                                  error: outError];
        }

        // Inform 7 source file
        case IFFileTypeInform7SourceFile: {
            return [self readSourceFile: fileWrapper
                                  error: outError];
        }
        
        // Inform 6 Extension project
        case IFFileTypeInform6ExtensionProject: {
            return [self readExtension: fileWrapper
                                 error: outError];
        }

        // Unknown
        case IFFileTypeUnknown:
        default: {
            if( outError ) {
                *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                                code: NSFileReadUnknownError
                                            userInfo: nil];
            }
            return NO;
        }
    }
    
    return NO;
}

-(NSData*) dataForSourceFileWithKey: (NSString*) key {
    // Get data
    NSString* ext = [[key pathExtension] lowercaseString];

    if ([ext isEqualToString: @"rtf"] ||
        [ext isEqualToString: @"rtfd"]) {
        NSAttributedString* str = sourceFiles[key];
        return [str RTFFromRange: NSMakeRange(0, [str length]) documentAttributes: @{NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType}];
    } else {
        return [[sourceFiles[key] string] dataUsingEncoding: NSUTF8StringEncoding];
    }
}

-(BOOL) writeAllSourceFiles: (NSFileWrapper*) sourceFileWrapper
                      error: (NSError*__autoreleasing*) outError {
    // Output all the source files to the project file wrapper
    for( NSString* key in sourceFiles ) {
        NSData* data = [self dataForSourceFileWithKey: key];

        //NSLog(@"***** Writing source file %@ *****", key);

        // Add FileWrapper to list
        [sourceFileWrapper removeFileWrapper: [sourceFileWrapper fileWrappers][key]];
        [sourceFileWrapper addRegularFileWithContents: data preferredFilename: key];
    }
    return YES;
}

-(BOOL) writeBegin {
	// Clean out any files that we aren't using any more, if set in the preferences
	if ([[IFPreferences sharedPreferences] cleanProjectOnClose]) {
		[self cleanOutUnnecessaryFiles: NO];
	}

    return YES;
}


- (NSFileWrapper *) documentFileWrapper {
    if (_documentFileWrapper == nil) {
        _documentFileWrapper = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: @{}];
        if( uuid != nil )
        {
            NSData *textData = [uuid dataUsingEncoding: NSUTF8StringEncoding];
            [_documentFileWrapper addRegularFileWithContents:textData preferredFilename:@"uuid.txt"];
        }
    }

    return _documentFileWrapper;
}

- (void) setDocumentFileWrapper:(NSFileWrapper *) theDocumentFileWrapper {
    _documentFileWrapper = theDocumentFileWrapper;
}

-(NSFileWrapper *) writeExtensionProject: (NSError*__autoreleasing*) outError {
    [self writeBegin];

    // Create 'Source' directory to hold the extension files?
    NSFileWrapper* source = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: @{}];
    [source setPreferredFilename: @"Source"];
    [source setFilename: @"Source"];

    // Write out all source files
	if( ![self writeAllSourceFiles: source
                             error: outError] ) {
        return nil;
    }

    // Add to document for writing
    [[self documentFileWrapper] addFileWrapper: source];
    return [self documentFileWrapper];
}

-(NSFileWrapper *) writeProject: (NSError*__autoreleasing*) outError {
    [self writeBegin];

    // Create new 'project file', based on the document's file wrapper
    projectFile = [[IFProjectFile alloc] initWithFileWrapper: [self documentFileWrapper]];
    NSFileWrapper* source = [projectFile sourceDirectory];

	if( ![self writeAllSourceFiles: source
                             error: outError] ) {
        return nil;
    }

    // Replace the current source directory with the new source directory files
    [projectFile replaceSourceDirectoryWrapper: source];

	// Write the Notes file
    [projectFile writeNotes: [notes RTFFromRange: NSMakeRange(0, [notes length])
                              documentAttributes: @{NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType}]];

	// Write the Skein file
    [projectFile writeSkeins: _skeins isExtensionProject: [self isExtensionProject]];

	// Write the Watchpoints file
    [projectFile writeWatchpoints: watchExpressions];

	// Write the Breakpoints file
    [projectFile writeBreakpoints: breakpoints];

    // Setup the settings
    [projectFile setSettings: settings];

    [[self documentFileWrapper] addFileWrapper: source];

    return [self documentFileWrapper];
}

- (NSFileWrapper *)fileWrapperOfType: (NSString *)typeName
                               error: (NSError *__autoreleasing*)outError {
    switch( [IFProjectTypes fileTypeFromString: typeName] ) {
        // Inform project file
        case IFFileTypeInform7Project:
        case IFFileTypeInform7ExtensionProject: {
            return [self writeProject: outError];
        }

        // Inform 6 source file
        case IFFileTypeInform6SourceFile: {
            NSTextStorage* theFile = [self storageForFile: [self mainSourceFile]];
            if (theFile == nil) {
                NSLog(@"Bug: no file storage found");
                return nil;
            }
            
            NSData *textData = [[theFile string] dataUsingEncoding: NSISOLatin1StringEncoding];
            
            [[self documentFileWrapper] addRegularFileWithContents: textData
                                                 preferredFilename: [[self mainSourceFile] lastPathComponent]];
            return [self documentFileWrapper];
        }

        // Inform 7 source file
        case IFFileTypeInform7SourceFile: {
            NSAssert(false, @"Should never get to here");
            return nil;
        }
        
        // Inform 6 Extension project
        case IFFileTypeInform6ExtensionProject: {
            NSError* error;
            return [self writeExtensionProject: &error];
        }

        // Unknown
        case IFFileTypeUnknown:
        default: {
            NSAssert(false, @"Unknown typeName of %@", typeName);
            return nil;
        }
    }
}

- (BOOL) addFile: (NSString*) newFile {
    if (sourceFiles[newFile] != nil) return NO;
    if (singleFile) return NO;
	    
    sourceFiles[newFile] = [self storageWithString: @""
										forFilename: newFile];

    // Write out new file to disk
    NSData* data = [self dataForSourceFileWithKey: newFile];
    NSURL* destinationURL = [[self sourceDirectoryURL] URLByAppendingPathComponent: newFile];

    NSFileWrapper* newFileWrapper = [[NSFileWrapper alloc] initRegularFileWithContents: data];
    [newFileWrapper setPreferredFilename: newFile];
    [newFileWrapper setFilename: newFile];
    [newFileWrapper writeToURL: destinationURL
                       options: NSFileWrapperWritingWithNameUpdating
           originalContentsURL: nil
                         error: NULL];

	[[NSNotificationCenter defaultCenter] postNotificationName: IFProjectFilesChangedNotification
														object: self];
    return YES;
}

- (BOOL) removeFile: (NSString*) oldFile {
	if (sourceFiles[oldFile] == nil) return YES; // Deleting a non-existant file always succeeds
	if (singleFile) return NO;
	
    [IFSyntaxManager unregisterTextStorage: sourceFiles[oldFile]];
	[sourceFiles removeObjectForKey: oldFile];

	[[NSNotificationCenter defaultCenter] postNotificationName: IFProjectFilesChangedNotification
														object: self];
	return YES;
}

- (BOOL) renameFile: (NSString*) oldFile 
		withNewName: (NSString*) newFile {
	if (sourceFiles[oldFile] == nil) return NO;
	if (sourceFiles[newFile] != nil) return NO;
	if (singleFile) return NO;
	
	NSTextStorage* oldFileStorage = sourceFiles[oldFile];

	[sourceFiles removeObjectForKey: oldFile];
	sourceFiles[[newFile copy]] = oldFileStorage;
	
	[[NSNotificationCenter defaultCenter] postNotificationName: IFProjectSourceFileRenamedNotification
														object: self
													  userInfo: @{@"OldFilename": [oldFile copy],
														          @"NewFilename": [newFile copy]}];
	[[NSNotificationCenter defaultCenter] postNotificationName: IFProjectFilesChangedNotification
														object: self];
	return YES;
}

// == General housekeeping ==
- (void)windowControllerDidLoadNib:(NSWindowController *) aController {
    [super windowControllerDidLoadNib:aController];
}

- (void)makeWindowControllers {
    IFProjectController *aController = [[IFProjectController alloc] init];
    [self addWindowController:aController];
}

// == Document info ==
- (IFCompilerSettings*) settings {
    return settings;
}

- (IFCompiler*) compiler {
    return compiler;
}

- (BOOL) singleFile {
    return singleFile;
}

- (NSTextStorage*) storageForFile: (NSString*) sourceFile {
	NSTextStorage*  storage;
	NSString*       originalSourceFile  = sourceFile;
	NSString*       sourceDir           = [self directoryURLToFindSourceFiles].path;

	if (projectFile == nil && [sourceFile.lastPathComponent isEqualToString: self.fileURL.lastPathComponent]) {
		if (![sourceFile isAbsolutePath]) {
			// Special case: when we're editing an individual file, then we always use that filename if possible
			sourceFile = self.fileURL.path;
		}
	}

	// Refuse to return storage for files outside the project directory
	if (sourceDir && [sourceFile isAbsolutePath]) {
		if (![[sourceFile stringByStandardizingPath] hasPrefix: sourceDir]) {
			return nil;
		}
	}

	if (![sourceFile isAbsolutePath]) {
		// Force absolute path
		sourceFile = [sourceDir stringByAppendingPathComponent: sourceFile];
        sourceFile = [sourceFile stringByStandardizingPath];

		if (![[NSFileManager defaultManager] fileExistsAtPath: sourceFile]) {
			// project/Source/whatever doesn't exist: try project/whatever
			sourceFile = [self.fileURL.path stringByAppendingPathComponent: originalSourceFile];
            sourceFile = [sourceFile stringByStandardizingPath];

			if (![[NSFileManager defaultManager] fileExistsAtPath: sourceFile]) {
				// If neither exists, use project/Source/whatever by default
				sourceFile = [sourceDir stringByAppendingPathComponent: sourceFile];
                sourceFile = [sourceFile stringByStandardizingPath];
			}
		}
	}

	if ([sourceFile isAbsolutePath]) {
		// Absolute path
		if ([[[sourceFile stringByDeletingLastPathComponent] stringByStandardizingPath] isEqualToString: sourceDir]) {
			return sourceFiles[[sourceFile lastPathComponent]];
		}
		
		if (![[NSFileManager defaultManager] fileExistsAtPath: sourceFile]) {
			return nil;
		}
		
		// Read text
		NSString* textData = [[NSString alloc] initWithData: [NSData dataWithContentsOfFile: sourceFile]
                                                   encoding: NSUTF8StringEncoding];
		
		if (textData == nil) {
			// Sometimes a file cannot be interpreted using UTF-8: present something in this case
			textData = [[NSString alloc] initWithData: [NSData dataWithContentsOfFile: sourceFile]
                                             encoding: NSISOLatin1StringEncoding];
		}

		storage = [self storageWithString: textData
							  forFilename: sourceFile];
		return storage;
	}

    return sourceFiles[sourceFile];
}

- (IFProjectFile*) projectFile {
    return projectFile;
}

- (NSDictionary*) sourceFiles {
    return sourceFiles;
}

- (NSTextStorage*) notes {
	return notes;
}

#pragma mark - The index file

@synthesize indexFile;

- (void) reloadIndexFile {
	if (singleFile) return; // Nothing to do
    NSError *err;

	indexFile = [[IFIndexFile alloc] initWithContentsOfURL: self.indexHeadingsFileURL error: &err];
    if (!indexFile) {
        NSLog(@"IFIndexFile: found no data: %@", err);
    }
}

- (void) reloadIndexDirectory {
	// Nothing to do if this is a single file
	if (singleFile) return;
	
    // Get a new index wrapper
    NSFileWrapper*	indexWrapper	= nil;
    NSString*		indexPath		= self.indexDirectoryURL.path;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath: indexPath]) {
        indexWrapper = [[NSFileWrapper alloc] initWithURL: self.indexDirectoryURL
                                                  options: (NSFileWrapperReadingOptions)0
                                                    error: NULL];
        [indexWrapper setPreferredFilename: @"Index"];
    }

    // Replace the old index wrapper
    [projectFile replaceIndexDirectoryWrapper: indexWrapper];
}

- (void) reloadDirectory {
    // Nothing to do if this is a single file
    if (singleFile) return;

    // Get a new wrapper
    NSFileWrapper*	wrapper	= nil;

    if ([[NSFileManager defaultManager] fileExistsAtPath: self.fileURL.path]) {
        wrapper = [[NSFileWrapper alloc] initWithURL: self.fileURL
                                             options: NSFileWrapperReadingImmediate
                                               error: NULL];
    }

    // Replace the old build wrapper
    [projectFile replaceWrapper: wrapper];
}

- (void) reloadSourceDirectory {
    // Nothing to do if this is a single file
    if (singleFile) return;

    // Get a new wrapper
    NSFileWrapper*	wrapper	= nil;
    NSString*		path    = self.sourceDirectoryURL.path;

    if ([[NSFileManager defaultManager] fileExistsAtPath: path]) {
        wrapper = [[NSFileWrapper alloc] initWithURL: self.sourceDirectoryURL
                                             options: (NSFileWrapperReadingOptions)0
                                               error: NULL];
        [wrapper setPreferredFilename: @"Source"];
    }

    // Replace the old build wrapper
    [projectFile replaceSourceDirectoryWrapper: wrapper];
}

- (NSFileWrapper*) buildWrapper {
    return [projectFile buildWrapper];
}

- (void) DEBUGverifyWrapper {
    // Nothing to do if this is a single file
    if (singleFile) return;

    [projectFile DEBUGverifyWrapper];
}

- (BOOL) editingExtension {
	return editingExtension;
}

- (void) setInitialSelectionRange:(NSRange) range {
    initialSelectionRange = range;
}

- (NSRange) initialSelectionRange {
    return initialSelectionRange;
}

#pragma mark - Watch expressions

- (void) addWatchExpression: (NSString*) expression {
	[watchExpressions addObject: [expression copy]];
}

- (void) replaceWatchExpressionAtIndex: (NSInteger) index
						withExpression: (NSString*) expression {
	watchExpressions[index] = [expression copy];
}

- (void) removeWatchExpressionAtIndex: (NSInteger) index {
	[watchExpressions removeObjectAtIndex: index];
}

- (NSString*) watchExpressionAtIndex: (NSInteger) index {
	return watchExpressions[index];
}

- (NSInteger) watchExpressionCount {
	return [watchExpressions count];
}

// Breakpoints

- (void) breakpointsHaveChanged {
	[[NSNotificationCenter defaultCenter] postNotificationName: IFProjectBreakpointsChangedNotification
														object: self];
}

- (void) addBreakpointAtLine: (int) line
					  inFile: (NSString*) filename {
	[breakpoints addObject: @[@(line), [filename copy]]];
	
	[self breakpointsHaveChanged];
}

- (void) replaceBreakpointAtIndex: (NSInteger) index
			 withBreakpointAtLine: (int) line
						   inFile: (NSString*) filename {
	breakpoints[index] = @[@(line), [filename copy]];
	
	[self breakpointsHaveChanged];
}

- (int) lineForBreakpointAtIndex: (NSInteger) index {
	return [breakpoints[index][0] intValue];
}

- (NSString*) fileForBreakpointAtIndex: (NSInteger) index {
	return breakpoints[index][1];
}

- (NSInteger) breakpointCount {
	return [breakpoints count];
}

- (void) removeBreakpointAtIndex: (NSInteger) index {
	[breakpoints removeObjectAtIndex: index];
	
	[self breakpointsHaveChanged];
}

- (void) removeBreakpointAtLine: (NSInteger) line
						 inFile: (NSString*) file {
	NSArray* bp =  @[@(line), [file copy]];
	NSUInteger index = [breakpoints indexOfObject: bp];
	
	if (index == NSNotFound) {
        NSLog(@"Attempt to remove nonexistant breakpoint %@:%li", file, (long)line);
		return;
	}
	
	[self removeBreakpointAtIndex: index];
}

#pragma mark - Cleaning

- (void) cleanOutUnnecessaryFiles: (BOOL) alsoCleanIndex {
    [projectFile cleanOutUnnecessaryFiles: alsoCleanIndex];
}

- (BOOL)canAsynchronouslyWriteToURL:(NSURL *)url
                             ofType:(NSString *)typeName
                   forSaveOperation:(NSSaveOperationType)saveOperation {
    return NO;
}

-(BOOL) isExtensionProject {
    return [self projectFileType] == IFFileTypeInform7ExtensionProject;
}

-(BOOL) copyProjectExtensionSourceToMaterialsExtensions {
    // Only relevant for extension projects
    if( ![self isExtensionProject] ) {
        return NO;
    }

    if( self.sourceDirectoryURL != nil )
    {
        NSString* title = nil;
        NSString* author = nil;
        NSString* version = nil;

        NSURL* sourceExtensionFileURL = [self.sourceDirectoryURL URLByAppendingPathComponent: @"extension.i7x"];

        // Extract title and author from sourceExtensionFileURL
        IFExtensionsManager* mgr = [IFExtensionsManager sharedNaturalInformExtensionsManager];
        IFExtensionResult gotInfo = [mgr infoForNaturalInformExtension: sourceExtensionFileURL.path
                                                                author: &author
                                                                 title: &title
                                                               version: &version];
        if( gotInfo == IFExtensionSuccess )
        {
            NSURL* materialsURL  = [self materialsDirectoryURL];
            NSURL* extensionsURL = [materialsURL  URLByAppendingPathComponent: @"Extensions"];
            NSURL* authorURL     = [extensionsURL URLByAppendingPathComponent: author];
            NSURL* fileURL       = [authorURL     URLByAppendingPathComponent: title];
            fileURL              = [fileURL       URLByAppendingPathExtension: @"i7x"];

            // Read source data
            NSData* data = [NSData dataWithContentsOfURL: sourceExtensionFileURL];
            if( data != nil )
            {
                // Create intermediate directories
                [[NSFileManager defaultManager] createDirectoryAtURL: authorURL
                                          withIntermediateDirectories: YES
                                                           attributes: nil
                                                                error: NULL];
                // Write to destination path
                return [data writeToURL: fileURL
                                options: (NSDataWritingOptions)0
                                  error: NULL];
            }
        }
    }
    return NO;
}


// Extension project compilation problems need redirecting back to extension.i7x source, not story.ni
-(NSArray*) redirectLinksToExtensionSourceCode:(NSArray*) link {

    if( [link count] == 3 ) {
        if( [self projectFileType] == IFFileTypeInform7ExtensionProject ) {
            if( [link[0] isEqualToStringCaseInsensitive: @"story.ni"] ) {
                int extensionLineNumber = [_inTest adjustLine: [link[2] intValue] forTestCase: link[1]];
                return @[@"extension.i7x", @(extensionLineNumber)];
            }
        }
        // Remove the test case parameter
        return @[link[0], link[2]];
    }

    return link;
}

// Save iFiction
- (void) saveIFictionWithWindow:(NSWindow*) window {
    // Work out where the iFiction file should be
    NSURL* iFictionURL = [self metadataURL];

    // Prompt the user to save the iFiction file if it exists
    if ([[NSFileManager defaultManager] fileExistsAtPath: iFictionURL.path]) {
        // Setup a save panel
        NSSavePanel* panel = [NSSavePanel savePanel];

        [panel setAccessoryView: nil];
        [panel setAllowedFileTypes: @[@"iFiction"]];
        [panel setCanSelectHiddenExtension: YES];
        [panel setPrompt: [IFUtility localizedString: @"Save iFiction record"]];
        [panel setTreatsFilePackagesAsDirectories: NO];
        [panel setDirectoryURL:         [self.fileURL URLByDeletingLastPathComponent]];
        [panel setNameFieldStringValue: [self.fileURL.lastPathComponent stringByDeletingPathExtension]];

        // Show it
        [panel beginSheetModalForWindow:window completionHandler:^(NSInteger result)
         {
             // Copy the file to the specified path
             if (result == NSModalResponseOK) {
                 NSString* filepath = [[[panel URL] path] stringByResolvingSymlinksInPath];
                 NSError* error;
                 [[NSFileManager defaultManager] copyItemAtPath: [iFictionURL path]
                                                         toPath: filepath
                                                          error: &error];

                 // Hide the file extension if the user has requested it
                 NSMutableDictionary* attributes = [[[NSFileManager defaultManager] attributesOfItemAtPath:filepath
                                                                                                     error:&error] mutableCopy];
                 attributes[NSFileExtensionHidden] = @([panel isExtensionHidden]);
                 [[NSFileManager defaultManager] setAttributes: attributes
                                                  ofItemAtPath: filepath error:&error];
             }
         }];
    } else {
        // Oops, failed to generate an iFiction record
        [IFUtility runAlertWarningWindow: window
                                   title: @"The compiler failed to produce an iFiction record"
                                 message: @"The compiler failed to create an iFiction record; check the errors page to see why."];
    }
}

// This ignores the specific deprecation of saveToURL
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

-(void) saveDocumentWithoutUserInteraction {
    // Note: We don't call [self saveDocument: self]; because from 10.5 and upwards this performs
    // checks to see if the file has changed since last opened or saved, and shows a user dialog if so.
    // This is a problem for our application because the compiler output adds folders / files to the
    // saved bundle, making it look like it's changed.
    NSError* error = nil;

    if( self.fileURL != nil ) {
        // NOTE: The following 'saveToURL::::' function is supposedly deprecated in 10.6, but the
        // suggested replacement function did not appear until 10.7.
        [self saveToURL: self.fileURL
                 ofType: self.fileType
       forSaveOperation: NSSaveOperation
                  error: &error];
    }
}

#pragma clang diagnostic pop

- (void) openMaterials {
    // Work out where the materials folder is located
    NSString* materialsPath = [self materialsDirectoryURL].path;

    // Create the folder if necessary
    if (![self singleFile]) {

        // Create materials folder, in a sandbox friendly way, with an icon
        [self createMaterials];
    }

    // Open the folder if it exists
    BOOL isDir;
    if ([[NSFileManager defaultManager] fileExistsAtPath: materialsPath
                                             isDirectory: &isDir]) {
        if (!isDir) {
            // Odd; the materials folder is a file. We open the containing path so the user can see this and correct it if they like
            [[NSWorkspace sharedWorkspace] openFile: [materialsPath stringByDeletingLastPathComponent]];
        } else {
            [[NSWorkspace sharedWorkspace] openFile: materialsPath];
        }
    }
}

-(void) saveCompilerOutputWithWindow:(NSWindow*) window {
    // Setup a save panel
    NSSavePanel* panel = [NSSavePanel savePanel];

    tempInternalWindow = window;

    [panel setAccessoryView: nil];
    [panel setAllowedFileTypes: @[[[[self compiler] outputFile] pathExtension]]];
    [panel setCanSelectHiddenExtension: YES];
    [panel setPrompt: [IFUtility localizedString: @"Save"]];
    [panel setTreatsFilePackagesAsDirectories: NO];
    [panel setNameFieldStringValue: [self.fileURL.lastPathComponent stringByDeletingPathExtension]];

    // Show it
    [panel beginSheetModalForWindow: window
                  completionHandler: ^(NSInteger result) {
        if (result == NSModalResponseOK) {
            NSError* error;
            NSString* whereToSave = [[panel URL] path];

            // Remove existing file then copy
            [[NSFileManager defaultManager] removeItemAtPath: whereToSave
                                                       error: &error];
            if (![[NSFileManager defaultManager] copyItemAtPath: [[self compiler] outputFile]
                                                         toPath: whereToSave
                                                          error: &error]) {
                [panel close];

                // File failed to save
                // Report that a file failed to save
                NSAlert* alert = [[NSAlert alloc] init];
                NSString* contents = [NSString stringWithFormat: [IFUtility localizedString: @"An error was encountered while trying to save the file '%@'"],
                                                                [whereToSave lastPathComponent]];

                [alert addButtonWithTitle:  [IFUtility localizedString: @"Retry"]];
                [alert addButtonWithTitle:  [IFUtility localizedString: @"Cancel"]];
                [alert setMessageText:      [IFUtility localizedString: @"Unable to save file"]];
                [alert setInformativeText:  contents];
                [alert setAlertStyle:       NSAlertStyleWarning];

                [alert beginSheetModalForWindow: window
                              completionHandler:^(NSModalResponse returnCode) {
                    if (returnCode == NSAlertFirstButtonReturn) {
                        [[NSRunLoop currentRunLoop] performSelector: @selector(saveCompilerOutputWithWindow:)
                                                             target: self
                                                           argument: self->tempInternalWindow
                                                              order: 128
                                                              modes: @[NSDefaultRunLoopMode]]; // Try again
                    }
                    self->tempInternalWindow = nil;
                }];
                return;
            }
        }
    }];
    self->tempInternalWindow = nil;
}

- (BOOL) buildBlorbSetting {
    IFI7OutputSettings* outputSettings = (IFI7OutputSettings*)[self.settings settingForClass: [IFI7OutputSettings class]];
    return [outputSettings createBlorbForRelease];
}


- (IFCompiler*) prepareCompilerForRelease: (BOOL) release
                               forTesting: (BOOL) releaseForTesting
                              refreshOnly: (BOOL) onlyRefresh
                                 testCase: (NSString*) testCase {
    // Set up the compiler
    BOOL buildBlorb = release && ![self singleFile] && [self buildBlorbSetting];

    IFCompiler* theCompiler = [self compiler];
    [theCompiler setBuildForRelease: release
                         forTesting: releaseForTesting];
    [theCompiler setSettings: [self settings]];

    if (![self singleFile]) {
        // Create <projectname>.materials folder, in a sandbox friendly way
        [self createMaterials];

        // If necessary, copy the extension from an extension project to <projectname>.materials/Extensions/Author/Extension.i7x
        [self copyProjectExtensionSourceToMaterialsExtensions];

        [theCompiler setOutputFile: self.buildOutputFileURL.path];
        [theCompiler setInputFile: [self projectInputPathName]];
        [theCompiler setDirectory: self.buildDirectoryURL.path];
    } else {
        [theCompiler setInputFile: [self singleInputPathName]];
        [theCompiler setDirectory: [self singleBuildDirectoryPath]];
    }

    if (onlyRefresh) {
        [theCompiler addNaturalInformStageUsingTestCase: testCase];
        if (![theCompiler prepareForLaunchWithBlorbStage: NO testCase: testCase]) {
            return nil;
        }
    } else {
        if (![theCompiler prepareForLaunchWithBlorbStage: buildBlorb testCase: testCase]) {
            return nil;
        }
    }

    return theCompiler;
}


#pragma mark - Importing skein information

- (IFSkein*) skeinFromRecording: (NSString*) path {
    // Read the file
    NSData* fileData = [[NSData alloc] initWithContentsOfFile: path];
    NSString* fileString = [[NSString alloc] initWithData: fileData
                                                 encoding: NSUTF8StringEncoding];

    if (fileString == nil) return nil;

    // Pull out the lines from the file
    NSInteger lineStart = 0;
    NSInteger pos = 0;
    NSInteger len = [fileString length];

    // Maximum length of 500k characters
    if (len > 500000) return nil;

    NSMutableArray* lines = [NSMutableArray array];

    for (pos=0; pos<len; pos++) {
        // Get the next character
        unichar lineChar = [fileString characterAtIndex: pos];

        // Check for a newline
        if (lineChar == '\n' || lineChar == '\r') {
            // Maximum line length of 50 characters
            if (pos - lineStart > 50) return nil;

            // Maximum 10,000 moves
            if ([lines count] >= 10000) return nil;

            // Get the current line
            NSString* thisLine = [fileString substringWithRange: NSMakeRange(lineStart, pos-lineStart)];
            [lines addObject: thisLine];

            // Deal with <CR><LF> and <LF><CR> sequences
            if (pos+1 < len) {
                if (lineChar == '\r' && [fileString characterAtIndex: pos+1] == '\n') pos++;
                else if (lineChar == '\n' && [fileString characterAtIndex: pos+1] == '\r') pos++;
            }

            // Store the start of the next line
            lineStart = pos+1;
        }
    }

    // Must be at least one line in the file
    if ([lines count] < 1) return nil;

    // Build the new skein
    IFSkein* newSkein = [[IFSkein alloc] initWithProject: self];

    [newSkein setActiveItem: [newSkein rootItem]];

    for( NSString* line in lines ) {
        [newSkein inputCommand: line];
    }

    return newSkein;
}

- (void) importIntoSkeinWithWindow: (NSWindow*) window {
    // We can currently import .rec files, .txt files, zoomSave packages and .skein files
    // In the case of .rec/.txt files, they must be <300k, be valid UTF-8 and have less than 10000 lines
    // of a length no more than 50 characters each. (Anything else probably isn't a recording)

    // Set up an open panel
    NSOpenPanel* importPanel = [NSOpenPanel openPanel];

    [importPanel setAccessoryView: nil];
    [importPanel setCanChooseFiles: YES];
    [importPanel setCanChooseDirectories: NO];
    [importPanel setResolvesAliases: YES];
    [importPanel setAllowsMultipleSelection: NO];
    [importPanel setTitle: [IFUtility localizedString:@"Choose a recording, skein or Zoom save game file"]];
    [importPanel setAllowedFileTypes: @[@"rec", @"txt", @"zoomSave", @"skein"]];

    // Display the panel
    [importPanel beginSheetModalForWindow: window completionHandler:^(NSInteger result)
     {
         if (result == NSModalResponseOK) {
             NSString* path = [[importPanel URL] path];
             NSString* extn = [[path pathExtension] lowercaseString];

             IFSkein* loadedSkein = nil;
             NSString* loadError = nil;

             if ([extn isEqualToString: @"txt"] || [extn isEqualToString: @"rec"]) {
                 loadedSkein = [self skeinFromRecording: path];

                 loadError = [IFUtility localizedString: @"Recording Skein Load Failure" default: nil];
             } else if ([extn isEqualToString: @"skein"]) {
                 loadedSkein = [[IFSkein alloc] initWithProject: self];

                 BOOL parsed = [loadedSkein parseXmlData: [NSData dataWithContentsOfFile: path]];
                 if (!parsed) loadedSkein = nil;
             } else if ([extn isEqualToString: @"zoomsave"]) {
                 loadedSkein = [[IFSkein alloc] initWithProject: self];

                 BOOL parsed = [loadedSkein parseXmlData: [NSData dataWithContentsOfFile: [path stringByAppendingPathComponent: @"Skein.skein"]]];
                 if (!parsed) loadedSkein = nil;
             }

             if (loadedSkein != nil) {
                 // Merge the new skein into the current skein
                 while( [[[loadedSkein rootItem] children] count] > 0 ) {
                     IFSkeinItem* child = [[loadedSkein rootItem] children][0];
                     [child removeFromParent];

                     [[self->_currentSkein rootItem] addChild: child];
                 }

                 [self->_currentSkein postSkeinChangedWithAnimate: NO
                                                keepActiveVisible: NO];
             } else {
                 if (loadError == nil)
                     loadError = [IFUtility localizedString: @"Skein Load Failure" default: nil];

                 [importPanel close];
                 NSAlert *alert = [[NSAlert alloc] init];
                 alert.messageText = [IFUtility localizedString: @"Could not import skein"];
                 alert.informativeText = loadError;
                 [alert addButtonWithTitle:[IFUtility localizedString: @"Cancel"]];
                 [alert beginSheetModalForWindow: window completionHandler:^(NSModalResponse returnCode) {
                     // do nothing.
                 }];
             }
         }
     }];
}


- (void) exportExtension: (NSWindow*) window {
    if( [self isExtensionProject] ) {
        // Save the project, without user interaction.
        [self saveDocument: self];

        // Set up an open panel
        NSSavePanel* panel = [NSSavePanel savePanel];

        [panel setAccessoryView: nil];
        [panel setAllowedFileTypes: @[@"i7x"]];
        [panel setCanSelectHiddenExtension: YES];
        [panel setPrompt: [IFUtility localizedString: @"Export Extension (.i7x)"]];
        [panel setTreatsFilePackagesAsDirectories: NO];
        [panel setDirectoryURL:         [self.fileURL URLByDeletingLastPathComponent]];
        [panel setNameFieldStringValue: [self.fileURL.lastPathComponent stringByDeletingPathExtension]];

        // Show it
        [panel beginSheetModalForWindow:window completionHandler:^(NSInteger result)
         {
             // Copy the file to the specified path
             if (result == NSModalResponseOK) {
                 NSString* filepath = [[[panel URL] path] stringByResolvingSymlinksInPath];
                 NSError* error;

                 NSURL* sourceExtensionFileURL = [self.sourceDirectoryURL URLByAppendingPathComponent: @"extension.i7x"];

                 [[NSFileManager defaultManager] copyItemAtPath: [sourceExtensionFileURL path]
                                                         toPath: filepath
                                                          error: &error];

                 // Hide the file extension if the user has requested it
                 NSMutableDictionary* attributes = [[[NSFileManager defaultManager] attributesOfItemAtPath:filepath
                                                                                                     error:&error] mutableCopy];
                 attributes[NSFileExtensionHidden] = @([panel isExtensionHidden]);
                 [[NSFileManager defaultManager] setAttributes: attributes
                                                  ofItemAtPath: filepath error:&error];
             }
         }];
    }
}

@end
