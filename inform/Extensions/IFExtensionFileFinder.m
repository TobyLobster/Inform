//
//  IFExtensionFileFinder.m
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//

#import "IFExtensionFileFinder.h"
#import "IFExtensionsManager.h"

@implementation IFExtensionFileFinder

+ (NSString*) fileForExtension: (NSString*) filename
             extensionsManager: (IFExtensionsManager*) extensionsManager {
    // Get the author and extension name
    NSArray* components = filename.pathComponents;
    if (components.count != 2) {
        if ([filename characterAtIndex: 0] == '/' && [[NSFileManager defaultManager] fileExistsAtPath: filename]) {
            return filename;
        }
        return nil;
    }

    NSString* author = components[0];
    NSString* extension = components[1];

    // Search for this extension
    NSArray* possibleExtensions = [extensionsManager filesInExtensionWithName: author];
    if (possibleExtensions.count <= 0) return nil;

    for( NSString* extnFile in possibleExtensions ) {
        if ([extnFile.lastPathComponent caseInsensitiveCompare: extension] == NSOrderedSame) {
            // This is the extension file we need to open
            return extnFile;
        }
    }

    return nil;
}

@end
