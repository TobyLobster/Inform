//
//  ZoomZMachine.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZoomProtocol.h"
#import "ZoomServer.h"

extern void cocoa_debug_handler(ZDWord pc);

extern struct BlorbImage* zoomImageCache;
extern int zoomImageCacheSize;
extern int zDisplayCurrentWindow;
extern ZStyle* zDisplayCurrentStyle;
extern BOOL zPixmapDisplay;

@interface ZoomZMachine : NSObject<ZMachine> {
    // Remote objects
    id<ZDisplay> display;
    id<ZWindow>  windows[3];
    NSMutableAttributedString* windowBuffer[3];

    // The file
	NSData* storyData;
	NSData* dataToRestore;
    ZFile* machineFile;

    // Some pieces of state information
    NSMutableString* inputBuffer;
    ZBuffer*         outputBuffer;
	
	int terminatingCharacter;
    
    BOOL             filePromptFinished;
    id<ZFile>        lastFile;
    NSInteger        lastSize;
	
	BOOL wasRestored;
	
	int mousePosX, mousePosY;
	
	// Debugging state
	BOOL waitingForBreakpoint;
}

@property (readonly, strong) id<ZDisplay> display;
- (id<ZWindow>)  windowNumber: (int) num;
@property (readonly, strong) NSMutableString *inputBuffer;
@property (readonly) int terminatingCharacter;

@property (readonly) int mousePosX;
@property (readonly) int mousePosY;

- (void)                filePromptStarted;
@property (readonly) BOOL filePromptFinished;
@property (readonly, strong) id<ZFile> lastFile;
@property (readonly) NSInteger lastSize;
- (void)                clearFile;

@property (readonly, strong) ZBuffer *buffer;
- (void) flushBuffers;

- (void) breakpoint: (int) pc;

- (void) connectionDied: (NSNotification*) notification;

@end
