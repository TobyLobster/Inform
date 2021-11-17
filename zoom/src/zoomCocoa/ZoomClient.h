//
//  ZoomClient.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <ZoomView/ZoomProtocol.h>
#import <ZoomPlugIns/ZoomStory.h>
#import <ZoomView/ZoomSkein.h>
#import <ZoomView/ZoomBlorbFile.h>
#import <ZoomView/ZoomView.h>

@interface ZoomClient : NSDocument

@property (readonly, retain) NSData *gameData;
@property (readonly, retain) ZoomStory *storyInfo;
@property (readonly, retain) ZoomStoryID *storyId;
@property (readonly, retain) ZoomSkein *skein;

/// Restoring from an autosave
- (void) loadDefaultAutosave;
@property (retain) NSData *autosaveData;

// Loading a zoomSave file
@property (readonly, retain) ZoomView *defaultView;
@property (copy) NSData *saveData;

/// Resources
@property (retain) ZoomBlorbFile *resources;

/// Errors that might have happened but we recovered from (for example, resources not found)
- (void) addLoadingError: (NSString*) loadingError;
@property (readonly, nonatomic, copy) NSArray<NSString*> *loadingErrors;

@end
