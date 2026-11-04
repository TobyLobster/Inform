//
//  IFMaintenanceTask.m
//  Inform
//
//  Created by Andrew Hunter on 25/04/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import "IFMaintenanceTask.h"

NSString* const IFMaintenanceTasksStarted = @"IFMaintenanceTasksStarted";
NSString* const IFMaintenanceTasksFinished = @"IFMaintenanceTasksFinished";

@implementation IFMaintenanceTask {
    /// The task that's currently running
    NSTask* activeTask;
    /// The tasks that are going to be run
    NSMutableArray<NSArray*>* pendingTasks;
    /// Current notification type for activeTask
    NSNotificationName activeTaskNotificationType;

    /// \c YES if we've notified of a finish event
    BOOL haveFinished;
}

#pragma mark - Initialisation

+ (IFMaintenanceTask*) sharedMaintenanceTask {
	static IFMaintenanceTask* maintenanceTask = nil;
	
	if (!maintenanceTask) {
		maintenanceTask = [[IFMaintenanceTask alloc] init];
	}
	
	return maintenanceTask;
}

- (instancetype) init {
	self = [super init];
	
	if (self) {
		activeTask = nil;
        activeTaskNotificationType = nil;
		pendingTasks = [[NSMutableArray alloc] init];

		haveFinished = YES;
	}
	
	return self;
}


#pragma mark - Starting tasks

- (BOOL) startNextTask {
	if (activeTask != nil) return YES;
	if (pendingTasks.count <= 0) return NO;
	
	// Retrieve the next task to run
	NSArray* newTask = pendingTasks[0];
	[pendingTasks removeObjectAtIndex: 0];

	// Set up a new task
	activeTask = [[NSTask alloc] init];
	
	activeTask.executableURL = newTask[0];
	activeTask.arguments = newTask[1];
    activeTaskNotificationType = newTask[2];
	
    // NSLog(@"About to launch task '%@' with arguments '%@'", [newTask objectAtIndex: 0], [newTask objectAtIndex: 1]);
    
	// Register for notifications
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(taskFinished:)
												 name: NSTaskDidTerminateNotification
											   object: activeTask];
	
	// Notify anyone who's interested that we're started
	if (haveFinished) {
		[[NSNotificationCenter defaultCenter] postNotificationName: IFMaintenanceTasksStarted
															object: self];
		haveFinished = NO;
	}
	
	// Start the task
	[activeTask launch];
	return YES;
}

- (void) taskFinished: (NSNotification*) not {
	// Stop monitoring the old task
	[[NSNotificationCenter defaultCenter] removeObserver: self
													name: NSTaskDidTerminateNotification
												  object: activeTask];
	
	// Clear up the old task
	activeTask = nil;
	
	// Start the next task in the queue
	if (![self startNextTask]) {
		// We've finished!
		haveFinished = YES;
        if( activeTaskNotificationType != nil ) {
            [[NSNotificationCenter defaultCenter] postNotificationName: activeTaskNotificationType
                                                                object: self];
            activeTaskNotificationType = nil;
        }
	}
}

#pragma mark - Queuing tasks

- (void) queueTask: (NSString*) command
	 withArguments: (NSArray<NSString*>*) arguments
        notifyType: (NSNotificationName) notifyType {
    [self queueTaskAtURL: [NSURL fileURLWithPath: command]
           withArguments: arguments
              notifyType: notifyType];
}

- (void) queueTaskAtURL: (NSURL*) command
          withArguments: (NSArray<NSString*>*) arguments
             notifyType: (NSNotificationName) notifyType {

    // Check if the previous item on the queue is exactly the same command, skip if so.
    if( pendingTasks.count > 0 ) {
        NSArray* lastObject   = pendingTasks.lastObject;
        NSURL* lastCommand = lastObject[0];
        NSArray*  lastArgs    = lastObject[1];
        NSString* lastNotifyType = lastObject[2];
        
        if( lastArgs.count == arguments.count ) {
            int i = 0;
            BOOL argsEqual = YES;
            for(NSString*arg in lastArgs) {
                if( ![arg isEqualToString: arguments[i]] ) {
                    argsEqual = NO;
                    break;
                }
                i++;
            }
            if( [lastCommand isEqual: command] &&
                argsEqual &&
                [lastNotifyType isEqualToString: notifyType] ) {
                //NSLog(@"Skipping, already added to queue");
                return;
            }
        }
    }
    
	[pendingTasks addObject: @[command, arguments, notifyType]];

	[self startNextTask];
}

@end
