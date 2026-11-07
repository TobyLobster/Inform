//
//  IFSingleFile.m
//  Inform
//
//  Created by Andrew Hunter on 23/06/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "IFSingleFile.h"
#import "IFSingleController.h"
#import "IFProjectTypes.h"

#import "IFSyntaxManager.h"
#import "IFNaturalIntel.h"
#import "IFUtility.h"

@implementation IFSingleFile {
    /// The contents of the file
    NSTextStorage* fileStorage;
    /// The encoding used for the file
    NSStringEncoding fileEncoding;
    
    NSRange initialSelectionRange;
}

#pragma mark - Initialisation

- (instancetype) init {
	self = [super init];
	
	if (self) {
		fileStorage = [[NSTextStorage alloc] init];
		fileEncoding = NSUTF8StringEncoding;
	}
	
	return self;
}

- (void) dealloc {
    [IFSyntaxManager unregisterTextStorage: fileStorage];
}

#pragma mark - Data

- (void)makeWindowControllers {
    IFSingleController *aController = [[IFSingleController alloc] initWithInitialSelectionRange: initialSelectionRange];
    [self addWindowController:aController];
}

- (NSData *)dataOfType: (NSString*) type error:(NSError *__autoreleasing  _Nullable * _Nullable)outError {
    NSData* data = [fileStorage.string dataUsingEncoding: fileEncoding];

    // The text has characters the file's encoding can't hold
    if (data == nil && outError) {
        *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                        code: NSFileWriteInapplicableStringEncodingError
                                    userInfo: @{NSStringEncodingErrorKey: @(fileEncoding)}];
    }
    return data;
}

- (BOOL)readFromData: (NSData*) data
              ofType: (NSString*) type
               error: (NSError *__autoreleasing  _Nullable * _Nullable)outError {
    IFHighlightType                     highlightType   = IFHighlightTypeNone;
    id<IFSyntaxIntelligence>            intel           = nil;

	fileEncoding = NSUTF8StringEncoding;

    //
	// Use the appropriate highlighter, intelligence and encoding, based on the file type
    //
    switch( [IFProjectTypes fileTypeFromString: type] ) {
        case IFFileTypeInform6ICLFile: {
            // No highlighter currently available for ICL files, and they're latin-1
            fileEncoding = NSISOLatin1StringEncoding;
            break;
        }
        case IFFileTypeInform6SourceFile: {
            fileEncoding = NSISOLatin1StringEncoding;
            highlightType = IFHighlightTypeInform6;
            break;
        }
        case IFFileTypeInform7SourceFile:
        case IFFileTypeInform7ExtensionFile: {
            highlightType = IFHighlightTypeInform7;
            intel = [[IFNaturalIntel alloc] init];
            break;
        }
        case IFFileTypeInform7Project:
        case IFFileTypeInform7ExtensionProject:
        case IFFileTypeInform6ExtensionProject:
        case IFFileTypeUnknown:
        default: {
            NSAssert(false, @"Found invalid file type %d from type '%@'", (int) [IFProjectTypes fileTypeFromString: type], type);
            break;
        }
    }

	// Create the file data
	NSString* fileString = [[NSString alloc] initWithData: data
												 encoding: fileEncoding];
	if (fileString == nil) {
        // If opening with the suggested encoder doesn't work, fall back to using Latin1
		fileEncoding = NSISOLatin1StringEncoding;
		fileString = [[NSString alloc] initWithData: data
										   encoding: fileEncoding];
	}

	if (fileString == nil) {
        if (outError) {
            *outError = [NSError errorWithDomain: NSCocoaErrorDomain code: NSFileReadUnknownStringEncodingError userInfo:
                         @{NSLocalizedDescriptionKey: @"Error: failed to load file: could not find an acceptable character encoding",
                           NSStringEncodingErrorKey : @(fileEncoding)}
            ];
        }
		NSLog(@"Error: failed to load file: could not find an acceptable character encoding");
		return NO;
	}

    // Read again, as by Revert To Saved: the window shows this storage, so it's given the new text
    if ([IFSyntaxManager isRegistered: fileStorage]) {
        [fileStorage replaceCharactersInRange: NSMakeRange(0, fileStorage.length)
                                   withString: fileString];
        return YES;
    }

    // Update fileStorage
	fileStorage = [[NSTextStorage alloc] initWithString: fileString];
    [IFSyntaxManager registerTextStorage: fileStorage
                                    name: @"single file"
                                    type: highlightType
                            intelligence: intel
                             undoManager: self.undoManager];
    return YES;
}

#pragma mark - Retrieving document data

@synthesize storage = fileStorage;

#pragma mark - Whether or not this should be treated as read-only

- (BOOL) isReadOnly {
	if (self.fileURL == nil) return NO;

	NSString* filename = (self.fileURL.path).stringByStandardizingPath;

	// Files in the extensions directory in the application should be treated as read-only
    NSString* appDir = [IFUtility pathForInformInternalExtensions:@""];

	if ([filename.lowercaseString hasPrefix: appDir.lowercaseString]) {
		return YES;
	}

	// Default is read-write
	return NO;
}

- (BOOL)validateMenuItem:(NSMenuItem*) menuItem {
	if (menuItem.action == @selector(saveDocument:)) {
		return !self.readOnly;
	}
	
	return YES;
}

@synthesize initialSelectionRange;

@end
