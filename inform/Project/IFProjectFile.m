//
//  IFProjectFile.m
//  Inform
//
//  Created by Andrew Hunter on Fri Sep 12 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "IFProjectFile.h"

#include "uuid/uuid.h"
#import "ZoomView/ZoomSkein.h"

@implementation IFProjectFile

-(void) createUUID {
    if ([[bundleDirectory fileWrappers] objectForKey: @"uuid.txt"] == nil) {
        // Generate a UUID string
        uuid_t newUID;
        uuid_clear(newUID);
        uuid_generate(newUID);
        
        char uid[40];
        uuid_unparse(newUID, uid);
        
        NSString* uidString = [NSString stringWithCString: uid
                                                 encoding: NSUTF8StringEncoding];
        [bundleDirectory addRegularFileWithContents: [uidString dataUsingEncoding: NSUTF8StringEncoding]
                                  preferredFilename: @"uuid.txt"];
    }
}

// = Empty project creation =

- (id) initWithEmptyProject {
    self = [super init];
    
    if ( self )  {
        // First we have to create the source directory, etc
        NSFileWrapper* srcDir;
        NSFileWrapper* bldDir;
        NSFileWrapper* indexDir;

        srcDir   = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: [NSDictionary dictionary]];
        bldDir   = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: [NSDictionary dictionary]];
        indexDir = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: [NSDictionary dictionary]];
        [srcDir   setPreferredFilename: @"Source"];
        [bldDir   setPreferredFilename: @"Build"];
        [indexDir setPreferredFilename: @"Index"];

        [srcDir autorelease];
        [bldDir autorelease];
        [indexDir autorelease];

        if (srcDir == nil || bldDir == nil) {
            return nil;
        }
        
        bundleDirectory = [ [NSFileWrapper alloc] initDirectoryWithFileWrappers:
                                [NSDictionary dictionaryWithObjectsAndKeys: srcDir,   @"Source",
                                                                            bldDir,   @"Build",
                                                                            indexDir, @"Index", nil] ];
        sourceDirectory = [srcDir retain];
        buildDirectory  = [bldDir retain];

        [self createUUID];
    }

    return self;
}

- (id) initWithFileWrapper: (NSFileWrapper*) fileWrapper {
    self = [super init];
    if( self ) {
        if( ![fileWrapper isDirectory] ) {
            return nil;
        }

        bundleDirectory = [fileWrapper retain];
        sourceDirectory = [[[fileWrapper fileWrappers] objectForKey:@"Source"] retain];
        buildDirectory =  [[[fileWrapper fileWrappers] objectForKey:@"Build"] retain];
        if( !sourceDirectory ) {
            sourceDirectory = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: [NSDictionary dictionary]];
            [sourceDirectory setPreferredFilename: @"Source"];
        }
        if( !buildDirectory ) {
            buildDirectory  = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: [NSDictionary dictionary]];
            [buildDirectory  setPreferredFilename: @"Build"];
        }

        [bundleDirectory addFileWrapper:sourceDirectory];
        [bundleDirectory addFileWrapper:buildDirectory];

        if( ![sourceDirectory isDirectory] ) {
            [sourceDirectory release];
            sourceDirectory = nil;
        }

        if( ![buildDirectory isDirectory] ) {
            [buildDirectory release];
            buildDirectory = nil;
        }

        [self createUUID];
    }
    return self;
}

- (void) dealloc {
    [sourceDirectory release];
    [buildDirectory release];
    
    [super dealloc];
}

- (void) addSourceFile: (NSString*) filename {
    [sourceDirectory addRegularFileWithContents: [NSData data]
                              preferredFilename: filename];
}

- (void) addSourceFile: (NSString*) filename
          withContents: (NSData*) contents {
    [sourceDirectory addRegularFileWithContents: contents
                              preferredFilename: filename];
}

- (void) setSettings: (IFCompilerSettings*) settings {
    // Add the settings plist to the wrapper
    [bundleDirectory removeFileWrapper: [[bundleDirectory fileWrappers] objectForKey:@"Settings.plist"]];
	
	NSData* settingsData = [settings currentPlist];

    [bundleDirectory addRegularFileWithContents: settingsData
                              preferredFilename: @"Settings.plist"];

	// Delete the old-style file, if it exists
	NSFileWrapper* settingsFile = [[bundleDirectory fileWrappers] objectForKey: @"Settings"];
	if (settingsFile) [bundleDirectory removeFileWrapper: settingsFile];
}

- (IFCompilerSettings*) settings {
    NSFileWrapper* settingsFile = [[bundleDirectory fileWrappers] objectForKey: @"Settings.plist"];

	if (settingsFile == nil) {
		// Old-style loading
		settingsFile = [[bundleDirectory fileWrappers] objectForKey: @"Settings"];

		if (settingsFile == nil) {
			return nil;
			//return [[[IFCompilerSettings alloc] init] autorelease];
		}

		NSData* settingsData = [settingsFile regularFileContents];
		NSUnarchiver* theCoder = [[NSUnarchiver alloc] initForReadingWithData:
			settingsData];

		// Decode the file
		NSString* creator = [theCoder decodeObject];
		int version = -1;
		[theCoder decodeValueOfObjCType: @encode(int) at: &version];
		IFCompilerSettings* settings = [[theCoder decodeObject] retain];

		// Release the decoder
		[theCoder release];

		if (creator == nil || version != 1 || settings == nil) {
            [settings autorelease];

			// We don't understand this file
			return [[[IFCompilerSettings alloc] init] autorelease];       
		}

		return [settings autorelease];
	} else {
		// New-style loading
		IFCompilerSettings* newSettings = [[[IFCompilerSettings alloc] init] autorelease];
		
		[newSettings restoreSettingsFromPlist: [settingsFile regularFileContents]];
		
		return newSettings;
	}
}

- (void) clearIndex {
	// Delete the contents of the index file wrapper
	NSFileWrapper* index = [[bundleDirectory fileWrappers] objectForKey: @"Index"];
	
	for(NSString* file in [[[index fileWrappers] copy] autorelease]) {
		[index removeFileWrapper: [[index fileWrappers] objectForKey: file]];
	}
}

- (NSFileWrapper*) sourceDirectory {
    return sourceDirectory;
}

- (NSFileWrapper*) syntaxDirectory {
    return [[bundleDirectory fileWrappers] objectForKey: @"Syntax"];
}

// Load the notes (if present)
- (NSTextStorage *) loadNotes {
    NSFileWrapper* noteWrapper = [[bundleDirectory fileWrappers] objectForKey: @"notes.rtf"];
    NSData* data = [noteWrapper regularFileContents];
    if (data != nil) {
        return [[[NSTextStorage alloc] initWithRTF: data
                                documentAttributes: nil] autorelease];
    }
    return nil;
}

-(void) loadIntoSkein:(ZoomSkein *) skein {
    NSFileWrapper* skeinWrapper = [[bundleDirectory fileWrappers] objectForKey: @"Skein.skein"];
    NSData* data = [skeinWrapper regularFileContents];
    if (data != nil) {
        [skein parseXmlData: data];
        [skein setActiveItem: [skein rootItem]];
    }
}

-(NSMutableArray*) loadWatchpoints {
    // Load the watchpoints file (if present)
    NSFileWrapper* watchWrapper = [[bundleDirectory fileWrappers] objectForKey: @"Watchpoints.plist"];
    if (watchWrapper != nil && [watchWrapper regularFileContents] != nil) {
        NSString* propError = nil;
        NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
        NSArray* array = [NSPropertyListSerialization propertyListFromData: [watchWrapper regularFileContents]
                                                          mutabilityOption: NSPropertyListImmutable
                                                                    format: &format
                                                          errorDescription: &propError];
        return [[array mutableCopy] autorelease];
    }
    return nil;
}

-(NSMutableArray*) loadBreakpoints {
    // Load the breakpoints file (if present)
    NSFileWrapper* breakWrapper = [[bundleDirectory fileWrappers] objectForKey: @"Breakpoints.plist"];
    if (breakWrapper != nil && [breakWrapper regularFileContents] != nil) {
        NSString* propError = nil;
        NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
        NSArray* array = [NSPropertyListSerialization propertyListFromData: [breakWrapper regularFileContents]
                                                           mutabilityOption: NSPropertyListImmutable
                                                                     format: &format
                                                           errorDescription: &propError];
        return [[array mutableCopy] autorelease];
    }
    return nil;
}

-(NSString*) loadUUID {
    NSFileWrapper* uuidWrapper = [[bundleDirectory fileWrappers] objectForKey: @"uuid.txt"];
    if (uuidWrapper != nil && [uuidWrapper regularFileContents] != nil) {

        NSString* uuidString = [NSString stringWithUTF8String:[[uuidWrapper regularFileContents] bytes]];
        return uuidString;
    }
    return nil;
}

-(void) setPreferredFilename:(NSString*) name {
    [bundleDirectory setPreferredFilename:name];
}

-(void) replaceSourceDirectoryWrapper: (NSFileWrapper*) newWrapper {
    // Replace the source file wrapper
    [bundleDirectory removeFileWrapper: [[bundleDirectory fileWrappers] objectForKey: @"Source"]];
    [bundleDirectory addFileWrapper: newWrapper];
}

-(void) replaceIndexDirectoryWrapper: (NSFileWrapper*) newWrapper {
    // Replace the source file wrapper
    [bundleDirectory removeFileWrapper: [[bundleDirectory fileWrappers] objectForKey: @"Index"]];
    if( newWrapper != nil ) {
        [bundleDirectory addFileWrapper: newWrapper];
    }
}

-(void) writeNotes:(NSData*) noteData {
    [bundleDirectory removeFileWrapper: [[bundleDirectory fileWrappers] objectForKey: @"notes.rtf"]];
    [bundleDirectory addRegularFileWithContents: noteData
                              preferredFilename: @"notes.rtf"];
}

-(void) writeSkein:(NSString*) xmlData {
    // The skein file
    NSString* xmlString = [@"<?xml version=\"1.0\"?>\n" stringByAppendingString: xmlData];
    NSData* skeinData = [xmlString dataUsingEncoding: NSUTF8StringEncoding];
    
	[bundleDirectory removeFileWrapper: [[bundleDirectory fileWrappers] objectForKey: @"Skein.skein"]];
	[bundleDirectory addRegularFileWithContents: skeinData
                              preferredFilename: @"Skein.skein"];
}

-(void) writeWatchpoints:(NSArray *) watchExpressions {
    // The watchpoints file
    [bundleDirectory removeFileWrapper: [[bundleDirectory fileWrappers] objectForKey: @"Watchpoints.plist"]];

    if ([watchExpressions count] > 0) {
        NSString* plistError = nil;
        
        NSData* watchData = [NSPropertyListSerialization dataFromPropertyList: watchExpressions
                                                                       format: NSPropertyListXMLFormat_v1_0
                                                             errorDescription: &plistError];
        
        [bundleDirectory addRegularFileWithContents: watchData
                                  preferredFilename: @"Watchpoints.plist"];
    }
}

-(void) writeBreakpoints:(NSArray *) breakpoints {
    // The breakpoints file
    [bundleDirectory removeFileWrapper: [[bundleDirectory fileWrappers] objectForKey: @"Breakpoints.plist"]];

    if ([breakpoints count] > 0) {
        NSString* plistError = nil;
        
        NSData* breakData = [NSPropertyListSerialization dataFromPropertyList: breakpoints
                                                                       format: NSPropertyListXMLFormat_v1_0
                                                             errorDescription: &plistError];

        [bundleDirectory addRegularFileWithContents: breakData
                                  preferredFilename: @"Breakpoints.plist"];
    }
}

- (void) cleanOutUnnecessaryFiles: (BOOL) alsoCleanIndex {
	// Clean out the build folder from the project
	NSFileWrapper* build = [[bundleDirectory fileWrappers] objectForKey: @"Build"];
	if (build) [bundleDirectory removeFileWrapper: build];
	
	// Replace it with an empty directory
	build = [[[NSFileWrapper alloc] initDirectoryWithFileWrappers: [NSDictionary dictionary]] autorelease];
	[build setPreferredFilename: @"Build"];
	[bundleDirectory addFileWrapper: build];
	
	// There may also be a 'Temp' directory: remove that too (no need to recreate this)
	NSFileWrapper* temp = [[bundleDirectory fileWrappers] objectForKey: @"Temp"];
	if (temp) [bundleDirectory removeFileWrapper: temp];
	
	// Clean out the index folder from the project
	if (alsoCleanIndex) {
		NSFileWrapper* index = [[bundleDirectory fileWrappers] objectForKey: @"Index"];
		if (index) [bundleDirectory removeFileWrapper: index];
		
		// Replace it with an empty directory
		index = [[[NSFileWrapper alloc] initDirectoryWithFileWrappers: [NSDictionary dictionary]] autorelease];
		[index setPreferredFilename: @"Index"];
		[bundleDirectory addFileWrapper: index];
	}
}

-(NSString*) filename {
    return [bundleDirectory filename];
}

-(void) setFilename:(NSString*) newFilename {
    [bundleDirectory setFilename: newFilename];
}

-(BOOL) write {
    return [bundleDirectory writeToFile: [self filename]
                             atomically: YES
                        updateFilenames: YES];
}

@end
