//
//  IFProjectTypes.m
//  Inform
//
//  Created by Toby nelson in 2014.
//

#import "IFProjectTypes.h"
#import "IFPreferences.h"

NSString* const IFProjectFilesChangedNotification         = @"IFProjectFilesChangedNotification";
NSString* const IFProjectBreakpointsChangedNotification   = @"IFProjectBreakpointsChangedNotification";
NSString* const IFProjectSourceFileRenamedNotification    = @"IFProjectSourceFileRenamedNotification";

@implementation IFProjectTypes

+(NSStringEncoding) encodingForFilename: (NSString*) filename {
	NSString* extn = filename.pathExtension.lowercaseString;
    
	if ( [extn isEqualToString: @"inf"] ||
         [extn isEqualToString: @"i6"] ||
         [extn isEqualToString: @"icl"] ||
         [extn isEqualToString: @"txt"] ||
         [extn isEqualToString: @"h"] ) {
		// Latin1 encoding
		return NSISOLatin1StringEncoding;
	}

    if ( [extn isEqualToString: @"ni"] ||
         [extn isEqualToString: @"i7"] ||
         [extn isEqualToString: @"i7x"] ||
         [extn isEqualToString: @"html"] ||
         [extn isEqualToString: @"htm"] ||
         [extn isEqualToString: @""] ) {
		// UTF8 encoding
		return NSUTF8StringEncoding;
	}

    // Unknown file type, assuming UTF8 encoding
    NSLog(@"Couldn't find encoding for file %@, assuming UTF8", filename);
	return NSUTF8StringEncoding;
}

+(IFInformVersion) informVersionForFilename: (NSString*) filename {
	NSString* extn = filename.pathExtension.lowercaseString;
    
	if ( [extn isEqualToString: @"inf"] ||
		 [extn isEqualToString: @"i6"] ||
		 [extn isEqualToString: @"h"] ) {
		// Inform 6 file
		return IFInformVersion6;
	}
    
    if ([extn isEqualToString: @"ni"] ||
	    [extn isEqualToString: @"i7"] ||
	    [extn isEqualToString: @"i7x"] ||
	    [extn isEqualToString: @""]) {
		// Natural Inform file
		return IFInformVersion7;
	}

	return IFInformVersionUnknown;
}

+(IFFileType) fileTypeFromString:(NSString*) typeName {
    typeName = typeName.lowercaseString;
    
    if ( [typeName isEqualTo: @"inform project file"] ||
         [typeName isEqualTo: @"inform project"] ||
         [typeName isEqualTo: @"org.inform-fiction.project"] ) {
        return IFFileTypeInform7Project;
    }

    if ([typeName isEqualTo: @"org.inform-fiction.xproject"] ) {
        return IFFileTypeInform7ExtensionProject;
    }

    //
    // Inform 6 source file
    //
    if ( [typeName isEqualTo: @"inform 6 source file"] ||
         [typeName isEqualTo: @"org.inform-fiction.source.inform6"] ) {
        return IFFileTypeInform6SourceFile;
    }
    //
    // Inform 7 source file
    //
    if ( [typeName isEqualTo: @"natural inform source file"] ||
         [typeName isEqualTo: @"inform 7 source file"] ||
         [typeName isEqualTo: @"org.inform-fiction.source.inform7"] ) {
        return IFFileTypeInform7SourceFile;
    }

    //
    // Inform 6 Extension Project
    //
    if ([typeName isEqualTo: @"inform extension Directory"]) {
        return IFFileTypeInform6ExtensionProject;
    }

    //
    // Inform 6 ICL file
    //
	if ([typeName isEqualTo: @"inform control language file"] ||
        [typeName isEqualToString: @"public.c-header"]) {
        return IFFileTypeInform6ICLFile;
	}

    //
    // Inform 7 Extension File
    //
    if ( [typeName isEqualToString: @"inform 7 extension"] ||
         [typeName isEqualToString: @"org.inform-fiction.inform7.extension"] ) {
        return IFFileTypeInform7ExtensionFile;
	}
    
    NSLog(@"Unknown file type '%@' found", typeName);
    return IFFileTypeUnknown;
}

+(IFHighlightType) highlighterTypeForFilename: (NSString*) filename {
    IFInformVersion version = [IFProjectTypes informVersionForFilename: filename];
    switch( version ) {
        case IFInformVersion6:       return IFHighlightTypeInform6;   // Inform 6 file
        case IFInformVersion7:       return IFHighlightTypeInform7;   // Inform 7 file
        case IFInformVersionUnknown:
        default:                     return IFHighlightTypeNone;
	}
}


+ (NSObject<IFSyntaxIntelligence>*) intelligenceForFilename: (NSString*) filename {

    IFInformVersion version = [IFProjectTypes informVersionForFilename: filename];
    switch( version ) {
        case IFInformVersion6:       return nil;                            // Inform 6 file (no intelligence yet)
        case IFInformVersion7:       return [[IFNaturalIntel alloc] init];  // Inform 7 file
        case IFInformVersionUnknown: return nil;                            // Unknown file type - no intelligence
    }

	// No intelligence
	return nil;
}

@end
