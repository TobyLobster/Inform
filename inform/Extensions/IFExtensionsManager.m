//
//  IFExtensionsManager.m
//  Inform
//
//  Created by Andrew Hunter on 06/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//  Rewritten by Toby Nelson in 2014.
//

#import "IFExtensionsManager.h"
#import "IFMaintenanceTask.h"
#import "IFUtility.h"
#import "IFProject.h"
#import "IFInBuild.h"
#import "NSString+IFStringExtensions.h"
#import "IFCompilerSettings.h"
#import "IFProjectController.h"

NSString* const IFCensusFinishedNotification      = @"IFCensusFinishedNotification";
NSString* const IFCensusFinishedButDontUpdateExtensionsWebPageNotification = @"IFCensusFinishedButDontUpdateExtensionsWebPageNotification";

static int maxErrorMessagesToDisplay = 3;

// *******************************************************************************************
@implementation IFExtensionsManager {
    // Collection directories to look
    /// Standard set of extension directories
    NSMutableArray* extensionCollectionDirectories;
    
    // Cache data
    /// Caches the extension dictionary until we next clear the cache
    NSDictionary* cacheExtensionDictionary;
    /// Caches the available extensions array until we next clear the cache
    NSArray*      cacheAvailableExtensions;
    /// Number of extension dictionaries that are 'installed' to ~/Library/Inform rather than internal to the Inform app bundle resources (i.e. one)
    int           userLibraryCount;

    BOOL _rebuildAvailableExtensionsCache;
    BOOL _rebuildExtensionDictionaryCache;
    BOOL _cacheChanged;

    // Download and install
    /// Mutable array of current downloads
    NSMutableArray* downloads;
    /// How many things we are downloading and installing
    int numberOfBatchedExtensions;
    /// Number of failed download / installs
    int numberOfErrors;
    /// Multiple error messages are accumulated into this string
    NSMutableString* errorString;
    /// Progress
    IFProgress* dlProgress;

    IFInBuild * _inBuild;
}

#pragma mark - Shared extension manager

+ (IFExtensionsManager*) sharedNaturalInformExtensionsManager {
	static IFExtensionsManager* mgr = nil;

	if (!mgr) {
		mgr = [[IFExtensionsManager alloc] init];
	}

	return mgr;
}

#pragma mark - Initialisation

- (instancetype) init {
	self = [super init];

	if (self) {
		extensionCollectionDirectories  = [[NSMutableArray alloc] init];

		cacheAvailableExtensions = nil;
        cacheExtensionDictionary = nil;

		// Get the list of directories where extensions might live

        userLibraryCount = 1;
        [self addExtensionCollectionDirectory: [IFUtility pathForInformExternalExtensions]];        // External directory of extensions
        [self addExtensionCollectionDirectory: [IFUtility pathForInformInternalExtensions:@""]];    // Internal directory of extensions

        downloads = [[NSMutableArray alloc] init];
        numberOfBatchedExtensions = 0;
        numberOfErrors = 0;
        errorString = [[NSMutableString alloc] init];

        self.rebuildAvailableExtensionsCache = YES;
        self.rebuildExtensionDictionaryCache = YES;
        self.cacheChanged = NO;

        _inBuild = [[IFInBuild alloc] init];
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];

	 extensionCollectionDirectories = nil;
     downloads =  nil;
     errorString = nil;
    
}

#pragma mark - Setting up

- (void) addExtensionCollectionDirectory: (NSString*) directory {
	[extensionCollectionDirectories addObject: directory];
}

- (void) dirtyCache {
    self.rebuildExtensionDictionaryCache = YES;
    self.rebuildAvailableExtensionsCache = YES;
}

// Returns a dictionary where key is author name, value is an array of directory paths for that author
- (NSDictionary<NSString*,NSArray<NSString*>*>*) extensionDictionary {
	if (!self.rebuildExtensionDictionaryCache && cacheExtensionDictionary) {
        return cacheExtensionDictionary;
    }

	NSFileManager* manager = [NSFileManager defaultManager];

	// Retrieve the extensions that exist in the directory
	NSMutableDictionary* resultSet = [NSMutableDictionary dictionary];
	
	// Look through the directories
	for( NSString* extnDir in extensionCollectionDirectories ) {
        NSError* error;
		NSArray* extnFiles = [manager contentsOfDirectoryAtPath: extnDir
                                                          error: &error];
		for( NSString* filename in extnFiles ) {
			NSString* fullPath = [extnDir stringByAppendingPathComponent: filename];

			// Must not be hidden from the finder
			if ([filename characterAtIndex: 0] == '.') {
                continue;
            }

			// 'reserved' is a special case and never shows up in the list
			if ([filename.lowercaseString isEqualToString: @"reserved"]) {
                continue;
            }

			// Must exist and be a directory
			BOOL exists;
			BOOL isDir;

			exists = [manager fileExistsAtPath: fullPath
								   isDirectory: &isDir];

			if (exists && isDir) {
				// Add to the list of paths for this name
				NSString* filenameKey = filename.lowercaseString;
				NSMutableArray* dirsWithName = resultSet[filenameKey];

				if (dirsWithName == nil) {
                    dirsWithName = [NSMutableArray array];
                }

				[dirsWithName addObject: fullPath];

				// Add to the result
				resultSet[filenameKey] = dirsWithName;
			}
		}
	}

    // Cache the results
    NSDictionary* newExtensionDictionary = resultSet;

    // Compare dictionaries
    if( ![ cacheExtensionDictionary isEqualTo: newExtensionDictionary] ) {
        self.cacheChanged = YES;
    }

    cacheExtensionDictionary = newExtensionDictionary;
    self.rebuildExtensionDictionaryCache = NO;
    
	return resultSet;
}

-(BOOL) isBuiltIn:(NSString*) fullPath {
    NSInteger count = 0;
	for( NSString* extnDir in extensionCollectionDirectories ) {
        if( [fullPath startsWith: extnDir] ) {
            if (count >= userLibraryCount ) {
                return YES;
            }
            return NO;
        }
        count++;
    }
    return NO;
}

-(NSMutableArray*) parseExtensionsList: (NSString*) jsonString {
    NSMutableArray* result = [NSMutableArray array];
    NSError* error;

    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];

    id object = [NSJSONSerialization
                 JSONObjectWithData:jsonData
                 options:0
                 error:&error];

    if(error) {
        // JSON was malformed
        NSLog(@"Warning: Inbuild JSON error: %@", error.description);
        NSLog(@"JSON was: %@", jsonString);
        return result;
    }

    // The top level is a dictionary. We are only interested in key "inspection".
    if([object isKindOfClass:[NSDictionary class]])
    {
        NSDictionary *results = object;
        id inspection_id = results[@"inspection"];
        if([inspection_id isKindOfClass:[NSArray class]]) {
            NSArray *inspection = inspection_id;
            for(int i= 0; i < inspection.count; i++) {
                id entry_id = inspection[i];

                if(![entry_id isKindOfClass:[NSDictionary class]]) {
                    continue;
                }
                NSDictionary* entry = entry_id;
                NSString* fullFilepath = entry[@"location-file"];
                id resource_id = entry[@"resource"];
                if(![resource_id isKindOfClass:[NSDictionary class]]) {
                    continue;
                }
                NSDictionary* resource = resource_id;

                NSString* type = resource[@"type"];
                if(![type isEqualToStringCaseInsensitive: @"extension"]) {
                    continue;
                }

                NSString* title = resource[@"title"];
                NSString* author = resource[@"author"];
                NSString* version = resource[@"version"];
                if (title == nil) { title = @""; }
                if (author == nil) { author = @""; }
                if (version == nil) {
                    version = @"";
                }
                if (version.length > 0) {
                    version = [NSString stringWithFormat: @"v%@", version];
                }

                IFExtensionInfo* info = [[IFExtensionInfo alloc] initWithDisplayName: title
                                                                            filepath: fullFilepath
                                                                              author: author
                                                                             version: version
                                                                           isBuiltIn: false];
                [result addObject: info];
            }
        }
    }

    return result;
}

// Get an array of the available extension information
- (NSArray*) availableExtensionsWithCompilerVersion: (NSString*) compilerVersion {
    NSMutableArray* result = [NSMutableArray array];

    // Use the cached version if it's around
    if (!self.rebuildAvailableExtensionsCache && cacheAvailableExtensions) {
        return cacheAvailableExtensions;
    }

    if ([IFUtility compilerVersion: compilerVersion isAfter: @"6M62"]) {
        // New extension census. This is only used to populate the
        // menu items for extensions.

        // Step 1: call inbuild to get list of extensions
        [_inBuild executeInBuildForCensus];

        // Step 2: Parse list of extensions into array
        NSString* text = _inBuild.stdOut;
        result = [self parseExtensionsList: text];
    } else {
        // Old extension parsing
        NSFileManager* manager            = [NSFileManager defaultManager];
        NSDictionary* extensionDictionary = [self extensionDictionary];

        // Go through authors
        for( NSString* authorName in extensionDictionary ) {
            NSArray* authorPaths = extensionDictionary[authorName];

            // For each path of an author
            for(NSString* authorPath in authorPaths) {
                NSString* title;
                NSString* author;
                NSString* version;

                NSError* error;
                NSArray* extnFiles = [manager contentsOfDirectoryAtPath: authorPath
                                                                  error: &error];
                // For each extension file
                for( NSString* filename in extnFiles ) {
                    NSString* fullFilepath = [authorPath stringByAppendingPathComponent: filename];

                    // Must not be hidden from the finder
                    if ([filename characterAtIndex: 0] == '.') {
                        continue;
                    }

                    NSString* fileExtension = filename.pathExtension.lowercaseString;
                    if ([fileExtension isEqualToString: @"i7x"] ||
                        [fileExtension isEqualToString: @""]) {
                        // Get information about the extension
                        IFExtensionResult gotInfo = [self infoForNaturalInformExtension: fullFilepath
                                                                                 author: &author
                                                                                  title: &title
                                                                                version: &version];
                        if( gotInfo == IFExtensionSuccess ) {
                            BOOL isBuiltIn = [self isBuiltIn: fullFilepath];
                            IFExtensionInfo* info = [[IFExtensionInfo alloc] initWithDisplayName: title
                                                                                        filepath: fullFilepath
                                                                                          author: author
                                                                                         version: version
                                                                                       isBuiltIn: isBuiltIn];
                            [result addObject: info];
                        }
                    }
                }
            }
        }
	}

    // Remember this result in cache
    NSArray* newAvailableExtensions = result;
    
    if( ![cacheAvailableExtensions isEqualToArray: newAvailableExtensions] ) {
        self.cacheChanged = YES;
    }
    
    cacheAvailableExtensions = newAvailableExtensions;
    self.rebuildAvailableExtensionsCache = NO;

    // Tell anything that wants to know that the extensions have been updated
    [[NSNotificationCenter defaultCenter] postNotificationName: IFCensusFinishedNotification
                                                        object: self];

	return result;
}

- (NSArray*) availableAuthorsWithCompilerVersion: (NSString*) compilerVersion {
    NSMutableSet<NSString*>* authors = [NSMutableSet set];

    for( IFExtensionInfo* info in [self availableExtensionsWithCompilerVersion: compilerVersion] ) {
        [authors addObject: info.author];
    }
    return [authors.allObjects sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

- (NSArray*) availableExtensionsByAuthor: (NSString*) author
                     withCompilerVersion: (NSString*) compilerVersion {
    author = author.lowercaseString;
    NSMutableArray* extensions = [NSMutableArray array];

    for( IFExtensionInfo* info in [self availableExtensionsWithCompilerVersion: compilerVersion] ) {
        if([(info.author).lowercaseString isEqualToString:author]) {
            [extensions addObject:info];
        }
    }
	[extensions sortUsingSelector: @selector(caseInsensitiveCompare:)];
    return extensions;
}







// Returns the array of full extension pathnames for a given extension directory (author) name
- (NSArray*) filesInExtensionWithName: (NSString*) name {
	// Returns all the files in a particular extension (as full path names)
	NSFileManager* manager = [NSFileManager defaultManager];
	NSArray* pathsToSearch;
	
	// Work out which paths to search (just one if we're not merging)
    pathsToSearch = [self extensionDictionary][name.lowercaseString];

	// Search all the paths to generate the list of files
	// If a file with the same name exists in multiple places, then only the first one is used
	NSMutableDictionary* resultDict = [NSMutableDictionary dictionary];

	for( NSString* path in pathsToSearch ) {
		// Search this path
        NSError* error;
		NSArray* files = [manager contentsOfDirectoryAtPath: path
                                                      error: &error];
		for(NSString* file in files) {
			// Add to the result
			resultDict[file.lowercaseString] = [path stringByAppendingPathComponent: file];
		}
	}

    // Sort
	NSMutableArray* result = [resultDict.allValues mutableCopy];
	[result sortUsingSelector: @selector(caseInsensitiveCompare:)];

	return [result copy];
}

// Create directories
- (void) createDirectory: (NSString*) dir {
    NSAssert(dir != nil,                   @"Bad directory in createDirectory (1)");
    NSAssert(![dir isEqualToString: @""],  @"Bad directory in createDirectory (2)");
    NSAssert(![dir isEqualToString: @"/"], @"Bad directory in createDirectory (3)");

	BOOL exists;
    BOOL isDir;

	exists = [[NSFileManager defaultManager] fileExistsAtPath: dir
												  isDirectory: &isDir];
	if (exists) return;

    NSError* error;
	[[NSFileManager defaultManager] createDirectoryAtPath: dir
                              withIntermediateDirectories: YES
                                               attributes: nil
                                                    error: &error];
}

- (void) createDefaultExtnDir {
	// Create the directory that will contain the extensions (if necessary)
	NSString* directory = extensionCollectionDirectories[0];
	if (directory == nil) return;

    // Create the directory (and the hierarchy)
	[self createDirectory: directory];
}

// Work out the extension's author, title and version by reading the first line from a given full filepath of a Natural Inform extension file
- (IFExtensionResult) infoForNaturalInformExtension: (NSString*) file
                                             author: (NSString*__strong*) authorOut
                                              title: (NSString*__strong*) titleOut
                                            version: (NSString*__strong*) versionOut {
	NSFileManager* mgr = [NSFileManager defaultManager];
	
	if (authorOut != nil) {
        *authorOut = nil;
    }
	if (titleOut != nil) {
        *titleOut = nil;
    }
    if( versionOut != nil ) {
        *versionOut = nil;
    }

	// Can't do anything with a non-existant file
	BOOL isDir;
	BOOL exists = [mgr fileExistsAtPath: file
							isDirectory: &isDir];
	if (!exists || isDir) return IFExtensionNotFound;

	// Read the first 1k of the extension
	NSFileHandle* extensionFile = [NSFileHandle fileHandleForReadingAtPath: file];
	NSData* extensionInitialData = [extensionFile readDataOfLength: 1024];
	NSString* extensionString = [[NSString alloc] initWithData: extensionInitialData
                                                       encoding: NSUTF8StringEncoding];
    // The data read can end part way through a character: if so, leave that character out
    for (NSUInteger cut = 1; (extensionString == nil) && (cut <= 3) && (cut < extensionInitialData.length); cut++) {
        extensionString = [[NSString alloc] initWithData: [extensionInitialData subdataWithRange: NSMakeRange(0, extensionInitialData.length - cut)]
                                                encoding: NSUTF8StringEncoding];
    }

    // Fix line endings
    if ([extensionString rangeOfString:@"\r"].location != NSNotFound) {
        extensionString = [extensionString stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
        extensionString = [extensionString stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    }
    
    // Get the first line
    NSRange range = [extensionString rangeOfString:@"\n"];
    if( range.location != NSNotFound ) {
        extensionString = [extensionString substringToIndex:range.location];
    }

    // Trim whitespace
	extensionString = [extensionString stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];

	// Check that the ending is 'begins here'
    if (![extensionString.lowercaseString endsWith:@" begins here."]) {
        return IFExtensionNotValid;
    }

    // Remove the " begins here." from the end
    extensionString = [extensionString substringToIndex: extensionString.length - (@" begins here.").length];

    // Examples:
    // Version 1 of Title Name by Author Name
    // Another Title Name by Author Name

    // Find version name
    NSString* versionName = nil;
    if( [extensionString.lowercaseString startsWith:@"version "] ) {
        NSRange versionRange = [extensionString rangeOfString: @" of "
                                                      options: NSCaseInsensitiveSearch];
        // Without an ' of ', 'Version' is part of the title
        if (versionRange.location != NSNotFound) {
            versionName     = [extensionString substringToIndex:   versionRange.location];

            // Remove the version
            extensionString = [extensionString substringFromIndex: versionRange.location + versionRange.length];
        }
    }

    // Find title name
    NSString* titleName = nil;
    {
        NSRange byPosition = [extensionString rangeOfString: @" by "
                                                    options: NSCaseInsensitiveSearch];
        // Must have a ' by '
        if (byPosition.location == NSNotFound) return IFExtensionNotValid;

        titleName = [extensionString substringToIndex: byPosition.location];

        // Remove the title
        extensionString = [extensionString substringFromIndex: byPosition.location + byPosition.length];
    }

    // Remainder of string is the author
    NSString* authorName = extensionString;

	authorName  = authorName.stringByTrimmingWhitespace;
	titleName   = titleName.stringByTrimmingWhitespace;
	versionName = versionName.stringByTrimmingWhitespace;

    // Remove leading 'The' from extension name
    if( [titleName.lowercaseString startsWith:@"the "] ) {
        titleName = [titleName substringFromIndex: (@"the ").length];
    }

    // Bail out if there is no author name or title left
    if( (authorName.length == 0) ||
        (titleName.length  == 0) ) {
        return IFExtensionNotValid;
    }

    if(authorOut) {
        *authorOut = authorName;
    }
	if (titleOut) {
        *titleOut = titleName;
    }
    if(versionOut) {
        *versionOut = versionName;
    }
	return IFExtensionSuccess;
}

// Install the given extension
- (IFExtensionResult) installLegacyExtension: (NSString*) extensionPath
                                   finalPath: (NSString*__strong*) finalPathOut
                                       title: (NSString*__strong*) titleOut
                                      author: (NSString*__strong*) authorOut
                                     version: (NSString*__strong*) versionOut
                          showWarningPrompts: (BOOL) showWarningPrompts
                                      notify: (BOOL) notify {
	if (finalPathOut) {
        *finalPathOut = nil;
    }

	// We can add directories (of all sorts, but with no subdirectories, and no larger than 1Mb total)
	// We can also add .h, .inf and .i6 files on their own, creating a directory to do so
	NSFileManager* mgr = [NSFileManager defaultManager];

	extensionPath = extensionPath.stringByStandardizingPath;

	[self createDefaultExtnDir];

	// Check that file or directory exists
	BOOL exists, isDir;

	exists = [mgr fileExistsAtPath: extensionPath
					   isDirectory: &isDir];
	if (!exists || isDir) {
        return IFExtensionNotFound;          // Can't add something that does not exist
    }

	NSString* author  = nil;
	NSString* title   = nil;
    NSString* version = nil;

    // Check if it is valid to add the file
    // Inform 7 extensions (i7x) have a first line defining title and author (and optional version number)
    // Try to read out the author and title name to see if this file is valid
    IFExtensionResult result = [self infoForNaturalInformExtension: extensionPath
                                                            author: &author
                                                             title: &title
                                                           version: &version];
    if (result != IFExtensionSuccess) return result;

    if( authorOut != nil ) {
        *authorOut = author;
    }
    if( titleOut != nil ) {
        *titleOut = title;
    }
    if( versionOut != nil ) {
        *versionOut = version;
    }

	// We should be able to add the file/directory

	// Try to create the destination. First extensionDirectory should be the writable one
	NSString* directory = extensionCollectionDirectories[0];
	NSString* destDir;

	if (directory == nil) {
        return IFExtensionCantWriteDestination;
    }

    if (author) {
        destDir = [directory stringByAppendingPathComponent: author];
    } else {
        destDir = [directory stringByAppendingPathComponent: extensionPath.lastPathComponent.stringByDeletingPathExtension];
    }

	destDir = destDir.stringByStandardizingPath;

	if ([destDir.lowercaseString isEqualToString: extensionPath.lowercaseString]) {
        return IFExtensionAlreadyExists;		// Trying to re-add an extension that already exists
    }

	// If the old directory exists and we're not merging, then move the old directory to the trash
	BOOL oldExists = [mgr fileExistsAtPath: destDir];

	// If the directory does not exist, create it
	if (!oldExists) {
        NSError* error;
		if (![mgr createDirectoryAtPath: destDir
            withIntermediateDirectories: YES
                             attributes: nil
                                  error: &error]) {
			// Can't create the extension directory
			return IFExtensionCantWriteDestination;
		}
	}

    NSString* destFile;

    // Work out the destination filename
    if (title != nil) {
        destFile = title;
    }
    else {
        destFile = extensionPath.lastPathComponent;
    }
    
    destFile = [IFExtensionInfo canonicalTitle: destFile];
    
    // destination file mut not be longer than 50 characters? (Is this true?)
    if (destFile.stringByDeletingPathExtension.length > 50) {
        // Extension filenames must be at most 50 characters
        // Remove extension and truncate
        destFile = [destFile.stringByDeletingPathExtension substringToIndex: 50];
    }

    // Extension must have a .i7x extension
    if (![destFile.pathExtension isEqualToString: @"i7x"]) {
        destFile = [destFile stringByAppendingPathExtension: @"i7x"];
    }

    NSString* dest = [destDir stringByAppendingPathComponent: destFile];
    if (finalPathOut) {
        *finalPathOut = [dest copy];
    }

    // Are we trying to install over a newer version?
    NSString* existingAuthor;
    NSString* existingTitle;
    NSString* existingVersion;
    result = [self infoForNaturalInformExtension: dest
                                          author: &existingAuthor
                                           title: &existingTitle
                                         version: &existingVersion];
    if (result == IFExtensionSuccess) {
        if( showWarningPrompts ) {
            if( [existingTitle.lowercaseString isEqualToString: title.lowercaseString] ) {
                if( [existingAuthor.lowercaseString isEqualToString: author.lowercaseString] ) {
                    if( version == nil ) { version = @"Version 1"; }
                    if( existingVersion == nil ) { existingVersion = @"Version 1"; }
                    
                    NSComparisonResult comparison = [existingVersion compare: version options: (NSStringCompareOptions) (NSNumericSearch | NSCaseInsensitiveSearch)];
                    
                    // WARNING: About to overwrite a later version with an earlier one!
                    if( comparison == NSOrderedDescending ) {
                        NSAlert *alert = [[NSAlert alloc] init];
                        alert.messageText = [NSString stringWithFormat: [IFUtility localizedString: @"Overwrite Extension"], existingTitle, existingAuthor];
                        alert.informativeText = [NSString stringWithFormat: [IFUtility localizedString: @"Overwrite Extension Explanation"], existingVersion, version];
                        [alert addButtonWithTitle:[IFUtility localizedString: @"Cancel"]];
                        NSButton *destructive = [alert addButtonWithTitle:[IFUtility localizedString: @"Replace"]];
                        if (@available(macOS 11, *)) {
                            destructive.hasDestructiveAction = YES;
                        }
                        NSModalResponse overwrite = [alert runModal];
                        if (overwrite != NSAlertSecondButtonReturn) {
                            return IFExtensionSuccess;
                        }
                    }
                    else {
                        // WARNING: About to overwrite on earlier or equal version with a later version.
                        NSAlert *alert = [[NSAlert alloc] init];
                        alert.messageText = [NSString stringWithFormat: [IFUtility localizedString: @"Replace Extension"], existingTitle, existingAuthor];
                        alert.informativeText = [NSString stringWithFormat: [IFUtility localizedString: @"Replace Extension Explanation"], existingVersion, version];
                        [alert addButtonWithTitle:[IFUtility localizedString: @"Cancel"]];
                        NSButton *destructive = [alert addButtonWithTitle:[IFUtility localizedString: @"Replace"]];
                        if (@available(macOS 11, *)) {
                            destructive.hasDestructiveAction = YES;
                        }
                        NSModalResponse overwrite = [alert runModal];
                        if (overwrite != NSAlertSecondButtonReturn) {
                            return IFExtensionSuccess;
                        }
                    }
                }
            }
        }
    }

    NSError* error;

    // Remove old file at destination
    {
        NSString* destFileWithoutExtension = dest.stringByDeletingPathExtension;

        // Try removing the destination file *without* the i7x file extension (remove old version that may not have had a file extension)
        [mgr removeItemAtPath: destFileWithoutExtension
                        error: &error];

        // Try removing the destination file *with* i7x file extension
        [mgr removeItemAtPath: dest
                        error: &error];
    }

    // Copy new file to destination
    if (![mgr copyItemAtPath: extensionPath
                      toPath: dest
                       error: &error] ) {
        // Couldn't finish installing the extension
        return IFExtensionCantWriteDestination;
    }

    // Note: this is for Legacy extensions, hence an old version "6M62"
    [self updateExtensionsForCompilerVersion:@"6M62" notify: @(notify)];

    // Success
	return IFExtensionSuccess;
}

#pragma mark - Data source support functions

- (void) updateExtensionsForCompilerVersion: (NSString*) compilerVersion
                                     notify: (NSNumber*) notify {
    // Calculate fresh available extensions
    [self dirtyCache];
    [self availableExtensionsWithCompilerVersion: compilerVersion];

    // Has the array of available extensions changed?
    if( !self.cacheChanged ) {
        return;
    }
    self.cacheChanged = NO;

    if ([IFUtility compilerVersion: compilerVersion isNoLaterThan: @"6M62"]) {
        // Perform a legacy census with the new extensions
        [self startLegacyCensus: notify];
    }
}

-(void) startLegacyCensus:(NSNumber*) notify {
    // Re-run the maintenance tasks
    NSString *compilerPath = [IFUtility pathForCompiler:@""];
    if (compilerPath != nil) {
        NSString* notifyType;
        if( notify.boolValue ) {
            notifyType = IFCensusFinishedNotification;
        } else {
            notifyType = IFCensusFinishedButDontUpdateExtensionsWebPageNotification;
        }

        NSString* externalPath = [IFUtility pathForInformExternalAppSupport];
        NSArray * arguments = @[@"-census",
                                @"-internal",
                                [IFUtility pathForInformInternalAppSupport:@""],
                                @"-external",
                                externalPath];

        NSLog(@"Compiler Path: %@", compilerPath);
        NSLog(@"Arguments: %@", arguments);

        [[IFMaintenanceTask sharedMaintenanceTask] queueTask: compilerPath
                                               withArguments: arguments
                                                  notifyType: notifyType];
    }
}

#pragma mark - NSSavePanel delegate methods

- (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url {
    BOOL isDir;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath: url.path
                                                       isDirectory: &isDir];
    
    if (!exists) return NO;
    if (isDir) return YES;
    
    NSString* extn = url.pathExtension.lowercaseString;

    if( ![extn isEqualToString: @"i7x"] &&
        ![extn isEqualToString: @""] ) {
        return NO;
    }

    return YES;
}

#pragma mark - Download and Install

-(void) addError: (NSString*) message {
    // Log error
    NSLog(@"%@", message);

    numberOfErrors++;

    // Append the new message
    NSString* gap = (numberOfErrors > 1) ? @"\n\n" : @"";
    if( numberOfErrors <= maxErrorMessagesToDisplay ) {
        [errorString appendFormat: @"%@%@", gap, message];
    }
    else if (numberOfErrors == (maxErrorMessagesToDisplay+1) ) {
        [errorString appendString: @"\n\n..."];
    }
}

-(void) startDownloadAndInstallNextInQueue {
    if( downloads.count > 0 ) {
        IFExtensionDownload* dl = downloads[0];

        [dl startDownloadAndInstall];
    }
}

- (BOOL) downloadAndInstallExtension: (NSURL*) url
                              window: (NSWindow*) aWindow
                      notifyDelegate: (NSObject*) notifyDelegate
                        javascriptId: (NSString*) javascriptId {
    IFExtensionDownload* download = [[IFExtensionDownload alloc] initWithURL: url
                                                                      window: aWindow
                                                              notifyDelegate: notifyDelegate
                                                                javascriptId: javascriptId];
    if ( download ) {
        [downloads addObject: download];
        numberOfBatchedExtensions++;

        if( downloads.count == 1 ) {
            // Remove old progress
            if( dlProgress != nil ) {
                if( [download.notifyDelegate isKindOfClass:[IFProjectController class]] ) {
                    [dlProgress stopProgress];
                    [(IFProjectController*) download.notifyDelegate removeProgressIndicator: dlProgress];
                }
            }
            // Create new progress
            dlProgress = [[IFProgress alloc] initWithPriority: IFProgressPriorityExtensions
                                             showsProgressBar: YES
                                                    canCancel: YES];
            if( [download.notifyDelegate isKindOfClass:[IFProjectController class]] ) {
                [(IFProjectController*) download.notifyDelegate addProgressIndicator: dlProgress];
            }
            dlProgress.message = [IFUtility localizedString:@"Installing extension"];
            [dlProgress startProgress];
            [self startDownloadAndInstallNextInQueue];
        }
        return YES;
    }
    return NO;
}

-(void) reportDownloadResults: (IFExtensionDownload*) download {
    // Report errors or success - only if we are not cancelled
    if( !dlProgress.isCancelled ) {
        // Were there errors? Report them if so.
        if( numberOfErrors > 0 ) {
            if( numberOfErrors < numberOfBatchedExtensions ) {
                NSString* messageKey;

                if( (numberOfBatchedExtensions - numberOfErrors) == 1 ) {
                    messageKey = [NSString stringWithFormat: [IFUtility localizedString: @"One extension installed successfully, %d failed"], numberOfErrors];
                } else {
                    messageKey = [NSString stringWithFormat: [IFUtility localizedString: @"%d extensions installed successfully, %d failed"], numberOfBatchedExtensions - numberOfErrors, numberOfErrors];
                }
                [IFUtility runAlertWindow: download.window
                                localized: YES
                                  warning: YES
                                    title: messageKey
                                  message: @"%@", errorString];
            } else {
                if (numberOfBatchedExtensions > 1 ) {
                    [IFUtility runAlertWindow: download.window
                                    localized: YES
                                      warning: YES
                                        title: [NSString stringWithFormat: [IFUtility localizedString: @"Failed to install %d extensions"], numberOfErrors]
                                      message: @"%@", errorString];
                } else {
                    [IFUtility runAlertWindow: download.window
                                    localized: YES
                                      warning: YES
                                        title: [IFUtility localizedString: @"Failed to install extension"]
                                      message: @"%@", errorString];
                }
            }
        }/* else {
            // Show final message
            if( numberOfBatchedExtensions > 1 ) {
                [IFUtility runAlertInformationWindow: download.window
                                               title: @"Installation complete"
                                             message: @"%d extensions installed successfully", numberOfBatchedExtensions];
            } else {
                [IFUtility runAlertInformationWindow: download.window
                                               title: @"Installation complete"
                                             message: @"Extension \"%@\" by %@ (%@) installed successfully", download.title, download.author, download.safeVersion];
            }
        } */
    }

    // Remove progress indicator
    if( [download.notifyDelegate isKindOfClass:[IFProjectController class]] ) {
        [dlProgress stopProgress];
        [(IFProjectController*) download.notifyDelegate removeProgressIndicator: dlProgress];
    }

    numberOfBatchedExtensions = 0;
    numberOfErrors = 0;
    [errorString setString:@""];
}

- (void) downloadAndInstallFinishedOnMainThread: (IFExtensionDownload*) download {
    int done  = numberOfBatchedExtensions - (int) downloads.count;
    int total = numberOfBatchedExtensions;
    CGFloat percentage = 100.0f * (CGFloat) done / (CGFloat) total;
    NSString* message;
    if( numberOfErrors > 0 ) {
        message = [NSString stringWithFormat: [IFUtility localizedString:@"Installed %d of %d (%d failed)"], done - numberOfErrors, total, numberOfErrors];
    } else {
        message = [NSString stringWithFormat: [IFUtility localizedString:@"Installed %d of %d"], done, total];
    }
    dlProgress.percentage = percentage;
    dlProgress.message = message;

    // Remove any remaining items if we are we cancelled
    if( dlProgress.isCancelled ) {
        [downloads removeAllObjects];
    }

    // Last one finished downloading?
    if( downloads.count == 0 ) {
        // Report results back on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [self reportDownloadResults: download];
        });
    }

    // If this particular download succeeded, tell the IFProjectController so it can update the web page to indicate it's downloaded
    if( download.state == IFExtensionDownloadAndInstallSucceeded ) {
        [self dirtyCache];
        // TODO: For the moment at least, this is for old style extensions
        [self availableExtensionsWithCompilerVersion: @"6M62"];

        if( download.notifyDelegate != nil ) {
            if( [download.notifyDelegate isKindOfClass:[IFProjectController class]] ) {
                [(IFProjectController*)download.notifyDelegate extensionUpdated: download.javascriptId];
            }
        }
        self.cacheChanged = NO;
    }
}

- (void) downloadAndInstallFinished: (IFExtensionDownload*) download {
    [downloads removeObject: download];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self downloadAndInstallFinishedOnMainThread: download];
    });

    if( downloads.count > 0 ) {
        [self performSelector: @selector(startDownloadAndInstallNextInQueue)
                 withObject: nil
                 afterDelay: 0.5];
    }
}

@end
