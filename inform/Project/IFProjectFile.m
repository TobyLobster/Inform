//
//  IFProjectFile.m
//  Inform
//
//  Created by Andrew Hunter on Fri Sep 12 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "IFProjectFile.h"
#import "NSString+IFStringExtensions.h"

#import "IFSkein.h"
#import "IFSkeinItem.h"
#import "IFCompilerSettings.h"
#import "IFCompilerSettings+OldStyle.h"

@implementation IFProjectFile {
    NSFileWrapper* bundleDirectory;
}

-(void) createUUID {
    if (bundleDirectory.fileWrappers[@"uuid.txt"] == nil) {
        // Generate a UUID string
        [bundleDirectory addRegularFileWithContents: [NSUUID.UUID.UUIDString dataUsingEncoding: NSUTF8StringEncoding]
                                  preferredFilename: @"uuid.txt"];
    }
}

#pragma mark - Empty project creation

- (instancetype) initWithEmptyProject {
    self = [super init];
    
    if ( self )  {
        // First we have to create the source directory, etc
        NSFileWrapper* srcDir;
        NSFileWrapper* bldDir;
        NSFileWrapper* indexDir;

        srcDir   = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: @{}];
        bldDir   = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: @{}];
        indexDir = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: @{}];
        srcDir.preferredFilename = @"Source";
        bldDir.preferredFilename = @"Build";
        indexDir.preferredFilename = @"Index";

        bundleDirectory = [ [NSFileWrapper alloc] initDirectoryWithFileWrappers:
                                @{@"Source": srcDir,
                                  @"Build": bldDir,
                                  @"Index": indexDir} ];

        [self createUUID];
    }

    return self;
}

- (instancetype) initWithFileWrapper: (NSFileWrapper*) fileWrapper {
    self = [super init];
    if( self ) {
        if( !fileWrapper.directory ) {
            return nil;
        }

        bundleDirectory = fileWrapper;
        NSFileWrapper* sourceDirectory = fileWrapper.fileWrappers[@"Source"];
        NSFileWrapper* buildDirectory = fileWrapper.fileWrappers[@"Build"];
        if( !sourceDirectory ) {
            sourceDirectory = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: @{}];
            sourceDirectory.preferredFilename = @"Source";
        }
        if( !buildDirectory ) {
            buildDirectory  = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: @{}];
            buildDirectory.preferredFilename = @"Build";
        }

        [bundleDirectory addFileWrapper:sourceDirectory];
        [bundleDirectory addFileWrapper:buildDirectory];

        [self createUUID];
    }
    return self;
}


- (void) addSourceFile: (NSString*) filename
          withContents: (NSData*) contents {
    [self.sourceDirectory addRegularFileWithContents: contents
                                   preferredFilename: filename];
}

- (void) setSettings: (IFCompilerSettings*) settings {
    // Add the settings plist to the wrapper
    [bundleDirectory removeFileWrapper: bundleDirectory.fileWrappers[@"Settings.plist"]];
	
	NSData* settingsData = settings.currentPlist;

    [bundleDirectory addRegularFileWithContents: settingsData
                              preferredFilename: @"Settings.plist"];

	// Delete the old-style file, if it exists
	NSFileWrapper* settingsFile = bundleDirectory.fileWrappers[@"Settings"];
	if (settingsFile) [bundleDirectory removeFileWrapper: settingsFile];
}

- (IFCompilerSettings*) settings {
    NSFileWrapper* settingsFile = bundleDirectory.fileWrappers[@"Settings.plist"];

	if (settingsFile == nil) {
		// Old-style loading
		settingsFile = bundleDirectory.fileWrappers[@"Settings"];

		if (settingsFile == nil) {
			return nil;
		}
		if (!settingsFile.regularFile) {
			// A folder has no settings to read
			return [[IFCompilerSettings alloc] init];
		}

		return [IFCompilerSettings settingsFromOldStyleData: settingsFile.regularFileContents];
	} else {
		// New-style loading
		IFCompilerSettings* newSettings = [[IFCompilerSettings alloc] init];

		// A folder has no settings to read
		if (settingsFile.regularFile) {
			[newSettings restoreSettingsFromPlist: settingsFile.regularFileContents];
		}
		
		return newSettings;
	}
}

- (NSFileWrapper*) sourceDirectory {
    // The project's Source folder now, which reloading may have replaced
    NSFileWrapper* sourceDirectory = bundleDirectory.fileWrappers[@"Source"];
    return sourceDirectory.directory ? sourceDirectory : nil;
}

// Load the notes (if present)
- (NSTextStorage *) loadNotes {
    NSFileWrapper* noteWrapper = bundleDirectory.fileWrappers[@"notes.rtf"];
    NSData* data = noteWrapper.regularFileContents;
    if (data != nil) {
        return [[NSTextStorage alloc] initWithRTF: data
                                documentAttributes: nil];
    }
    return nil;
}

-(BOOL) loadIntoSkein: (IFSkein *) skein
             fromFile: (NSString*) skeinFilename {
    NSFileWrapper* skeinWrapper = bundleDirectory.fileWrappers[skeinFilename];
    NSData* data = skeinWrapper.regularFileContents;
    if (data != nil) {
        [skein parseXmlData: data];

        // Set the root command to the title of the project
        skein.rootItem.command = (bundleDirectory.preferredFilename).lastPathComponent.stringByDeletingPathExtension;

        [skein setActiveItem: nil];
        [skein postSkeinChangedWithAnimate: NO
                         keepActiveVisible: NO];
        return YES;
    }
    return NO;
}

-(void) loadIntoSkeins: (NSMutableArray *) skeins
               project: (IFProject*) project
    isExtensionProject: (BOOL) isExtensionProject {
    IFSkein* skein = nil;

    if( !isExtensionProject ) {
        skein = [[IFSkein alloc] initWithProject: project];
        if( [self loadIntoSkein: skein fromFile: @"Skein.skein"] ) {
            [skeins addObject: skein];
        }
    }
    else {
        // Load all skeins for an extension project
        NSDictionary* wrappers = bundleDirectory.fileWrappers;
        for(int alphabetCount = 0; alphabetCount < 26; alphabetCount++ ) {
            BOOL found = NO;
            NSString* fileToFind = [NSString stringWithFormat:@"Skein%c.skein", 'A' + alphabetCount];
            for( NSString* key in wrappers ) {
                NSFileWrapper* wrapper = wrappers[key];
                if( wrapper.regularFile ) {
                    if( [wrapper.filename isEqualToStringCaseInsensitive: fileToFind] ) {
                        skein = [[IFSkein alloc] initWithProject: project];
                        if( [self loadIntoSkein: skein fromFile: fileToFind] ) {
                            [skeins addObject: skein];
                            found = YES;
                        }
                    }
                }
            }
            if( !found ) {
                break;
            }
        }
    }

    // If no skein found, use a new one
    if( skeins.count == 0 ) {
        skein = [[IFSkein alloc] initWithProject: project];

        // Set the root command to the title of the project
        skein.rootItem.command = (bundleDirectory.preferredFilename).lastPathComponent.stringByDeletingPathExtension;
        
        [skeins addObject: skein];
    }
}

-(NSMutableArray*) loadWatchpoints {
    // Load the watchpoints file (if present)
    NSFileWrapper* watchWrapper = bundleDirectory.fileWrappers[@"Watchpoints.plist"];
    if (watchWrapper != nil && watchWrapper.regularFileContents != nil) {
        NSError* propError = nil;
        NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
        NSArray* array = [NSPropertyListSerialization propertyListWithData: watchWrapper.regularFileContents
                                                          options: NSPropertyListImmutable
                                                                    format: &format
                                                          error: &propError];
        if (![array isKindOfClass: [NSArray class]]) {
            return nil;
        }
        return [array mutableCopy];
    }
    return nil;
}

-(NSMutableArray*) loadBreakpoints {
    // Load the breakpoints file (if present)
    NSFileWrapper* breakWrapper = bundleDirectory.fileWrappers[@"Breakpoints.plist"];
    if (breakWrapper != nil && breakWrapper.regularFileContents != nil) {
        NSError* propError = nil;
        NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
        NSArray* array = [NSPropertyListSerialization propertyListWithData: breakWrapper.regularFileContents
                                                                   options: NSPropertyListImmutable
                                                                    format: &format
                                                                     error: &propError];
        if (![array isKindOfClass: [NSArray class]]) {
            return nil;
        }
        return [array mutableCopy];
    }
    return nil;
}

-(NSString*) loadUUID {
    NSFileWrapper* uuidWrapper = bundleDirectory.fileWrappers[@"uuid.txt"];
    if (uuidWrapper != nil && uuidWrapper.regularFileContents != nil) {
        // The file's contents don't end with a NUL, so they can't be read as a C string
        NSString* uuidString = [[NSString alloc] initWithData: uuidWrapper.regularFileContents
                                                     encoding: NSUTF8StringEncoding];
        return uuidString;
    }
    return nil;
}

-(void) replaceSourceDirectoryWrapper: (NSFileWrapper*) newWrapper {
    // Replace the source file wrapper
    [bundleDirectory removeFileWrapper: bundleDirectory.fileWrappers[@"Source"]];
    if( newWrapper != nil ) {
        [bundleDirectory addFileWrapper: newWrapper];
    }
}

-(void) replaceIndexDirectoryWrapper: (NSFileWrapper*) newWrapper {
    // Replace the source file wrapper
    [bundleDirectory removeFileWrapper: bundleDirectory.fileWrappers[@"Index"]];
    if( newWrapper != nil ) {
        [bundleDirectory addFileWrapper: newWrapper];
    }
}

-(void) replaceWrapper: (NSFileWrapper*) newWrapper {
    // Remove all old items
    while (bundleDirectory.fileWrappers.count > 0 ) {
        NSFileWrapper* wrapper = bundleDirectory.fileWrappers.allValues[0];
        [bundleDirectory removeFileWrapper: wrapper];
    }

    // Add new items
    NSDictionary* itemsToAdd = newWrapper.fileWrappers;
    for( NSString* key in itemsToAdd ) {
        [bundleDirectory addFileWrapper: itemsToAdd[key]];
    }
}

-(void) writeNotes:(NSData*) noteData {
    [bundleDirectory removeFileWrapper: bundleDirectory.fileWrappers[@"notes.rtf"]];
    [bundleDirectory addRegularFileWithContents: noteData
                              preferredFilename: @"notes.rtf"];
}

-(void) writeSkein:(NSString*) xmlString toFilename: (NSString*) toFilename {
    // The skein file
    NSString* fullXMLString = [@"<?xml version=\"1.0\"?>\n" stringByAppendingString: xmlString];
    NSData* skeinData = [fullXMLString dataUsingEncoding: NSUTF8StringEncoding];
    
	[bundleDirectory removeFileWrapper: bundleDirectory.fileWrappers[toFilename]];
	[bundleDirectory addRegularFileWithContents: skeinData
                              preferredFilename: toFilename];
}

-(void) writeSkeins: (NSArray<IFSkein*>*) skeins isExtensionProject: (BOOL) isExtensionProject {
    if( isExtensionProject ) {
        // Load all skeins for an extension project
        int alphabetCount = 0;
        for( IFSkein* skein in skeins ) {
            if( alphabetCount >= 26 ) {
                break;
            }
            NSString* toFilename = [NSString stringWithFormat:@"Skein%c.skein", 'A' + alphabetCount];
            [self writeSkein: skein.XMLString toFilename: toFilename];
            alphabetCount++;
        }
    }
    else {
        // Set the root command to the title of the project
        (skeins[0]).rootItem.command = (bundleDirectory.preferredFilename).lastPathComponent.stringByDeletingPathExtension;
        [self writeSkein: (skeins[0]).XMLString toFilename: @"Skein.skein"];
    }
}

-(void) writeWatchpoints:(NSArray *) watchExpressions {
    // The watchpoints file
    [bundleDirectory removeFileWrapper: bundleDirectory.fileWrappers[@"Watchpoints.plist"]];

    if (watchExpressions.count > 0) {
        NSData* watchData = [NSPropertyListSerialization dataWithPropertyList: watchExpressions
                                                                       format: NSPropertyListXMLFormat_v1_0
                                                                      options: 0
                                                                        error: NULL];
        
        [bundleDirectory addRegularFileWithContents: watchData
                                  preferredFilename: @"Watchpoints.plist"];
    }
}

-(void) writeBreakpoints:(NSArray *) breakpoints {
    // The breakpoints file
    [bundleDirectory removeFileWrapper: bundleDirectory.fileWrappers[@"Breakpoints.plist"]];

    if (breakpoints.count > 0) {
        NSData* breakData = [NSPropertyListSerialization dataWithPropertyList: breakpoints
                                                                       format: NSPropertyListXMLFormat_v1_0
                                                                      options: 0
                                                                        error: NULL];

        [bundleDirectory addRegularFileWithContents: breakData
                                  preferredFilename: @"Breakpoints.plist"];
    }
}

- (void) cleanOutUnnecessaryFiles: (BOOL) alsoCleanIndex {
	// Clean out the build folder from the project
	NSFileWrapper* build = bundleDirectory.fileWrappers[@"Build"];
	if (build) [bundleDirectory removeFileWrapper: build];
	
	// Replace it with an empty directory
	build = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: @{}];
	build.preferredFilename = @"Build";
	[bundleDirectory addFileWrapper: build];
	
	// There may also be a 'Temp' directory: remove that too (no need to recreate this)
	NSFileWrapper* temp = bundleDirectory.fileWrappers[@"Temp"];
	if (temp) [bundleDirectory removeFileWrapper: temp];

	// Clean out the index folder from the project
	if (alsoCleanIndex) {
		NSFileWrapper* index = bundleDirectory.fileWrappers[@"Index"];
		if (index) [bundleDirectory removeFileWrapper: index];
		
		// Replace it with an empty directory
		index = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: @{}];
		index.preferredFilename = @"Index";
		[bundleDirectory addFileWrapper: index];
	}
}

-(NSString*) filename {
    return bundleDirectory.filename;
}

-(void) setFilename:(NSString*) newFilename {
    bundleDirectory.filename = newFilename;
}

-(BOOL) write {
    NSError *error;
    NSURL* writeToURL = [[NSURL alloc] initFileURLWithPath: self.filename];

    return [bundleDirectory writeToURL: writeToURL
                               options: NSFileWrapperWritingAtomic | NSFileWrapperWritingWithNameUpdating
                   originalContentsURL: nil
                                 error: &error];
}

@end
