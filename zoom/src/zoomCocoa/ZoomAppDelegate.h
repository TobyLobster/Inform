//
//  ZoomAppDelegate.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Oct 14 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <ZoomView/ZoomProtocol.h>
#import "ZoomPreferenceWindow.h"
#import <ZoomPlugIns/ZoomMetadata.h>
#import <ZoomPlugIns/ZoomStory.h>
#import "ZoomiFictionController.h"
#import <ZoomView/ZoomView.h>
#import "ZoomLeopard.h"

NS_ASSUME_NONNULL_BEGIN

@class SUUpdater;
@interface ZoomAppDelegate : NSObject <NSApplicationDelegate, NSOpenSavePanelDelegate, NSMenuItemValidation> {
	ZoomPreferenceWindow* preferencePanel;
	IBOutlet SUUpdater* updater;
	
	NSMutableArray<ZoomMetadata*>* gameIndices;
	id<ZoomLeopard> leopard;
}

@property (readonly, copy) NSArray<ZoomMetadata*> *gameIndices;
- (nullable ZoomStory*) findStory: (ZoomStoryID*) gameID;
- (ZoomMetadata*) userMetadata;

@property (readonly, copy, null_unspecified) NSString *zoomConfigDirectory;
@property (readonly, strong) id<ZoomLeopard> leopard;

- (IBAction) fixedOpenDocument: (nullable id) sender;
- (IBAction) showPluginManager: (nullable id) sender;
- (IBAction) checkForUpdates: (nullable id) sender;

@end

BOOL urlIsAvailableAndIsDirectory(NSURL *url, BOOL *__nullable isDirectory, BOOL *__nullable isPackage, BOOL *__nullable isReadable, NSError **error) NS_SWIFT_NAME(urlIsAvailable(_:isDirectory:isPackage:isReadable:error:)) NS_SWIFT_NOTHROW;

NS_ASSUME_NONNULL_END
