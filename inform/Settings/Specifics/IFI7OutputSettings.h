//
//  IFI7OutputSettings.h
//  Inform
//
//  Created by Andrew Hunter on 10/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFSetting.h"

NS_ASSUME_NONNULL_BEGIN

///
/// The Z-Machine (or glulx) version settings
///
@interface IFI7OutputSettings : IFSetting

@property (atomic) BOOL createBlorbForRelease;

@end

NS_ASSUME_NONNULL_END
