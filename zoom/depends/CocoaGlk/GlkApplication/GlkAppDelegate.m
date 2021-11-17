//
//  GlkAppDelegate.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 18/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <GlkView/GlkHub.h>

#import "GlkAppDelegate.h"
#import "GlkWindowController.h"


@implementation GlkAppDelegate

#pragma mark - Application delegate

- (void)applicationWillFinishLaunching: (NSNotification*) aNotification {
	// Set up the hub
	[[GlkHub sharedGlkHub] setDelegate: self];
	
	[[GlkHub sharedGlkHub] setKeychainHubCookie];
	[[GlkHub sharedGlkHub] setHubName: @"CocoaGlk"];
	
#if 0
	// Start the test application (eventually we'll have a better way to do this, but for now, we do things this way)
	NSTask* testTask = [[[NSTask alloc] init] autorelease];
	NSString* taskPath = [[NSBundle mainBundle] pathForResource: @"glulxe" 
														 ofType: nil];
	
	[testTask setLaunchPath: taskPath];
	[testTask setArguments: [NSArray arrayWithObjects: @"-hubname", [[GlkHub sharedGlkHub] hubName], @"-hubcookie", [[GlkHub sharedGlkHub] hubCookie], nil]];
	
	[testTask launch];
#else
	
	// Start another task, this time using the launch facility
	GlkWindowController* control = [[GlkWindowController alloc] init];
	
	[control showWindow: self];
	[[control glkView] launchClientApplication: [[NSBundle mainBundle] pathForResource: @"glulxe" 
																				ofType: nil]
								 withArguments: nil];
#endif
}

#pragma mark - GlkHub delegate

- (id<GlkSession>) createAnonymousSession {
	return nil;
	
	GlkWindowController* control = [[GlkWindowController alloc] init];
	
	[control showWindow: self];
	
	return [control glkView];
}

@end
