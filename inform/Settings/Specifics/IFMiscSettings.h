//
//  IFMiscSettings.h
//  Inform
//
//  Created by Andrew Hunter on 10/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFSetting.h"

NS_ASSUME_NONNULL_BEGIN

///
/// Some miscellaneous Inform 6 settings
///
@interface IFMiscSettings : IFSetting

@property (atomic) BOOL strict;
@property (atomic) BOOL infix;
@property (atomic) BOOL debug;

@end

NS_ASSUME_NONNULL_END
