//
//  IFMaintenanceTask.h
//  Inform
//
//  Created by Andrew Hunter on 25/04/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const IFMaintenanceTasksStarted;
extern NSNotificationName const IFMaintenanceTasksFinished;

///
/// Class that deals with background maintenance tasks (particularly ni -census)
///
@interface IFMaintenanceTask : NSObject

/// The common maintenance task object
@property (class, atomic, readonly, strong) IFMaintenanceTask *sharedMaintenanceTask;

/// Queues a task to run the given command (with arguments)
- (void) queueTask: (NSString*) command
	 withArguments: (NSArray<NSString*>*) arguments
        notifyType: (NSNotificationName) notifyType;

/// Queues a task to run the given command (with arguments)
- (void) queueTaskAtURL: (NSURL*) command
          withArguments: (NSArray<NSString*>*) arguments
             notifyType: (NSNotificationName) notifyType;

@end

NS_ASSUME_NONNULL_END
