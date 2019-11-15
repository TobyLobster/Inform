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
#import "IFNaturalHighlighter.h"
#import "IFNaturalIntel.h"
#import "IFPreferences.h"
#import "IFCompilerSettings.h"
#import "IFUtility.h"

@implementation IFSingleFile {
    NSTextStorage* fileStorage;						// The contents of the file
    NSStringEncoding fileEncoding;					// The encoding used for the file
    NSRange initialSelectionRange;
}

// = Initialisation =

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

    fileStorage = nil;
}

// = Data =

- (void)makeWindowControllers {
    IFSingleController *aController = [[IFSingleController alloc] initWithInitialSelectionRange: initialSelectionRange];
    [self addWindowController:aController];
}

- (NSData *)dataRepresentationOfType: (NSString*) type {
    return [[fileStorage string] dataUsingEncoding: fileEncoding];
}

- (BOOL)loadDataRepresentation: (NSData*) data
						ofType: (NSString*) type {
    IFHighlightType                     highlightType   = IFHighlightTypeNone;
    id<IFSyntaxIntelligence,NSObject>   intel           = nil;

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
		NSLog(@"Error: failed to load file: could not find an acceptable character encoding");
		return NO;
	}

    // Update fileStorage
	fileStorage = [[NSTextStorage alloc] initWithString: fileString];
    [IFSyntaxManager registerTextStorage: fileStorage
                                    name: @"single file"
                                    type: highlightType
                            intelligence: intel
                             undoManager: [self undoManager]];
    return YES;
}

// = Retrieving document data =

- (NSTextStorage*) storage {
	return fileStorage;
}

// = Whether or not this should be treated as read-only =

- (BOOL) isReadOnly {
	if (self.fileURL.path == nil) return NO;

	NSString* filename = [self.fileURL.path stringByStandardizingPath];

	// Files in the extensions directory in the application should be treated as read-only
    NSString* appDir = [IFUtility pathForInformInternalExtensions:@""];

	if ([[filename lowercaseString] hasPrefix: [appDir lowercaseString]]) {
		return YES;
	}

	// Default is read-write
	return NO;
}

- (BOOL)validateMenuItem:(NSMenuItem*) menuItem {
	if ([menuItem action] == @selector(saveDocument:)) {
		return ![self isReadOnly];
	}
	
	return YES;
}

-(void) setInitialSelectionRange: (NSRange) anInitialSelectionRange {
    initialSelectionRange = anInitialSelectionRange;
}

-(NSRange) initialSelectionRange {
    return initialSelectionRange;
}

@end
