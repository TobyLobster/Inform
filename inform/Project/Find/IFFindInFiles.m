//
//  IFFindInFiles.m
//  Inform
//
//  Created by Toby Nelson in 2014
//

#import "IFFindInFiles.h"
#import "IFFindController.h"
#import "IFFindResult.h"
#import "IFAppDelegate.h"
#import "IFExtensionsManager.h"
#import "IFDocParser.h"
#import "IFScanner.h"
#import "IFCompilerSettings.h"

#include <wctype.h>

@interface IFSearchItem : NSObject

-(instancetype) init NS_UNAVAILABLE NS_DESIGNATED_INITIALIZER;
-(instancetype) initWithText: (NSString*) textString
      withFilePath: (NSString*) filepathString
      withLocation: (IFFindLocation) locationType NS_DESIGNATED_INITIALIZER;

@end

@implementation IFSearchItem {
@public
    NSString*       text;
    NSString*       filepath;
    IFFindLocation  location;
}

-(instancetype) init { self = [super init]; return self; }

-(instancetype) initWithText: (NSString*) textString
      withFilePath: (NSString*) filepathString
      withLocation: (IFFindLocation) locationType {
	self = [super init];
	
	if (self) {
        text     = textString;
        filepath = filepathString;
        location = locationType;
    }
    return self;
}


@end

@implementation IFFindInFiles {
    BOOL            searching;
    NSMutableArray* searchItems;
    NSMutableArray* results;
    NSDictionary*   exampleInfo;
    NSArray*        codeInfo;
    NSArray*        definitionInfo;

    NSObject *      searchLock;
    NSObject *      searchItemsLock;
    NSObject *      searchResultsLock;
}

-(instancetype) init {
    self = [super init];
    
    if (self) {
        searchItems = [[NSMutableArray alloc] init];
        results     = [[NSMutableArray alloc] init];
        searchLock  = [[NSObject alloc] init];
        searchItemsLock   = [[NSObject alloc] init];
        searchResultsLock = [[NSObject alloc] init];
    }
    return self;
}


-(void) foundMatchInFile: (NSString*)       filename
             rangeInFile: (NSRange)         fileRange
     documentDisplayName: (NSString*)       documentDisplayName
        documentSortName: (NSString*)       documentSortName
            locationType: (IFFindLocation)  locationType
                 context: (NSString*)       context
            contextRange: (NSRange)         contextRange
             exampleName: (NSString*)       exampleName
        exampleAnchorTag: (NSString*)       exampleAnchorTag
           codeAnchorTag: (NSString*)       codeAnchorTag
     definitionAnchorTag: (NSString*)       definitionAnchorTag
        regexFoundGroups: (NSArray*)        regexFoundGroups
{
    IFFindResult* result = [[IFFindResult alloc] initWithFilepath: filename
                                                      rangeInFile: fileRange
                                              documentDisplayName: documentDisplayName
                                                 documentSortName: documentSortName
                                                     locationType: locationType
                                                          context: context
                                                     contextRange: contextRange
                                                      exampleName: exampleName
                                                 exampleAnchorTag: exampleAnchorTag
                                                    codeAnchorTag: codeAnchorTag
                                              definitionAnchorTag: definitionAnchorTag
                                                 regexFoundGroups: regexFoundGroups];
    @synchronized( searchResultsLock ) {
        [results addObject:result];
    }
}

+ (NSString*) getContextFromText: (NSString*) textString
                    withLocation: (NSUInteger) location
                       andLength: (NSUInteger) matchLength
             findingContextRange: (NSRange*) rangeOut {
    
    //
    NSCharacterSet* set = [NSCharacterSet characterSetWithCharactersInString:@"\n\r"];
    NSRange startRange = [textString rangeOfCharacterFromSet:set
                                                     options:NSBackwardsSearch
                                                       range:NSMakeRange(0, location)];
    NSRange endRange = [textString rangeOfCharacterFromSet:set
                                                   options:NSLiteralSearch
                                                     range:NSMakeRange(location + matchLength, textString.length - (location + matchLength))];
    NSUInteger lowContext = (startRange.location == NSNotFound) ? 0 : startRange.location;
    NSUInteger highContext = (endRange.location == NSNotFound) ? textString.length - 1 : endRange.location;
    
    
    // Skip past whitespace / newlines at either end
    NSCharacterSet* whiteSet = [NSCharacterSet characterSetWithCharactersInString:@"\n\r \t"];
    while ( (lowContext < location) && [whiteSet characterIsMember:[textString characterAtIndex:lowContext]] ) {
        lowContext++;
    }
    while ( (highContext > location) && [whiteSet characterIsMember:[textString characterAtIndex:highContext]] ) {
        highContext--;
    }

    NSAssert(lowContext >= 0, @"Bad context range");
    NSAssert(highContext < [textString length], @"Bad context range (high)");
    NSAssert(lowContext <= highContext, @"Bad context range (swapped)");
    
    *rangeOut = NSMakeRange(location - lowContext, matchLength);
    return [textString substringWithRange: NSMakeRange(lowContext, highContext + 1 - lowContext)];
}

- (IFExampleInfo*) exampleInfoForRange: (NSRange) range {
    if( exampleInfo != nil ) {
        for( NSString* key in exampleInfo) {
            IFExampleInfo* info = exampleInfo[key];
            if(( range.location >= info.range.location ) &&
               ((range.location + range.length) <= (info.range.location + info.range.length))) {
                return info;
            }
        }
    }
    return nil;
}

- (IFCodeInfo*) codeInfoForRange: (NSRange) range {
    if( codeInfo != nil ) {
        for( IFCodeInfo*info in codeInfo) {
            if(( range.location >= info.range.location ) &&
               ((range.location + range.length) <= (info.range.location + info.range.length))) {
                return info;
            }
        }
    }
    return nil;
}

- (IFCodeInfo*) definitionInfoForRange: (NSRange) range {
    if( definitionInfo != nil ) {
        for( IFCodeInfo*info in definitionInfo) {
            if(( range.location >= info.range.location ) &&
               ((range.location + range.length) <= (info.range.location + info.range.length))) {
                return info;
            }
        }
    }
    return nil;
}

- (void) searchThreadWithPhrase: (NSString*)                    searchPhrase
                     searchType: (IFFindType)                   searchType
                      locations: (IFFindLocation)               searchLocations
                  progressBlock: (IFFindInFilesProgressBlock)   progressBlock {
    // memory pool
    @autoreleasepool {

    @synchronized ( searchItemsLock )
    {
        int totalSearchItems = (int) searchItems.count;
        int progressCount = 0;
        dispatch_queue_t main = dispatch_get_main_queue();
        int resultCount;

        for( IFSearchItem* searchItem in searchItems ) {
            // Retrieve values from it
            NSString* storage           = searchItem->text;
            NSString* filename          = searchItem->filepath;
            IFFindLocation locationType = searchItem->location;

            NSString* displayName = filename.lastPathComponent.stringByDeletingPathExtension;
            NSString* sortKey = nil;

            exampleInfo = nil;
            NSString* lastFoundInExample = nil;
            bool foundOutsideExample = false;
            bool onlyOneMatchPerSegment = false;        // I define a segment to be an Example or the text outside an Example.

            if (storage == nil && filename != nil) {
                // What we do depends on file type
                NSAttributedString* res = nil;
                NSString* extn = filename.pathExtension.lowercaseString;

                // .inf, .h, .ni, .i7, .txt and those with no extension are treated as text files
                // .rtf or .rtfd are opened as RTF files
                // .html or .htm are opened as HTML files
                // all other file types are not searched
                if (extn == nil ||
                    [extn isEqualToString: @""] ||
                    [extn isEqualToString: @"h"] ||
                    [extn isEqualToString: @"ni"] ||
                    [extn isEqualToString: @"i7"] ||
                    [extn isEqualToString: @"inf"] ||
                    [extn isEqualToString: @"i7x"] ||
                    [extn isEqualToString: @"txt"]) {
                    NSError* error;
                    NSString* fileContents = [NSString stringWithContentsOfFile: filename
                                                                       encoding: [IFProjectTypes encodingForFilename:filename]
                                                                          error: &error];
                    if (fileContents) res = [[NSAttributedString alloc] initWithString: fileContents];
                } else if ([extn isEqualToString: @"rtf"] ||
                           [extn isEqualToString: @"rtfd"]) {
                    res = [[NSAttributedString alloc] initWithURL: [NSURL fileURLWithPath: filename]
                                                          options: @{}
                                               documentAttributes: nil
                                                            error: NULL];
                } else if ([extn isEqualToString: @"html"] ||
                           [extn isEqualToString: @"htm"]) {
                    // Parse the file
                    NSData* fileData = [[NSData alloc] initWithContentsOfFile: filename];
                    NSString* fileString = [[NSString alloc] initWithData: fileData
                                                                 encoding: NSUTF8StringEncoding];
                    IFDocParser* fileContents = [[IFDocParser alloc] initWithHtml: fileString];
                    
                    // Retrieve the storage contents
                    storage = fileContents.plainText;
                    
                    // Work out the display name
                    NSString* title = fileContents.attributes[IFDocAttributeTitle];
                    NSString* section = fileContents.attributes[IFDocAttributeSection];
                    
                    sortKey = fileContents.attributes[IFDocAttributeSort];
                    
                    if (title != nil && section != nil) {
                        displayName = [NSString stringWithFormat: @"%@: %@", section, title];
                    } else {
                        displayName = fileContents.attributes[IFDocAttributeHtmlTitle];
                    }
                    
                    exampleInfo     = fileContents.exampleInfo;
                    codeInfo        = fileContents.codeInfo;
                    definitionInfo  = fileContents.definitionInfo;
                    
                    onlyOneMatchPerSegment = true;
                }
                
                if (res) {
                    storage = res.string;
                }
            }

            if (sortKey == nil) sortKey = displayName;
            
            // storage now contains the string for the file/internal data - search it
            if (storage) {
                NSUInteger searchPosition = 0;
                NSRange matchRange;
                NSArray* matchGroups;
                
                do {
                    matchRange = [IFScanner findNextMatch: searchPhrase
                                                  storage: storage
                                                 position: searchPosition
                                                  options: searchType
                                         regexFoundGroups: &matchGroups];
                    if( matchRange.location != NSNotFound ) {
                        NSRange contextRange;
                        bool alreadyFound;

                        //
                        // Found a match.
                        //

                        //
                        // For HTML documentation files, we record a maximum of one search result
                        // per page, plus one result per example. I call these regions 'segments'.
                        // The following code enforces this.
                        //

                        // Get information about where the match occured
                        IFExampleInfo* info = [self exampleInfoForRange: matchRange];
                        IFCodeInfo* cdInfo  = [self codeInfoForRange: matchRange];
                        IFCodeInfo* dfInfo  = [self definitionInfoForRange: matchRange];

                        // Check if we have already found a result in this segment...
                        if( info != nil ) {
                            //
                            // The match is inside an example
                            //
                            alreadyFound = ( lastFoundInExample != nil ) && ([lastFoundInExample compare:info.name] == NSOrderedSame);
                            lastFoundInExample = info.name;
                        }
                        else {
                            //
                            // The match is outside any examples
                            //
                            alreadyFound = foundOutsideExample;
                            foundOutsideExample = true;
                        }
                        
                        // Should we ignore this match?
                        
                        // Ignore if it's already found in this segment
                        BOOL ignoreThisMatch = alreadyFound && onlyOneMatchPerSegment && (cdInfo == nil) && (dfInfo == nil);

                        if( !ignoreThisMatch ) {
                            
                            // If we are currently looking in documentation...
                            if( searchItem->location & IFFindDocumentationBasic ) {

                                // Ignore this match if it's in code, but we are not looking for code
                                BOOL isInCode = (cdInfo != nil);
                                if( isInCode && ((searchLocations & IFFindDocumentationSource) == 0) ) {
                                    ignoreThisMatch = YES;
                                }

                                // Ignore this match if it's in definitions, when we are not looking for definitions
                                BOOL isInDefinitions = (dfInfo != nil);
                                if( isInDefinitions && ((searchLocations & IFFindDocumentationDefinitions) == 0) ) {
                                    ignoreThisMatch = YES;
                                }
                                
                                // Ignore this match if it's in basic, when we are not looking for basic
                                if( !isInDefinitions && !isInCode && ((searchLocations & IFFindDocumentationBasic) == 0) ) {
                                    ignoreThisMatch = YES;
                                }
                            }
                        }

                        if( !ignoreThisMatch ) {
                            //
                            // Calculate the context (i.e. the text around the match to display in the results)
                            //
                            NSString* context = [IFFindInFiles getContextFromText: storage
                                                                     withLocation: matchRange.location
                                                                        andLength: matchRange.length
                                                              findingContextRange: &contextRange];

                            //
                            // Record the result
                            //
                            [self foundMatchInFile: filename
                                       rangeInFile: matchRange
                               documentDisplayName: displayName
                                  documentSortName: sortKey
                                      locationType: locationType
                                           context: context
                                      contextRange: contextRange
                                       exampleName: info.name
                                  exampleAnchorTag: info.anchorTag
                                     codeAnchorTag: cdInfo.anchorTag
                               definitionAnchorTag: dfInfo.anchorTag
                                  regexFoundGroups: matchGroups];
                        }

                        searchPosition = matchRange.location + 1;
                    }
                }
                while(matchRange.location != NSNotFound);
            }
             filename = nil;
             displayName = nil;
             sortKey = nil;
             storage = nil;
             exampleInfo = nil;
             codeInfo = nil;
             definitionInfo = nil;


            // Update progress
            @synchronized( searchResultsLock ) {
                resultCount = (int) results.count;
            }
            progressCount++;

            dispatch_async(main, ^ {
                progressBlock(progressCount, totalSearchItems + 1, resultCount);
            });
        }

        // Finished searching - send one final update to the main thread
        @synchronized( searchResultsLock ) {
            resultCount = (int) results.count;
        }
        dispatch_async(main, ^ {
            progressBlock(totalSearchItems + 1, totalSearchItems + 1, resultCount);
        });

        searching = NO;
    }

    // clean up
    }
}


// Gather files to search through...

-(void) addSearchText: (NSString*) text
         withFilePath: (NSString*) filepath
         withLocation: (IFFindLocation) location {
    // NSLog(@"Found text file %@ (length %d) in location %d", filepath, [text length], (int) location);
    
    IFSearchItem* item = [[IFSearchItem alloc] initWithText:text withFilePath:filepath withLocation:location];
    [searchItems addObject:item];
}

-(void) addSearchFile:(NSString*) filepath
         withLocation:(IFFindLocation) location {
    [self addSearchText:nil withFilePath:filepath withLocation:location];
}

- (void) addDocumentation {
	// Find the documents to search
	NSString* resourcePath = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html"].stringByDeletingLastPathComponent;
	
	// Find all .htm and .html documents from the resources
	NSDirectoryEnumerator* dirEnum = [[NSFileManager defaultManager] enumeratorAtPath: resourcePath];

	for( NSString* path in dirEnum ) {
		NSString* extension = path.pathExtension;
		NSString* description = path.lastPathComponent.stringByDeletingPathExtension.lowercaseString;
		
		// Must be an html file and start with doc or Rdoc.
        if ([extension isEqualToString: @"html"] ||
            [extension isEqualToString: @"htm"]) {
            if ([description hasPrefix: @"doc"] ||
                [description hasPrefix: @"rdoc"]) {
                [self addSearchFile: [resourcePath stringByAppendingPathComponent: path]
                       withLocation: IFFindDocumentationBasic];
            }
		}
	}
}

- (void) addExtensions: (IFProject *) project {
    IFExtensionsManager* manager = [IFExtensionsManager sharedNaturalInformExtensionsManager];

	for( IFExtensionInfo* info in [manager availableExtensionsWithCompilerVersion: (project.settings).compilerVersion] ) {
        [self addSearchFile: info.filepath
               withLocation: IFFindExtensions];
    }
}

- (void) addSourceFiles: (IFProject*) project {
    // Find all text in the project source files
	NSDictionary* sourceFiles = project.sourceFiles;

    for( NSString* filepath in sourceFiles) {
		NSTextStorage* file = sourceFiles[filepath];
		
		[self addSearchText: file.string
               withFilePath: filepath
               withLocation: IFFindSource];
	}
}

- (BOOL) isSearching {
    return searching;
}

- (int) resultsCount {
    @synchronized (searchResultsLock) {
        return (int) results.count;
    }
}

- (NSArray*) results {
    @synchronized (searchResultsLock) {
        NSArray *sortedArray = [results sortedArrayUsingComparator:^(id firstObject, id secondObject) {
            IFFindResult*first  = (IFFindResult*)firstObject;
            IFFindResult*second = (IFFindResult*)secondObject;
            
            // Sort by location type first
            if( first.locationType != second.locationType ) {
                return (NSComparisonResult) ((int) first.locationType - (int) second.locationType);
            }
            
            // Then sort by document name
            return [first.documentSortName compare:second.documentSortName options:NSNumericSearch];
        }];
        return sortedArray;
    }
}

- (NSObject*) searchResultsLock {
    return searchResultsLock;
}

- (void) startFindInFilesWithPhrase: (NSString*)       searchPhrase
                     withSearchType: (IFFindType)      searchType
                        fromProject: (IFProject*)      project
                      withLocations: (IFFindLocation)  locations
                  withProgressBlock: (IFFindInFilesProgressBlock)   progressBlock
{
    searching = YES;

    @synchronized(searchLock)
    {
        @synchronized( searchItemsLock )
        {
            @synchronized( searchResultsLock )
            {
                [results removeAllObjects];

                [searchItems removeAllObjects];

                if(( locations & IFFindDocumentationBasic ) ||
                   ( locations & IFFindDocumentationSource ) ||
                   ( locations & IFFindDocumentationDefinitions )) {
                    [self addDocumentation];
                }
                if( locations & IFFindExtensions ) {
                    [self addExtensions: project];
                }
                if( locations & IFFindSource ) {
                    [self addSourceFiles: project];
                }
            }
        }

        // Start a thread to do the search... GCD style
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(queue,
        ^{
            [self searchThreadWithPhrase: searchPhrase
                              searchType: searchType
                               locations: locations
                           progressBlock: progressBlock];
        });
    }
}

@end
