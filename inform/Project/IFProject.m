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
#import "IFNaturalIntel.h"
#import "IFProjectMaterialsPresenter.h"

@implementation IFProject

- (NSFileWrapper *) documentFileWrapper {
    if (documentFileWrapper == nil) {
        documentFileWrapper = [[NSFileWrapper alloc] initDirectoryWithFileWrappers:nil];
        if( uuid != nil )
        {
            NSData *textData = [uuid dataUsingEncoding: NSUTF8StringEncoding];
            [documentFileWrapper addRegularFileWithContents:textData preferredFilename:@"uuid.txt"];
        }
    }

    return documentFileWrapper;
}

- (void) setDocumentFileWrapper: (NSFileWrapper *) aDocumentFileWrapper {
    [documentFileWrapper release];
    documentFileWrapper = [aDocumentFileWrapper retain];
}

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
	return [res autorelease];
}

- (NSTextStorage*) storageWithAttributedString: (NSAttributedString*) string
                                   forFilename: (NSString*) filename {
	NSTextStorage* res = [[NSTextStorage alloc] initWithAttributedString: string];
	
	[IFSyntaxManager registerTextStorage: res
                                filename: [filename lastPathComponent]
                            intelligence: [IFProjectTypes intelligenceForFilename: filename]
                             undoManager: [self undoManager]];
	return [res autorelease];
}

- (NSTextStorage*) storageWithData: (NSData*) fileContents
                       forFilename: (NSString*) filename {
    NSString* ext = [[filename pathExtension] lowercaseString];
	BOOL loadAsRtf = [ext isEqualToString: @"rtf"] ||
                     [ext isEqualToString: @"rtfd"];

	if (loadAsRtf) {
		return [self storageWithAttributedString: [[[NSAttributedString alloc] initWithRTF: fileContents
																		documentAttributes: nil] autorelease]
									 forFilename: filename];
	} else {
        NSStringEncoding encoding = [IFProjectTypes encodingForFilename: filename];
        
		// First, try loading as a UTF-8 string (this is the default behaviour)
		NSString* fileString = [[NSString alloc] initWithData: fileContents
													 encoding: encoding];
		
		if (fileString == nil) {
            NSStringEncoding newEncoding;

            // Try to load in an alternative string encoding...
            if( encoding == NSUTF8StringEncoding ) {
                newEncoding = NSISOLatin1StringEncoding;
            } else {
                newEncoding = NSUTF8StringEncoding;
            }
			NSLog(@"Warning: file '%@' cannot be interpreted as string encoding %d: trying %d",
                  filename, (int) encoding, (int) newEncoding);

			fileString = [[NSString alloc] initWithData: fileContents
											   encoding: newEncoding];
		}
		if (fileString == nil) {
			// We can't interpret this file in any way - report the failure. An exception will be thrown later
			NSLog(@"Warning: no text available for file '%@'", filename);
		}
		return [self storageWithString: [fileString autorelease]
						   forFilename: filename];
	}
}

// == Initialisation ==

- (id) init {
    self = [super init];

    if (self) {
        settings = [[IFCompilerSettings alloc] init];
        projectFile = nil;
        sourceFiles = nil;
        mainSource  = nil;
        singleFile  = YES;
        initialSelectionRange = NSMakeRange(0, 0);
        materialsAccess = nil;

		skein = [[ZoomSkein alloc] init];

        compiler = [[IFCompiler alloc] init];
		
		notes = [[NSTextStorage alloc] initWithString: @""];
		
		watchExpressions = [[NSMutableArray alloc] init];
		breakpoints = [[NSMutableArray alloc] init];
        uuid = nil;
    }

    return self;
}

-(void) unregisterProjectTextStorage {
    for( NSString* key in sourceFiles) {
        [IFSyntaxManager unregisterTextStorage:[sourceFiles objectForKey:key]];
    }
}

- (void) dealloc {
    [documentFileWrapper release];
    [sourceFiles release];
    [projectFile release];
    [mainSource  release];
	[notes release];
	[indexFile release];
    [skein release];
    [materialsAccess release];
    
	[settings release];
    [compiler release];
	
	[watchExpressions release];
	[breakpoints release];
    [uuid release];
	
    [mainThreadPort release];
	[subThreadPort release];
	[subThreadConnection release];

    [super dealloc];
}

// == close ==
-(void) close {
	// Clean out any files that we aren't using any more, if set in the preferences
	if ([[IFPreferences sharedPreferences] cleanProjectOnClose]) {
		[self cleanOutUnnecessaryFiles: NO];
	}
    [self unregisterProjectTextStorage];

    [materialsAccess release];
    materialsAccess = nil;

    [super close];
}

- (void) createMaterials {
    [materialsAccess release];
    materialsAccess = [[IFProjectMaterialsPresenter alloc] initWithURL: [self fileURL]];
}

// == reading/writing ==

-(BOOL) readProject: (NSFileWrapper*) fileWrapper
              error: (NSError **) outError {

    // Check we have a directory... Inform projects are bundle directories.
    if (![fileWrapper isDirectory]) {
        if( outError ) {
            *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                            code: NSFileReadUnknownError
                                        userInfo: nil];
        }
        return NO;
    }

    // Remove old project data
    [self unregisterProjectTextStorage];
    [projectFile release];
    [sourceFiles release];
    [mainSource  release];

    // Create an object to represent the bundle files
    projectFile = [[IFProjectFile alloc] initWithFileWrapper: fileWrapper];

    // Refresh the settings
    [settings release];
    settings = [[projectFile settings] retain];

    // Turn the source directory into NSTextStorages
    NSFileWrapper* sourceDir = [projectFile sourceDirectory];

    if (sourceDir == nil) {
        [projectFile release];
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
        if (![[source objectForKey: key] isRegularFile]) {
            continue;
        }
        
        NSData* regularFileContents = [[source objectForKey: key] regularFileContents];
        
        NSTextStorage* text = [self storageWithData: regularFileContents
                                        forFilename: key];

        [sourceFiles setObject: text
                        forKey: key];
        
        if ([[key pathExtension] isEqualTo: @"inf"] ||
            [[key pathExtension] isEqualTo: @"ni"] ||
            [[key pathExtension] isEqualTo: @"i7"]) {
            mainSource = [key copy];
        }
    }

    // Re-create the settings as required
    if (settings == nil) {
        settings = [[IFCompilerSettings alloc] init];
        
        if ([[mainSource pathExtension] isEqualTo: @"ni"] ||
            [[mainSource pathExtension] isEqualTo: @"i7"]) {
            [settings setLibraryToUse: @"Natural"];
            [settings setUsingNaturalInform: YES];
        }
    }

    singleFile = NO;

    // Load the notes (if present)
    [notes release];
    notes = [[projectFile loadNotes] retain];

    // Load the skein file (if present)
    [projectFile loadIntoSkein: skein];

    // Load the watchpoints file (if present)
    [watchExpressions release];
    watchExpressions = [[projectFile loadWatchpoints] retain];
    if (watchExpressions == nil ) {
        watchExpressions = [[NSMutableArray alloc] init];
    }

    // Load the breakpoints file (if present)
    [breakpoints release];
    breakpoints = [[projectFile loadBreakpoints] retain];
    if( breakpoints == nil ) {
		breakpoints = [[NSMutableArray alloc] init];
    }
    
    // Load UUID, if present
    uuid = [[projectFile loadUUID] retain];

    // Load the index file (if present)
    [self reloadIndexFile];

    [self breakpointsHaveChanged];
    return YES;
}

-(BOOL) readSourceFile: (NSFileWrapper*) fileWrapper
                 error: (NSError**) outError {
    // No project file
    [projectFile release];
    projectFile = nil;
    
    [self unregisterProjectTextStorage];
    [sourceFiles release];
    sourceFiles = nil;
    
    // Default settings
    [settings release];
    settings = [[IFCompilerSettings alloc] init];
    
    NSString* filename = [fileWrapper filename];

    if( [IFProjectTypes informVersionForFilename: filename] ) {
		[settings setLibraryToUse: @"Natural"];
		[settings setUsingNaturalInform: YES];
    }

    // Load the single file
    NSData* data = [fileWrapper regularFileContents];

    NSString* theFile = [[[NSString alloc] initWithData: data
                                               encoding: [IFProjectTypes encodingForFilename:filename]] autorelease];

    NSTextStorage* text = [[NSTextStorage alloc] initWithString: theFile];
    
    [IFSyntaxManager registerTextStorage: text
                                    name: filename
                                    type: [IFProjectTypes highlighterTypeForFilename: filename]
                            intelligence: [IFProjectTypes intelligenceForFilename: filename]
                             undoManager: [self undoManager]];

    sourceFiles = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                   [text autorelease],
                   [filename lastPathComponent], nil];
    
    [mainSource release];
    mainSource = [[filename lastPathComponent] copy];

    singleFile = YES;
    return YES;
}

-(BOOL) readExtension: (NSFileWrapper*) fileWrapper
                error: (NSError**) outError {
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
    [mainSource release];
    mainSource = nil;

    [sourceFiles release];
    sourceFiles = [[NSMutableDictionary alloc] init];
    NSDictionary* source = [fileWrapper fileWrappers];
    
    // Load all the source files
    for( NSString* key in source ) {
        NSTextStorage* text;
        
        if ([key characterAtIndex: 0] == '.') {
            continue;
        }
        if (![[source objectForKey: key] isRegularFile]) {
            continue;
        }
        
        NSData* regularFileContents = [[source objectForKey: key] regularFileContents];
        text = [self storageWithData: regularFileContents
                         forFilename: key];
        
        [sourceFiles setObject: text
                        forKey: key];

        if ([[key pathExtension] isEqualTo: @"inf"] ||
            [[key pathExtension] isEqualTo: @"ni"] ||
            [[key pathExtension] isEqualTo: @"i7"] ||
            [[key pathExtension] isEqualTo: @""]) {
            [mainSource release];
            mainSource = [key copy];
        }
    }

    // Create an 'Untitled' file if there's no mainSource
    if (!mainSource) {
        mainSource = [@"Untitled" retain];
        [sourceFiles setObject: [self storageWithString: @""
                                            forFilename: @"Untitled"]
                        forKey: mainSource];
    }
    return YES;
}

- (BOOL)readFromFileWrapper: (NSFileWrapper *) fileWrapper
                     ofType: (NSString *) typeName
                      error: (NSError **) outError {
    switch( [IFProjectTypes fileTypeFromString: typeName] ) {
        // Inform project file
        case IFFileTypeInform7Project: {
            return [self readProject: fileWrapper
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

- (BOOL)loadFileWrapperRepresentation:(NSFileWrapper *)wrapper
							   ofType:(NSString *)docType {
    NSLog(@"Trying to load doc type %@", docType);
    NSError* error;
    BOOL result = [self readFromFileWrapper: wrapper
                                     ofType: docType
                                      error: &error];
    NSLog(@"Load of doc type %@ = %d", docType, (int) result);
    return result;
}

-(NSData*) dataForSourceFileWithKey: (NSString*) key {
    // Get data
    NSString* ext = [[key pathExtension] lowercaseString];

    if ([ext isEqualToString: @"rtf"] ||
        [ext isEqualToString: @"rtfd"]) {
        NSAttributedString* str = [sourceFiles objectForKey: key];
        return [str RTFFromRange: NSMakeRange(0, [str length]) documentAttributes: nil];
    } else {
        return [[[sourceFiles objectForKey: key] string] dataUsingEncoding: NSUTF8StringEncoding];
    }
}

-(BOOL) writeAllSourceFiles: (NSFileWrapper*) sourceFileWrapper
                      error: (NSError**) outError {
    // Output all the source files to the project file wrapper
    for( NSString* key in sourceFiles ) {
        NSData* data = [self dataForSourceFileWithKey: key];

        //NSLog(@"***** Writing source file %@ *****", key);

        // Add FileWrapper to list
        [sourceFileWrapper removeFileWrapper: [[sourceFileWrapper fileWrappers] objectForKey: key]];
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


-(NSFileWrapper *) writeExtensionProject: (NSError**) outError {
    [self writeBegin];

    // Create 'Source' directory to hold the extension files?
    NSFileWrapper* source = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: nil];
    [source setPreferredFilename: @"Source"];
    [source setFilename: @"Source"];

    // Write out all source files
	if( ![self writeAllSourceFiles: source
                             error: outError] ) {
        [source release];
        return nil;
    }

    // Add to document for writing
    [[self documentFileWrapper] addFileWrapper: [source autorelease]];
    return [self documentFileWrapper];
}


-(NSFileWrapper *) writeProject: (NSError**) outError {
    [self writeBegin];

    // Create new 'project file', based on the document's file wrapper
    [projectFile release];
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
                              documentAttributes: nil]];

	// Write the Skein file
    [projectFile writeSkein: [skein xmlData]];

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
                               error: (NSError **)outError {
    switch( [IFProjectTypes fileTypeFromString: typeName] ) {
        // Inform project file
        case IFFileTypeInform7Project: {
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
    if ([sourceFiles objectForKey: newFile] != nil) return NO;
    if (singleFile) return NO;
	    
    [sourceFiles setObject: [self storageWithString: @""
										forFilename: newFile]
                    forKey: newFile];

    // Write out new file to disk
    NSData* data = [self dataForSourceFileWithKey: newFile];

    NSString* sourceDir = [[[[self fileURL] path] stringByAppendingPathComponent: @"Source"] stringByStandardizingPath];
    NSString* destinationFilepath = [sourceDir stringByAppendingPathComponent: newFile];
    
    NSFileWrapper* newFileWrapper = [[NSFileWrapper alloc] initRegularFileWithContents: data];
    [newFileWrapper setPreferredFilename: newFile];
    [newFileWrapper setFilename: newFile];
    [newFileWrapper writeToFile: destinationFilepath
                     atomically: NO
                updateFilenames: YES];
    [newFileWrapper release];

	[[NSNotificationCenter defaultCenter] postNotificationName: IFProjectFilesChangedNotification
														object: self];
    return YES;
}

- (BOOL) removeFile: (NSString*) oldFile {
	if ([sourceFiles objectForKey: oldFile] == nil) return YES; // Deleting a non-existant file always succeeds
	if (singleFile) return NO;
	
    [IFSyntaxManager unregisterTextStorage: [sourceFiles objectForKey:oldFile]];
	[sourceFiles removeObjectForKey: oldFile];

	[[NSNotificationCenter defaultCenter] postNotificationName: IFProjectSourceFileDeletedNotification
														object: self
													  userInfo: [NSDictionary dictionaryWithObjectsAndKeys: 
														  oldFile, @"OldFilename",
														  nil]];
	[[NSNotificationCenter defaultCenter] postNotificationName: IFProjectFilesChangedNotification
														object: self];
	return YES;
}

- (BOOL) renameFile: (NSString*) oldFile 
		withNewName: (NSString*) newFile {
	if ([sourceFiles objectForKey: oldFile] == nil) return NO;
	if ([sourceFiles objectForKey: newFile] != nil) return NO;
	if (singleFile) return NO;
	
	NSTextStorage* oldFileStorage = [sourceFiles objectForKey: oldFile];

	[sourceFiles removeObjectForKey: oldFile];
	[sourceFiles setObject: oldFileStorage
					forKey: [[newFile copy] autorelease]];
	
	[[NSNotificationCenter defaultCenter] postNotificationName: IFProjectSourceFileRenamedNotification
														object: self
													  userInfo: [NSDictionary dictionaryWithObjectsAndKeys: 
														  [[oldFile copy] autorelease], @"OldFilename",
														  [[newFile copy] autorelease], @"NewFilename",
														  nil]];
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
    [aController release];
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

- (NSString*) mainSourceFile {
    if (singleFile || editingExtension) return mainSource;
    
    NSFileWrapper* sourceDir = [projectFile sourceDirectory];
    NSDictionary* source = [sourceDir fileWrappers];

    [mainSource autorelease];
    mainSource = nil;

    for( NSString* key in source ) {
        if ([[key pathExtension] isEqualTo: @"inf"] ||
            [[key pathExtension] isEqualTo: @"ni"] ||
            [[key pathExtension] isEqualTo: @"i7"]) {
            if (mainSource) [mainSource autorelease];
            mainSource = [key copy];
        }
    }

    return mainSource;
}

- (NSTextStorage*) storageForFile: (NSString*) sourceFile {
	NSTextStorage* storage;
	NSString* originalSourceFile = sourceFile;
	NSString* sourceDir = [[[[self fileURL] path] stringByAppendingPathComponent: @"Source"] stringByStandardizingPath];
	
	if (editingExtension) {
		// Special case: we're editing an extension, so source files are in the root directory
		sourceDir = [[[self fileURL] path] stringByStandardizingPath];
	}
	
	if (projectFile == nil && [[sourceFile lastPathComponent] isEqualToString: [[[self fileURL] path] lastPathComponent]]) {
		if (![sourceFile isAbsolutePath]) {
			// Special case: when we're editing an individual file, then we always use that filename if possible
			sourceFile = [[self fileURL] path];
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
		sourceFile = [[sourceDir stringByAppendingPathComponent: sourceFile] stringByStandardizingPath];
		
		if (![[NSFileManager defaultManager] fileExistsAtPath: sourceFile]) {
			// project/Source/whatever doesn't exist: try project/whatever
			sourceFile = [[[[self fileURL] path] stringByAppendingPathComponent: originalSourceFile] stringByStandardizingPath];
			
			if (![[NSFileManager defaultManager] fileExistsAtPath: sourceFile]) {
				// If neither exists, use project/Source/whatever by default
				sourceFile = [[sourceDir stringByAppendingPathComponent: sourceFile] stringByStandardizingPath];
			}
		}
	}
	
	if ([sourceFile isAbsolutePath]) {
		// Absolute path
		if ([[[sourceFile stringByDeletingLastPathComponent] stringByStandardizingPath] isEqualToString: sourceDir]) {
			return [sourceFiles objectForKey: [sourceFile lastPathComponent]];
		}
		
		if (![[NSFileManager defaultManager] fileExistsAtPath: sourceFile]) {
			return nil;
		}
		
		// Temporary text storage
		NSString* textData = [[[NSString alloc] initWithData: [NSData dataWithContentsOfFile: sourceFile]
                                                    encoding: NSUTF8StringEncoding] autorelease];
		
		if (textData == nil) {
			// Sometimes a file cannot be interpreted using UTF-8: present something in this case
			textData = [[[NSString alloc] initWithData: [NSData dataWithContentsOfFile: sourceFile]
                                              encoding: NSISOLatin1StringEncoding] autorelease];
		}
		
		storage = [self storageWithString: textData
							  forFilename: sourceFile];
		return storage;
	} else {
		// Not absolute path
	}
	
    return [sourceFiles objectForKey: sourceFile];
}

- (BOOL) fileIsTemporary: (NSString*) sourceFile {
	// If the filename is Source/Whatever, make it just Whatever
	if ([[sourceFile stringByDeletingLastPathComponent] isEqualToString: @"Source"]) {
		sourceFile = [sourceFile lastPathComponent];
	}
	
	// Work out the source directory
	NSString* sourceDir = [[[[self fileURL] path] stringByAppendingPathComponent: @"Source"] stringByStandardizingPath];
	
	if (editingExtension) {
		// Special case: we're editing an extension, so source files are in the root directory
		sourceDir = [[[self fileURL] path] stringByStandardizingPath];
	}
	
	if (projectFile == nil && [[sourceFile lastPathComponent] isEqualToString: [[[self fileURL] path] lastPathComponent]]) {
		if (![sourceFile isAbsolutePath]) {
			// Special case: when we're editing an individual file, then we always use that filename if possible
			sourceFile = [[self fileURL] path];
		}
	}
	
	sourceFile = [sourceFile stringByStandardizingPath];
	sourceDir = [sourceDir stringByStandardizingPath];	
	NSString* filename = [[[self fileURL] path] stringByStandardizingPath];
	
	if ([sourceFile isAbsolutePath]) {
		// Must begin with our filename/source
		if (projectFile == nil) {
			// Must be our filename
			if ([filename isEqualToString: sourceFile])
				return NO;
			else
				return YES;
		}
		
		if ([[sourceFile stringByDeletingLastPathComponent] isEqualToString: sourceDir]) {
			return NO;
		} else {
			return YES;
		}
	} else {
		// Must be in the list of project files
		if ([sourceFiles objectForKey: sourceFile] != nil) {
			return NO;
		} else {
			return YES;
		}
	}
	
	return YES;
}

- (IFProjectFile*) projectFile {
    return projectFile;
}

- (NSDictionary*) sourceFiles {
    return sourceFiles;
}

- (NSString*) pathForFile: (NSString*) file {
	if ([file isAbsolutePath]) return [file stringByStandardizingPath];
	
	if (!editingExtension)
		return [[[[[self fileURL] path] stringByAppendingPathComponent: @"Source"] stringByAppendingPathComponent: file] stringByStandardizingPath];
	else
		return [[[[self fileURL] path] stringByAppendingPathComponent: file] stringByStandardizingPath];
	
    /*
	if ([sourceFiles objectForKey: file] != nil) {
		return [[[[self fileURL] path] stringByAppendingPathComponent: @"Source"] stringByAppendingPathComponent: file];
	}
	
	// FIXME: search libraries
	
	return file;
    */
}

- (NSString*) materialsPath {
	// Work out the location of the materials folder
	NSString* projectPath	= [[self fileURL] path];
	NSString* projectName	= [[projectPath lastPathComponent] stringByDeletingPathExtension];
	NSString* materialsName	= [NSString stringWithFormat: @"%@.materials", projectName];
	NSString* materialsPath	= [[projectPath stringByDeletingLastPathComponent] stringByAppendingPathComponent: materialsName];

	return materialsPath;
}

- (NSTextStorage*) notes {
	return notes;
}

// = The index file =

- (IFIndexFile*) indexFile {
	return indexFile;
}

- (void) reloadIndexFile {
	if (singleFile) return; // Nothing to do
	
    [indexFile release];
	indexFile = [[IFIndexFile alloc] initWithContentsOfFile: [[[[self fileURL] path] stringByAppendingPathComponent: @"Index"] stringByAppendingPathComponent: @"Headings.xml"]];
}

- (void) reloadIndexDirectory {
	// Nothing to do if this is a single file
	if (singleFile) return;
	
    // Get a new index wrapper
    NSFileWrapper*	indexWrapper	= nil;
    NSString*		indexPath		= [[[self fileURL] path] stringByAppendingPathComponent: @"Index"];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath: indexPath]) {
        indexWrapper = [[[NSFileWrapper alloc] initWithPath: indexPath] autorelease];
        [indexWrapper setPreferredFilename: @"Index"];
    }

    // Replace the old index wrapper
    [projectFile replaceIndexDirectoryWrapper: indexWrapper];
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

// = The skein =

- (ZoomSkein*) skein {
	return skein;
}

// = Watch expressions =

- (void) addWatchExpression: (NSString*) expression {
	[watchExpressions addObject: [[expression copy] autorelease]];
}

- (void) replaceWatchExpressionAtIndex: (unsigned) index
						withExpression: (NSString*) expression {
	[watchExpressions replaceObjectAtIndex: index
								withObject: [[expression copy] autorelease]];
}

- (void) removeWatchExpressionAtIndex: (unsigned) index {
	[watchExpressions removeObjectAtIndex: index];
}

- (NSString*) watchExpressionAtIndex: (unsigned) index {
	return [watchExpressions objectAtIndex: index];
}

- (unsigned) watchExpressionCount {
	return [watchExpressions count];
}

// Breakpoints

- (void) breakpointsHaveChanged {
	[[NSNotificationCenter defaultCenter] postNotificationName: IFProjectBreakpointsChangedNotification
														object: self];
}

- (void) addBreakpointAtLine: (int) line
					  inFile: (NSString*) filename {
	[breakpoints addObject: [NSArray arrayWithObjects: [NSNumber numberWithInt: line], [[filename copy] autorelease], nil]];
	
	[self breakpointsHaveChanged];
}

- (void) replaceBreakpointAtIndex: (unsigned) index
			 withBreakpointAtLine: (int) line
						   inFile: (NSString*) filename {
	[breakpoints replaceObjectAtIndex: index
						   withObject: [NSArray arrayWithObjects: [NSNumber numberWithInt: line], [[filename copy] autorelease], nil]];
	
	[self breakpointsHaveChanged];
}

- (int) lineForBreakpointAtIndex: (unsigned) index {
	return [[[breakpoints objectAtIndex: index] objectAtIndex: 0] intValue];
}

- (NSString*) fileForBreakpointAtIndex: (unsigned) index {
	return [[breakpoints objectAtIndex: index] objectAtIndex: 1];
}

- (unsigned) breakpointCount {
	return [breakpoints count];
}

- (void) removeBreakpointAtIndex: (unsigned) index {
	[breakpoints removeObjectAtIndex: index];
	
	[self breakpointsHaveChanged];
}

- (void) removeBreakpointAtLine: (int) line
						 inFile: (NSString*) file {
	NSArray* bp =  [NSArray arrayWithObjects: [NSNumber numberWithInt: line], [[file copy] autorelease], nil];
	unsigned index = [breakpoints indexOfObject: bp];
	
	if (index == NSNotFound) {
		NSLog(@"Attempt to remove nonexistant breakpoint %@:%i", file, line);
		return;
	}
	
	[self removeBreakpointAtIndex: index];
}

// = Cleaning =

- (void) cleanOutUnnecessaryFiles: (BOOL) alsoCleanIndex {
    [projectFile cleanOutUnnecessaryFiles: alsoCleanIndex];
}

// = The syntax matcher =

- (void) rebuildSyntaxMatchers {
    /* We don't use this any more...

	// Post a notification so the UI can explain what's going on
	[[NSNotificationCenter defaultCenter] postNotificationName: IFProjectStartedBuildingSyntaxNotification
														object: self];

	// Start a thread to build the syntax matchers for this project
	[matcherLock lock];

	// Increase the build count so that only the results from the most recent thread gets through
	syntaxBuildCount++;

	// Build the thread information dictionary
	NSMutableDictionary* threadDictionary = [[[NSMutableDictionary alloc] init] autorelease];
	[threadDictionary setObject: [NSNumber numberWithInt: syntaxBuildCount]
						 forKey: @"RebuildNumber"];

	// Get the data for the files to copy
	NSMutableDictionary* xmlData = [[[NSMutableDictionary alloc] init] autorelease];
	
	if (projectFile != nil) {
		// Look in the syntax directory in the project directory
		NSString* xmlDir = [[[self fileURL] path] stringByAppendingPathComponent: @"Syntax"];

		// Refresh the syntax wrapper if necessary
		NSFileWrapper* syntaxWrapper = [projectFile syntaxDirectory];
		[syntaxWrapper updateFromPath: xmlDir];
		
		// Must exist and be a directory
		BOOL isDir;
		if (![[NSFileManager defaultManager] fileExistsAtPath: xmlDir
												  isDirectory: &isDir])
			isDir = NO;
		
		if (isDir) {
			NSDictionary* fileWrappers = [syntaxWrapper fileWrappers];
			NSEnumerator* fileEnum = [[fileWrappers allKeys] objectEnumerator];
			NSString* file;
			
			// Iterate through the files in the directory and read in all the .xml files
			while (file = [fileEnum nextObject]) {
				if ([[file pathExtension] isEqualToString: @"xml"]) {
					NSData* dataForFile = [[fileWrappers objectForKey: file] regularFileContents];
					
					if (dataForFile) {
						[xmlData setObject: dataForFile
									forKey: file];
					}
				}
			}
		}
	}
	
	[threadDictionary setObject: xmlData
						 forKey: @"XmlData"];
	
	// Start a thread to build the syntax matchers
	if (mainThreadPort)			[mainThreadPort release];
	if (subThreadPort)			[subThreadPort release];
	if (subThreadConnection)	[subThreadConnection release];
	
	mainThreadPort	= [[NSPort port] retain];
	subThreadPort	= [[NSPort port] retain];
	[[NSRunLoop currentRunLoop] addPort: mainThreadPort
								forMode: NSDefaultRunLoopMode];
	
	subThreadConnection = [[NSConnection alloc] initWithReceivePort: mainThreadPort
														   sendPort: subThreadPort];
	[subThreadConnection setRootObject: self];
	
	[self retain];
	[NSThread detachNewThreadSelector: @selector(runSyntaxRebuild:)
							 toTarget: self
						   withObject: threadDictionary];
	
	[matcherLock unlock];
    */
}

- (void) finishedRebuildingSyntax: (int) rebuildNumber {
	// Check the rebuild number
	[matcherLock lock];
	if (rebuildNumber != syntaxBuildCount) {
		// Do nothing if the last build to finish is not the build we're currently running
		[matcherLock unlock];
		return;
	}
	[matcherLock unlock];
	
	// Notify that the build has finished
	[[NSNotificationCenter defaultCenter] postNotificationName: IFProjectFinishedBuildingSyntaxNotification
														object: self];
}

- (void) runSyntaxRebuild: (NSDictionary*) rebuild {
    /* We don't use this any more...
	NSAutoreleasePool* mainPool = [[NSAutoreleasePool alloc] init];

	// Get the rebuild number
	int thisRebuild = [[rebuild objectForKey: @"RebuildNumber"] intValue];

	// Set up the connection to the main thread
	[[NSRunLoop currentRunLoop] addPort: subThreadPort
								forMode: NSDefaultRunLoopMode];
	NSConnection* mainThreadConnection = [[[NSConnection alloc] initWithReceivePort: subThreadPort
																		   sendPort: mainThreadPort] autorelease];

    // Notify the main thread that the matcher is ready
	[(IFProject*)[mainThreadConnection rootProxy] finishedRebuildingSyntax: thisRebuild];
		
	// We're done
	[self autorelease];
	[mainPool release];
     */
}

@end
