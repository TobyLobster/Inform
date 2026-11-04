//
//  IFNewExtensionsManager.m
//  Inform
//
//  Created by Toby Nelson on 21/04/2023.
//

#import "IFNewExtensionsManager.h"
#import "IFUtility.h"
#import "IFProject.h"
#import "NSString+IFStringExtensions.h"

// *******************************************************************************************
@implementation IFNewExtensionsManager {
}

#pragma mark - Shared extension manager

+ (IFNewExtensionsManager*) sharedNewExtensionsManager {
	static IFNewExtensionsManager* mgr = nil;

	if (!mgr) {
		mgr = [[IFNewExtensionsManager alloc] init];
	}

	return mgr;
}

#pragma mark - Initialisation

- (instancetype) init {
	self = [super init];

	if (self) {
	}

	return self;
}

- (void) dealloc {
}

#pragma mark - Methods

- (NSURL*) copyWithUnzip: (NSURL *) sourceURL
      toProjectTemporary: (IFProject *) project
           extensionName: (NSString *) name {
    NSURL* destinationURL = [[[project.materialsDirectoryURL URLByAppendingPathComponent: @"Extensions"]
                             URLByAppendingPathComponent: @"Reserved"]
                             URLByAppendingPathComponent: @"Temporary" isDirectory: true];
    return [self copyWithUnzip: sourceURL
                            to: destinationURL
                 extensionName: name];
}


// Returns a URL of the downloaded file (or the .i7xd directory inside an unzipped zip file)
- (NSURL*) copyWithUnzip: (NSURL *) sourceURL
                      to: (NSURL *) destinationURL
           extensionName: (NSString *) name {
    NSError *error;

    if ([sourceURL.pathExtension.lowercaseString isEqualToString: @"zip"]) {
        if ([IFUtility unzip: sourceURL
                 toDirectory: destinationURL]) {
            name = [[name stringByDeletingPathExtension] stringByAppendingPathExtension: @"i7xd"];
            return [destinationURL URLByAppendingPathComponent: name];
        }
        return nil;
    }
    NSFileManager* fm = [NSFileManager defaultManager];

    // Remove any existing file or directory
    [fm removeItemAtURL:destinationURL error:nil];
    // Create destination directory
    [fm createDirectoryAtURL: destinationURL
 withIntermediateDirectories: YES
                  attributes: nil
                       error: &error];
    destinationURL = [destinationURL URLByAppendingPathComponent: name];
    if (![fm copyItemAtURL: sourceURL
                     toURL: destinationURL
                     error: &error] ) {
        if( error != nil ) {
            [IFUtility runAlertWarningWindow: nil
                                       title: [IFUtility localizedString:@"Error"]
                                     message: @"%@", error.localizedDescription];
        }
        return nil;
    }
    return destinationURL;
}

@end
