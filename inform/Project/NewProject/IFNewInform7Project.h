//
//  IFNewInform7Project.h
//  Inform
//
//  Created by Andrew Hunter on Sat Sep 13 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IFNewProjectProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@class IFPreferences;

///
/// Project type that creates an empty Natural Inform project
///
/// (Actually, we use the file and the current user name to generate an initial heading for the game)
///
@interface IFNewInform7Project : NSObject<IFNewProjectProtocol>

/// A project type that takes the author's name from the shared preferences
- (instancetype) init;
/// A project type that takes the author's name from the preferences given
- (instancetype) initWithPreferences: (IFPreferences*) preferences NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
