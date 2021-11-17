//
//  ZoomServer.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomServer.h"
#import "ZoomZMachine.h"

#include <sys/types.h>
#include <unistd.h>
#include "zmachine.h"

NSRunLoop*         mainLoop = nil;

ZoomZMachine*      mainMachine = nil;

// == The main() function ==
int main(int argc, char** argv) {
    @autoreleasepool {
        // Create the main runloop
    mainLoop = [NSRunLoop currentRunLoop];

	
#ifdef DEBUG
    {
		NSLog(@"DEBUG");
        int x;
        for (x=0; x<10; x++) {
            NSLog(@"...%i...", 10-x);
            sleep(1);
        }
    }
#endif
	
    // Indicates that the client should be able to connect
    NSLog(@"Server ready");
	
	// Connect to the view process
	id<ZClient> client = nil;
	NSString* connectionName = [NSString stringWithFormat: @"Zoom-%s",
		argv[1]];

	NSConnection* remoteConnection = [NSConnection connectionWithRegisteredName: connectionName
																		   host: nil];
	
	if (remoteConnection == nil) {
		NSLog(@"Warning: unable to locate connection %@. Aborting.", connectionName);
	}
	
	client = (id<ZClient>)[remoteConnection rootProxy];
	
	if (client == nil) {
		NSLog(@"Unable to locate client object for connection %@. Aborting", connectionName);
		abort();
	}
	
	mainMachine = [[ZoomZMachine alloc] init];
	if ([client connectToDisplay: mainMachine] == nil) {
		NSLog(@"Failed to connect to view");
		abort();
	}
	
	[[NSNotificationCenter defaultCenter] addObserver: mainMachine
											 selector: @selector(connectionDied:)
												 name: NSConnectionDidDieNotification
											   object: remoteConnection];
	[[NSNotificationCenter defaultCenter] addObserver: mainMachine
											 selector: @selector(connectionDied:)
												 name: NSPortDidBecomeInvalidNotification
											   object: [remoteConnection sendPort]];
	[[NSNotificationCenter defaultCenter] addObserver: mainMachine
											 selector: @selector(connectionDied:)
												 name: NSPortDidBecomeInvalidNotification
											   object: [remoteConnection receivePort]];
	
	NSLog(@"Server connected");

	// Main runloop
        while (mainMachine != nil) @autoreleasepool {
        [mainLoop acceptInputForMode: NSDefaultRunLoopMode
                          beforeDate: [NSDate distantFuture]];
	}

#ifdef DEBUG
    NSLog(@"Finalising...");
#endif
    
    return 0;
    }
}
