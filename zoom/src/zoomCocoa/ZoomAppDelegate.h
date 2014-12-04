//
//  ZoomAppDelegate.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Oct 14 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZoomProtocol.h"
#import "ZoomPreferenceWindow.h"
#import "ZoomMetadata.h"
#import "ZoomStory.h"
#import "ZoomiFictionController.h"
#import "ZoomView.h"
#import "ZoomLeopard.h"

@class SUUpdater;
@interface ZoomAppDelegate : NSObject {
	ZoomPreferenceWindow* preferencePanel;
	IBOutlet SUUpdater* updater;
	
	NSMutableArray* gameIndices;
	id<ZoomLeopard> leopard;
}

- (NSArray*) gameIndices;
- (ZoomStory*) findStory: (ZoomStoryID*) gameID;
- (ZoomMetadata*) userMetadata;

- (NSString*) zoomConfigDirectory;
- (id<ZoomLeopard>) leopard;

- (IBAction) fixedOpenDocument: (id) sender;
- (IBAction) showPluginManager: (id) sender;
- (IBAction) checkForUpdates: (id) sender;

@end
