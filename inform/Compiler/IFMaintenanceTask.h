//
//  IFMaintenanceTask.h
//  Inform
//
//  Created by Andrew Hunter on 25/04/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

static NSNotificationName const IFMaintenanceTasksStarted = @"IFMaintenanceTasksStarted";

///
/// Class that deals with background maintenance tasks (particularly ni -census)
///
NS_SWIFT_UI_ACTOR
@interface IFMaintenanceTask : NSObject

/// The common maintenance task object
@property (class, atomic, readonly, strong) IFMaintenanceTask *sharedMaintenanceTask;

/// Queues a task to run the given command (with arguments)
- (void) queueTask: (NSString*) command
	 withArguments: (NSArray<NSString*>*) arguments
        notifyType: (NSNotificationName) notifyType;

@end

NS_ASSUME_NONNULL_END
