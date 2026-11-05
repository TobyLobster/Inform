//
//  IFExtensionDownload.m
//  Inform
//
//  Created by Andrew Hunter on 06/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//  Rewritten by Toby Nelson in 2014.
//

#import "IFExtensionDownload.h"
#import "IFExtensionsManager.h"
#import "IFNewExtensionsManager.h"
#import "IFUtility.h"
#import "IFAppDelegate.h"
#import "IFProject.h"
#import "IFProjectController.h"

@interface IFExtensionDownload () <NSURLSessionDataDelegate>

@end

@implementation IFExtensionDownload {
    NSURLSession *urlSession;
}

-(instancetype) initWithURL: (NSURL*) url
           window: (NSWindow*) aWindow
   notifyDelegate: (NSObject*) notifyDelegate
     javascriptId: (NSString*) javascriptId {
	self = [super init];

	if (self) {
        self.url            = url;
        self.state          = IFExtensionDownloadNotStarted;
        self.window         = aWindow;
        self.receivedData   = [NSMutableData data];
        self.notifyDelegate = notifyDelegate;
        self.javascriptId   = javascriptId;
    }

    return self;
}


#pragma mark - Download and Install

- (BOOL) startDownloadAndInstall {
    // Create the request
    NSURLRequest *theRequest = [NSURLRequest requestWithURL: self.url
                                                cachePolicy: NSURLRequestUseProtocolCachePolicy
                                            timeoutInterval: 10.0];

    // The session keeps this download until it's invalidated, once the task is finished
    urlSession = [NSURLSession sessionWithConfiguration: NSURLSessionConfiguration.ephemeralSessionConfiguration
                                               delegate: self
                                          delegateQueue: nil];

    // Create the connection with the request and start loading the data
    self.connection = [urlSession dataTaskWithRequest: theRequest];
    self.state          = IFExtensionDownloadInProgress;

    // Start the task
    [self.connection resume];

    return YES;
}

- (void)URLSession: (NSURLSession *)session
          dataTask: (NSURLSessionDataTask *)dataTask
didReceiveResponse: (NSURLResponse *)response
 completionHandler: (void (^)(NSURLSessionResponseDisposition))completionHandler
{
    if (dataTask == self.connection)
    {
        if ( [response isKindOfClass: [NSHTTPURLResponse class]] )
        {
            NSUInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
            if (statusCode >= 400)
            {
                NSString* localizedStringForStatusCode = [NSHTTPURLResponse localizedStringForStatusCode: statusCode];
                completionHandler(NSURLSessionResponseCancel);// stop connecting; no more delegate messages
                NSDictionary *errorInfo = @{NSLocalizedDescriptionKey: [NSString stringWithFormat:
                                                      [IFUtility localizedString:@"Server returned status code %d, local string %@"],
                                                      (int)statusCode, localizedStringForStatusCode]};
                NSError *statusError = [NSError errorWithDomain: @"Error"
                                                           code: statusCode
                                                       userInfo: errorInfo];
                [self   URLSession: session
                              task: dataTask
              didCompleteWithError: statusError];
                return;
            }
        }

        // This method is called when the server has determined that it
        // has enough information to create the NSURLResponse object.
        
        // It can be called multiple times, for example in the case of a
        // redirect, so each time we reset the data.
        
        (self.receivedData).length = 0;
    }
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession: (NSURLSession *)session
          dataTask: (NSURLSessionDataTask *)dataTask
    didReceiveData: (NSData *)data
{
    if (dataTask == self.connection)
    {
        // do something with the data object.
        [self.receivedData appendData:data];
    }
}

// *******************************************************************************************
- (void) downloadedTask: (NSURLSessionTask*) task error: (NSError*) error {
    IFExtensionsManager* mgr = [IFExtensionsManager sharedNaturalInformExtensionsManager];

    if (error) {
        //NSString* file = [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey];

        // Log message
        NSString* message = [NSString stringWithFormat:[IFUtility localizedString: @"Failed to Download Extension Explanation - %@"],
                             error.localizedDescription];

        [mgr addError: message];

        self.state        = IFExtensionDownloadFailed;
        self.connection   = nil;
        self.receivedData = nil;

        [mgr downloadAndInstallFinished: self];
        return;
    }

    // Get temporary filename
    char tempFilename[256];
    snprintf(tempFilename, 255, "%stemp.XXXXXX.zip", [NSTemporaryDirectory() fileSystemRepresentation]);
    int result = mkstemps(tempFilename,4);
    if( result != -1 ) {
        // Only the name is needed: the file is written below
        close(result);

        NSString* filename = [[NSFileManager defaultManager] stringWithFileSystemRepresentation: tempFilename
                                                                                         length: strlen(tempFilename)];
        // Save the data to a temporary file
        if( [self.receivedData writeToFile: filename
                                atomically: YES] ) {
            // Install this extension
            NSURL *url = [NSURL fileURLWithPath: filename isDirectory: NO];
            IFAppDelegate* appDelegate = (IFAppDelegate*)NSApp.delegate;
            IFProjectController * projectController = appDelegate.frontmostProjectController;
            BOOL installing = NO;
            if (projectController) {
                IFProject * project = projectController.document;
                NSString *name = [task.originalRequest.URL lastPathComponent];
                NSURL *extensionURL = [[IFNewExtensionsManager sharedNewExtensionsManager] copyWithUnzip: url
                                                                                      toProjectTemporary: project
                                                                                           extensionName: name];
                if (extensionURL) {
                    // Call inbuild to check it's a valid extension and install
                    [projectController installExtensionURL: extensionURL];
                    installing = YES;
                }
            }

            // Remove temporary file
            NSError* ourError;
            [[NSFileManager defaultManager] removeItemAtPath: filename
                                                       error: &ourError];

            // Only report success if the extension was handed over to be installed
            self.state = installing ? IFExtensionDownloadAndInstallSucceeded : IFExtensionInstallFailed;
        }
        else {
            self.state = IFExtensionInstallFailed;
            // Log error
            NSString* message = [NSString stringWithFormat: [IFUtility localizedString: @"Failed to Install Extension Explanation - Could not write to file '%@'"], filename];
            [mgr addError: message];
        }
    }
    else {
        self.state = IFExtensionInstallFailed;
        [mgr addError: [IFUtility localizedString: @"Failed to Install Extension Explanation - Could not make temporary filename"]];
    }

    self.connection     = nil;
    self.receivedData   = nil;

    [mgr downloadAndInstallFinished: self];
}

// *******************************************************************************************
- (void)   URLSession: (NSURLSession *)session
                 task: (NSURLSessionTask *)task
 didCompleteWithError: (NSError *)error
{
    if (task == self.connection)
    {
        // Let go of the session, so that it lets go of this download
        [session finishTasksAndInvalidate];

        // Process the downloaded data on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [self downloadedTask: task error: error];
        });
    }
}

@end
