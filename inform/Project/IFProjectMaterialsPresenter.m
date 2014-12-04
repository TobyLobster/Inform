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

@implementation IFProjectMaterialsPresenter

- (id) initWithURL:(NSURL*) mainURL {
    self = [super init];
    if( self ) {
        primaryURL = [mainURL retain];
        if( [mainURL isFileURL] ) {
            secondaryURL = [[[mainURL URLByDeletingPathExtension] URLByAppendingPathExtension: @"materials"] retain];
            NSString* moveName = [[[mainURL URLByDeletingPathExtension] lastPathComponent] stringByAppendingString: @" Materials"];
            moveURL = [[[mainURL URLByDeletingLastPathComponent] URLByAppendingPathComponent: moveName] retain];
        } else {
            secondaryURL = nil;
            primaryURL = nil;
            moveURL = nil;
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
    [primaryURL release];
    [secondaryURL release];
    [super dealloc];
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
        wrapper = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: nil];

        BOOL didCreateFolder = [wrapper writeToURL: secondaryURL
                                           options: NSFileWrapperWritingAtomic
                               originalContentsURL: nil
                                             error: &error];

        if( !didCreateFolder ) {
            NSLog(@"WARNING: Could not create materials folder at URL %@", secondaryURL);
            [wrapper release];
            return;
        }
    }
    [wrapper release];

    // Add icon to folder
    NSImage* image = [IFImageCache loadResourceImage: @"App/Icons/materialsfile.icns"];
    BOOL didSetIcon = [[NSWorkspace sharedWorkspace] setIcon: image
                                                     forFile: [secondaryURL path]
                                                     options: (NSWorkspaceIconCreationOptions) 0];
    if( !didSetIcon ) {
        NSLog(@"Could not set icon for materials folder at URL %@", secondaryURL);
    }
}

@end
