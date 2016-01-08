//
//  IFMaintenanceTask.h
//  Inform
//
//  Created by Andrew Hunter on 25/04/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>


extern NSString* IFMaintenanceTasksStarted;
extern NSString* IFMaintenanceTasksFinished;

///
/// Class that deals with background maintenance tasks (particularly ni -census)
///
@interface IFMaintenanceTask : NSObject

+ (IFMaintenanceTask*) sharedMaintenanceTask;					// Retrieves the common maintenance task object

- (void) queueTask: (NSString*) command							// Queues a task to run the given command (with arguments)
	 withArguments: (NSArray*) arguments
        notifyType: (NSString*) notifyType;

@end
