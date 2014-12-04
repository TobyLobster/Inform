//
//  ZoomClient.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "ZoomProtocol.h"
#import "ZoomStory.h"
#import "ZoomSkein.h"
#import "ZoomBlorbFile.h"

@class ZoomView;
@interface ZoomClient : NSDocument {
    NSData* gameData;
	
	ZoomStory* story;
	ZoomStoryID* storyId;
	
	NSData* autosaveData;
	
	ZoomView*  defaultView;
	ZoomSkein* skein;
	NSData*   saveData;
	
	ZoomBlorbFile* resources;
	
	BOOL wasRestored;
	
	NSMutableArray* loadingErrors;
}

- (NSData*) gameData;
- (ZoomStory*) storyInfo;
- (ZoomStoryID*) storyId;
- (ZoomSkein*)   skein;

// Restoring from an autosave
- (void) loadDefaultAutosave;
- (void) setAutosaveData: (NSData*) data;
- (NSData*) autosaveData;

// Loading a zoomSave file
- (ZoomView*) defaultView;
- (NSData*)   saveData;
- (void)	  setSaveData: (NSData*) saveData;

// Resources
- (void)           setResources: (ZoomBlorbFile*) resources;
- (ZoomBlorbFile*) resources;

// Errors that might have happened but we recovered from (for example, resources not found)
- (void) addLoadingError: (NSString*) loadingError;
- (NSArray*) loadingErrors;

@end
