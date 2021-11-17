//
//  IFProjectMaterialsPresenter.h
//  Inform
//
//  Created by Toby Nelson in 2014
//
// This class allows us to read/write to a project's materials folder in a sandboxed app.

#import "IFProjectMaterialsPresenter.h"
#import "IFImageCache.h"
#import "IFUtility.h"

@implementation IFProjectMaterialsPresenter {
    NSURL* primaryURL;
    NSURL* secondaryURL;
    NSURL* moveURL;

    NSOperationQueue* queue;
}

- (instancetype) init { self = [super init]; return self; }

- (instancetype) initWithURL:(NSURL*) mainURL {
    self = [super init];
    if( self ) {
        if( [mainURL isFileURL] ) {
            primaryURL          = mainURL;
            secondaryURL        = [[mainURL URLByDeletingPathExtension] URLByAppendingPathExtension: @"materials"];
            NSString* moveName  = [[[mainURL URLByDeletingPathExtension] lastPathComponent] stringByAppendingString: @" Materials"];
            moveURL             = [[mainURL URLByDeletingLastPathComponent] URLByAppendingPathComponent: moveName];
        } else {
            primaryURL          = nil;
            secondaryURL        = nil;
            moveURL             = nil;
        }
        queue = [NSOperationQueue new];
        
        if( [IFUtility isSandboxed] ) {
            [NSFileCoordinator addFilePresenter: self];
            [NSFileCoordinator filePresenters];
        }
        
        [self createFolder];
    }
    return self;
}

-(void) dealloc {
    if( [IFUtility isSandboxed] ) {
        [NSFileCoordinator removeFilePresenter: self];
    }
}

- (NSURL *) presentedItemURL {
    return secondaryURL;
}

- (NSOperationQueue *) presentedItemOperationQueue {
    return queue;
}

- (NSURL *) primaryPresentedItemURL {
    return primaryURL;
}

- (void) createFolder {
    NSError* error;
    
    // move old folder, if present
    BOOL isDirectory = NO;
    if( ![[NSFileManager defaultManager] fileExistsAtPath: [secondaryURL path]] ) {
        if( [[NSFileManager defaultManager] fileExistsAtPath: [moveURL path] isDirectory: &isDirectory] ) {
            if( isDirectory == YES ) {
                if( [[NSFileManager defaultManager] moveItemAtURL: moveURL
                                                            toURL: secondaryURL
                                                            error: nil] ) {
                    NSString* message = [NSString stringWithFormat: [IFUtility localizedString: @"Note: This version of Inform stores materials in a '.materials' folder. The folder '%@' has been renamed to '%@'"],
                                                                     [moveURL lastPathComponent], [secondaryURL lastPathComponent]];
                    [IFUtility runAlertInformationWindow: nil
                                                   title: @"Materials folder has been renamed"
                                                 message: message];
                }
            }
        }
    }

    NSFileWrapper * wrapper = [[NSFileWrapper alloc] initWithURL: secondaryURL
                                                         options: NSFileWrapperReadingWithoutMapping
                                                           error: &error];

    // Create folder at secondaryURL (the materials folder), if not already there, then set it's icon
    if( !wrapper ) {
        wrapper = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: @{}];

        BOOL didCreateFolder = [wrapper writeToURL: secondaryURL
                                           options: NSFileWrapperWritingAtomic
                               originalContentsURL: nil
                                             error: &error];

        if( !didCreateFolder ) {
            NSLog(@"WARNING: Could not create materials folder at URL %@", secondaryURL);
            return;
        }
    }

    // Add icon to folder
    NSImage* image = [NSImage imageNamed: @"materialsfile"];
    BOOL didSetIcon = [[NSWorkspace sharedWorkspace] setIcon: image
                                                     forFile: [secondaryURL path]
                                                     options: (NSWorkspaceIconCreationOptions) 0];
    if( !didSetIcon ) {
        NSLog(@"Could not set icon for materials folder at URL %@", secondaryURL);
    }
}

@end
