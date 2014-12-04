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

extern NSAutoreleasePool* displayPool;

extern void cocoa_debug_handler(ZDWord pc);

extern struct BlorbImage* zoomImageCache;
extern int zoomImageCacheSize;

@interface ZoomZMachine : NSObject<ZMachine> {
    // Remote objects
    NSObject<ZDisplay>* display;
    NSObject<ZWindow>*  windows[3];
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
    NSObject<ZFile>* lastFile;
    int              lastSize;
	
	BOOL wasRestored;
	
	int mousePosX, mousePosY;
	
	// Debugging state
	BOOL waitingForBreakpoint;
}

- (NSObject<ZDisplay>*) display;
- (NSObject<ZWindow>*)  windowNumber: (int) num;
- (NSMutableString*)    inputBuffer;
- (int)					terminatingCharacter;

- (int) mousePosX;
- (int) mousePosY;

- (void)                filePromptStarted;
- (BOOL)                filePromptFinished;
- (NSObject<ZFile>*)    lastFile;
- (int)                 lastSize;
- (void)                clearFile;

- (ZBuffer*) buffer;
- (void) flushBuffers;

- (void) breakpoint: (int) pc;

- (void) connectionDied: (NSNotification*) notification;

@end
