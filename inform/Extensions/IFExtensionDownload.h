//
//  IFExtensionDownload.h
//  Inform
//
//  Created by Andrew Hunter on 06/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(int, IFExtensionDownloadState) {
    IFExtensionDownloadNotStarted,
    IFExtensionDownloadInProgress,
    IFExtensionDownloadFailed,
    IFExtensionInstallFailed,
    IFExtensionDownloadAndInstallSucceeded,
};

@interface IFExtensionDownload : NSObject

@property (atomic) IFExtensionDownloadState state;
@property (atomic, strong, nullable) NSURLSessionDataTask* connection;
@property (atomic, strong, nullable) NSMutableData*   receivedData;
@property (atomic, strong, nullable) NSWindow*        window;
@property (atomic, strong, nullable) NSString*        javascriptId;
/// The controller of the project whose page started the download, which the extension is installed in
@property (atomic, strong, nullable) NSObject*        notifyDelegate;
@property (atomic, strong) NSURL*           url;

// Download and install
- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithURL: (NSURL*) url
                      window: (nullable NSWindow*) aWindow
              notifyDelegate: (nullable NSObject*) notifyDelegate
                javascriptId: (nullable NSString*) javascriptId NS_DESIGNATED_INITIALIZER;

-(BOOL) startDownloadAndInstall;

@end

NS_ASSUME_NONNULL_END
